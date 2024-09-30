if (require(testthat)) {
  library(examinr)
  options(shiny.testmode = TRUE)
  test_check("examinr")
} else {
  warning("'examinr' requires 'testthat' for tests.")
}
