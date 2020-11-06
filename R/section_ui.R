## knitr opts_hook for chunks with examinr.sectionchunk=TRUE
exam_section_opts_hook <- function (options, ...) {
  options$eval <- TRUE
  options$include <- TRUE
  options$echo <- FALSE
  options$comment <- NA
  return(options)
}

## Initialize the UI component for section management
#' @importFrom knitr knit_meta
#' @importFrom rlang abort
initialize_sections <- function (options, overrides) {
  overrides <- unserialize_object(overrides)
  # Merge section information with section configuration overrides
  sections <- knit_meta('examinr_section')

  any_has_button <- any(vapply(sections, FUN.VALUE = logical(1L), `[[`, 'has_button'))
  if (!isTRUE(any_has_button)) {
    abort("At least one exam section must have a visible button.")
  }

  sections <- lapply(sections, function (section) {
    section$overrides <- overrides[[section$id]] %||% list()
    return(section)
  })

  return(structure(list(sections = sections, options = options), class = 'examinr_section_init'))
}

## Print section initialization
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @method knit_print examinr_section_init
#' @rdname knit_print
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @export
#' @keywords internal
knit_print.examinr_section_init <- function (x, ...) {
  # Note that x$options is already serialized!
  shiny_prerendered_chunk('server', sprintf('examinr:::initialize_sections_server("%s", "%s")',
                                            serialize_object(x$sections),
                                            x$options))

  knit_print(tags$script(id = 'examinr-sections-options', type = 'application/json',
                         to_json(unserialize_object(x$options))), ...)
}

## Start a new section
#' @importFrom knitr opts_chunk
section_start <- function (section_id, section_ui_id) {
  opts_chunk$set(examinr.section_id = section_id, examinr.section_ui_id = section_ui_id)
  return(structure(list(id = section_id, ui_id = section_ui_id), class = 'examinr_section_start'))
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
  knit_print(tags$div(id = x$ui_id))
}

## Render a chunk of a section
#' @importFrom knitr opts_chunk
section_chunk <- function (section_id, section_ui_id, content_enc, chunk_counter) {
  structure(list(id = section_id, ui_id = section_ui_id, content_enc = content_enc, counter = chunk_counter),
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
  chunk_ns <- paste(x$ui_id, x$counter, sep = '-')
  ns <- NS(chunk_ns)

  metadata <- c(x[c('id', 'ui_id')], chunk_ns = chunk_ns)
  shiny_prerendered_chunk('server', code = sprintf('examinr:::section_chunk_server("%s", "%s")',
                                                   serialize_object(metadata), x$content_enc))

  knit_print(htmlOutput(ns('out')), ...)
}

## Add controls at the end of a section for navigation
section_end <- function (section_id, section_ui_id, btn_label, btn_context) {
  opts_chunk$set(examinr.section_id = NULL, examinr.section_ui_id = NULL)
  structure(list(id = section_id, ui_id = section_ui_id,
                 context = enc2utf8(as.character(btn_context)),
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
  knit_meta_add(list(structure(list(id = x$id, ui_id = x$ui_id, has_button = !is.na(x$label)),
                               class = 'examinr_section')))

  if (is.na(x$label)) {
    return(invisible(NULL))
  }
  ns <- NS(x$ui_id)
  shiny_prerendered_chunk('server', code = sprintf('examinr:::section_end_server("%s")', serialize_object(x)))

  knit_print(actionButton(ns('btn-next'), label = x$label,
                          class = paste('examinr-section-next', add_prefix('btn-', x$context %||% 'default'))), ...)
}
