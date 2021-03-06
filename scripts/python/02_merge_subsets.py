import sys
import os
import pyarrow
import pyarrow.parquet
import pandas
import functools

# define functions
def mergeSubsets(data_directory, unit_id):
    subsets = []
    for filename in os.listdir(data_directory):
        if filename == 'full_feature_data.parquet': # make sure we don't merge on the full feature data if it has already been created
            continue
        print('load %s' % filename)
        dt = pyarrow.parquet.read_table(os.path.join(data_directory, filename)).to_pandas()
        subsets.append(dt)
    print('merging all subsets')
    return functools.reduce(lambda left_dt, right_dt: pandas.merge(left_dt, right_dt, how = 'outer', on = unit_id), subsets)

# define main
def main():
    # accept and manage command line arguments
    arg_len = 2 # number of expected arguments
    args = sys.argv # read in arguments

    if (len(args) - 1) != arg_len: # args also includes script name as argument, so subtract 1
        sys.stderr.write('Must supply %i arguments -- you provided %i' % arg_len, (len(args) - 1))
        sys.exit()
    else:
        data_dir = str(args[1])
        print('data_dir: %s' % data_dir)
        unit_id = str(args[2])
        print('unit_id: %s' % unit_id)

    # identify files that need to be merged and merge them
    feature_dir = os.path.join(data_dir, '01_final_features') # directory holding files to be merged
    merged_dt = mergeSubsets(data_directory = feature_dir, unit_id = unit_id)

    # Impute missing values. Perform 0 imputation for count variables, median imputation for non-count variables
    # TODO: this is quite slow, might be a better way
    for colname in merged_dt.columns:
        if colname.split('_t')[0] == colname: # identify whether or not variable name has '_t', our marker for a 'count' variable
            merged_dt[colname] = merged_dt[colname].fillna(0).astype('int64')
        else:
            merged_dt[colname] = merged_dt[colname].fillna(int(merged_dt[colname].median()))

    # write merged version to file
    print('write merged data to full_feature_data.parquet')
    pyarrow.parquet.write_table(pyarrow.Table.from_pandas(merged_dt), os.path.join(feature_dir, 'full_feature_data.parquet'))

    return None

# execute main
if __name__ == '__main__':
    main()
