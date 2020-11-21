## knitr opts_hook for chunks with examinr.sectionchunk=TRUE
exam_section_opts_hook <- function (options, ...) {
  options$eval <- TRUE
  options$include <- TRUE
  options$echo <- FALSE
  options$comment <- NA
  return(options)
}

## Start a new section
#' @importFrom knitr opts_chunk
section_start <- function (section_id) {
  opts_chunk$set(examinr.section_id = section_id)
  return(structure(list(id = section_id), class = 'examinr_section_start'))
}

## Print section start
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @importFrom htmltools tags
#' @method knit_print examinr_section_start
#' @rdname knit_print
#' @export
#' @keywords internal
knit_print.examinr_section_start <- function (x, ...) {
  # render an anchor div to find the section from the UI javascript code.
  knit_print(tags$div(id = x$id), ...)
}

## Render a chunk of a section
#' @importFrom knitr opts_chunk
section_chunk <- function (section_id, content_enc, chunk_counter) {
  structure(list(id = section_id, content_enc = content_enc, counter = chunk_counter),
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
  ns <- NS(paste(x$id, x$counter, sep = '-'))

  metadata <- list(id = x$id, chunk_ns = ns(NULL))
  shiny_prerendered_chunk('server', code = sprintf('examinr:::section_chunk_server("%s", "%s")',
                                                   serialize_object(metadata), x$content_enc))

  knit_print(htmlOutput(ns('out')), ...)
}

## Add controls at the end of a section for navigation
section_end <- function (section_name, section_id, exam_metadata, btn_label) {
  exam_metadata <- unserialize_object(exam_metadata)
  opts_chunk$set(examinr.section_id = NULL)
  structure(list(name = section_name, id = section_id, progressive = exam_metadata$progressive,
                 label = enc2utf8(as.character(btn_label))),
            class = 'examinr_section_end')
}

## Print section end
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @importFrom knitr knit_print knit_meta_add opts_knit
#' @importFrom shiny NS actionButton
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @method knit_print examinr_section_end
#' @rdname knit_print
#' @export
#' @keywords internal
knit_print.examinr_section_end <- function (x, ...) {
  knit_meta_add(list(structure(list(id = x$id, name = x$name, has_button = !is.na(x$label)),
                               class = 'examinr_section')))

  if (is.na(x$label)) {
    return(invisible(NULL))
  }
  shiny_prerendered_chunk('server', code = sprintf('examinr:::section_end_server("%s")', serialize_object(x)))

  knit_print(actionButton(NS(x$id, 'btn-next'), label = x$label, class = 'examinr-section-next btn-primary'), ...)
}
