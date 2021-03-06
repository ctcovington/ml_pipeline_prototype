import sys
import os
import pyarrow
import pyarrow.parquet
import pandas
import shutil
import sklearn.metrics
import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt

# define functions
def outputROC(dt, prediction_col_name, outcome_col_name, output_dir):
    fpr, tpr, threshold = sklearn.metrics.roc_curve(dt[outcome_col_name], dt[prediction_col_name])
    roc_auc = sklearn.metrics.auc(fpr, tpr)

    plt.title('Ensemble Model ROC')
    plt.plot(fpr, tpr, 'b', label = 'AUC = %0.2f' % roc_auc)
    plt.legend(loc = 'lower right')
    plt.plot([0, 1], [0, 1],'r--')
    plt.xlim([0, 1])
    plt.ylim([0, 1])
    plt.ylabel('True Positive Rate')
    plt.xlabel('False Positive Rate')
    plt.savefig(os.path.join(output_dir, 'ensemble_roc.png'), bbox_inches = 'tight')

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
        performance_outcome = str(args[1])
        print('performance_outcome: %s' % performance_outcome)
        data_dir = str(args[2])
        print('data_dir: %s' % data_dir)
        output_dir = str(args[3])
        print('output_dir: %s' % output_dir)
        performance_model_name = str(args[4])
        print('performance_model_name: %s')
        performance_split = str(args[5])
        print('performance_split: %s')
        performance_split_value = int(args[6])
        print('performance_split_value: %s')

        # reset output directory
        if os.path.exists(output_dir):
            shutil.rmtree(output_dir)
        os.mkdir(output_dir)

    # load holdout data
    if performance_model_name == 'ensemble':
        holdout_dt = pyarrow.parquet.read_table(os.path.join(data_dir, '03_data_with_predictions', 'holdout_with_predictions_including_ensemble.parquet')).to_pandas()
    else:
        holdout_dt = pyarrow.parquet.read_table(os.path.join(data_dir, '03_data_with_predictions', 'holdout_with_predictions_including_ensemble.parquet')).to_pandas()

    # subset data to portion on which we will evaluate model
    if performance_split != 'full':
        holdout_dt.drop(holdout_dt[holdout_dt[performance_split] != performance_split_value].index, inplace=True)

    # create ROC curve
    outputROC(dt = holdout_dt, prediction_col_name = '%s_ensemble_prediction' % performance_outcome, outcome_col_name = performance_outcome, output_dir = output_dir)

    return None

# execute main
if __name__ == '__main__':
    main()
