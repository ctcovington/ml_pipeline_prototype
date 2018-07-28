source('/data/zolab/general_ml_pipeline_snakemake/scripts/util.R')

package_list <- list('devtools', 'data.table', 'stringr')

# Load and execute specified libraries
load_or_install(package_list)

### Read in command line arguments ###
arg_len <- 5
args <- commandArgs(TRUE)
# print(args)
if (length(args) != arg_len) {
    stop(sprintf('Must supply %i arguments -- you supplied %i\n', arg_len, length(args)))
} else {
    ensemble_outcome <- as.character(args[1])
    # cat(sprintf('ensemble_outcome: %s\n', ensemble_outcome))
    names <- as.character(args[2])
    # cat(sprintf('names: %s\n', names))
    model_types <- as.character(args[3])
    # cat(sprintf('model_types: %s\n', model_types))
    data_dir <- as.character(args[4])
    # cat(sprintf('data_dir: %s\n', data_dir))
    model_dir <- as.character(args[5])
    # cat(sprintf('model_dir: %s\n', model_dir))
}

# convert multi-argument arguments to vectors
names <- str_split(names, '--')[[1]]
model_types <- str_split(model_types, '--')[[1]]

a <- length(names)
b <- length(model_types)

if (length(unique(c(a,b))) != 1) {
    stop('All multi-argument arguments must have same length\n')
}

### main function ###
createEnsembleModel <- function(ensemble_outcome, names, model_types, data_dir, model_dir) {
    # read ensemble_training and holdout data
    ensemble_train_dt <- readRDS(sprintf('%s03_data_with_predictions/ensemble_train_data_with_predictions.rds', data_dir))
    holdout_dt <- readRDS(sprintf('%s03_data_with_predictions/holdout_data_with_predictions.rds', data_dir))

    # train logit ensemble model
    rhs_vars <- paste(names, model_types, 'prediction', sep = '_') # TODO: need to allow for interactions
    model_formula <- reformulate(termlabels = rhs_vars, response = ensemble_outcome, intercept = FALSE) # create ensemble model formula
    ensemble_model <- lm(formula = model_formula, data = ensemble_train_dt) # run model

    # save model
    saveRDS(ensemble_model, sprintf('%sensemble_model.rds', model_dir))

    # use model to predict ensemble_outcome in holdout set
    holdout_dt[, (paste(ensemble_outcome, 'ensemble_prediction', sep = '_')) := predict(ensemble_model, newdata = holdout_dt[, (rhs_vars), with = FALSE], type = 'response')]
    holdout_dt[get(paste(ensemble_outcome, 'ensemble_prediction', sep = '_')) < 0, (paste(ensemble_outcome, 'ensemble_prediction', sep = '_')) := 0] # censor outcomes outside of [0,1] risk range
    holdout_dt[get(paste(ensemble_outcome, 'ensemble_prediction', sep = '_')) > 1, (paste(ensemble_outcome, 'ensemble_prediction', sep = '_')) := 1] # censor outcomes outside of [0,1] risk range

    # save holdout dt
    saveRDS(holdout_dt, sprintf('%s03_data_with_predictions/holdout_data_with_predictions_including_ensemble.rds', data_dir))
}

### component functions ###

### execute ###
createEnsembleModel(ensemble_outcome, names, model_types, data_dir, model_dir)
