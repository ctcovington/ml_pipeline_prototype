import sys
import os
import pyarrow
import pyarrow.parquet
import pandas
import sklearn
from sklearn import linear_model
from sklearn.externals import joblib

# define functions
def createEnsembleModel(ensemble_outcome, names, model_types, data_dir, model_dir):
    # define filepath for data with predictions
    prediction_data_dir = os.path.join(data_dir, '03_data_with_predictions')

    # load ensemble_train and holdout data
    ensemble_train_dt = pyarrow.parquet.read_table(os.path.join(prediction_data_dir, 'ensemble_train_with_predictions.parquet')).to_pandas()
    holdout_dt = pyarrow.parquet.read_table(os.path.join(prediction_data_dir, 'holdout_with_predictions.parquet')).to_pandas()

    # define features and outcome in each data set
    feature_cols = ['%s_%s_prediction' % (name, model_type) for name, model_type in zip(names, model_types)] # define right hand side variables
    ensemble_train_X = ensemble_train_dt[feature_cols].values
    ensemble_train_Y = ensemble_train_dt[ensemble_outcome].values
    holdout_X = holdout_dt[feature_cols].values

    # fit ensemble model on ensemble_train
    lm = sklearn.linear_model.LinearRegression(fit_intercept = False) # define model
    ensemble_model = lm.fit(ensemble_train_X, ensemble_train_Y)

    # predict ensemble outcome on holdout set
    holdout_predictions = lm.predict(holdout_X)
    holdout_dt['%s_ensemble_prediction' % ensemble_outcome] = holdout_predictions
    holdout_dt['%s_ensemble_prediction' % ensemble_outcome].clip(lower = 0, upper = 1, inplace = True) # censor predictions so that they are on [0,1]

    # save ensemble model
    sklearn.externals.joblib.dump(ensemble_model, os.path.join(model_dir, 'ensemble.pkl'))

    # save holdout data with ensemble predictions
    pyarrow.parquet.write_table(pyarrow.Table.from_pandas(holdout_dt), os.path.join(prediction_data_dir, 'holdout_with_predictions_including_ensemble.parquet'))
    holdout_dt.to_csv(os.path.join(prediction_data_dir, 'holdout_with_predictions_including_ensemble.csv')

    return None

# define main
def main():
    # accept and manage command line arguments
    arg_len = 5 # number of expected arguments
    args = sys.argv # read in arguments

    if (len(args) - 1) != arg_len: # args also includes script name as argument, so subtract 1
        sys.stderr.write('Must supply %i arguments -- you provided %i' % arg_len, (len(args) - 1))
        sys.exit()
    else:
        ensemble_outcome = str(args[1])
        print('ensemble_outcome: %s' % ensemble_outcome)
        names = str(args[2])
        print('names: %s' % names)
        model_types = str(args[3])
        print('model_types: %s' % model_types)
        data_dir = str(args[4])
        print('data_dir: %s' % data_dir)
        model_dir = str(args[5])
        print('model_dir: %s' % model_dir)

        # convert multi-argument arguments to vectors
        names = names.split('--')
        model_types = model_types.split('--')

        #  get number of arguments in each multi-argument arguments
        a = len(names)
        b = len(model_types)

        # ensure multi-argument arguments are the same length
        if (len(set([a,b])) != 1):
            sys.stderr.write('All multi-argument arguments must have same length')
            sys.exit()

    # create ensemble model and use it to predict on holdout set
    createEnsembleModel(ensemble_outcome, names, model_types, data_dir, model_dir)

    return None

# execute main
if __name__ == '__main__':
    main()
