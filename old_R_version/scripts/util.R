load_or_install <- function(package_names) {
    if (('ehR' %in% package_names) & (!'ehR' %in% installed.packages())) {
        if (! 'devtools' %in% installed.packages) {
            install.packages('devtools', repos='http://cran.cnr.berkeley.edu/', dependencies = TRUE)
        }
        library('devtools')
        install_github('sysmedlab/ehR', dependencies = TRUE)
    }

    lapply(package_names, function(x) if(!x %in% installed.packages())
    suppressMessages(install.packages(x,repos='http://cran.cnr.berkeley.edu/',dependencies = TRUE)))
    packages_loaded <- lapply(package_names, function(x) suppressMessages(library(x,character.only=TRUE,
                                                                                logical.return = FALSE)))
    packages_loaded[[length(package_names)]]
}

add_quantile <- function(col, n_quantile) {
  quantile <- tryCatch(
    {
      # try assigning n_pctile
      return(cut(col, quantile(col, probs = (0:n_quantile)/n_quantile),
                                    include.lowest = TRUE, labels = FALSE))
    },
    error = function(error_cond){
      # randomize assignment into n_quantile where breaks are equal
      message("Warning: cannot create unique cuts")
      message("Randomizing assignment to create equal breaks")
      return(cut(rank(col, ties.method = "random"),
                 quantile(rank(col, ties.method = "random"),
                 probs = (0:n_quantile)/n_quantile), include.lowest = TRUE,
                 labels = FALSE))
    }
  )
  # return assigned quantile
  return (quantile)
}
