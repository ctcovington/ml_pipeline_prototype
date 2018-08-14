# General ML Pipeline
Repository for machine learning pipeline code

<hr>

## Table of Contents
0. [State of the Project](#State_of_the_Project)
1. [Project Overview](#Project_Overview)
2. [File Structure](#Directory_Structure)
3. [Data Setup](#Data_Setup)
4. [Running the Pipeline](#Running_the_Pipeline)

<hr>

### State of the Project <a name='State_of_the_Project'></a>
As of 8.6.18, the project should contain the general structure necessary to go from a cohort file and features generated via the features pipeline to a set of models/predictions. The next step, as Christian sees it, is to finish the features pipeline (to the extent possible) and then test this pipeline on some data.

Once this has been done, there are some things that could be useful for someone to add in the future. This is by no means an exhaustive list, and future users should think of things that would be useful and either note them here or add the features themselves!

- [ ] We are not sure if the conda environment sourcing actually passes the correct package versions to R, because it happens outside of the batch mode submissions of the R scripts. One solution would be to submit bash scripts as batch jobs (and have the bash scripts load the conda environment and run the R script) -- we believe this would require the bash scripts to read in the variables for each R script from `config.yaml`. Another possibility is that we wrap the whole Snakfile process in a bash script and run each R script within normally, but we think this would hinder our ability to use different cluster configurations (i.e. amount of RAM, cores, etc.) for different parts of the pipeline
- [ ] Rewrite R scripts into python. This will align with the (possible) goal of becoming a python-focused lab, and will pair more naturally with Snakemake as a workflow management system. Christian is starting on this but likely will not be able to finish before 8.17.18.
- [ ] ecg file appears to have extraneous columns we wouldn't want in the model (`ecg_file`, `ecg_meta_file`, `npy_index`) -- these are removed in the python version, but we should make sure that this is correct -- additionally, ecg file has at least one variable (`Remarks`) that is a string, and this will not be usable by our ml models
- [ ] Set data types in `count_files` to be integers (except for `unit_id`) early in the process **NOTE: this should be done now, check on this though**
- [ ] Add various capabilities/details to training set generation (e.g. allow for up/downsampling of some group)
- [ ] Add more model diagnostics/analysis
- [ ] `run_pipeline.sh` and `cluster.json` are both currently configured for running on lsf clusters only -- this should be generalized (particularly if we move to the cloud)

<hr>

### Project Overview <a name='Project_Overview'></a>
Broadly speaking, the pipeline takes a cohort and associated features, builds an ensemble model, and assesses model performance.

The pipeline should work for any features that were generated via the [features pipeline](../standard_features).

<hr>

### File Structure <a name='File_Structure'></a>
- `cluster.json`: configuration file for submitting jobs to a computing cluster
- `conda_env.yaml`: configuration file to create conda environment for running the pipeline
- `config.yaml`: configuration file containing  all parameters necessary to run pipeline
- `run_pipeline.sh`: bash script that runs pipeline
- `Snakefile`: snakemake file that specifies rules (tasks to be completed)
- `scripts/`: contains all the R code that actually makes up the pipeline

<hr>

### Data Setup <a name='Data_Setup'></a>
The features file coming from the [features pipeline](../standard_features) should be standardized enough to work with this pipeline out of the box. You will, however, have to ensure that your cohort file meets the appropriate specifications. In particular, the cohort file (the file you will use as `cohort_filepath` in `config.yaml`) must have variables defining each subset of the data on which you would like to train separately, as well as outcomes on each. The easiest way to set this up is to have each be a binary variable, specifying whether or not the observations belongs to the subset in question or had the outcome in question.

<hr>

### Running the Pipeline <a name='Running_the_Pipeline'></a>
Christian recommends first cloning this repository wherever you need it

```console
cd <directory_where_you_want_project>
git clone git@gitlab.com:labsysmed/zolab-projects/ml_pipeline.git ./
```

Then, edit the `config.yaml` and `cluster.json` as necessary. `config.yaml` will certainly need to be edited with the parameters for your project. `cluster.json` may be fine as is -- you should edit if you are not working on an lsf cluster (i.e. one where you can submit jobs with `bsub`), or if you believe you will need different amounts of RAM from what is specified in the configuration file.

Finally, you should be able to run the entire pipeline with a single command:

```console
bash run_pipeline.sh
```

This will load the appropriate conda environment and run the pipeline (specifically, it will submit batch jobs for each rule defined in `Snakefile`).

<hr>
