source('util.R')

package_list <- list('devtools', 'data.table', 'stringr')

# Load and execute specified libraries
load_or_install(package_list)

### Read in command line arguments ###
arg_len <- 8
args <- commandArgs(TRUE)
# print(args)
if (length(args) != arg_len) {
    stop(sprintf('Must supply %i arguments -- you provided %i', arg_len, length(args)))
} else {
    file <- as.character(args[1])
    feature_dir <- as.character(args[2])
    data_dir <- as.character(args[3])
    unit_id <- as.character(args[4])
    count_files <- as.character(args[5])
    non_count_files <- as.character(args[6])
    missingness_threshold_count <- as.character(args[7])
    missingness_threshold_non_count <- as.character(args[8])
}

# convert multi-argument arguments to vectors
count_files <- str_split(count_files, '--')[[1]]
non_count_files <- str_split(non_count_files, '--')[[1]]

raw_subset_dir <- sprintf('%s01_feature_data/', data_dir)
dir.create(raw_subset_dir)

subsetSave <- function(file, feature_dir, data_dir, unit_id, count_files, non_count_files, missingness_threshold_count, missingness_threshold_non_count) {
    dt <- fread(sprintf('%s%s', feature_dir, file))
    ed_enc_id_names <- names(dt)[names(dt) %like% unit_id]
    if (length(ed_enc_id_names) != 1) { # exit script if there is not exactly one variable name in 'dt' containing 'ed_inc_id'
        cat(sprintf('%s has multiple variable names containing \'%s\'\n', non_stats_files[i], unit_id))
        quit()
    }
    setnames(dt, ed_enc_id_names, unit_id) # standardize ed_enc_id variable name

    # subset columns based on missingness
    n <- nrow(dt) # number of observations
    prop_missing <- colSums(is.na(dt)) / n # get proportion missing for each

    file_prefix <- str_split(file, '_t')[[1]][1] # get beginning of filename up to first '_t', which is our marker for 'time_period' -- this should cover any files that are 'count_files'
    if (file_prefix == file) {
        file_prefix <- str_split(file, '_')[[1]][1] # get beginning of filename up to first '_' -- this should cover any files that are 'non_count_files'
    }

    if (file_prefix %in% count_files) {
        low_miss <- prop_missing < missingness_threshold_count
    } else if (file_prefix %in% non_count_files) {
        low_miss <- prop_missing < missingness_threshold_non_count
    } else {
        stop('Error: file prefix not included in \'count_files\' or \'non_count_files\'')
    }

    dt <- dt[, (low_miss), with = FALSE] # subset to columns with low missingness
    fwrite(dt, sprintf('%s%s', raw_subset_dir, file)) # return data table of all features
}

subsetSave(file, feature_dir, data_dir, unit_id, count_files, non_count_files, missingness_threshold_count, missingness_threshold_non_count)
