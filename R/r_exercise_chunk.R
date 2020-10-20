#' @include state_frame.R
.support_code <- state_frame()

#' @importFrom rlang abort
#' @importFrom stringr str_ends fixed str_sub
#' @importFrom knitr all_labels knit_code
#' @importFrom rmarkdown shiny_prerendered_chunk
opts_hook_possible_exercise <- function (options, ...) {
  # Check if the the chunk is an exercise, a setup chunk (ends in `-setup`), or a solution chunk (ends in `-solution`).
  if (isTRUE(options[['exercise']])) {
    options$eval <- FALSE
    options$echo <- TRUE
    options$highlight <- FALSE
    options$comment <- NA

    if (is.null(knit_code$get(options$label))) {
      abort(sprintf("Exercise chunk '%s' is completely empty. Add at least one empty line inside the code chunk.",
                    options$label))
    }

    shiny_prerendered_chunk(context = 'server-start', sprintf(
      'examinr:::register_exercise_options(options = "%s", exercise_label = "%s")',
      serialize_object(options), options$label))

    .exam_data$append(implied_static_chunks = options$label)
  } else {
    exercise_chunk_labels <- all_labels(eval(quote(exercise == TRUE)))  # quote to silence R CMD check
    for (type in c('setup', 'solution', 'check')) {
      if (isTRUE(str_ends(options$label, fixed(paste('-', type, sep = ''))))) {
        exercise_label <- str_sub(options$label, end = -nchar(type) - 2)
        if (isTRUE(exercise_label %in% exercise_chunk_labels)) {
          # Collect the code for the server context
          chunk_code <- options$code
          attr(chunk_code, 'chunk_opts') <- extract_relevant_chunk_options(options)

          # Don't evaluate or print the code in the chunk.
          options$eval <- FALSE
          options$echo <- FALSE
          options$include <- FALSE

          if (!is.null(chunk_code)) {
            shiny_prerendered_chunk(context = 'server-start', sprintf(
              'examinr:::register_support_code(code = "%s", what = "%s", exercise_label = "%s")',
              serialize_object(chunk_code), type, exercise_label))
          }

          .exam_data$append(implied_static_chunks = options$label)
        }
        break
      }
    }
  }

  return(options)
}

## Extract options from exercise / exercise support chunks which should be re-established
## when evaluation the user code.
extract_relevant_chunk_options <- function (options) {
  options[names(options) %in% c('results', 'dev.args', 'dpi', 'fig.width', 'fig.height', 'fig.asp', 'fig.dim',
                                'out.width', 'out.height', 'fig.retina', 'engine')]
}

#' @importFrom rlang abort
#' @importFrom jsonlite toJSON
#' @importFrom stringr str_detect str_remove
#' @importFrom shiny NS
#' @importFrom rmarkdown shiny_prerendered_chunk
knit_hook_possible_exercise <- function (before, options, envir, ...) {
  if (!isTRUE(options[['exercise']])) {
    return(NULL)
  }

  if (before) {
    label <- get_chunk_label(options)

    section_ns <- NS(opts_chunk$get('examinr.section_ns') %||% opts_chunk$get('examinr.section_id') %||%
                       random_ui_id('unknown_section'))

    points_str <- if (!is.null(options$exercise.points)) {
      if (options$exercise.points[[1L]] < 0) {
        abort("`exercise.points` must be non-negative.")
      }
      .exam_data$get('points_format')(options$exercise.points[[1L]])
    } else {
      NULL
    }

    status_messages <- options[str_detect(names(options), fixed('exercise.status_'))]
    names(status_messages) <- str_remove(names(status_messages), fixed('exercise.status_'))

    exercise_data <- list(label = label,
                          section_ns = section_ns(NULL),
                          input_id = section_ns(label),
                          output_id = section_ns(paste(label, 'out', sep = '-')),
                          points = points_str,
                          status_messages = status_messages,
                          panel_class = add_prefix('panel-', options$exam.question_context %||% 'default'),
                          button_class = add_prefix('btn-', options$exercise.button_context %||% 'default'),
                          label_class = add_prefix('label-', opts_current$get('exam.points_context') %||% 'info'),
                          title = options$exercise.title,
                          button = options$exercise.button,
                          engine = tolower(options$engine %||% 'r'),
                          lines = options$exercise.lines %||% 5,
                          completion = options$exercise.completion %||% FALSE)

    exercise_div <- sprintf('<div class="examinr-exercise"><script type="application/json">%s</script>',
                            toJSON(exercise_data, force = TRUE, auto_unbox = TRUE, digits = NA, null = 'null'))

    shiny_prerendered_chunk('server', sprintf('examinr:::exercise_chunk_server("%s")', serialize_object(exercise_data)))

    return(exercise_div)
  } else {
    return('</div>')
  }
}

#' @importFrom rlang exec `:=`
register_support_code <- function (code, what, exercise_label) {
  code <- unserialize_object(code)
  exec(.support_code$append, !!exercise_label := exec('list', !!what := code))
}

#' @importFrom rlang exec `:=`
register_exercise_options <- function (options, exercise_label, force = TRUE, unserialize = TRUE) {
  if (isTRUE(unserialize)) {
    options <- unserialize_object(options)
  }
  if (isTRUE(force) || is.null(.exam_data$get('exercise_chunk_options')[[exercise_label]])) {
    .exam_data$append(exercise_chunk_options = exec('list', !!exercise_label := options))
  }
}

register_global_exercise_options <- function (options, force = TRUE, unserialize = TRUE) {
  if (isTRUE(unserialize)) {
    options <- unserialize_object(options)
  }
  if (isTRUE(force) || is.null(.exam_data$get('global_exercise_chunk_options'))) {
    .exam_data$set(global_exercise_chunk_options = options)
  }
}

#' @importFrom rlang is_missing
get_exercise_option <- function (label, what, default = NULL) {
  global <- .exam_data$get('global_exercise_chunk_options')[[what]] %||% default
  if (!is_missing(label) && !is.null(label)) {
    .exam_data$get('exercise_chunk_options')[[label]][[paste('exercise', what, sep = '.')]] %||% global
  } else {
    global
  }
}

#' Create Exercise Results
#'
#' Create error results from a custom exercise evaluator.
#'
#' @param feedback a message to be displayed underneath the code chunk.
#' @param html_output the HTML code to be inserted into the exercise's output container.
#' @param severity can be one of `error`, `warning`, or `info`.
#' @param error_message if present, `severity` is set to `error` and the error message is used as feedback.
#' @param timeout_exceeded if `TRUE`, `severity` is set to `error` and the timeout error message is shown.
#' @param label the label of the exercise chunk. If missing, globally defined status messages are displayed
#'  instead of the chunk-specific messages.
#'
#' @importFrom rlang is_missing
exercise_result <- function (feedback, html_output, error_message, timeout_exceeded = FALSE, severity, label = NULL) {
  if (!is_missing(error_message)) {
    result <- exercise_result_error(error_message, 'error')
    result$html_output <- html_output
    return(result)
  }
  if (isTRUE(timeout_exceeded)) {
    result <- exercise_result_timeout(label)
    result$html_output <- html_output
    return(result)
  }

  status_class <- if (is_missing(severity)) {
    'success'
  } else {
    ifelse(severity == 'error', 'danger', severity)
  }

  fallback_status_msg <- if (is_missing(severity)) {
    get_exercise_option(label, 'status_success')
  } else if (isTRUE(severity == 'error')) {
    get_exercise_option(label, 'status_error')
  } else {
    NULL
  }

  structure(list(html_output = html_output, status_class = status_class, status = feedback %||% fallback_status_msg),
            class = 'exminar_exercise_result')
}

#' @description
#' `exercise_result_error()` is the preferred way to create an error result.
#'
#' @rdname exercise_result
#' @export
exercise_result_error <- function (error_message, severity = c('error', 'warning', 'info'), timeout_exceeded = FALSE,
                                   label = NULL) {
  if (isTRUE(timeout_exceeded)) {
    return(exercise_result_timeout(label))
  }
  structure(list(status_class = switch(match.arg(severity), warning = 'warning', 'danger'),
                 status = error_message %||% get_exercise_option(label, 'status_error')),
            class = 'exminar_exercise_result')
}

#' @description
#' `exercise_result_empty()` creates an exercise result representing an "empty" output.
#'
#' @rdname exercise_result
#' @export
exercise_result_empty <- function (label = NULL, severity) {
  status_class <- if (is_missing(severity)) {
    'warning'
  } else {
    ifelse(severity == 'error', 'danger', severity)
  }
  structure(list(status_class = status_class, status = get_exercise_option(label, 'status_empty')),
            class = 'exminar_exercise_result')
}

#' @description
#' `exercise_result_timeout()` is a short-hand version for the common problem of the R code timing out.
#'
#' @details
#' The function `exercise_result_timeout()` uses the correct message configured for the exam (or code chunk).
#'
#' @rdname exercise_result
#' @export
exercise_result_timeout <- function (label = NULL) {
  exercise_result_error(get_exercise_option(label, 'status_timeout'))
}

#' @importFrom rlang is_condition cnd_type cnd_message warn
render_exercise_result <- function (label, result) {
  function () {
    if (is_condition(result)) {
      status_class <- switch(cnd_type(result), warning = 'warning', error = 'danger', 'info')
      return(list(status_class = status_class, status = cnd_message(result)))
    }
    if (!inherits(result, 'exminar_exercise_result')) {
      rlang::warn("Exercise result is of wrong type!")
      return(list(status_class = 'danger', status = 'Cannot render result.'))
    }
    return(list(result = result$html_output, status_class = result$status_class,
                status = result$status %||% get_exercise_option(label, 'status_success')))
  }
}

#' @importFrom stringr str_remove str_replace_all str_detect
check_exercise_code <- function (input) {
  # Check if the code is empty
  if (str_detect(input$code, '^\\s*$')) {
    return(exercise_result_empty(input$label))
  }

  # Check if the code is syntactically valid (if it's R code)
  if (isTRUE(input$engine == 'r')) {
    invalid_syntax <- tryCatch({
      str2expression(input$code)
      NULL
    }, error = function (e) {
      str_replace_all(str_remove(e$message, '^<text>:\\d+:\\d+:\\s+'), fixed('\n'), '<br />')
    })

    if (!is.null(invalid_syntax)) {
      exercise_result_error(sprintf('%s <pre><code>%s</code></pre>', get_exercise_option(input$label, 'status_invalid'),
                                    invalid_syntax))
    }
  }

  return(NULL)
}

#' @importFrom shiny observeEvent observe invalidateLater isolate
exercise_chunk_server <- function (exercise_data) {
  exercise_data <- unserialize_object(exercise_data)

  moduleServer(exercise_data$section_ns, function (input, output, session) {
    observeEvent(input[[exercise_data$label]], {
      input_data <- isolate(input[[exercise_data$label]])
      output_id <- paste(exercise_data$label, 'out', sep = '-')

      # First do some preliminary checks of the code
      check_result <- check_exercise_code(input_data)
      if (!is.null(check_result)) {
        # The checks have not passed. Update the output and be done.
        output[[paste(exercise_data$label, 'out', sep = '-')]] <- render_exercise_result(
          exercise_data$label, check_result)
      } else {
        # The checks have passed. Evaluate the code.
        timelimit <- get_exercise_option(exercise_data$label, 'timelimit', 5)
        endtime <- Sys.time() + timelimit

        exercise_runner <- prepare_exercise_runner(input_data, exercise_data, session, timelimit)
        exercise_runner$start()
        delay <- 100
        observe({
          if (exercise_runner$completed()) {
            output[[output_id]] <- render_exercise_result(exercise_data$label, exercise_runner$result())
            if (!is.null(exercise_runner$kill)) {
              exercise_runner$kill()
            }
          } else if (Sys.time() < endtime) {
            invalidateLater(delay)
            delay <<- min(2000, 1.3 * delay)
          } else {
            output[[output_id]] <- render_exercise_result(exercise_data$label,
                                                          exercise_result_timeout(exercise_data$label))

            if (!is.null(exercise_runner$kill)) {
              exercise_runner$kill()
            }
          }
        })
      }
    })
  })
}

prepare_exercise_runner <- function (input_data, exercise_data, session, timelimit) {
  eval_exercise_env <- new.env(parent = baseenv())
  eval_exercise_env$label <- exercise_data$label
  eval_exercise_env$rendering_env <- get_exercise_user_env(exercise_data$label, session)
  eval_exercise_env$support_code <- .support_code$get(exercise_data$label)
  eval_exercise_env$code <- input_data$code
  eval_exercise_env$options <- list(global = .exam_data$get('global_exercise_chunk_options'),
                                    chunk = .exam_data$get('exercise_chunk_options')[[exercise_data$label]] %||% list())

  # Construct the expression which will turn the user code into a html result.
  expr <- quote(examinr::evaluate_exercise(code, support_code, options, rendering_env, label))

  .exam_data$get('exercise_evaluator')(expr = expr, envir = eval_exercise_env, timelimit = timelimit,
                                       label = exercise_data$label)
}

#' Evaluate Exercise
#'
#' Evaluate the user code of an exercise. This compiles an Rmd file with the given code
#' and calls [rmarkdown::render()] in the correct environment.
#'
#' @param user_code character vector of user code.
#' @param support_code list of support codes.
#' @param chunk_options chunk options for the _user_ code.
#' @param envir environment in which to execute the user and support code.
#' @param label the exercise label
#'
#' @keywords internal
#'
#' @importFrom stringr str_detect
#' @importFrom rmarkdown html_fragment render
#' @export
evaluate_exercise <- function (user_code, support_code, options, envir, label) {
  tmpfile <- tempfile(fileext = '.Rmd')
  on.exit(unlink(tmpfile, force = TRUE))

  write_exercise_rmd(tmpfile, user_code, support_code, options$chunk$engine)
  out <- html_fragment(mathjax = FALSE,
                       section_divs = FALSE,
                       number_sections = FALSE,
                       toc = FALSE,
                       anchor_sections = FALSE,
                       fig_caption = TRUE,
                       df_print = 'default',
                       code_download = FALSE)

  out$knitr$opts_chunk <- c(extract_relevant_chunk_options(options$chunk),
                            list(eval = TRUE, echo = FALSE, include = TRUE, fig.keep = 'all', dev = 'png'))

  # Set package-internal state if necessary
  register_global_exercise_options(options$global, force = FALSE, unserialize = FALSE)
  register_exercise_options(options$chunk, label, force = FALSE, unserialize = FALSE)

  output_html <- render(tmpfile, output_format = out, quiet = TRUE)
  on.exit(unlink(output_html, force = TRUE), add = TRUE)

  html_output_str <- paste(readLines(output_html, encoding = 'UTF-8'), collapse = '\n')
  if (str_detect(html_output_str, '^\\s*$')) {
    exercise_result_empty(label, 'info')
  } else {
    exercise_result(html_output = html_output_str)
  }
}

write_exercise_rmd <- function (fname, user_code, support_code, user_code_engine) {
  rmd_fh <- file(fname, open = 'wt')
  writeLines(con = rmd_fh, '---\ntitle: Exercise\n---\n')
  # Setup chunk
  if (!is.null(support_code$setup)) {
    setup_chunk_opts <- attr(support_code$setup, 'chunk_opts')
    if (!is.null(setup_chunk_opts)) {
      setup_chunk_opts$label <- NULL

      writeLines(con = rmd_fh, c('```{', engine <- tolower(setup_chunk_opts$engine %||% 'r'), ',',
                                 chunk_options_to_string(setup_chunk_opts), '}\n'), sep = '')
    } else {
      writeLines(con = rmd_fh, '```{r}')
    }

    writeLines(con = rmd_fh, support_code$setup)
    writeLines(con = rmd_fh, '```')
  }

  # Chunk with user code
  writeLines(con = rmd_fh, sprintf('```{%s, eval=TRUE, echo=FALSE}', tolower(user_code_engine %||% 'r')))
  writeLines(con = rmd_fh, user_code)
  writeLines(con = rmd_fh, '```')

  on.exit(close(rmd_fh))
}

chunk_options_to_string <- function (chunk_options) {
  list_str <- paste(deparse(chunk_options, backtick = TRUE), collapse = '')
  # remove the parts "list(" at the beginning and ")" at the end.
  str_sub(list_str, 6, -2)
}
