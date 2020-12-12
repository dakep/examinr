#' Exercise Options
#'
#' Global options for exercise chunks. Each of these options can be overwritten in the individual exercise chunks by
#' specifying the `exercise.xyz` chunk option (`xyz` is one of the parameter names below).
#'
#' @param title title of the exercise. Default: _exercise.panelTitle_ from [status_messages()].
#' @param button label of the run exercise button. Default: _exercise.buttonLabel_ from [status_messages()].
#' @param timelimit time limit for the code to run (in seconds). Default: 5.
#' @param lines the minimum number of lines in the code editor. Default: 5.
#' @param autocomplete enable or disable auto-completion in the code editor. Note that this sends many requests
#'   to the server and could pose performance issues if many users access the exam at the same time. Default: `FALSE`.
#' @param df_print method used for printing data frames created by the user code. Default to use the same
#'  as the R-markdown document, but can be changed if needed. See argument `df_print` in
#'  [html_document()][rmarkdown::html_document()] for details.
#' @param setup the name of an R code chunk which is evaluated before the user code.
#' @param solution the name of an R code chunk which gives the solution to the exercise code chunk.
#'  This really only makes sense if set on a per-chunk basis.
#' @param checker a function (or the name of a function) which checks the R code in the exercise chunk.
#' @param points the default number of points an exercise is worth. Default: 1.
#' @param label a label to help screen readers describe the purpose of the input element.
#'  Default: _exercise.label_ from [status_messages()].
#'
#' @importFrom knitr opts_chunk opts_knit
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @importFrom rlang abort
#' @family exercise configuration
#' @export
exercise_options <- function (title, button, timelimit, lines, autocomplete, df_print, points,
                              setup, solution, checker, label) {
  if (!is_missing(checker)) {
    checker <- match.fun(checker)
  }

  if (!is_knitr_context('setup')) {
    abort("`exercise_options()` must be called in a context='setup' chunk.")
  }

  exercise_options <- list(
    title = title %||% opts_chunk$get('exercise.title'),
    button = button %||% opts_chunk$get('exercise.button'),
    setup = setup %||% opts_chunk$get('exercise.setup'),
    solution = solution %||% opts_chunk$get('exercise.solution'),
    checker = checker %||% opts_chunk$get('exercise.checker'),
    lines = as.numeric(lines %||% opts_chunk$get('exercise.lines')),
    df_print = df_print %||% opts_chunk$get('exercise.df_print') %||%
      opts_knit$get('rmarkdown.df_print') %||% 'default',
    timelimit = as.numeric(timelimit %||% opts_chunk$get('exercise.timelimit')),
    autocomplete = isTRUE(autocomplete %||% opts_chunk$get('exercise.autocomplete')),
    points = as.numeric(points %||% opts_chunk$get('exercise.points')),
    label = label %||% opts_chunk$get('exercise.label')
  )

  names(exercise_options) <- paste('exercise', names(exercise_options), sep = '.')
  opts_chunk$set(exercise_options)
}
