#' @include state_frame.R
#' @importFrom yaml read_yaml
.status_messages <- state_frame(yaml::read_yaml(system.file('messages.yaml', package = 'examinr', mustWork = TRUE),
                                                eval.expr = FALSE))

#' Customize Status Messages
#'
#' Customize the status messages displayed at various times and states during an exam.
#' A template with the default status messages can be saved as a YAML text file with `status_message_template()`.
#'
#' Note that `status_message_template()` should not be called from within an exam document. Rather, generate the
#' template once, modify as necessary, and use in the exam document by specifying the file name in the [exam_document()]
#' or by calling `status_messages()`
#'
#' Calling `status_messages()` without arguments invisibly returns the currently set status messages.
#'
#' @param file path to the messages file. For `status_message_template()`, this is where the template is saved
#'  (if `NULL`, only returns the default messages). For `status_messages()`, the file to read the status messages
#'  from.
#' @param messages Optionally specify the messages via an R list, in the same format as returned by
#'   `status_message_template()`. If `messages` is set, `file` is ignored with a warning.
#'
#' @return `status_message_template()` invisibly returns the default messages as R list.
#'   `status_messages()` invisibly returns the new status messages as R list.
#'
#' @importFrom yaml read_yaml
#' @importFrom rlang warn
#' @family localization
#' @export
status_message_template <- function (file) {
  if (isTRUE(getOption('knitr.in.progress'))) {
    warn("`status_message_template()` should not be called from a knitr document")
  }
  template <- system.file('messages.yaml', package = 'examinr', mustWork = TRUE)
  messages <- read_yaml(template, eval.expr = FALSE)

  if (is.null(file)) {
    cat(readLines(template, encoding = 'UTF-8'), sep = '\n')
  } else {
    file.copy(template, file, overwrite = FALSE)
  }

  return(invisible(messages))
}

#' @rdname status_message_template
#' @importFrom yaml read_yaml
#' @importFrom rlang warn abort
#' @importFrom knitr opts_current
#' @export
status_messages <- function (file, messages) {
  if (missing(file) && missing(messages)) {
    return(invisible(get_status_message()))
  }

  if (!is_knitr_context('setup')) {
    abort("`status_messages()` must be called in a context='setup' chunk.")
  }
  if (is_missing(messages) || is.null(messages)) {
    messages <- read_yaml(file, eval.expr = FALSE)
  } else {
    if (!is_missing(file)) {
      warn("Ignoring argument `file` as argument `messages` is also given.")
    }
  }
  validate_status_messages(messages)
  set_status_messages(messages)

  return(invisible(messages))
}

set_status_messages <- function (messages) {
  .status_messages$set(messages)
}

#' @importFrom rlang abort
get_status_message <- function (what) {
  if (is_missing(what)) {
    .status_messages$get()
  } else {
    .status_messages$get(what) %||% abort(paste("Requested unknown status message", what))
  }
}

#' @importFrom yaml read_yaml
#' @importFrom rlang abort
validate_status_messages <- function (messages, template = NULL, path = NULL) {
  if (is.null(template)) {
    template <- read_yaml(system.file('messages.yaml', package = 'examinr', mustWork = TRUE), eval.expr = FALSE)
  }

  for (name in names(template)) {
    subpath <- paste(c(path, name), collapse = ' > ')
    if (is.null(messages[[name]])) {
      abort(sprintf("Message string %s is missing.", subpath))
    } else if (is.list(template[[name]])) {
      if (is.list(messages[[name]])) {
        validate_status_messages(messages[[name]], template[[name]], subpath)
      } else {
        abort(sprintf("Messages malformed: %s must contain sub-items %s.", subpath,
                      paste(names(template[[name]]), collapse = ', ')))
      }
    }
  }
}
