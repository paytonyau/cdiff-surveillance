# Run the whole suite from the project root:  Rscript tests/testthat.R   (or: make test)
library(testthat)
test_dir("tests/testthat", reporter = "progress", stop_on_failure = TRUE)
