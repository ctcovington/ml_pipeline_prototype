import sys
import os
import pyarrow
import pyarrow.parquet
import pandas
import shutil
from joblib import Parallel, delayed

# define functions
def subsetAndSave(filename, data_directory, output_directory, unit_id, count_files, non_count_files, missingness_threshold_count, missingness_threshold_non_count):
    print('subset and save %s' % filename)
    # read features
    dt = pyarrow.parquet.read_table(os.path.join(data_directory, filename)).to_pandas()

    # identify unit_id column and make consistent across files
    unit_id_name = [colname for colname in list(dt) if unit_id in colname] # get column names that are similar to our specified unit_id

    if len(unit_id_name) != 1: # exit script if there is not exactly one variable name in 'dt' containing unit_id
        print('%s has multiple variable names containing \'%s\'\n' % (filename, unit_id))
        sys.exit()

    unit_id_name = unit_id_name[0] # we now know unit_id_name has only one element, so we unlist it

    dt.rename(columns = {unit_id_name:unit_id}, inplace = True) # rename unit_id column to be consistent across all files

    ### subset columns based on missingness ###
    # identify proportion missing for each column
    n,m = dt.shape # number of rows and columns
    prop_missing = dt.isnull().sum() / n # get proportion missing for each

    # identify whether file is 'count' or 'non_count'
    file_prefix = filename.split('_t')[0] # get beginning of filename up to first '_t', which is our marker for 'time_period' -- this should cover any files that are 'count_files'
    if file_prefix == filename:
        file_prefix = filename.split('_')[0] # get beginning of filename up to first '_' -- this should cover any files that are 'non_count_files'

    # set missingness thresholds based on whether file is a 'count' or 'non-count' file and identify whether or not each column has 'low missingness'
    if file_prefix in count_files:
        low_miss = prop_missing < missingness_threshold_count
    elif file_prefix in non_count_files:
        low_miss = prop_missing < missingness_threshold_non_count
    else:
        print('Error: file prefix not included in \'count_files\' or \'non_count_files\'')
        sys.exit()

    # subset to columns with low missingness
    dt = dt.loc[:, low_miss] # uses boolean values generated in low_miss above to subset columns

    # impute missing values. Perform zero imputation for count files and median imputation for non-count files
    if file_prefix in count_files:
        dt.fillna(0)
    elif file_prefix in non_count_files:
        for column in dt:
            dt[column].fillna(dt[column].median())

    # write subset version to file
    pyarrow.parquet.write_table(pyarrow.Table.from_pandas(dt), os.path.join(output_directory, filename))

    return None

# define main
def main():
    # accept and manage command line arguments
    arg_len = 6 # number of expected arguments
    args = sys.argv # read in arguments

    if (len(args) - 1) != arg_len: # args also includes script name as argument, so subtract 1
        sys.stderr.write('Must supply %i arguments -- you provided %i' % arg_len, (len(args) - 1))
        sys.exit()
    else:
        data_dir = str(args[1])
        print('data_dir: %s' % data_dir)
        unit_id = str(args[2])
        print('unit_id: %s' % unit_id)
        count_files = str(args[3])
        print('count_files: %s' % count_files)
        non_count_files = str(args[4])
        print('non_count_files: %s' % non_count_files)
        missingness_threshold_count = float(args[5])
        print('missingness_threshold_count: %s' % missingness_threshold_count)
        missingness_threshold_non_count = float(args[6])
        print('missingness_threshold_non_count: %s' % missingness_threshold_non_count)

    # convert multi-argument arguments to vectors
    count_files = count_files.split('--')
    non_count_files = non_count_files.split('--')

    # create directory for subsets of raw feature data
    subset_dir = os.path.join(data_dir, '01_final_features')
    if os.path.exists(subset_dir):
        shutil.rmtree(subset_dir)
    os.makedirs(subset_dir)

    # loop over feature files and subset
    raw_feature_dir = os.path.join(data_dir, '00_raw_features')
    Parallel(n_jobs = len(os.listdir(raw_feature_dir)))(delayed(subsetAndSave)(filename = filename, data_directory = raw_feature_dir, output_directory = subset_dir, unit_id = unit_id, count_files = count_files, non_count_files = non_count_files, missingness_threshold_count = missingness_threshold_count, missingness_threshold_non_count = missingness_threshold_non_count) for filename in os.listdir(raw_feature_dir))

    return None

# execute main
if __name__ == '__main__':
    main()
