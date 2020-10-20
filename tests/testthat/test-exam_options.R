expect_list_equal <- function (object, expected, label = NULL)  {
  act <- quasi_label(rlang::enquo(object), arg = "object")
  exp <- quasi_label(rlang::enquo(expected), arg = "expected")

  if (!rlang::is_vector(act$val) || !rlang::is_vector(exp$val)) {
    rlang::abort("`object` and `expected` must both be vectors")
  }

  if (rlang::is_list(act$val)) {
    # remove nulls
    act$val <- act$val[!vapply(act$val, rlang::is_null, TRUE)]
  }

  if (length(act$val) == 0 && length(exp$val) == 0) {
    rlang::warn("`object` and `expected` are empty lists")
    succeed()
    return(invisible(act$val))
  }
  act_nms <- names(act$val)
  exp_nms <- names(exp$val)

  if (!setequal(act_nms, exp_nms)) {
    act_miss <- setdiff(exp_nms, act_nms)
    if (length(act_miss) > 0) {
      vals <- paste0(encodeString(act_miss, quote = "\""), ", ")
      fail(paste0(label, "Names absent from `object`: ", vals))
    }
    exp_miss <- setdiff(act_nms, exp_nms)
    if (length(exp_miss) > 0) {
      vals <- paste0(encodeString(exp_miss, quote = "\""), ", ")
      fail(paste0(label, "Names absent from `expected`: ", vals))
    }
  }
  else {
    # Names are okay. Check nested lists
    exp_nested_lists <- vapply(exp$val, is.list, FUN.VALUE = FALSE, USE.NAMES = FALSE)
    if (any(exp_nested_lists)) {
      for (i in which(exp_nested_lists)) {
        name <- encodeString(names(exp$val)[[i]], quote = "\"")
        expect_list_equal(act$val[[i]], exp$val[[i]], label = paste0("Component ", name, ": "))
      }
    }

    # Check non-lists
    expect_equal(act$val[exp_nms[!exp_nested_lists]], exp$val[!exp_nested_lists], label = label)
  }
  invisible(act$val)
}

test_that("Exam options only from metadata", {
  # Reset the exam options environment before and after the test
  examinr:::.exam_data$reset()
  examinr:::.sections_data$reset()
  withr::defer({
    examinr:::.exam_data$reset()
    examinr:::.sections_data$reset()
  })

  metadata <- rmarkdown::yaml_front_matter(test_path('exams', 'with-metadata.Rmd'))

  examinr:::sections_options_from_metadata(metadata$exam$sections)
  expect_equal(examinr:::.sections_data$get('render'), 'client')
  expect_equal(examinr:::.sections_data$get('order'), 'fixed')
  expect_equal(examinr:::.sections_data$get('next_button_label'), 'Next section')
  expect_list_equal(examinr:::.sections_data$get('specific'),
                    list(introduction = list(fixed = TRUE), 'final-comments' = list(fixed = TRUE)))
})

test_that("Exam options from metadata and programmatically set", {
  # Reset the exam options environment before and after the test
  examinr:::.exam_data$reset()
  examinr:::.sections_data$reset()
  withr::defer({
    examinr:::.exam_data$reset()
    examinr:::.sections_data$reset()
  })

  # Set sections options beforehand
  sections_options(render = 'server', next_button_label = 'Forward')
  section_specific_options('Introduction', fix_order = FALSE, next_button_label = 'Start')
  section_specific_options('Section 1', fix_order = TRUE)

  metadata <- rmarkdown::yaml_front_matter(test_path('exams', 'with-metadata.Rmd'))

  examinr:::sections_options_from_metadata(metadata$exam$sections)
  expect_equal(examinr:::.sections_data$get('render'), 'server')
  expect_equal(examinr:::.sections_data$get('order'), 'fixed')
  expect_equal(examinr:::.sections_data$get('next_button_label'), 'Forward')
  expect_list_equal(examinr:::.sections_data$get('specific'),
                    list(introduction = list(fixed = FALSE, next_button_label = 'Start'),
                         'section-1' = list(fixed = TRUE),
                         'final-comments' = list(fixed = TRUE)))
})
