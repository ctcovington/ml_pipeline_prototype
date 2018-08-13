import sys
import os
import pyarrow
import pyarrow.parquet
import pandas
import re
import shutil
import math
import numpy
import rpy2.robjects as robjects
from rpy2.robjects import pandas2ri

# define functions
def loadFeatures(data_dir, use_ecg_feats, ecg_filepath, unit_id):
    print('### loading features ###')
    # define feature filepath
    feature_filepath = os.path.join(data_dir, '01_final_features', 'full_feature_data.parquet')

    # load features
    feature_dt = pyarrow.parquet.read_table(feature_filepath).to_pandas()

    if use_ecg_feats is True:
        # read ecg features file
        print('loading ecg features')
        readRDS = robjects.r['readRDS'] # ecg file is in rds format, so define readRDS function
        ecg_dt = readRDS(ecg_filepath) # load data
        ecg_dt = pandas2ri.ri2py(ecg_dt) # convert data to a pandas data frame

        # remove extraneous identification columns
        ecg_dt.drop(columns = ['ecg_file', 'ecg_meta_file', 'npy_index'])

        # take first instance of ecg feature if multiple exist per visit
        print('keeping first instance of ecg feature when multiple exist per visit')
        ecg_dt.drop_duplicates(subset = unit_id, keep = 'first', inplace = True)

        # merge ecg_dt onto feature_dt
        print('merging ecg features onto other features')
        feature_dt = feature_dt.merge(right = ecg_dt, how = 'left', on = unit_id)

    # ensure unit_id is string
    feature_dt[unit_id] = feature_dt[unit_id].astype(str)

    print('')

    # return features
    return feature_dt

def loadAndAppendCohortInfo(feature_dt, cohort_filepath, splits, values, outcomes, names, unit_id, cluster_id):
    print('### loading cohort information and merging it onto feature data ###')
    # load cohort
    print('loading cohort')
    outcome_dt = pandas.read_csv(cohort_filepath, low_memory = False)

    # make sure id columns are strings
    outcome_dt[unit_id] = outcome_dt[unit_id].astype(str)
    outcome_dt[cluster_id] = outcome_dt[cluster_id].astype(str)

    # choose columns to keep
    keep_cols = [unit_id, cluster_id] + splits + outcomes
    keep_cols = [col for col in keep_cols if col is not 'full'] # don't include 'full'

    # keep relevant columns
    outcome_dt.drop(columns = [col for col in outcome_dt.columns if col not in keep_cols], inplace = True)

    # merge outcomes data onto features
    print('merging cohort data onto features')
    feature_dt = feature_dt.merge(right = outcome_dt, how = 'left', on = unit_id)

    # return feature data with outcomes merged on
    return feature_dt

def splitTrainEnsembleTrainHoldout(dt, train_prop, ensemble_train_prop, splits, values, outcomes, names, data_dir, cluster_id):
        print('### splitting data into train, ensemble train, and holdout sets ###')
        # define modeling data directory and reset it (delete directory and files, then remake)
        modeling_data_dir = os.path.join(data_dir, '02_modeling_data')
        if os.path.exists(modeling_data_dir):
            shutil.rmtree(modeling_data_dir)
        os.mkdir(modeling_data_dir)

        # generate list of unique cluster_id values -- we use this to define train, ensemble_train, and holdout sets
        unique_cluster_id = list(set(dt[cluster_id]))
        n = len(unique_cluster_id)

        # calculate appropriate number of unique cluster_id for each set
        train_size = math.floor(train_prop * n)
        ensemble_train_size = math.floor(ensemble_train_prop * n)
        holdout_size = n - train_size - ensemble_train_size

        # create sets of unique values of 'cluster_id' we want to include in each set
        # TODO: these are pretty slow -- could maybe be sped up by sorting lists as we go and doing binary search -- not sure how this works within a list comprehension
        print('splitting %s into sets of values needed to define each set' % cluster_id)
        train_vals = numpy.random.choice(unique_cluster_id, size = train_size, replace = True) # sample from full set of cluster ids
        unique_cluster_id = [id for id in unique_cluster_id if id not in train_vals] # remove all values sampled into training set from list of cluster ids
        ensemble_train_vals = numpy.random.choice(unique_cluster_id, size = ensemble_train_size, replace = True) # sample from restricted set of cluster ids
        holdout_vals = numpy.asarray([id for id in unique_cluster_id if id not in ensemble_train_vals]) # remove all values sampled into ensemble training set and assign remaining values to holdout set

        # create ensemble_train and holdout sets
        if len(ensemble_train_vals) > 0: # if we have ensemble train values
            print('saving ensemble train set')
            pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt.loc[dt[cluster_id].isin(ensemble_train_vals)]), os.path.join(modeling_data_dir, 'ensemble_train.parquet')) # create ensemble train set
        print('saving holdout set')
        pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt.loc[dt[cluster_id].isin(holdout_vals)]), os.path.join(modeling_data_dir, 'holdout.parquet')) # create holdout set

        # create training set and split it into its component pieces
        dt.drop(dt[dt[cluster_id].isin(numpy.concatenate([ensemble_train_vals, holdout_vals]))].index, inplace = True)

        for split, value, name in zip(splits, values, names):
            if split == 'full':
                print('saving full training set')
                pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt), os.path.join(modeling_data_dir, 'train_%s.parquet' % name))
            else:
                print('saving %s training set' % name)
                pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt.loc[dt[split] == value]), os.path.join(modeling_data_dir, 'train_%s.parquet' % name))

        return None

# define main
def main():
    # accept and manage command line arguments
    arg_len = 12 # number of expected arguments
    args = sys.argv # read in arguments

    if (len(args) - 1) != arg_len: # args also includes script name as argument, so subtract 1
        sys.stderr.write('Must supply %i arguments -- you provided %i' % arg_len, (len(args) - 1))
        sys.exit()
    else:
        cohort_filepath = str(args[1])
        print('cohort_filepath: %s' % cohort_filepath)
        splits = str(args[2])
        print('splits: %s' % splits)
        values = str(args[3])
        print('values: %s' % values)
        outcomes = str(args[4])
        print('outcomes: %s' % outcomes)
        names = str(args[5])
        print('names: %s' % names)
        ecg_filepath = str(args[6])
        print('ecg_filepath: %s' % ecg_filepath)
        use_ecg_feats = str(args[7])
        print('use_ecg_Feats: %s' % use_ecg_feats)
        train_prop = float(args[8])
        print('train_prop: %s' % train_prop)
        ensemble_train_prop = float(args[9])
        print('ensemble_train_prop: %s' % ensemble_train_prop)
        data_dir = str(args[10])
        print('data_dir: %s' % data_dir)
        unit_id = str(args[11])
        print('unit_id: %s' % unit_id)
        cluster_id = str(args[12])
        print('cluster_id: %s' % cluster_id)

        # convert use_ecg_feats to bool
        use_ecg_feats = use_ecg_feats == 'True'

        # convert multi-argument arguments to vectors
        splits = splits.split('--')
        values = [int(value) for value in values.split('--')]
        outcomes = outcomes.split('--')
        names = names.split('--')

        #  get number of arguments in each multi-argument arguments
        a = len(splits)
        b = len(values)
        c = len(outcomes)
        d = len(names)

        # ensure multi-argument arguments are the same length
        if (len(set([a,b,c,d])) != 1):
            sys.stderr.write('All multi-argument arguments must have same length')
            sys.exit()

    # load features
    feature_dt = loadFeatures(data_dir, use_ecg_feats, ecg_filepath, unit_id)

    # load cohort and append cohort information (subset markers and outcomes) to features
    print('load and append cohort information')
    full_dt = loadAndAppendCohortInfo(feature_dt, cohort_filepath, splits, values, outcomes, names, unit_id, cluster_id)

    # split data into different sets (train, ensemble_train, and holdout)
    print('split into various sets')
    splitTrainEnsembleTrainHoldout(full_dt, train_prop, ensemble_train_prop, splits, values, outcomes, names, data_dir, cluster_id)

    return None

# execute
if __name__ == '__main__':
    main()
