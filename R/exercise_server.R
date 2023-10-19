#' @importFrom shiny observeEvent observe invalidateLater isolate getDefaultReactiveDomain
#' @importFrom promises then is.promising
#' @importFrom rlang warn cnd_message local_use_cli
exercise_chunk_server <- function (exercise_data) {
  exercise_data <- unserialize_object(exercise_data)
  session <- getDefaultReactiveDomain()

  # register a transformation function for this exercise
  register_transformer(exercise_data$input_id, session = session, function (input_value, session) {
    input_value$code
  })

  solution <- if (!is.null(exercise_data$support_code$solution)) {
    md_as_html(paste(c('```{r, eval=FALSE, echo=TRUE}',
                       exercise_data$support_code$solution,
                       '```'),
                     collapse = '\n'),
               use_rmarkdown = TRUE)
  } else {
    NULL
  }

  register_static_autograder(exercise_data$input_id, max_points = exercise_data$points,
                             solution = solution,
                             session = session)

  observeEvent(session$input[[exercise_data$input_id]], {
    input_data <- session$input[[exercise_data$input_id]]

    if (isTRUE(input_data$evaluate)) {
      # First do some preliminary checks of the code
      check_result <- check_exercise_code(input_data, exercise_data)
      if (!is.null(check_result)) {
        # The checks have not passed. Update the output and be done.
        session$output[[exercise_data$output_id]] <- render_exercise_result(check_result)
      } else {
        # The checks have passed. Evaluate the code.
        timelimit <- exercise_data$timelimit %||% 1  # ensure that there is a time limit set!
        endtime <- Sys.time() + timelimit
        local_use_cli(format = FALSE)

        promise <- exercise_promise(input_data, exercise_data, session, timelimit)
        if (!is.promising(promise)) {
          warn(sprintf("Exercise evaluator for exercise %s does not yield a promise.",
                       exercise_data$label))
          session$output[[exercise_data$output_id]] <- render_exercise_result(
            exercise_result_error())
        } else {
          then(promise, onFulfilled = function (value) {
            session$output[[exercise_data$output_id]] <- render_exercise_result(value)
          }, onRejected = function (error) {
            warn(sprintf("Exercise evaluator for exercise %s raises an error: %s",
                         exercise_data$label),
                 cnd_message(error))
            session$output[[exercise_data$output_id]] <- render_exercise_result(
              exercise_result_error())
          })
        }
      }
    }

  })
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
#'
#' @importFrom rlang is_missing
exercise_result <- function (feedback, html_output, error_message, timeout_exceeded = FALSE, severity) {
  if (!is_missing(error_message)) {
    result <- exercise_result_error(error_message, 'error')
    result$html_output <- html_output
    return(result)
  }
  if (isTRUE(timeout_exceeded)) {
    result <- exercise_result_timeout()
    result$html_output <- html_output
    return(result)
  }

  status_class <- if (is_missing(severity)) {
    'success'
  } else if (identical(severity, 'error')) {
    'danger'
  } else {
    as.character(severity[[1L]])
  }

  fallback_status_msg <- if (is_missing(severity)) {
    get_status_message('exercise')$success
  } else if (identical(severity, 'error')) {
    get_status_message('exercise')$unknownError
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
exercise_result_error <- function (error_message, severity = c('error', 'warning', 'info'), timeout_exceeded = FALSE) {
  if (isTRUE(timeout_exceeded)) {
    return(exercise_result_timeout())
  }
  structure(list(status_class = switch(match.arg(severity), warning = 'warning', 'danger'),
                 status = error_message %||% get_status_message('exercise')$unknownError),
            class = 'exminar_exercise_result')
}

#' @description
#' `exercise_result_empty()` creates an exercise result representing an "empty" output.
#'
#' @rdname exercise_result
#' @export
exercise_result_empty <- function (severity) {
  status_class <- if (is_missing(severity)) {
    'warning'
  } else if (identical(severity, 'error')) {
    'danger'
  } else {
    as.character(severity[[1L]])
  }
  structure(list(status_class = status_class, status = get_status_message('exercise')$emptyResult),
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
exercise_result_timeout <- function () {
  exercise_result_error(get_status_message('exercise')$timeout)
}

#' @importFrom rlang is_condition cnd_type cnd_message warn local_use_cli
#' @importFrom stringr str_remove_all
render_exercise_result <- function (result) {
  function () {
    local_use_cli(format = FALSE)
    if (is_condition(result)) {
      status_class <- switch(cnd_type(result), warning = 'warning', error = 'danger', 'info')
      msg <- md_as_html(str_remove_all(cnd_message(result, prefix = TRUE), r'(\033[\d\[;]+m)'),
                        use_rmarkdown = FALSE)
      return(list(status_class = status_class, status = str_replace_all(msg, fixed('\n'), '<br />')))
    }
    if (!inherits(result, 'exminar_exercise_result')) {
      rlang::warn("Exercise result is of wrong type!")
      return(list(status_class = 'danger', status = 'Cannot render result.'))
    }
    return(list(result = result$html_output, status_class = result$status_class,
                status = result$status %||% get_status_message('exercise')$success))
  }
}

#' @importFrom stringr str_remove str_replace_all str_replace str_detect
check_exercise_code <- function (input, exercise_data) {
  # Check if the code is empty
  if (str_detect(input$code, '^\\s*$')) {
    return(exercise_result_empty(input$label))
  }

  # Check if the code is syntactically valid (if it's R code)
  if (identical(exercise_data$engine, 'r')) {
    invalid_syntax <- tryCatch({
      str2expression(input$code)
      NULL
    }, error = function (e) {
      str_replace_all(str_remove(e$message, '^<text>:\\d+:\\d+:\\s+'), fixed('\n'), '<br />')
    })

    if (!is.null(invalid_syntax)) {
      return(exercise_result_error(str_replace(get_status_message('exercise')$syntaxError, fixed('{diagnostics}'),
                                               invalid_syntax)))
    }
  }

  return(NULL)
}

exercise_promise <- function (input_data, exercise_data, session, timelimit) {
  eval_exercise_env <- new.env(parent = baseenv())
  eval_exercise_env$label <- exercise_data$label
  eval_exercise_env$rendering_env <- get_exercise_user_env(exercise_data$label, session = session)
  eval_exercise_env$support_code <- exercise_data$support_code
  eval_exercise_env$code <- input_data$code
  eval_exercise_env$options <- exercise_data$chunk_options
  eval_exercise_env$status_messages <- get_status_message()

  # Construct the expression which will turn the user code into a html result.
  expr <- quote(examinr::evaluate_exercise(code, support_code, options, status_messages, rendering_env, label))
  setup_exercise_promise(expr, eval_exercise_env, exercise_data$label, timelimit)
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
#' @importFrom stringr str_detect str_starts fixed
#' @importFrom rmarkdown html_fragment render
#' @importFrom tools Rd2txt_options
#' @importFrom rlang local_use_cli
#' @export
evaluate_exercise <- function (user_code, support_code, chunk_options, status_messages, envir, label) {
  tmpfile <- tempfile(fileext = '.Rmd')
  on.exit(unlink(tmpfile, force = TRUE))

  write_exercise_rmd(tmpfile, user_code, support_code, chunk_options$engine)
  out <- html_fragment(mathjax = FALSE,
                       section_divs = FALSE,
                       number_sections = FALSE,
                       toc = FALSE,
                       anchor_sections = FALSE,
                       fig_caption = TRUE,
                       df_print = chunk_options$df_print,
                       code_download = FALSE)

  out$knitr$opts_chunk <- c(chunk_options,
                            list(eval = TRUE, echo = FALSE, include = TRUE, fig.keep = 'all', dev = 'png'))

  # Set package-internal state if necessary
  set_status_messages(status_messages)

  # Make error messages from rlang not use CLI:
  local_use_cli(format = FALSE)

  parent.env(envir) <- globalenv()

  # Render help pages as simple text. This isn't optimal, but better than no output.
  opts <- options(help_type = 'text',
                  pager = function  (files, header, title, delete.file) {
                    if (isTRUE(delete.file)) {
                      on.exit(unlink(files, force = TRUE))
                    }
                    cont <- vapply(files, FUN.VALUE = character(1L), function (fname) {
                      paste(readLines(fname, encoding = 'UTF-8'), collapse = '\n')
                    })
                    cat(paste(cont, collapse = '\n'))
                  })
  on.exit(options(opts), add = TRUE)

  rd2txt_opts <- Rd2txt_options()
  Rd2txt_options(underline_titles = FALSE, width = 80, extraIndent = 2, sectionIndent = 4, sectionExtra = 2)
  on.exit(Rd2txt_options(rd2txt_opts), add = TRUE)

  # Sanitize the system environment: only keep required and R-related env variables
  envvars <- Sys.getenv()
  keep_envvars <- names(envvars) %in% c('PATH', 'HOME', 'LANG', 'TAR', 'TMPDIR', 'USER', 'UID', 'GID', 'LC') |
    str_starts(names(envvars), fixed('R_'))
  Sys.unsetenv(names(envvars)[!keep_envvars])
  on.exit(do.call(Sys.setenv, as.list(envvars)), add = TRUE)

  output_html <- render(tmpfile, output_format = out, quiet = TRUE, envir = envir)
  on.exit(unlink(output_html, force = TRUE), add = TRUE)

  html_output_str <- paste(readLines(output_html, encoding = 'UTF-8'), collapse = '\n')
  if (str_detect(html_output_str, '^\\s*$')) {
    exercise_result_empty('info')
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

