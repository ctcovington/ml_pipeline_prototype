### load configuration ###
import os
import glob
import yaml

# create name of log file and reset it if it exists
logfile = os.path.join(os.getcwd(), 'pipeline.log')
if os.path.exists(logfile):
    os.remove(logfile)

# load configuration file as dictionary
config = yaml.load(open('config.yaml'))

# dictionary with all pairings of parameter with their grouping variable
parameter_pairings = {'feature_dir': 'feature_info',
                      'count_files': 'feature_info',
                      'non_count_files': 'feature_info',
                      'missingness_threshold_count': 'feature_info',
                      'missingness_threshold_non_count': 'feature_info',
                      'ecg_filepath': 'feature_info',
                      'use_ecg_feats': 'feature_info',
                      'cohort_filepath': 'cohort_info',
                      'unit_id': 'cohort_info',
                      'cluster_id': 'cohort_info',
                      'splits': 'modeling_info',
                      'values': 'modeling_info',
                      'outcomes': 'modeling_info',
                      'names': 'modeling_info',
                      'model_types': 'modeling_info',
                      'train_prop': 'modeling_info',
                      'ensemble_train_prop': 'modeling_info',
                      'ensemble_outcome': 'modeling_info',
                      'ensemble_performance_split': 'modeling_info',
                      'ensemble_performance_split_value': 'modeling_info',
                      'data_dir': 'pipeline_directories',
                      'model_dir': 'pipeline_directories',
                      'output_dir': 'pipeline_directories',
                      'learning_rate': 'xgboost',
                      'obj': 'xgboost',
                      'scale_pos_weight': 'xgboost',
                      'eval_metric': 'xgboost',
                      'max_depth': 'xgboost',
                      'nround': 'xgboost',
                      'colsample_bytree': 'xgboost',
                      'seed': 'xgboost'}

# create dictionary containing each parameter and its value
parameter_values = {}
for key, value in parameter_pairings.items():
    parameter_values[key] = config[value][key]

# identify relevant feature files
all_feature_files = [os.path.splitext(os.path.basename(f))[0] for f in glob.glob(parameter_values['feature_dir'] + '*.csv')]
non_stats_feature_files = [file for file in all_feature_files if 'stats' not in file]

### rules ###
rule post_modeling_analysis:
    input:
        holdout_with_predictions_including_ensemble = parameter_values['data_dir'] + '03_data_with_predictions/holdout_data_with_predictions_including_ensemble.rds'
    params:
        ensemble_outcome = parameter_values['ensemble_outcome'],
        data_dir = parameter_values['data_dir'],
        output_dir = parameter_values['output_dir'],
        ensemble_performance_split = parameter_values['ensemble_performance_split'],
        ensemble_performance_split_value = parameter_values['ensemble_performance_split_value']
    log:
        logfile
    shell:
        """
        cd scripts
        printf "perform post-modeling analysis\n" >> {log}
        R CMD BATCH --no-save --no-restore "--args {params.ensemble_outcome} {params.data_dir} {params.output_dir} {params.ensemble_performance_split} {params.ensemble_performance_split_value}" 06_post_modeling_analysis.R 06_post_modeling_analysis.Rout
        cd ..
        """

rule create_ensemble_model:
    input:
        ensemble_train_with_predictions = parameter_values['data_dir'] + '03_data_with_predictions/ensemble_train_data_with_predictions.rds',
        holdout_with_predictions = parameter_values['data_dir'] + '03_data_with_predictions/holdout_data_with_predictions.rds'
    output:
        holdout_with_predictions_including_ensemble = parameter_values['data_dir'] + '03_data_with_predictions/holdout_data_with_predictions_including_ensemble.rds'
    params:
        ensemble_outcome = parameter_values['ensemble_outcome'],
        names = parameter_values['names'],
        model_types = parameter_values['model_types'],
        data_dir = parameter_values['data_dir'],
        model_dir = parameter_values['model_dir']
    log:
        logfile
    shell:
        """
        cd scripts
        printf "create ensemble model and predict outcome\n" >> {log}
        R CMD BATCH --no-save --no-restore "--args {params.ensemble_outcome} {params.names} {params.model_types} {params.data_dir} {params.model_dir}" 05_create_ensemble_model.R 05_create_ensemble_model.Rout
        cd ..
        """

rule create_models:
    input:
        train_data = [parameter_values['data_dir'] + '02_modeling_data/train_' + outcome + '_data.rds' for outcome in parameter_values['names'].split('--')],
        ensemble_train_data = parameter_values['data_dir'] + '02_modeling_data/ensemble_train_data.rds',
        holdout_data = parameter_values['data_dir'] + '02_modeling_data/holdout_data.rds'
    output:
        ensemble_train_with_predictions = parameter_values['data_dir'] + '03_data_with_predictions/ensemble_train_data_with_predictions.rds',
        holdout_with_predictions = parameter_values['data_dir'] + '03_data_with_predictions/holdout_data_with_predictions.rds'
    params:
        splits = parameter_values['splits'],
        outcomes = parameter_values['outcomes'],
        names = parameter_values['names'],
        model_types = parameter_values['model_types'],
        data_dir = parameter_values['data_dir'],
        model_dir = parameter_values['model_dir'],
        unit_id = parameter_values['unit_id'],
        cluster_id = parameter_values['cluster_id'],
        learning_rate = parameter_values['learning_rate'],
        obj = parameter_values['obj'],
        scale_pos_weight = parameter_values['scale_pos_weight'],
        eval_metric = parameter_values['eval_metric'],
        max_depth = parameter_values['max_depth'],
        nround = parameter_values['nround'],
        colsample_bytree = parameter_values['colsample_bytree'],
        seed = parameter_values['seed']
    log:
        logfile
    shell:
        """
        cd scripts
        printf "create models and predict outcomes\n" >> {log}
        R CMD BATCH --no-save --no-restore "--args {params.splits} {params.outcomes} {params.names} {params.model_types} {params.data_dir} {params.model_dir} {params.unit_id} {params.cluster_id} {params.learning_rate} {params.obj} {params.scale_pos_weight} {params.eval_metric} {params.max_depth} {params.nround} {params.colsample_bytree} {params.seed}" 04_create_models.R 04_create_models.Rout
        cd ..
        """

rule create_modeling_data:
    input:
        cohort_filepath = parameter_values['cohort_filepath'],
        features = parameter_values['data_dir'] + '01_feature_data/full_feature_data.csv'
    output:
        train_sets = [parameter_values['data_dir'] + '02_modeling_data/train_' + name + '_data.rds' for name in parameter_values['names'].split('--')],
        ensemble_train_set = parameter_values['data_dir'] + '02_modeling_data/ensemble_train_data.rds',
        holdout_set = parameter_values['data_dir'] + '02_modeling_data/holdout_data.rds'
    params:
        cohort_filepath = parameter_values['cohort_filepath'],
        splits = parameter_values['splits'],
        values = parameter_values['values'],
        outcomes = parameter_values['outcomes'],
        names = parameter_values['names'],
        ecg_filepath = parameter_values['ecg_filepath'],
        use_ecg_feats = parameter_values['use_ecg_feats'],
        train_prop = parameter_values['train_prop'],
        ensemble_train_prop = parameter_values['ensemble_train_prop'],
        data_dir = parameter_values['data_dir'],
        unit_id = parameter_values['unit_id'],
        cluster_id = parameter_values['cluster_id']
    log:
        logfile
    shell:
        """
        cd scripts
        printf "creating modeling data\n" >> {log}
        R CMD BATCH --no-save --no-restore "--args {params.cohort_filepath} {params.splits} {params.values} {params.outcomes} {params.names} {params.ecg_filepath} {params.use_ecg_feats} {params.train_prop} {params.ensemble_train_prop} {params.data_dir} {params.unit_id} {params.cluster_id}" 03_create_modeling_data.R 03_create_modeling_data.Rout
        cd ..
        """

rule merge_subsets:
    input:
        files = expand(config['pipeline_directories']['data_dir'] + '01_feature_data/{file}.csv', file = non_stats_feature_files)
    output:
        file = config['pipeline_directories']['data_dir'] + '01_feature_data/full_feature_data.csv'
    params:
        data_dir = parameter_values['data_dir'],
        unit_id = parameter_values['unit_id']
    log:
        logfile
    shell:
        """
        cd scripts
        printf "merging together all subset files\n" >> {log}
        R CMD BATCH --no-save --no-restore "--args {params.data_dir} {params.unit_id}" 02_merge_subsets.R 02_merge_subsets.Rout
        cd ..
        """

rule subset_save:
    input:
        files = expand(parameter_values['feature_dir'] + '{file}.csv', file = non_stats_feature_files)
    output:
        files = expand(parameter_values['data_dir'] + '01_feature_data/{file}.csv', file = non_stats_feature_files)
    params:
        feature_dir = parameter_values['feature_dir'],
        data_dir = parameter_values['data_dir'],
        unit_id = parameter_values['unit_id'],
        count_files = parameter_values['count_files'],
        non_count_files = parameter_values['non_count_files'],
        missingness_threshold_count = parameter_values['missingness_threshold_count'],
        missingness_threshold_non_count = parameter_values['missingness_threshold_non_count']
    log:
        logfile
    shell:
        """
        cd scripts
        for file in {input.files}; do
             printf "subsetting and saving $(basename $file)\n" >> {log}
             R CMD BATCH --no-save --no-restore "--args $(basename $file) {params.feature_dir} {params.data_dir} {params.unit_id} {params.count_files} {params.non_count_files} {params.missingness_threshold_count} {params.missingness_threshold_non_count}" 01_subset_save.R 01_subset_save.Rout
        done
        cd ..
        """
