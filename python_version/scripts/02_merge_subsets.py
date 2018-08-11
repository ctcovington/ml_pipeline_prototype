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
        dt = pyarrow.parquet.read_table(os.path.join(data_directory, filename)).to_pandas()
        subsets.append(dt)
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

    # write merged version to file
    pyarrow.parquet.write_table(pyarrow.Table.from_pandas(merged_dt), os.path.join(feature_dir, 'full_feature_data.parquet'))

# execute main
if __name__ == '__main__':
    main()
