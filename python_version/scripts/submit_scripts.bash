#!/bin/bash

# create log directory
rm -rf /data/zolab/general_ml_pipeline/python_version/log/
mkdir -p /data/zolab/general_ml_pipeline/python_version/log/

# 00_csv_to_parquet
bsub -o /data/zolab/general_ml_pipeline/python_version/log/00_csv_to_parquet.out -e /data/zolab/general_ml_pipeline/python_version/log/00_csv_to_parquet.err -J '00_csv_to_parquet' -q big -R "rusage[mem=10000]" python /data/zolab/general_ml_pipeline/python_version/scripts/00_csv_to_parquet.py '/data/zolab/edw_cohort_data/bwh_ed_2010_2015/features/2018_05_14/' '/data/zolab/general_ml_pipeline/python_version/parquet_files/'

# 01_subset_save
# bsub -o /data/zolab/general_ml_pipeline/python_version/log/01_subset_and_save.out -e /data/zolab/general_ml_pipeline/python_version/log/01_subset_and_save.err -w "done(00_csv_to_parquet)" -J '01_subset_and_save' -q big -R "rusage[mem=10000]" python /data/zolab/general_ml_pipeline/python_version/scripts/01_subset_and_save.py '/data/zolab/general_ml_pipeline/python_version/parquet_files/' 'ed_enc_id' 'dia--ed_enc--enc--lab--lvs--med--prc' 'dem' '0.01' '0.01'
bsub -o /data/zolab/general_ml_pipeline/python_version/log/01_subset_and_save.out -e /data/zolab/general_ml_pipeline/python_version/log/01_subset_and_save.err  -J '01_subset_and_save' -q big -R "rusage[mem=10000]" python /data/zolab/general_ml_pipeline/python_version/scripts/01_subset_and_save.py '/data/zolab/general_ml_pipeline/python_version/parquet_files/' 'ed_enc_id' 'dia--ed_enc--enc--lab--lvs--med--prc' 'dem' '0.01' '0.01'

# 02_merge_subsets
bsub -o /data/zolab/general_ml_pipeline/python_version/log/02_merge_subsets.out -e /data/zolab/general_ml_pipeline/python_version/log/02_merge_subsets.err  -J '02_merge_subsets' -q big -R "rusage[mem=30000]" python /data/zolab/general_ml_pipeline/python_version/scripts/02_merge_subsets.py '/data/zolab/general_ml_pipeline/python_version/parquet_files/' 'ed_enc_id'

# 03_create_modeling_data
bsub -o /data/zolab/general_ml_pipeline/python_version/log/03_create_modeling_data.out -e /data/zolab/general_ml_pipeline/python_version/log/03_create_modeling_data.err  -J '03_create_modeling_data' -q big -R "rusage[mem=30000]" python /data/zolab/general_ml_pipeline/python_version/scripts/03_create_modeling_data.py '/data/zolab/general_ml_pipeline/cohort_data/joint_outcome.csv' 'full--untested--tested' '0--1--1' 'joint_outcome--mace--int' 'joint_outcome--untested_mace--tested_int' '/data/zolab/stressed_ensemble/data/ecg_feats/ecg_int_hats.rds' 'False' '0.77' '0.03' '/data/zolab/general_ml_pipeline/python_version/parquet_files' 'ed_enc_id' 'ptid'

# 04_create_models

# 05_create_ensemble_model

# 06_post_modeling_analysis
