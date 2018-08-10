source('util.R')

package_list <- list('devtools', 'data.table', 'ggplot2')

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
    data_dir <- as.character(args[2])
    # cat(sprintf('data_dir: %s\n', data_dir))
    output_dir <- as.character(args[3])
    # cat(sprintf('output_dir: %s\n', output_dir))
    ensemble_performance_split <- as.character(args[4])
    # cat(sprintf('ensemble_performance_split: %s\n', ensemble_performance_split))
    ensemble_performance_split_value <- as.numeric(args[5])
    # cat(sprintf('ensemble_performance_split_value: %s\n', ensemble_performance_split_value))
}

### main function ###
postModelingAnalysis <- function(ensemble_outcome, data_dir, output_dir, ensemble_performance_split, ensemble_performance_split_value) {
    unlink(output_dir, recursive = TRUE)
    dir.create(output_dir)

    # read in holdout data
    holdout_dt <- readRDS(sprintf('%s03_data_with_predictions/holdout_data_with_predictions_including_ensemble.rds', data_dir))

    # output ROC
    outputROC(dt = holdout_dt, prediction_col_name = paste(ensemble_outcome, 'ensemble_prediction', sep = '_'), ensemble_outcome = ensemble_outcome,
              ensemble_performance_split = ensemble_performance_split, ensemble_performance_split_value = ensemble_performance_split_value)

    # create tables of mean y_bar by y_hat quantile
    quantile_vals <- c(5, 10, 20, 100)
    quantile_names <- c('quintile', 'decile', 'ventile', 'percentile')
    if (length(quantile_vals) != length(quantile_names)) {
        stop('Error: quantile values and names must have same number of elements')
    }
    meanYByYHatQuantile(dt = holdout_dt, prediction_col_name = paste(ensemble_outcome, 'ensemble_prediction', sep = '_'),
                           ensemble_outcome = ensemble_outcome, ensemble_performance_split = ensemble_performance_split,
                           ensemble_performance_split_value = ensemble_performance_split_value,
                           quantile_vals = quantile_vals, quantile_names = quantile_names)
}

### component functions ###
outputROC <- function(dt, prediction_col_name, ensemble_outcome, ensemble_performance_split, ensemble_performance_split_value) {
    dt <- dt[get(ensemble_performance_split) == ensemble_performance_split_value] # subset data to portion on which we will evaluate model

    labels <- dt[, get(ensemble_outcome)] # observed outcomes
    predictions = dt[, get(paste(ensemble_outcome, 'ensemble_prediction', sep = '_'))] # predicted outcomes

    labels <- labels[order(predictions, decreasing = TRUE)] # order outcomes by decreasing order of prediction value
    roc_dt <- data.table(tpr = cumsum(labels) / sum(labels), fpr = cumsum(!labels) / sum(!labels), labels) # create data table for plotting

    d_tpr <- c(diff(roc_dt$tpr), 0) # true positive rate step sizes
    d_fpr <- c(diff(roc_dt$fpr), 0) # false positive rate step sizes
    auc <- sum(roc_dt$tpr * d_fpr) + sum(d_tpr * d_fpr) / 2 # calculate AUC using trapezoidal sum -- NOTE: version below might be more clear, but is slower

    # plot ROC
    options(device = 'png')
    plt <- ggplot(data = roc_dt, aes(x = fpr, y = tpr)) +
                  geom_line(color = 'red') +
                  geom_abline(intercept = 0, slope = 1) +
                  xlim(0,1) +
                  ylim(0,1) +
                  annotate(geom = 'text',  x = 1, y = 0, label = sprintf('AUC: %s', as.character(round(auc, 3))), vjust=1, hjust=1) +
                  labs(title = 'ROC', x = 'False Positive Rate', y = 'True Positive Rate')
    ggsave(filename = sprintf('%sensemble_roc.png', output_dir), device = 'png', width = 7, height = 7)
}

meanYByYHatQuantile <- function(dt, prediction_col_name, ensemble_outcome, ensemble_performance_split, ensemble_performance_split_value, quantile_vals, quantile_names) {
    dt <- dt[get(ensemble_performance_split) == ensemble_performance_split_value] # subset data to portion on which we will evaluate model

    # create quantiles of y_hat and get mean outcome by y_hat quantile
    for (i in 1:length(quantile_vals)) {
        dt[, (sprintf('prediction_%s', quantile_names[i])) := add_quantile(get(paste(ensemble_outcome, 'ensemble_prediction', sep = '_')), n_quantil = quantile_vals[i])]
        dt[, (sprintf('mean_%s_by_%s', ensemble_outcome, quantile_names[i])) := mean(get(ensemble_outcome), na.rm = TRUE), by = c(sprintf('prediction_%s', quantile_names[i]))]
        mean_dt <- unique(dt[, c(sprintf('prediction_%s', quantile_names[i]), sprintf('mean_%s_by_%s', ensemble_outcome, quantile_names[i])), with = FALSE])
        setkeyv(mean_dt, sprintf('prediction_%s', quantile_names[i]))
        setkeyv(mean_dt, NULL)
        fwrite(mean_dt, sprintf('%smean_%s_by_predicted_%s_%s.csv', output_dir, ensemble_outcome, ensemble_outcome, quantile_names[i]))
    }
}

### execute ###
postModelingAnalysis(ensemble_outcome, data_dir, output_dir, ensemble_performance_split, ensemble_performance_split_value)
