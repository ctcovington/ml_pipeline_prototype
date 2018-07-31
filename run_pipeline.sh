#!/bin/bash

# either create or load conda environment
if conda info --envs | grep -q "ml_pipeline"; then
    source activate "ml_pipeline"
else
    conda env create -f conda_env.yaml
fi

# create directed acyclic graph showing workflow
snakemake --dag | dot -Tsvg > dag.svg

# run pipeline
snakemake -j 20 --cluster-config cluster.json --cluster "bsub -K -q {cluster.queue} -J {cluster.name} -M {cluster.memory} -R {cluster.resources}" & # run pipeline
