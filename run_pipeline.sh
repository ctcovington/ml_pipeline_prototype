#!/bin/bash

# create conda environment (if necessary)
if ! conda info --envs | grep -wq "ml_pipeline"; then
    conda env create -f=conda_env.yaml
fi

# # load conda environment
# source activate "ml_pipeline"

# create directed acyclic graph showing workflow
snakemake --dag | dot -Tsvg > dag.svg

# run pipeline
snakemake -j 20 --cluster-config cluster.json --cluster "bsub -K -q {cluster.queue} -J {cluster.name} -M {cluster.memory} -R {cluster.resources}" & # run pipeline
