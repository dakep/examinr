if (require(testthat)) {
  library(examinr)
  test_check("examinr")
} else {
  warning("'examinr' requires 'testthat' for tests.")
}
