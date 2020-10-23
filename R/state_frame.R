## Create a frame to hold the state of the package.
#' @importFrom rlang is_missing
state_frame <- function (defaults = list()) {
  values <- defaults

  list(get = function(name) {
    if (is_missing(name)) {
      return(values)
    }
    values[[name]]
  },
  set = function (...) {
    args <- args_to_list(...)
    if (!is.null(args)) {
      values[names(args)] <<- args
    }
    invisible(NULL)
  },
  append = function (...) {
    args <- args_to_list(...)
    if (!is.null(args)) {
      for (name in names(args)) {
        args[[name]] <- c(values[[name]], args[[name]])
      }
      values[names(args)] <<- args
    }
    invisible(NULL)
  },
  reset = function (name) {
    if (is_missing(name)) {
      values <<- defaults
    } else {
      values[[name]] <<- defaults[[name]]
    }
  })
}

#' @importFrom rlang maybe_missing is_missing call_args abort
args_to_list <- function (...) {
  # Defuse possibly missing arguments.
  args <- lapply(call_args(match.call()), function (symbol, envir) {
    eval(call('maybe_missing', symbol), envir = envir)
  }, envir = environment())
  args <- args[!vapply(args, is_missing, FUN.VALUE = logical(1L), USE.NAMES = FALSE)]

  # Check the non-missing arguments.
  if (length(args) == 1L && (is.null(names(args)) || all(!nzchar(names(args)))) && is.list(args[[1L]])) {
    args <- args[[1L]]
  }
  if (is.null(names(args)) || any(nchar(names(args)) == 0L)) {
    abort("Arguments must be named.")
  }
  if (length(args) == 0L) {
    return(NULL)
  }
  return(args)
}

