#' Exercise Evaluator
#'
#' Configure how exercises are evaluated.
#' An exercise evaluator is a function taking the arguments described below and returning a
#' promise object which will eventually evaluate the user's code.
#'
#' @param expr an (un-evaluated) expression to be evaluated.
#' @param envir the environment in which `expr` is to be evaluated.
#' @param label the label of the exercise chunk.
#' @param timelimit the configured time limit in seconds.
#' @param ... additional parameters for future extensions.
#' @return a [promise][promises::promise()] object, or anything that can be cast to a promise object with
#'   [as.promise()][promises::as.promise()].
#'
#' @family exercise configuration
#' @name exercise_evaluator
NULL

#' @describeIn exercise_evaluator evaluate user code in a [future()][future::future()] promise. See [future::plan()]
#'   for details on configuring where/how these promises are resolved.
#' @importFrom rlang abort cnd_message
#' @importFrom stringr str_detect
#' @importFrom future future
#' @export
future_evaluator <- function (expr, envir, label, timelimit, ...) {
  future_expr <- quote({
    tryCatch({
      setTimeLimit(elapsed = timelimit, transient = TRUE)
      eval(expr, envir = envir)
    },
    error = function (e) {
      if (stringr::str_detect(as.character(e), stringr::fixed('reached elapsed time limit'))) {
        return(examinr::exercise_result_timeout())
      }
      return(e)
    },
    finally = {
      # Reset the time limit
      setTimeLimit()
    })
  })
  return(future(expr = future_expr, substitute = FALSE, envir = baseenv(), seed = NULL,
                stdout = FALSE,
                globals = list(expr = expr, envir = envir, label = label, timelimit = timelimit)))
}
