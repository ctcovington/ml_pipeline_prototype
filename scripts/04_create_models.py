import sys
import os
import pyarrow
import pyarrow.parquet
import pandas
import shutil
import itertools
import xgboost
import sklearn
from sklearn import linear_model

# define functions
def flatten(list):
    '''
    Given a list, possibly nested to any level, return it flattened
    '''
    new_list = []
    for item in list:
        if type(item) == type([]):
            new_list.extend(flatten(item))
        else:
            new_list.append(item)
    return new_list

def loadData(data_dir, names):
    # initialize dictionary of data
    dt_dict = dict()

    # read in data sets (train, ensemble_train, holdout)
    for name in names:
        print('loading %s data' % name)
        dt_dict[name + '_dt'] = pyarrow.parquet.read_table(os.path.join(data_dir, '02_modeling_data', 'train_%s.parquet' % name)).to_pandas()

    if 'ensemble_train.parquet' in os.listdir(os.path.join(data_dir, '02_modeling_data')):
        print('loading ensemble_train data')
        dt_dict['ensemble_train_dt'] = pyarrow.parquet.read_table(os.path.join(data_dir, '02_modeling_data', 'ensemble_train.parquet')).to_pandas()

    print('loading holdout data')
    dt_dict['holdout_dt'] = pyarrow.parquet.read_table(os.path.join(data_dir, '02_modeling_data', 'holdout.parquet')).to_pandas()

    return dt_dict

def makeAndRunModels(dt_dict, splits, outcomes, names, model_types, data_dir, model_dir, unit_id, cluster_id, learning_rate, obj, scale_pos_weight, eval_metric, max_depth, nround, colsample_bytree, seed):
    # create lists that will contain prediction column names and values to be added to ensemble_train and holdout sets after creating all models
    prediction_col_names = [] # this will serve as a list of names of columns including model predictions -- we need to track them because they are added to our data set as we iterate over the model creation, but we don't want them included as predictors
    ensemble_train_prediction_cols = [] # list to hold prediction lists
    holdout_prediction_cols = [] # list to hold prediction lists

    # for each training set, train the model and predict on the ensemble_train and holdout sets
    for outcome, name, model_type in zip(outcomes, names, model_types):
        # identify data sets
        # NOTE: with a little more though, ensemble_train_dt and holdout_dt could probably be copied outside of the for loop, though this shouldn't that big a deal -- it is not currently being done because extraneous columns are dropped below
        train_dt = dt_dict[name + '_dt'].copy()
        ensemble_train_dt = dt_dict['ensemble_train_dt'].copy()
        holdout_dt = dt_dict['holdout_dt'].copy()

        # remove extraneous outcome columns, as well as ID columns
        other_outcomes = [elem for elem in outcomes if elem != outcome]
        extra_cols = flatten([other_outcomes] + [splits] + [unit_id] + [cluster_id])
        remove_cols = [col for col in extra_cols if col in train_dt.columns]
        train_dt.drop(columns = remove_cols, inplace = True)
        ensemble_train_dt.drop(columns = remove_cols, inplace = True)
        holdout_dt.drop(columns = remove_cols, inplace = True)

        # store features and outcome separately
        feature_cols = [col for col in train_dt.columns if col != outcome]

        # run lasso if specified to do so
        if 'lasso' in model_type:
            # define data
            train_X = train_dt[feature_cols].values
            ensemble_train_X = ensemble_train_dt[feature_cols].values
            holdout_X = holdout_dt[feature_cols].values
            train_Y = train_dt[outcome].values

            # define lasso model
            lasso = sklearn.linear_model.LogisticRegression(penalty = 'l1', solver = 'liblinear')

            # fit lasso on training data
            lasso.fit(train_X, train_Y)

            # use lasso to predict outcome in ensemble_train and holdout
            ensemble_train_predictions = lasso.predict_proba(ensemble_train_X)[:,0]
            holdout_predictions = lasso.predict_proba(holdout_X)[:,0]

            # add prediction columns and column names to respective lists
            prediction_col_names.append('%s_lasso_prediction' % name)
            ensemble_train_prediction_cols.append(ensemble_train_predictions)
            holdout_prediction_cols.append(holdout_predictions)

        # run gradient boosted tree if specified to do so
        if 'gbt' in model_type:
            # define data
            train_xgb_data = xgboost.DMatrix(data = train_dt[feature_cols], label = train_dt[outcome])
            ensemble_train_xgb_data = xgboost.DMatrix(data = ensemble_train_dt[feature_cols])
            holdout_xgb_data = xgboost.DMatrix(data = holdout_dt[feature_cols])

            # define tree parameters
            params = {'learning_rate': learning_rate,
                      'obj': obj,
                      'scale_pos_weight': scale_pos_weight,
                      'eval_metric': eval_metric,
                      'max_depth': max_depth,
                      'colsample_bytree': colsample_bytree,
                      'seed': seed}

            # train model
            xgb = xgboost.train(params, train_xgb_data, nround)

            # use gradient boosted tree to predict outcome in ensemble_train and holdout
            ensemble_train_predictions = xgb.predict(ensemble_train_xgb_data)
            holdout_predictions = xgb.predict(holdout_xgb_data)

            # add prediction columns and column names to respective lists
            prediction_col_names.append('%s_gbt_prediction' % name)
            ensemble_train_prediction_cols.append(ensemble_train_predictions)
            holdout_prediction_cols.append(holdout_predictions)

    # add predictions to ensemble_train and holdout sets
    for name, ensemble_predict, holdout_predict in zip(prediction_col_names, ensemble_train_prediction_cols, holdout_prediction_cols):
        dt_dict['ensemble_train_dt'][name] = ensemble_predict
        dt_dict['holdout_dt'][name] = holdout_predict

    # return dictionary of data tables with updated prediction columns in each set
    return dt_dict

# define main
def main():
    # accept and manage command line arguments
    arg_len = 16 # number of expected arguments
    args = sys.argv # read in arguments

    if (len(args) - 1) != arg_len: # args also includes script name as argument, so subtract 1
        sys.stderr.write('Must supply %i arguments -- you provided %i' % arg_len, (len(args) - 1))
        sys.exit()
    else:
        splits = str(args[1])
        print('splits: %s' % splits)
        outcomes = str(args[2])
        print('outcomes: %s' % outcomes)
        names = str(args[3])
        print('names: %s' % names)
        model_types = str(args[4])
        print('model_types: %s' % model_types)
        data_dir = str(args[5])
        print('data_dir: %s' % data_dir)
        model_dir = str(args[6])
        print('model_dir: %s' % model_dir)
        unit_id = str(args[7])
        print('unit_id: %s' % unit_id)
        cluster_id = str(args[8])
        print('cluster_id: %s' % cluster_id)
        learning_rate = float(args[9])
        print('learning_rate: %s' % learning_rate)
        obj = str(args[10])
        print('obj: %s' % obj)
        scale_pos_weight = float(args[11])
        print('scale_pos_weight: %s' % scale_pos_weight)
        eval_metric = str(args[12])
        print('eval_metric: %s' % eval_metric)
        max_depth = int(args[13])
        print('max_depth: %s' % max_depth)
        nround = int(args[14])
        print('nround: %s' % nround)
        colsample_bytree = float(args[15])
        print('colsample_bytree: %s' % colsample_bytree)
        seed = int(args[16])
        print('seed: %s' % seed)

        # convert multi-argument arguments to vectors
        splits = splits.split('--')
        outcomes = outcomes.split('--')
        names = names.split('--')
        model_types = model_types.split('--')

        #  get number of arguments in each multi-argument arguments
        a = len(splits)
        b = len(outcomes)
        c = len(names)
        d = len(model_types)

        # ensure multi-argument arguments are the same length
        if (len(set([a,b,c,d])) != 1):
            sys.stderr.write('All multi-argument arguments must have same length')
            sys.exit()

    # define prediction data directory and reset it (delete directory and files, then remake)
    prediction_data_dir = os.path.join(data_dir, '03_data_with_predictions')
    if os.path.exists(prediction_data_dir):
        shutil.rmtree(prediction_data_dir)
    os.mkdir(prediction_data_dir)

    # reset model directory
    if os.path.exists(model_dir):
        shutil.rmtree(model_dir)
    os.mkdir(model_dir)

    # load training data
    dt_dict = loadData(data_dir, names)

    # for each training set, train models and predict on the ensemble_train and holdout sets
    dt_dict = makeAndRunModels(dt_dict, splits, outcomes, names, model_types, data_dir, model_dir, unit_id, cluster_id, learning_rate, obj, scale_pos_weight, eval_metric, max_depth, nround, colsample_bytree, seed)

    # save new ensemble_train and holdout data with predictions included
    pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt_dict['ensemble_train_dt']), os.path.join(prediction_data_dir, 'ensemble_train_with_predictions.parquet'))
    pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt_dict['holdout_dt']), os.path.join(prediction_data_dir, 'holdout_with_predictions.parquet'))

    return None

# execute
if __name__ == '__main__':
    main()
