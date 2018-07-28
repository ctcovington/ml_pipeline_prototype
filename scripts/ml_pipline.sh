#!/bin/bash

###############################################################################################
# Shell script that:
# 1. takes feature data, subsets it based on missingness thresholds, and saves the subset data,
# 2. merges together subsets into master feature data
# 3. perform imputation for missing values
# 4. appends outcomes of interest to the feature data and splits into training and holdout sets
# 5. creates models and generates predictions on ensemble_training set and holdout set
# 6. trains ensemble model on ensemble training set
###############################################################################################

source ../parameters.txt

####################################################################
## delete directories (if they exist) and recreate empty version ###
####################################################################
directories=(${data_dir} ${output_dir} ${model_dir})
for dir_name in "${directories[@]}"; do
    printf "resetting ${dir_name}\n"

    if [ -d "${dir_name}" ]; then
        rm -rf "${dir_name}"
    fi
    mkdir "${dir_name}"
done
printf "\n"

#####################################################
### Set up output directory and progress tracking ###
#####################################################

# copy parameters file to output directory (for record-keeping purposes) -- this will also serve as general information/tracking document
cp ../parameters.txt ${output_dir}info.txt

# transition from printing parameters to tracking current run information
printf "\n\n\n" &>> ${output_dir}info.txt
printf "####################################################\n" &>> ${output_dir}info.txt
printf "Begin tracking run\n" &>> ${output_dir}info.txt
printf "####################################################\n" &>> ${output_dir}info.txt
printf "\n\n\n" &>> ${output_dir}info.txt

start=`date '+%Y-%m-%d %H:%M:%S'`
printf "### Run began at $start ###" &>> ${output_dir}info.txt
printf "\n\n" &>> ${output_dir}info.txt

#############################################################################
### subset data based on missingness threshold and save                   ###
### NOTE: parallel version is not particularly robust to catching errors, ###
###       I suggest using the sequential version for now                  ###
#############################################################################
printf "subsetting feature sets -- keep only features with proportion missing less than $missingness_threshold_count for 'count' files and $missingness_threshold_non_count for 'non-count' files\n\n"

find $feature_dir -name "*.csv" ! -name "*stats*" -print | while read file; do
    file_no_path=$(basename $file) # filename (no path)
    printf "subsetting and saving $file_no_path\n"
    R CMD BATCH --no-save --no-restore "--args $file_no_path $feature_dir $data_dir $unit_id $count_files $non_count_files $missingness_threshold_count $missingness_threshold_non_count" 01_subset_save.R 01_subset_save.Rout
done

#######################################
### merge together all subset files ###
#######################################
printf "merging together all subset files\n"

bsub -q big -M 20000 -R "rusage[mem=20000]" -J "merge_files" R CMD BATCH --no-save --no-restore "--args $feature_dir $data_dir $unit_id"  02_merge_subsets.R 02_merge_subsets.Rout

################################################
### create modeling data (train and holdout) ###
################################################
printf "creating modeling data\n"

bsub -w "done(merge_files)" -q big -M 20000 -R "rusage[mem=20000]" -J "create_modeling_data" R CMD BATCH --no-save --no-restore "--args $cohort_filepath $splits $values $outcomes $names $ecg_filepath $use_ecg_feats $train_prop $ensemble_train_prop $data_dir $unit_id $cluster_id" 03_create_modeling_data.R 03_create_modeling_data.Rout
# bsub -q big -M 20000 -R "rusage[mem=20000]" -J "create_modeling_data" R CMD BATCH --no-save --no-restore "--args $cohort_filepath $splits $values $outcomes $names $ecg_filepath $use_ecg_feats $train_prop $ensemble_train_prop $data_dir $unit_id $cluster_id" 03_create_modeling_data.R 03_create_modeling_data.Rout


##############################################################################################
### Create individual models and add predicted outcomes to ensemble_train and holdout sets ###
##############################################################################################
printf "create models and predict outcomes\n"

bsub -w "done(create_modeling_data)" -q big -M 80000 -R "rusage[mem=80000]" -J "create_models" R CMD BATCH --no-save --no-restore "--args $splits $outcomes $names $model_types $data_dir $model_dir $unit_id $cluster_id $learning_rate $obj $scale_pos_weight $eval_metric $max_depth $nround $colsample_bytree $seed" 04_create_models.R 04_create_models.Rout
# bsub -q big -M 80000 -R "rusage[mem=80000]" -J "create_models" R CMD BATCH --no-save --no-restore "--args $splits $outcomes $names $model_types $data_dir $model_dir $unit_id $cluster_id $learning_rate $obj $scale_pos_weight $eval_metric $max_depth $nround $colsample_bytree $seed" 04_create_models.R 04_create_models.Rout

#############################
### Create ensemble model ###
#############################
printf "create ensemble model\n"

bsub -w "done(create_models)" -q big -M 20000 -R "rusage[mem=20000]" -J "create_ensemble_model" R CMD BATCH --no-save --no-restore "--args $ensemble_outcome $names $model_types $data_dir $model_dir" 05_create_ensemble_model.R 05_create_ensemble_model.Rout
# bsub -q big -M 20000 -R "rusage[mem=20000]" -J "create_ensemble_model" R CMD BATCH --no-save --no-restore "--args $ensemble_outcome $names $model_types $data_dir $model_dir" 05_create_ensemble_model.R 05_create_ensemble_model.Rout

##############################
### Post modeling analysis ###
##############################
printf "perform analysis"

bsub -w "done(create_ensemble_model)" -q big -M 20000 -R "rusage[mem=20000]" -J "model_analysis" R CMD BATCH --no-save --no-restore "--args $ensemble_outcome $data_dir $output_dir $ensemble_performance_split $ensemble_performance_split_value" 06_post_modeling_analysis.R 06_post_modeling_analysis.Rout
# bsub -q big -M 20000 -R "rusage[mem=20000]" -J "model_analysis" R CMD BATCH --no-save --no-restore "--args $ensemble_outcome $data_dir $output_dir $ensemble_performance_split $ensemble_performance_split_value" 06_post_modeling_analysis.R 06_post_modeling_analysis.Rout 
