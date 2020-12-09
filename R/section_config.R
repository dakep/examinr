#' Exam Section Configuration
#'
#' Control the behavior of each individual section of an exam.
#' Each exam contains one or more sections, which are shown either all-at-once or progressively to the user.
#'
#' The section configuration can be set in the metadata of the exam file and with the `section_config()` function.
#' Options set via `section_config()` take precedence over options set in the metadata.
#'
#' The last section in the exam document is assumed to be a "final remark" and displayed to the user after
#' an attempt is finished, without possibility of submitting the section.
#'
#' Sections are identified by their name.
#' For example, a section with title _# Section 1: Multiple Choice Questions_ would be identified by
#' `"Section 1: Multiple Choice Questions"`.
#' Note that pandoc heading identifiers (anything in `{}` at the end of the section title) are omitted from the name.
#'
#' @param section name of the section for which to set configuration options.
#' @param button_label the label for the button at the end of a section.
#'   Default button label is _Submit answers_.
#'   If `progressive=FALSE`, only the button in the last section will be displayed.
#' @param fix_order logical if the section should remain fixed in order.
#'
#' @importFrom rlang is_missing abort
#' @importFrom knitr opts_knit knit_meta_add
#' @family exam configuration
#' @export
section_config <- function (section, button_label, fix_order) {
  section <- normalize_string(section)
  knitting <- FALSE

  if (!is_knitr_context('setup')) {
    abort("Section configuration must be done in a `setup` context.")
  }

  # Collect section config overrides only in the first pass
  if (isTRUE(opts_knit$get('examinr.initial_pass'))) {
    knit_meta_add(list(structure(
      list(section = section,
           btn_label = button_label %|NA|% NULL,
           fixed = fix_order %||% NULL),
      class = 'examinr_section_config_overrides')))
  }

  return(invisible(NULL))
}

#' @importFrom knitr knit_meta
section_config_overrides <- function () {
  all_overrides <- knit_meta('examinr_section_config_overrides')
  overrides <- list()
  for (or in all_overrides) {
    if (is.null(overrides[[or$section]])) {
      overrides[[or$section]] <- list()
    }
    for (name in names(or)) {
      overrides[[or$section]][[name]] <- or[[name]] %||% overrides[[or$section]][[name]]
    }
  }
  return(overrides)
}
