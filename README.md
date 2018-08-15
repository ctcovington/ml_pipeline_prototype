# General ML Pipeline

<hr>

## Table of Contents
0. [State of the Project](#State_of_the_Project)
1. [Project Overview](#Project_Overview)
2. [Prerequisites](#Prerequisites)
3. [File Structure](#Directory_Structure)
4. [Data Setup](#Data_Setup)
5. [Running the Pipeline](#Running_the_Pipeline)
6. [Common Errors](#Common_Errors)
7. [Getting Help](#Getting_Help)

<hr>

### State of the Project <a name='State_of_the_Project'></a>
As of 8.15.18, the project should contain the general structure necessary to go from a cohort file and features generated via the features pipeline to a set of models/predictions. The next step is to finish the features pipeline (to the extent possible) and then test this pipeline on some data.

Once this has been done, there are some things that could be useful for someone to add in the future. This is by no means an exhaustive list, and future users should think of things that would be useful and either note them here or add the features themselves!

- [ ] ecg file appears to have extraneous columns we wouldn't want in the model (`ecg_file`, `ecg_meta_file`, `npy_index`) -- these are removed in the python version, but we should make sure that this is correct -- additionally, ecg file has at least one variable (`Remarks`) that is a string, and this will not be usable by our ml models
- [ ] Add various capabilities/details to training set generation (e.g. allow for up/downsampling of some group)
- [ ] Add more model diagnostics/analysis
- [ ] Pipeline currently requires generation of an ensemble model -- could be worthwhile to make this optional
- [ ] `run_pipeline.sh` and `cluster.json` are both currently configured for running on lsf clusters only -- this should be generalized (particularly if we move to the cloud)

<hr>

### Project Overview <a name='Project_Overview'></a>
Broadly speaking, the pipeline takes a cohort and associated features, builds an ensemble model, and assesses model performance.

The pipeline should work for any cohort (presented in a `.csv` file) and features that were generated via the [features pipeline](../standard_features) for that cohort.

<hr>

### Prerequisites <a name='Prerequisites'></a>
Because the pipeline uses conda environments, you will need to install [Anaconda 3](https://www.anaconda.com/download/#linux) beofre running the pipeline. We ask that you get the `python3` version.

<hr>

### File Structure <a name='File_Structure'></a>

#### `cluster.json`
In this file, the user can define cluster arguments for each rule in the `Snakefile`. Unless a rule is specifically named in `cluster.json`, the rule will use the `__default__` configuration.
Arguments from `cluster.json` are fed into `run_pipeline.sh`. The snakemake submission line in `run_pipeline.sh` will have a component that looks something like this:

```console
"bsub -K -q {cluster.queue} -J {cluster.name} -M {cluster.memory} -R {cluster.resources}"
```

These are the arguments read in from `cluster.json`. So, if you add an argument `x` in the configuration file, you will also need to add `{cluster.x}` to the aforementioned line in `run_pipeline.sh`

#### `conda_env.yaml`
This is a configuration file that provides the outline for the conda environment needed to run the pipeline. This conda environment is created at the top of `run_pipelines.sh`. The configuration includes the name of the environment, the conda channels it searches for necessary packages, and the list of necessary packages (and versions).

#### `config.yaml`
This is a configuration file containing all parameters necessary to run pipeline. Parameters are grouped based on their function (e.g. `feature_info`, `cohort_info`, etc.), and the file contains comments regarding their definitions and use.

#### `run_pipeline.sh`
This is a bash script that runs the entire pipeline.

#### `Snakefile`
This snakemake file specifies rules (tasks to be completed) and generally serves as the core file that defines the general framework of the pipeline.

`Snakefile` runs from top to bottom and begins by importing `config.yaml`, storing the pipeline parameters in a dictionary, and defining a few other important variables.

The file then proceeds to the rules. Each rule inside the snakefile represents a different script from the `scripts` directory, and a different step in the pipeline. Each rule has specified input and output files, parameters to pass to the script when executed, and shell commands to be run. Rules are listed in reverse order of how the pipeline will run (so the rule corresponding to the final script is at the top, and the rule corresponding to the first script is at the bottom). This is because when snakemake reaches a given rule, it checks for existence and creation datetime of that rule's input files. If the input files were updated more recently than the output files, then that rule will run. This ensures that the pipeline is always running exactly the right number of rules to get the most recent version of all files in the pipeline.

#### `scripts/`
This directory contains all the python code that actually makes up the pipeline. The files are as follows:
- `00_csv_to_parquet.py`
    - takes raw csv feature files and creates parquet versions
- `01_subset_and_save.py`
    - takes parquet feature files and subsets them based on missingness thresholds
- `02_merge_subsets.py`
    - merges all subsets together into master feature file
- `03_create_modeling_data.py`
    - merges standard features and ecg features if necessary
    - creates train, ensemble_train, and holdout sets
- `04_create_models.py`
    - trains models on each training set
    - uses models to predict outcomes on ensemble_train and holdout sets
- `05_create_ensemble_model.py`
    - trains ensemble model on ensemble_train set
    - uses model to predict outcomes on holdout set
- `06_post_modeling_analysis.py`
    - performs model analysis on holdout set
- `userutil.py`
    - user-created module that defines functions used in other scripts

<hr>

### Data Setup <a name='Data_Setup'></a>
The features file coming from the [features pipeline](../standard_features) should be standardized enough to work with this pipeline out of the box. You will, however, have to ensure that your cohort file meets the appropriate specifications. In particular, the cohort file (the file you will use as `cohort_filepath` in `config.yaml`) must have variables defining each subset of the data on which you would like to train separately, as well as outcomes on each. The easiest way to set this up is to have each be a binary variable, specifying whether or not the observations belongs to the subset in question or had the outcome in question.

Let's use stress test as an example. We run models separately on the `tested` and `untested` populations, where the outcomes are `intervention` and `MACE` (respectively). Thus, our cohort file needs binary variables representing inclusion in `tested` and `untested` and incidence of `intervention` and `MACE`. This may lead to some combinations of variables where a certain outcome cannot be properly defined on a certain subset of patients (e.g. `intervention` on `untested == 1`). For these observations, `intervention` can be set to missing or 0.

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

### Common Errors <a name='Common_Errors'></a>
- If you get an `IncompleteFilesException`, add the argument `--rerun-incomplete` to the line of `run_pipeline.sh` that executes the snakemake command

<hr>

### Getting Help <a name='Getting_Help'></a>
As of 8.15.18, Christian Covington is the primary author of the pipeline and is likely the best source for answering any questions you have. Christian can be reached at by email at `christian.t.covington@gmail.com` and his gitlab handle is `ctcovington`.
