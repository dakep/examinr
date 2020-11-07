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
#' @param next_button_label the label for the button at the end of a section.
#'   Default button label is _Submit answers_.
#'   If `progressive=FALSE`, only the button in the last section will be displayed.
#'   Buttons can be hidden for specific sections via `section_specific_options(next_button_label=NA)`. This is only
#'   useful for progressive exams where the last section is only for information purposes.
#' @param next_button_context bootstrap 3 contextual class applied to the button. See
#'   <https://getbootstrap.com/docs/3.3/css/#buttons-options> for a list of available classes.
#' @param fix_order logical if the section should remain fixed in order.
#'
#' @importFrom rlang is_missing abort
#' @importFrom knitr opts_knit knit_meta_add
#' @export
section_config <- function (section, next_button_label, next_button_context, fix_order) {
  section <- normalize_section_name(section)
  knitting <- FALSE

  if (!is_knitr_context('setup')) {
    abort("Section configuration must be done in a `setup` context.")
  }

  # Collect section config overrides only in the first pass
  if (isTRUE(opts_knit$get('examinr.initial_pass'))) {
    overrides <- structure(
      list(section = section,
           btn_label = next_button_label %||% NULL,
           fixed = fix_order %||% NULL,
           btn_context = next_button_context %||% NULL),
      class = 'examinr_section_config_overrides')

    knit_meta_add(list(overrides))
  }

  return(invisible(NULL))
}

## Normalize section names for use as identifiers
##  - strip any header attributes (the trailing "{...}") and leading/trailing white-space
##  - replace any sequence of non-alphanumeric character with a single `-`
##  - make lower-case
#' @importFrom stringi stri_trim_both
#' @importFrom stringr str_detect str_starts fixed str_match str_replace_all
normalize_section_name <- function (section_title) {
  has_identifiers <- which(str_detect(section_title, '\\s*\\{.*\\}\\s*$'))
  if (length(has_identifiers) > 0L) {
    section_title[has_identifiers] <- str_match(section_title[has_identifiers], '^#?\\s*(.+)\\s*\\{.*\\}\\s*$')[, 2]
  }
  stri_trim_both(str_replace_all(tolower(section_title), '[^\\p{Alphabetic}\\p{Decimal_Number}]+', '-'),
                 pattern = '[^\\p{Wspace}\\-#]')
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
