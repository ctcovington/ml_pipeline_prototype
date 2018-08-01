source('util.R')

package_list <- list('devtools', 'data.table', 'stringr')

# Load and execute specified libraries
load_or_install(package_list)

### Read in command line arguments ###
arg_len <- 12
args <- commandArgs(TRUE)
# print(args)
if (length(args) != arg_len) {
    stop(sprintf('Must supply %i arguments -- you supplied %i\n', arg_len, length(args)))
} else {
    cohort_filepath <- as.character(args[1])
    # cat(sprintf('cohort_filepath: %s\n', cohort_filepath))
    splits <- as.character(args[2])
    # cat(sprintf('splits: %s\n', splits))
    values <- as.character(args[3])
    # cat(sprintf('values: %s\n', values))
    outcomes <- as.character(args[4])
    # cat(sprintf('outcomes: %s\n', outcomes))
    names <- as.character(args[5])
    # cat(sprintf('names: %s\n', names))
    ecg_filepath <- as.character(args[6])
    # cat(sprintf('ecg_filepath: %s\n', ecg_filepath))
    use_ecg_feats <- as.logical(args[7])
    # cat(sprintf('use_ecg_Feats: %s\n', use_ecg_feats))
    train_prop <- as.numeric(args[8])
    # cat(sprintf('train_prop: %s\n', train_prop))
    ensemble_train_prop <- as.numeric(args[9])
    # cat(sprintf('ensemble_train_prop: %s\n', ensemble_train_prop))
    data_dir <- as.character(args[10])
    # cat(sprintf('data_dir: %s\n', data_dir))
    unit_id <- as.character(args[11])
    # cat(sprintf('unit_id: %s\n', unit_id))
    cluster_id <- as.character(args[12])
    # cat(sprintf('cluster_id: %s\n', cluster_id))
}

# convert multi-argument arguments to vectors
splits <- str_split(splits, '--')[[1]]
values <- as.numeric(str_split(values, '--')[[1]])
outcomes <- str_split(outcomes, '--')[[1]]
names <- str_split(names, '--')[[1]]

a <- length(splits)
b <- length(values)
c <- length(outcomes)
d <- length(names)

if (length(unique(c(a,b,c,d))) != 1) {
    stop('All multi-argument arguments must have same length\n')
}

set.seed(1)

### Main function ###
createModelingData <- function(cohort_filepath, splits, values, outcomes, names, ecg_filepath, use_ecg_feats, train_prop, ensemble_train_prop, data_dir, unit_id, cluster_id) {
    # load features
    cat('load features\n')
    loadFeatures(data_dir, use_ecg_feats, ecg_filepath)

    # load vector of outcomes and append to features
    cat('load and append model outcome\n')
    loadAndAppendModelOutcome(cohort_filepath, splits, values, outcomes, names)

    # perform imputation for missing values
    cat('impute missing values\n')
    impute(feature_with_outcome_dt)

    # split observations into train, ensemble_train, and holdout sets
    cat('split into train, ensemble_train, and holdout sets\n')
    splitTrainEnsembleTrainHoldout(feature_with_outcome_dt, train_prop, splits, values, outcomes, names, data_dir, cluster_id)
}

### Component functions ###
loadFeatures <- function(data_dir, use_ecg_feats, ecg_filepath) {
    feature_file <- sprintf('%s01_feature_data/full_feature_data.csv', data_dir)

    assign('feature_dt', fread(feature_file), envir=.GlobalEnv)

    if (use_ecg_feats) {
      # read ecg features file
      assign('ecg_feats', readRDS(ecg_filepath), envir=.GlobalEnv)

      # take first instance of ecg feature if multiple exist per visit
      assign('ecg_feats', unique(ecg_feats, by = c(unit_id)), envir=.GlobalEnv)
      assign('feature_dt', merge(x = feature_dt, y = ecg_feats, by = unit_id, all.x = TRUE), envir = .GlobalEnv)

      rm(list = c('ecg_feats'), envir = .GlobalEnv)
    }
}

loadAndAppendModelOutcome <- function(cohort_filepath, splits, values, outcomes, names) {
    outcome_dt <- fread(cohort_filepath)

    # choose columns to keep
    keep_cols <- c(unit_id, cluster_id, splits, outcomes)
    keep_cols <- keep_cols[keep_cols != 'full'] # don't include 'full'

    # NOTE: for now, make sure id columns are of same data type
    outcome_dt[, (cluster_id) := as.character(get(cluster_id))]

    # keep relevant columns
    outcome_dt <- outcome_dt[, ..keep_cols]

    # merge together full outcomes data table with features
    assign('feature_with_outcome_dt', merge(x = feature_dt, y = outcome_dt, by = c(unit_id), all.x = TRUE), envir=.GlobalEnv)
    rm(list = c('feature_dt'), envir = .GlobalEnv)
}

impute <- function(feature_with_outcome_dt) {
  # Imputes missing values in data table. Median imputation if the
  # column contains vital signs, lab values, indication of min or max
  # and demographics. Zero imputation otherwise.
  for(i in 1:ncol(feature_with_outcome_dt)) {
    x <- feature_with_outcome_dt[[names(feature_with_outcome_dt)[i]]]
    if(any(is.na(x))) {
      if(grepl('lvs|lab|min|max|mean|dem.basic|male|female', names(feature_with_outcome_dt)[i])) {
        x <- ifelse(is.na(x), median(x, na.rm=T), x)
      } else { x <- ifelse(is.na(x), 0, x) }
    }
    feature_with_outcome_dt[[names(feature_with_outcome_dt)[i]]] <- x
  }

  assign('feature_with_outcome_dt', feature_with_outcome_dt, envir = .GlobalEnv)
}

splitTrainEnsembleTrainHoldout <- function(feature_with_outcome_dt, train_prop, splits, values, outcomes, names, data_dir, cluster_id) {
    modeling_data_dir <- sprintf('%s02_modeling_data/', data_dir)
    unlink(modeling_data_dir, recursive = TRUE)
    dir.create(modeling_data_dir)

    # generate vector of unique values of 'cluster_id'
    unique_cluster_id <- unique(feature_with_outcome_dt[, get(cluster_id)])

    # calculate number of unique 'cluster_id' for training set
    train_size <- floor(train_prop * length(unique_cluster_id))
    ols_train_size <- floor(ensemble_train_prop * train_size)

    # create set of 'train_size' unique values of 'cluster_id' we want to include in the training set -- then, partition these into true training set and set used for training ensemble model
    # NOTE: the sampling is done at the level of the cluster id, so the proportion of observations in each set may not match the parameters exactly
    train_vals <- sample(unique_cluster_id, size = train_size, replace = FALSE)
    ols_train_vals <- sample(train_vals, size = ols_train_size, replace = FALSE)
    train_vals <- train_vals[!train_vals %in% ols_train_vals]
    rm(unique_cluster_id)

    # create train, ensemble_train, and holdout sets
    assign('train', feature_with_outcome_dt[get(cluster_id) %in% train_vals])

    assign('ensemble_train', feature_with_outcome_dt[get(cluster_id) %in% ols_train_vals])
    saveRDS(ensemble_train, sprintf('%sensemble_train_data.rds', modeling_data_dir))
    rm(ensemble_train)
    cat('done saving ensemble_train\n')

    assign('holdout', feature_with_outcome_dt[! get(cluster_id) %in% c(train_vals, ols_train_vals)])
    saveRDS(holdout, sprintf('%sholdout_data.rds', modeling_data_dir))
    rm(holdout)
    cat('done saving holdout\n')
    rm(list = c('train_vals', 'ols_train_vals'))

    # split training set back into its component pieces
    for (i in 1:length(splits)) {
        # cat(sprintf('before making train_%s:\n\n', splits[i]))
        # print(sort( sapply(ls(),function(x){object.size(get(x))})))
        if (splits[i] == 'full') {
            dt <- train
        } else {
            dt <- train[get(splits[i]) == values[i]]
        }
        saveRDS(dt, sprintf('%strain_%s_data.rds', modeling_data_dir, names[i]))
        cat(sprintf('done saving train_%s\n', splits[i]))
        rm(dt)
    }
}

### execute ###
createModelingData(cohort_filepath, splits, values, outcomes, names, ecg_filepath, use_ecg_feats, train_prop, ensemble_train_prop, data_dir, unit_id, cluster_id)
