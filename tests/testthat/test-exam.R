library(testthat)
library(rmarkdown)

test_that("Run exam", {
  rundir <- tempfile("examinr-test-wd")
  dir.create(rundir, mode = "0700")
  on.exit(unlink(rundir, recursive = TRUE), add = TRUE)

  tmp_loc <- file.path(rundir, "exam.Rmd")

  file.copy("tests/testthat/exams/exam.Rmd", tmp_loc)

  run(tmp_loc)
})

