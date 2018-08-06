# General ML Pipeline
Repository for machine learning pipeline code

<hr>

## Table of Contents
0. [State of the Project](#State_of_the_Project)
1. [Project Overview](#Project_Overview)
2. [File Structure](#Directory_Structure)
3. [Running the Pipeline](#Running_the_Pipeline)

<hr>

### State of the Project <a name='State_of_the_Project'></a>
As of 8.6.18, the project should contain the general structure necessary to go from a cohort file and features generated via the features pipeline to a set of models/predictions. The next step, as Christian sees it, is to finish the features pipeline (to the extent possible) and then test this pipeline on some data.

Once this has been done, there are some things that could be useful for someone to add in the future. This is by no means an exhaustive list, and future users should think of things that would be useful and either note them here or add the features themselves!

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
- `conda_env.yaml`: configuration file to create conda environment for running pipeline
- `config.yaml`: configuration file containing  all parameters necessary to run pipeline
- `run_pipeline.sh`: bash script that runs pipeline
- `Snakefile`: snakemake file that specifies rules (tasks to be completed)
- `scripts/`: contains all the R code that actually makes up the pipeline

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
