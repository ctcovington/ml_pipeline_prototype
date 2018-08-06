# General ML Pipeline
Repository for machine learning pipeline code

<hr>

## Table of Contents
1. [Project Overview](#Project_Overview)
2. [File Structure](#Directory_Structure)
3. [Running the Pipeline](#Running_the_Pipeline)

<hr>

### Project Overview <a name='Project_Overview'></a>
Broadly speaking, the pipeline takes a cohort and associated features, builds an ensemble model, and assesses model performance.

<hr>

### File Structure <a name='File_Structure'></a>
- `cluster.json`: configuration file for submitting jobs to a computing cluster
- `conda_env.yaml`: configuration file to create conda environment for running pipeline
- `config.yaml`: configuration file containing  all parameters necessary to run pipeline
- `run_pipeline.sh`: bash script that runs pipeline
- `Snakefile`: snakemake file that specifies rules (tasks to be completed)
- `scripts/`: contains all the R code that actually makes up the pipeline

<hr>

### Running the Pipeline <a name='Running_the_Pipeline'></a>
You can (hopefully) run the entire pipeline with a single command:

```console
bash run_pipeline.sh
```

<hr>
