import os
import pyarrow
import pyarrow.parquet
import pandas
import sys
from joblib import Parallel, delayed

def convertCSVToParquet(filename, input_directory, output_directory):
    '''
    Converts a csv file to parquet format

    Args:
        filename: basename of csv file we want to convert to parquet
        input_directory: directory containing the file represented in 'filename'
        output_directory: directory to which we want to write the parquer version of the file

    Returns:
        None
    '''
    print('converting %s to parquet' % filename)
    dt = pandas.read_csv(os.path.join(input_directory, filename)) # read features file as pandas data frame
    table = pyarrow.Table.from_pandas(dt) # convert pandas data frame to table
    pyarrow.parquet.write_table(table, os.path.join(output_directory, filename.replace('.csv', '.parquet'))) # write table as parquet file
    return None

def main():
    # accept and manage command line arguments
    arg_len = 2 # number of expected arguments
    args = sys.argv # read in arguments

    if (len(args) - 1) != arg_len: # args also includes script name as argument, so subtract 1
        print('Must supply %i arguments -- you provided %i' % arg_len, (len(args) - 1))
        sys.exit()
    else:
        feature_dir = str(args[1])
        print('feature_dir: %s' % feature_dir)
        data_dir = str(args[2])
        print('data_dir: %s' % data_dir)

    # create directories to which we write parquet files
    if not os.path.exists(data_dir):
        os.mkdir(data_dir)
    if not os.path.exists(os.path.join(data_dir, '00_raw_features')):
        os.mkdir(os.path.join(data_dir, '00_raw_features'))

    # loop over files and convert them to parquet
    Parallel(n_jobs = len(os.listdir(feature_dir)))(delayed(convertCSVToParquet)(filename = filename, input_directory = feature_dir, output_directory = os.path.join(data_dir, '00_raw_features')) for filename in os.listdir(feature_dir) if 'stats' not in filename and filename.endswith('csv'))

# execute main
if __name__ == '__main__':
    main()
