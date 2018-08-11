#!/bin/bash

# 01_subset_save
bsub -q big -R "rusage[mem=20000]" python scripts/python/01_subset_and_save.py ''

# 00_csv_to_parquet
bsub -q big -R "rusage[mem=8000]" python scripts/python/00_csv_to_parquet.py '/data/zolab/edw_cohort_data/bwh_ed_2010_2015/features/2018_05_14/' '/data/zolab/general_ml_pipeline/parquet_files/'
