source('/data/zolab/general_ml_pipeline_snakemake/scripts/util.R')

package_list <- list('devtools', 'data.table')

# Load and execute specified libraries
load_or_install(package_list)

### Read in command line arguments ###
arg_len <- 2
args <- commandArgs(TRUE)
# print(args)
if (length(args) != arg_len) {
    stop(sprintf('Must supply %i arguments -- you provided %i', arg_len, length(args)))
} else {
    data_dir <- as.character(args[1])
    unit_id <- as.character(args[2])
}

### main function ###
mergeSubsets <- function(data_dir, unit_id) {
    # loop over all files in the relevant directory
    files <- list.files(sprintf('%s01_feature_data/', data_dir))
    component_files <- files[! files == 'full_feature_data.csv']
    dt_list <- list()

    for (i in 1:length(component_files)) {
        dt <- fread(sprintf('%s01_feature_data/%s', data_dir, component_files[i])) # read in file
        setkeyv(dt, unit_id)
        dt_list[[i]] <- dt # add dt to dt_list
    }

    # merge all data tables together to create full feature data
    full_feature_dt <- Reduce(function(...) merge(..., all = TRUE), dt_list)
    fwrite(full_feature_dt, sprintf('%s01_feature_data/full_feature_data.csv', data_dir))
}

### execute ###
mergeSubsets(data_dir, unit_id)
