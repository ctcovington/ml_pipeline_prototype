#!/bin/bash
snakemake --dag | dot -Tsvg > dag.svg # create directed acyclic graph showing workflow
snakemake -j 20 --cluster-config cluster.json --cluster "bsub -K -q {cluster.queue} -J {cluster.name} -M {cluster.memory} -R {cluster.resources}" & # run pipeline
