.exam_section_opts_hook <- function (options, ...) {
  options$eval <- TRUE
  options$include <- TRUE
  options$echo <- FALSE
  options$comment <- NA
  return(options)
}

#' @importFrom knitr opts_chunk
section_start <- function (section_id, section_ns) {
  opts_chunk$set(examinr.section_id = section_id, examinr.section_ns = section_ns)
}

#' @importFrom knitr opts_chunk
section_chunk <- function (section_id, section_ns, content_enc, chunk_counter) {
  structure(list(id = section_id, ns = section_ns, content_enc = content_enc, counter = chunk_counter),
            class = 'examinr_section_chunk')
}

## Print section content
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @importFrom knitr knit_print
#' @importFrom shiny NS htmlOutput
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @method knit_print examinr_section_chunk
#' @rdname knit_print
#' @export
#' @keywords internal
knit_print.examinr_section_chunk <- function (x, ...) {
  chunk_ns <- paste(x$ns, x$counter, sep = '-')
  ns <- NS(chunk_ns)

  metadata <- c(x[c('id', 'ns')], chunk_ns = chunk_ns)

  shiny_prerendered_chunk('server', code = sprintf(
    'examinr:::section_chunk_server(examinr:::unserialize_object("%s"), examinr:::unserialize_object("%s"))',
    serialize_object(metadata), x$content_enc))

  knit_print(htmlOutput(ns('out')), ...)
}

#' @importFrom shiny moduleServer renderUI
#' @importFrom htmltools HTML
#' @importFrom rlang warn
section_chunk_server <- function (metadata, content) {
  data_env <- get_rendering_env()
  moduleServer(metadata$chunk_ns, function (input, output, session) {
    output$out <- renderUI(render_markdown_as_html(content, env = data_env))
  })
}


## Add controls at the end of a section for navigation
section_end <- function (section_id, section_ns) {
  opts_chunk$set(examinr.section_id = NULL, examinr.section_ns = NULL)
  structure(list(id = section_id, ns = section_ns,
                 context = .sections_data$get('specific')[[section_id]]$next_button_context %||%
                   opts_current$get('exam.next_button_context'),
                 label = .sections_data$get('specific')[[section_id]]$next_button_label %||%
                   .sections_data$get('next_button_label')),
            class = 'examinr_section_end')
}


## Print section end
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @importFrom knitr knit_print
#' @importFrom shiny NS actionButton
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @method knit_print examinr_section_end
#' @rdname knit_print
#' @export
#' @keywords internal
knit_print.examinr_section_end <- function (x, ...) {
  if (is.na(x$label)) {
    return(invisible(NULL))
  }

  ns <- NS(x$ns)

  shiny_prerendered_chunk('server', code = sprintf(
    'examinr:::.section_end_server(examinr:::unserialize_object("%s"))',
    serialize_object(x)))

  knit_print(actionButton(ns('btn-next'), label = x$label, class = add_prefix('btn-', x$context %||% 'default')), ...)
}

#' @importFrom shiny NS moduleServer
#' @importFrom htmltools HTML
.section_end_server <- function (metadata) {
  moduleServer(metadata$ns, function (input, output, session) {

  })
}
