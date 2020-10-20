#' Exercise Evaluator
#'
#' Configure how exercises are evaluated.
#' An exercise evaluator is a function taking the arguments described below and returning a list of functions.
#'
#' @param expr an (un-evaluated) expression to be evaluated.
#' @param envir the environment in which `expr` is to be evaluated.
#' @param label the label of the exercise chunk.
#' @param timelimit the configured time limit in seconds.
#' @param ... additional parameters for future extensions.
#' @return a list of functions, namely
#'   - `completed()` returns `TRUE` if the evaluator is finished, `FALSE` otherwise.
#'   - `kill()` kill/interrupt the evaluator. This will be called when the time limit has passed.
#'   - `result()` return the result from evaluating `expr`.
#'   - `start()` start the evaluation of `expr`.
#'
#' @name exercise_evaluator
NULL

#' @describeIn exercise_evaluator evaluate the user code in the current R process.
#' @importFrom stringr str_detect
#' @export
local_evaluator <- function (expr, envir, label, timelimit, ...) {
  result <- exercise_result_empty(label)
  list(completed = function() TRUE,
       result = function () result,
       kill = function () {},
       start = function () {
         setTimeLimit(elapsed = timelimit, transient = TRUE)
         on.exit(setTimeLimit(elapsed = Inf, cpu = Inf), add = TRUE)
         result <<- tryCatch(eval(expr, envir = envir),
                             error = function (e) {
                               if (str_detect(as.character(e), fixed('reached elapsed time limit'))) {
                                 return(exercise_result_timeout(label))
                               }
                               return(e)
                             })
       })
}

#' @describeIn exercise_evaluator evaluate the user code in a separate R process, created with
#'   [parallel::makePSOCKcluster()].
#' @importFrom rlang enquo
#' @importFrom parallel makePSOCKcluster stopCluster clusterExport clusterEvalQ
#' @export
psock_evaluator <- function (expr, envir, label, timelimit, ...) {
  result <- exercise_result_empty(label)
  cl <- makePSOCKcluster(1L)
  stopped <- FALSE

  list(completed = function() TRUE,
       result = function () result,
       kill = function () {
         if (!stopped) {
           stopCluster(cl)
           stopped <<- TRUE
         }
       },
       start = function () {
         on.exit({
           stopCluster(cl)
           stopped <<- TRUE
         })
         result <<- tryCatch({
           clusterExport(cl, c('expr', 'envir', 'timelimit'), envir = parent.env(environment()))
           clusterEvalQ(cl, {
             setTimeLimit(elapsed = timelimit, transient = TRUE)
             eval(expr, envir = envir)
           })[[1L]]
         }, error = function (e) {
           if (str_detect(as.character(e), fixed('reached elapsed time limit'))) {
             return(exercise_result_timeout(label))
           }
           return(e)
         })
       })
}

