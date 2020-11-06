#' @importFrom knitr knit_meta
initialize_exam_status <- function (exam_metadata, attempts_config) {
  exam_metadata <- unserialize_object(exam_metadata)
  attempts_config <- unserialize_object(attempts_config)
  return(structure(list(totalSections = length(knit_meta('examinr_section', clean = FALSE)),
                        haveTimelimit = isTRUE(attempts_config$timelimit < Inf),
                        progressive = isTRUE(exam_metadata$progressive),
                        progressbar = isTRUE(exam_metadata$progress_bar)), class = 'examinr_exam_status'))
}

## Print exam status container
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @method knit_print examinr_exam_status
#' @importFrom htmltools tags
#' @rdname knit_print
#' @export
#' @keywords internal
knit_print.examinr_exam_status <- function (x, ...) {
  ui <- tags$div(class = 'examinr-exam-status',
                 tags$script(type = 'application/json', class = 'status-config', to_json(x)),
                 tags$script(type = 'application/json', class = 'status-messages', HTML(to_json(get_status_message()))))
  knit_print(ui, ...)
}
