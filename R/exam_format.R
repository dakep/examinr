#' Exam Output Format
#'
#' @param use_cdn load javascript libraries from external content delivery networks (CDNs).
#'   Use this if the shiny server is slow at serving static resources, but beware of the downsides of
#'   relying on content from a third-party!
#' @param question_context,points_context,exercise_button_context,next_button_context contextual style classes for
#'   question panels, points labels, exercise buttons, and section navigation buttons.
#'   Can be `default` or any of the bootstrap 3 contextual classes listed at
#'   <https://getbootstrap.com/docs/3.3/css/#helper-classes-colors>.
#'   These can also be set on a per-question or per-exercise level by specifying code chunk options
#'   `exam.question_context`, `exam.points_context` and `exercise.button_context`.
#'   A section-specific button context can be set via [section_specific_options()].
#' @param ... passed on to [html_document()][rmarkdown::html_document()]. Parameters `section_divs` and `toc` are not
#'   supported.
#'
#' These status messages can also be overwritten by setting the exercise chunk options `exercise.status_xyz`, where
#' `xyz` is one of the status message types listed above.
#'
#' @importFrom rmarkdown output_format html_document html_dependency_jquery
#' @importFrom htmltools htmlDependency
#' @importFrom stringr str_starts str_sub
#' @importFrom utils packageVersion
#'
#' @export
exam_document <- function (use_cdn = FALSE, question_context = 'default', points_context = 'info',
                           exercise_button_context = points_context, next_button_context = 'primary', ...) {
  rmd_input_file <- NULL

  html_document_args <- list(...)
  html_document_args$section_divs <- TRUE
  html_document_args$anchor_sections <- FALSE
  html_document_args$toc <- FALSE

  additional_dependencies <- if (isTRUE(use_cdn)) {
    list(htmlDependency('ace', '1.4.12', c(href='https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12'),
                        head = '<script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12/ace.min.js"
          integrity="sha512-GoORoNnxst42zE3rYPj4bNBm0Q6ZRXKNH2D9nEmNvVF/z24ywVnijAWVi/09iBiVDQVf3UlZHpzhAJIdd9BXqw=="
                        crossorigin="anonymous"></script>
                        <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12/mode-r.min.js"
          integrity="sha512-Ywj4QTNVz4uBn0XqobDKK5pgwN5/bK1/RBAUxDq+2luI+mvA6pteiuuWXZZ4i6UQUnUMwa/UD+9MqOr2hn9H9g=="
                        crossorigin="anonymous"></script>
                        <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12/theme-textmate.min.js"
          integrity="sha512-EfT0yrRqRKdVeJXcphL/4lzFc33WZJv6xAe34FMpICOAMJQmlfsTn/Bt/+eUarjewh1UMJQcdoFulncymeLUgw=="
                        crossorigin="anonymous"></script>'))
  } else {
    list(htmlDependency('ace', '1.4.12', package = 'examinr', src = 'lib', script = 'ace-1.4.12.js'))
  }

  html_document_args$extra_dependencies <- c(html_document_args$extra_dependencies %||% list(),
                                             additional_dependencies,
                                             list(htmlDependency('exam', packageVersion('examinr'),
                                                                 package = 'examinr', src = 'www',
                                                                 script = 'exam.min.js', stylesheet = 'exam.min.css'),
                                                  html_dependency_jquery()))

  is_render <- isTRUE(html_document_args[['.examinr_is_render_serverside']])
  html_document_args[['.examinr_is_render_serverside']] <- NULL

  .support_code$reset()

  out <- output_format(
    pandoc = list(to = 'html5'),
    pre_knit = function (input, ...) {
      rmd_input_file <<- input
    },
    post_processor = function (metadata, input_file, output_file, clean, verbose, ...) {
      return(sections_to_serverside_content(metadata, rmd_input_file, output_file, clean, verbose,
                                            is_render = is_render, ...))
    },
    base_format = do.call(html_document, html_document_args),
    knitr = list(opts_chunk = list(examinr.exam = TRUE,
                                   exam.question_context = question_context,
                                   exam.points_context = points_context,
                                   exam.exercise_button_context = exercise_button_context,
                                   exam.next_button_context = next_button_context,
                                   exam.static = FALSE),
                 opts_hooks = list(examinr.exam = opts_hook_exam_format,
                                   examinr.sectionchunk = .exam_section_opts_hook),
                 knit_hooks = list(examinr.exam = knit_hook_possible_exercise)))

  return(out)
}

#' @importFrom knitr opts_knit knit_meta_add
#' @importFrom rmarkdown metadata
#' @importFrom rlang abort
opts_hook_exam_format <- function (options, ...) {
  if (!isTRUE(getOption('knitr.in.progress'))) {
    return(options)
  }

  if (!isTRUE(knitr::opts_knit$get('rmarkdown.runtime') == 'shiny_prerendered')) {
    abort("examinr exams can only be used with runtime: shiny_prerendered.")
  }

  if (!isTRUE(opts_knit$get('examinr.exam.initialized'))) {
    # Initialize the exam ...
    sections_options_from_metadata(rmarkdown::metadata$exam$sections)

    # Parse metadata
    # shiny_prerendered_chunk('server', sprintf('stat305templates:::.initialize_lab_server(session, metadata = %s)',
    #                                           dput_object(rmarkdown::metadata$lab)), singleton = TRUE)
    #
    # shiny_prerendered_chunk('server-start', 'stat305templates:::.generate_lab_key()', singleton = TRUE)

    opts_knit$set(examinr.exam.initialized = TRUE)
  }

  if (!isTRUE(opts_chunk$get('exercise_options_set'))) {
    # Set the global exercise options
    exercise_options()
  }

  if (is.null(options[['context']]) || isTRUE(options[['context']] == 'render')) {
    # Check all chunks within the "render" context for R exercise
    return(opts_hook_possible_exercise(options, ...))
  } else {
    return(options)
  }
}

#' @importFrom rmarkdown render
#' @importFrom rlang abort inform
#' @importFrom stringi stri_trim_both
#' @importFrom stringr str_detect str_starts fixed str_match str_sub str_replace_all str_remove regex
sections_to_serverside_content <- function (metadata, input_file, output_file, clean, verbose, is_render = TRUE, ...) {
  if (isTRUE(is_render)) {
    return(output_file)
  }

  if (!isTRUE(.sections_data$get('render') == 'server')) {
    if (verbose) inform("Exam file does not use server-side content.")
    return(output_file)
  }

  run_document <- file.path(dirname(input_file),
                            sprintf('%s.server.Rmd',
                                    str_remove(basename(input_file), regex('\\.rmd$', ignore_case = TRUE))))

  if (verbose) inform(sprintf("Creating exam file with server-side content as %s.", basename(run_document)))

  outfh <- file(run_document, open = 'wt', encoding = 'UTF-8')
  on.exit(tryCatch(close(outfh), error = function(...) {}), add = TRUE, after = FALSE)

  if (isTRUE(clean)) {
    on.exit(unlink(run_document, force = TRUE), add = TRUE, after = FALSE)
  }

  section_specifics <- .sections_data$get('specific')
  static_rchunks <- unlist(.exam_data$get('implied_static_chunks'), recursive = FALSE, use.names = FALSE)

  infh <- file(input_file, open = 'rt', encoding = 'UTF-8')
  on.exit(close(infh), add = TRUE, after = FALSE)

  input_lines <- enc2utf8(readLines(infh, warn = FALSE))

  inside_section <- FALSE
  inside_fixed_section <- FALSE
  current_section <- ''
  current_section_ui_id <- ''
  section_chunk_counter <- 1L
  inside_code_chunk <- FALSE
  run_chunk_server <- FALSE
  section_content <- vector('list')

  for (line in input_lines) {
    if (inside_code_chunk) {
      ## Inside a code chunk
      if (run_chunk_server) {
        section_content <- c(section_content, line)
      } else {
        writeLines(line, outfh)
      }
      if (line == '```') {
        run_chunk_server <- FALSE
        inside_code_chunk <- FALSE
      }
    } else if (str_starts(line, fixed('# '))) {
      ## A new section starts
      if (inside_section) {
        # a new section starts. output previous section.
        output_section_chunk(outfh, section_content, current_section, current_section_ui_id, section_chunk_counter)
        section_chunk_counter <- section_chunk_counter + 1L
        section_content <- vector('list')
      }
      if (inside_section || inside_fixed_section) {
        end_section_chunk(outfh, current_section, current_section_ui_id)
      }

      inside_section <- TRUE
      inside_fixed_section <- FALSE
      current_section <- normalize_section_name(line)
      current_section_ui_id <- random_ui_id(current_section)
      section_chunk_counter <- 1L


      # capture a new section, unless the next section is a "fixed" section
      if (isTRUE(section_specifics[[current_section]]$fixed)) {
        inside_fixed_section <- TRUE
        inside_section <- FALSE
      }

      writeLines('\n', outfh)
      writeLines(line, outfh)
      writeLines('\n', outfh)
      start_section_chunk(outfh, current_section, current_section_ui_id)

    } else if (str_starts(line, fixed('```{'))) {
      ## A code chunk begins
      inside_code_chunk <- TRUE
      run_chunk_server <- FALSE

      if (inside_section) {
        # Check if the chunk is to be run on the server
        run_chunk_server <- move_rchunk_into_section(line, static_rchunks)
        if (run_chunk_server) {
          section_content <- c(section_content, line)
        } else {
          output_section_chunk(outfh, section_content, current_section, current_section_ui_id, section_chunk_counter)
          section_chunk_counter <- section_chunk_counter + 1L
          section_content <- vector('list')

          writeLines(line, outfh)
        }
      } else {
        writeLines(line, outfh)
      }
    } else if (inside_section) {
      ## Inside a section
      section_content <- c(section_content, line)
    } else {
      ## Neither inside a section, nor a code chunk.
      writeLines(line, outfh)
    }
  }

  if (inside_section) {
    output_section_chunk(outfh, section_content, current_section, current_section_ui_id, section_chunk_counter)
  }
  if (inside_fixed_section || inside_section) {
    end_section_chunk(outfh, current_section, current_section_ui_id)
  }

  close(outfh)
  new_output <- render(run_document, quiet = !verbose, envir = parent.frame(), clean = clean,
                       output_options = list('.examinr_is_render_serverside' = TRUE))
  unlink(output_file)
  return(basename(new_output))
}

## Does the R chunk need to be extracted and put into the section chunk?
#' @importFrom stringr str_detect str_match
move_rchunk_into_section <- function (line, static_chunks) {
  label <- str_match(line, '```\\{r\\s+([^,\\}\\s]+)')[[2L]]
  # Check if the chunk label
  if (!is.na(label) && isTRUE(label %in% static_chunks)) {
    return(FALSE)
  }
  # Check if the chunk has any of the options
  return(!any(str_detect(line, c('r\\s+setup,', 'context\\s*=\\s*[\'"]server(?:\\-start)?[\'"]',
                                 # 'examinr\\.sectionchunk\\s*=\\s*T(?:RUE)?',
                                 'exam\\.exercise\\s*=\\s*T(?:RUE)?',
                                 'exam\\.static\\s*=\\s*T(?:RUE)?'))))
}

output_section_chunk <- function (out_con, content, section, section_ns, chunk_counter) {
  if (length(content) > 0L) {
    content <- unlist(content, recursive = FALSE, use.names = FALSE)

    # if it's only empty lines, just output empty lines.
    if (all(nchar(content) == 0L)) {
      writeLines(content, out_con)
    } else {
      content_enc <- serialize_object(content)
      writeLines(c('```{r, examinr.sectionchunk=TRUE}',
                   sprintf('examinr:::section_chunk("%s", "%s", "%s", %d)',
                           section, section_ns, content_enc, chunk_counter),
                   '```'), con = out_con)
    }
  }
}

start_section_chunk <- function (out_con, section, section_ns) {
  writeLines(c('```{r, examinr.sectionchunk=TRUE}',
               sprintf('examinr:::section_start("%s", "%s")', section, section_ns),
               '```'), con = out_con)
}

end_section_chunk <- function (out_con, section, section_ns) {
  writeLines(c('```{r, examinr.sectionchunk=TRUE}',
               sprintf('examinr:::section_end("%s", "%s")', section, section_ns),
               '```'), con = out_con)
}
