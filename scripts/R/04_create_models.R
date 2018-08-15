source('util.R')

package_list <- list('devtools', 'data.table', 'stringr', 'glmnet', 'xgboost', 'Matrix')

# Load and execute specified libraries
load_or_install(package_list)

### Read in command line arguments ###
arg_len <- 16
args <- commandArgs(TRUE)
# print(args)
if (length(args) != arg_len) {
    stop(sprintf('Must supply %i arguments -- you supplied %i\n', arg_len, length(args)))
} else {
    splits <- as.character(args[1])
    # cat(sprintf('splits: %s\n', splits))
    outcomes <- as.character(args[2])
    # cat(sprintf('outcomes: %s\n', outcomes))
    names <- as.character(args[3])
    # cat(sprintf('names: %s\n', names))
    model_types <- as.character(args[4])
    # cat(sprintf('model_types: %s\n', model_types))
    data_dir <- as.character(args[5])
    # cat(sprintf('data_dir: %s\n', data_dir))
    model_dir <- as.character(args[6])
    # cat(sprintf('model_dir: %s\n', model_dir))
    unit_id <- as.character(args[7])
    # cat(sprintf('unit_id: %s\n', unit_id))
    cluster_id <- as.character(args[8])
    # cat(sprintf('cluster_id: %s\n', cluster_id))
    learning_rate <- as.numeric(args[9])
    # cat(sprintf('learning_rate: %s\n', learning_rate))
    obj <- as.character(args[10])
    # cat(sprintf('obj: %s\n', obj))
    scale_pos_weight <- as.numeric(args[11])
    # cat(sprintf('scale_pos_weight: %s\n', scale_pos_weight))
    eval_metric <- as.character(args[12])
    # cat(sprintf('eval_metric: %s\n', eval_metric))
    max_depth <- as.numeric(args[13])
    # cat(sprintf('max_depth: %s\n', max_depth))
    nround <- as.numeric(args[14])
    # cat(sprintf('nround: %s\n', nround))
    colsample_bytree <- as.numeric(args[15])
    # cat(sprintf('colsample_bytree: %s\n', colsample_bytree))
    seed <- as.numeric(args[16])
    # cat(sprintf('seed: %s\n', seed))
}

# convert multi-argument arguments to vectors
splits <- str_split(splits, '--')[[1]]
outcomes <- str_split(outcomes, '--')[[1]]
names <- str_split(names, '--')[[1]]
model_types <- str_split(model_types, '--')[[1]]

a <- length(splits)
b <- length(outcomes)
c <- length(names)
d <- length(model_types)

if (length(unique(c(a,b,c,d))) != 1) {
    stop('All multi-argument arguments must have same length\n')
}

### Main function ###
createModels <- function(splits, outcomes, names, model_types, data_dir, model_dir, unit_id, cluster_id, learning_rate, obj, scale_pos_weight, eval_metric, max_depth, nround, colsample_bytree, seed) {
    # define prediction data directory and reset it (delete directory and files, then remake)
    prediction_data_dir <- sprintf('%s03_data_with_predictions/', data_dir)
    unlink(prediction_data_dir, recursive = TRUE)
    dir.create(prediction_data_dir)

    # reset model directory (delete directory and files, then remake)
    unlink(model_dir, recursive = TRUE)
    dir.create(model_dir)

    # load training data
    loadData(outcomes, names, data_dir)

    # iterate over training sets and train each model
    prediction_cols <<- c() # this will serve as a list of names of columns including model predictions -- we need to track them because they are added to our data set as we iterate over the model creation, but we don't want them included as predictors
    for (i in 1:length(names)) {
        cat(sprintf('\n### make and run models for %s ###\n\n', names[i]))
        other_outcomes <- outcomes[outcomes != outcomes[i]] # vector of outcomes we don't want -- these will be removed before modeling
        makeAndRunModels(dt_full = get(sprintf('%s_dt', names[i])), splits = splits, outcome = outcomes[i], name = names[i], model_type = model_types[i], data_dir, model_dir, unit_id, cluster_id, other_outcomes, prediction_cols, learning_rate, obj, scale_pos_weight, eval_metric, max_depth, nround, colsample_bytree, seed)
    }

    # create new holdout_dt and ensemble_train_dt (now including predicted outcomes), then save
    cat('\nadd predictions to ensemble_train and holdout\n')
    saveRDS(holdout_dt, sprintf('%sholdout_data_with_predictions.rds', prediction_data_dir))
    saveRDS(ensemble_train_dt, sprintf('%sensemble_train_data_with_predictions.rds', prediction_data_dir))
}

### component functions ###
loadData <- function(outcomes, names, data_dir) {
    # read in training data
    for (i in 1:length(outcomes)) {
        cat(sprintf('loading train_%s_data.rds as %s_dt\n', names[i], names[i]))
        assign(sprintf('%s_dt', names[i]), readRDS(sprintf('%s02_modeling_data/train_%s_data.rds', data_dir, names[i])), envir = .GlobalEnv)
    }

    # read in ensemble training and holdout data to which we will add predictions
    assign('ensemble_train_dt', readRDS(sprintf('%s02_modeling_data/ensemble_train_data.rds', data_dir)), envir=.GlobalEnv)
    cat(sprintf('loading ensemble_train_data.rds as ensemble_train_dt\n'))

    assign('holdout_dt', readRDS(sprintf('%s02_modeling_data/holdout_data.rds', data_dir)), envir=.GlobalEnv)
    cat(sprintf('loading holdout_data.rds as holdout_dt\n'))
}

makeAndRunModels <- function(dt_full, splits, outcome, name, model_type, data_dir, model_dir, unit_id, cluster_id, other_outcomes, prediction_cols, learning_rate, obj, scale_pos_weight, eval_metric, max_depth, nround, colsample_bytree, seed) {
    # remove extraneous outcome columns, as well as ID columns
    extra_cols <- c(other_outcomes, prediction_cols, splits, unit_id, cluster_id)
    remove_cols <- extra_cols[extra_cols %in% names(dt_full)]
    dt <- dt_full[, -remove_cols, with = FALSE]
    ensemble_train_temp <- ensemble_train_dt[, -remove_cols, with = FALSE]
    holdout_temp <- holdout_dt[, -remove_cols, with = FALSE]

    cat(sprintf('ncol(dt) = %i, ncol(holdout_temp) = %i\n', ncol(dt), ncol(holdout_temp)))

    # store features and outcome separately
    keep_cols <- setdiff(names(dt), c(outcome))

    X <- Matrix(data.matrix(dt[, ..keep_cols]), sparse = TRUE) # not sure how to get around converting to data.matrix first
    Y <- Matrix(dt[, get(outcome)], sparse = TRUE)

    # define ensemble_train and holdout feature sets
    holdout_X <-  Matrix(data.matrix(holdout_temp[, ..keep_cols]), sparse = TRUE)
    cat(sprintf('ncol(X) = %i, ncol(holdout_X) = %i\n', ncol(X), ncol(holdout_X)))
    stopifnot(ncol(X) == ncol(holdout_X))
    ensemble_train_X <-  Matrix(data.matrix(ensemble_train_temp[, ..keep_cols]), sparse = TRUE)
    stopifnot(ncol(X) == ncol(ensemble_train_X))

    # run LASSO if specified to do so
    if (grepl('lasso', model_type)) {
        cat('run lasso\n')
        # run and save lasso
        lasso <- cv.glmnet(x = X, y = Y, alpha = 1, family = 'binomial', nfolds = 10)
        lambda_1se <- lasso$lambda.1se # 'optimal' lambda
        saveRDS(lasso, sprintf('%s%s_lasso.rds', model_dir, name))

        # use lasso to predict outcome in ensemble_train and holdout
        cat('predict in holdout set\n')
        predictions <- predict(lasso, holdout_X, s = lambda_1se, type = 'response')
        assign('holdout_dt', holdout_dt[, (sprintf('%s_lasso_prediction', name)) := predictions], envir=.GlobalEnv)

        cat('predict in ensemble training set\n')
        predictions <- predict(lasso, ensemble_train_X, s = lambda_1se, type = 'response')
        assign('ensemble_train_dt', ensemble_train_dt[, (sprintf('%s_lasso_prediction', name)) := predictions], envir=.GlobalEnv)

        prediction_cols <<- c(prediction_cols, sprintf('%s_lasso_prediction', name))

        rm(lasso)
    }

    # run gradient boosted tree if specified to do so
    if (grepl('gbt', model_type)) {
        cat('train gradient boosted tree\n')

        gbt <- xgboost(data = X,
                       label = Y,
                       max.depth = max_depth,
                       eta = learning_rate,
                       scale_pos_weight = scale_pos_weight,
                       colsample_bytree = colsample_bytree,
                       nround = nround,
                       objective = obj,
                       eval_metric = eval_metric,
                       seed = seed,
                       verbose = 1
                       )

        saveRDS(gbt, sprintf('%s%s_gbt.rds', model_dir, name))

        # use gbt to predict outcome in ensemble_train and holdout
        cat('predict in holdout set\n')
        assign('holdout_dt', holdout_dt[, (sprintf('%s_gbt_prediction', name)) := predict(gbt, holdout_X, type = 'response')], envir=.GlobalEnv)

        cat('predict in ensemble training set\n')
        assign('ensemble_train_dt', ensemble_train_dt[, (sprintf('%s_gbt_prediction', name)) := predict(gbt, ensemble_train_X, type = 'response')], envir=.GlobalEnv)

        prediction_cols <<- c(prediction_cols, sprintf('%s_gbt_prediction', name))

        rm(gbt)
    }
}

### execute ###
createModels(splits, outcomes, names, model_types, data_dir, model_dir, unit_id, cluster_id, learning_rate, obj, scale_pos_weight, eval_metric, max_depth, nround, colsample_bytree, seed)
