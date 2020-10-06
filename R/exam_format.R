library(rmarkdown)
library(shiny)
library(htmltools)
library(knitr)
library(stringr)
library(stringi)
library(base64enc)

#' @importFrom rmarkdown html_document
#' @importFrom stringr str_remove regex
#' @export
exam_document <- function (keep_run_document = FALSE, section_divs = TRUE, toc = FALSE, self_contained = FALSE, ...) {
  rmd_input_file <- NULL

  additional_args <- list(...)

  out <- output_format(
    pandoc = list(to = 'html5'),
    pre_knit = function (input, ...) {
      rmd_input_file <<- input
    },
    post_processor = function (metadata, input_file, output_file, clean, verbose, ...) {
      return(sections_to_serverside_content(metadata, rmd_input_file, output_file, clean, verbose,
                                            is_render = isTRUE(additional_args[['.examinr_is_render_serverside']]),
                                            ...))
    },
    base_format = html_document(section_divs = section_divs, toc = toc, self_containted = self_contained, ...),
    knitr = list(opts_chunk = list(examinr.exam = TRUE),
                 opts_hooks = list(examinr.exam = function (options) {
                   initialize_exam()
                   return (options)
                 })))
  return(out)
}

#' @importFrom rmarkdown yaml_front_matter
#' @importFrom rlang abort inform
#' @importFrom stringi stri_trim_both
#' @importFrom stringr str_detect str_starts fixed str_match str_sub
sections_to_serverside_content <- function (metadata, input_file, output_file, clean, verbose, is_render = TRUE, ...) {
  if (isTRUE(is_render)) {
    return(output_file)
  }

  if (is.null(metadata$exam$sections) || !isTRUE(metadata$exam$sections$render == 'server')) {
    if (verbose) inform("Exam file does not use server-side content.")
    return(output_file)
  }

  run_document <- file.path(dirname(input_file),
                            sprintf('%s.exam.Rmd',
                                    str_remove(basename(input_file), regex('\\.rmd$', ignore_case = TRUE))))

  if (verbose) inform(sprintf("Creating exam file with server-side content as %s.", basename(run_document)))

  outfh <- file(run_document, open = 'wt', encoding = 'UTF-8')
  on.exit(tryCatch(close(outfh), error = function(...) {}), add = TRUE, after = FALSE)

  if (isTRUE(clean)) {
    on.exit(unlink(run_document, force = TRUE), add = TRUE, after = FALSE)
  }

  infh <- file(input_file, open = 'rt', encoding = 'UTF-8')
  on.exit(close(infh), add = TRUE, after = FALSE)

  input_lines <- enc2utf8(readLines(infh, warn = FALSE))

  inside_section <- FALSE
  inside_fixed_section <- FALSE
  current_section_id <- ''
  current_section_ns_id <- ''
  inside_code_chunk <- FALSE
  section_content <- vector('list')

  for (line in input_lines) {
    if (inside_code_chunk) {
      ## Inside a code chunk
      writeLines(line, outfh)
      if (line == '```') {
        inside_code_chunk <- FALSE
      }
    } else if (str_starts(line, fixed('# '))) {
      ## A new section starts
      if (inside_section) {
        # a new section starts. output previous section.
        output_section_chunk(outfh, section_content, current_section_id, current_section_ns_id)
        section_content <- vector('list')
      }
      if (inside_section || inside_fixed_section) {
        end_section_chunk(outfh, current_section_id, current_section_ns_id)
      }

      inside_section <- TRUE
      inside_fixed_section <- FALSE
      current_section_id <- if (str_detect(line, '\\s+\\{.*\\}\\s*$')) {
        str_match(line, '^#\\s+(.+)\\s+\\{.*\\}\\s*$')[[2]]
      } else {
        str_sub(line, 2L)
      }
      current_section_id <- stri_trim_both(str_replace_all(tolower(current_section_id), '[^a-zA-Z0-9]+', '-'),
                                           pattern = '[^\\p{Wspace}\\-]')
      current_section_ns_id <- random_ui_id(current_section_id)

      # capture a new section, unless the next section is a "fixed" section
      if (!is.null(metadata$exam$sections$fixed) &&
          any(str_detect(line, pattern = paste('#\\s+', metadata$exam$sections$fixed, '(\\s|$)', sep = '')))) {
        inside_fixed_section <- TRUE
        inside_section <- FALSE
      }

      writeLines('\n', outfh)
      writeLines(line, outfh)
      writeLines('\n', outfh)

    } else if (str_starts(line, fixed('```{'))) {
      ## A code chunk begins
      inside_code_chunk <- TRUE
      if (inside_section) {
        output_section_chunk(outfh, section_content, current_section_id, current_section_ns_id)
        section_content <- vector('list')
      }

      writeLines(line, outfh)
    } else if (inside_section) {
      ## Inside a section
      section_content <- c(section_content, line)
    } else {
      ## Neither inside a section, nor a code chunk.
      writeLines(line, outfh)
    }
  }

  if (inside_section) {
    output_section_chunk(outfh, section_content, current_section_id, current_section_ns_id)
  }
  if (inside_fixed_section || inside_section) {
    end_section_chunk(outfh, current_section_id, current_section_ns_id)
  }

  close(outfh)
  new_output <- render(run_document, quiet = !verbose, envir = parent.frame(), clean = clean,
                       output_options = list('.examinr_is_render_serverside' = TRUE))
  unlink(output_file)
  return(basename(new_output))
}

output_section_chunk <- function (out_con, content, section_id, section_ns_id) {
  if (length(content) > 0L) {
    content <- unlist(content, recursive = FALSE, use.names = FALSE)

    # if it's only empty lines, just output empty lines.
    if (all(nchar(content) == 0L)) {
      writeLines(content, out_con)
    } else {
      content_enc <- serialize_object(content)
      writeLines(c('```{r, eval=TRUE, echo=FALSE}',
                   sprintf('examinr:::section_chunk("%s", "%s", examinr:::unserialize_object("%s"))',
                           section_id, section_ns_id, content_enc),
                   '```'), con = out_con)
    }
  }
}

end_section_chunk <- function (out_con, section_id, section_ns_id) {
  writeLines(c('```{r, eval=TRUE, echo=FALSE}',
               sprintf('examinr:::section_end("%s", "%s")', section_id, section_ns_id),
               '```'), con = out_con)
}

#' @importFrom htmltools tagList
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @importFrom shiny observeEvent renderPrint textOutput actionButton
section_chunk <- function (section_id, section_ns_id, content) {
  content_enc <- serialize_object(unlist(content, recursive = FALSE, use.names = FALSE))
  output_id <- sprintf('out_%09d', sample.int(.Machine$integer.max, 1L))
  btn_id <- sprintf('btn_%09d', sample.int(.Machine$integer.max, 1L))
  shiny_prerendered_chunk('server', sprintf('observeEvent(input[["%s"]], { output[["%s"]] <- renderPrint(examinr:::unserialize_object("%s"))})',
                                            btn_id, output_id, content_enc))
  tagList(actionButton(btn_id, label="Hit me"), textOutput(output_id))
}

section_end <- function (section_id, section_ns_id) {
  cat("---------- END SECTION `",  section_id, "` (", section_ns_id, ") ---------------", sep = "")
}

#' @importFrom knitr opts_knit knit_meta_add
#' @importFrom rmarkdown metadata shiny_prerendered_chunk html_dependency_jquery html_dependency_bootstrap
initialize_exam <- function () {
  if (isTRUE(getOption('knitr.in.progress')) && !isTRUE(opts_knit$get('examinr.exam.initialized'))) {
    knit_meta_add(list(html_dependency_jquery()))

    # Parse metadata
    # shiny_prerendered_chunk('server', sprintf('stat305templates:::.initialize_lab_server(session, metadata = %s)',
    #                                           dput_object(rmarkdown::metadata$lab)), singleton = TRUE)
    #
    # shiny_prerendered_chunk('server-start', 'stat305templates:::.generate_lab_key()', singleton = TRUE)
    opts_knit$set(examinr.exam.initialized = TRUE)
  }
}
