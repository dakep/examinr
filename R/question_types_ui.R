#' Create a Question With Text Input
#'
#' Render a question which asks the user to input a value. Questions of _numeric_ support auto-grading.
#'
#' The solution is computed by evaluating the expression given in `solution` in the rendering environment.
#' The expression must yield either a single character string or, if the question is of type _numeric_, a numeric value.
#' The result of the expression is rendered with [commonmark][commonmark::markdown_html()].
#' To auto-grade _numeric_ questions, the `solution` expression can yield a numeric value or a character value with
#' attribute `answer`. This number is compared against the user's answer using the function provided via `comp`.
#'
#' @param title question title. Markdown is supported and by default the title will be rendered dynamically if it
#'   contains inline R code.
#' @param points total number of points for the question. Set to `NULL` to not give any points for the question.
#'   Will be shown next to the question text, formatted using the `points_format` given in [exam_config()].
#' @param type can be one of `textarea` (default), `text` or `numeric`.
#' @param solution an expression to compute the solution to the answer.
#'   The expression is evaluated in the environment returned by the data provider set up via [exam_config()].
#'   See below for details on how to auto-grade questions of type _numeric_.
#' @param comp function comparing the user's input with the correct answer. Must be a function taking two
#'   named arguments: `input` (the user's input value) and `answer` (the correct answer).
#' @param solution_quoted is the `solution` expression quoted?
#' @param width the width of the input, e.g., '300px' or '100%'; see [shiny::validateCssUnit()].
#' @param height the height of the input, e.g., '300px' or '100%'; see [shiny::validateCssUnit()]. Only relevant for
#'  `type="textarea"`.
#' @param placeholder A character string giving the user a hint as to what can be entered into the control.
#'   Internet Explorer 8 and 9 do not support this option.
#' @param label a label to help screen readers describe the purpose of the input element.
#' @param hide_label hide the label from non-screen readers.
#' @param title_container a function to generate an HTML element to contain the question title.
#' @param static_title if `NULL`, the title will be rendered statically if it doesn't contain inline R code, otherwise
#'   it will be rendered dynamically. If `TRUE`, always render the title statically. If `FALSE`, always render the
#'   title dynamically on the server.
#' @param mandatory is this question mandatory for submitting the section? If `TRUE`, a user can only navigate to the
#'   next section if the question is answered.
#' @param id question identifier to be used instead of the code chunk label. Must only contain
#'   characters `a-z`, `A-Z`, `0-9`, dash (`-`), or underscore (`_`).
#'
#' @family exam question types
#' @export
#' @importFrom htmltools h6
#' @importFrom rlang abort enexpr is_expression is_function fn_body new_function
text_question <- function (title, points = 1, type = c('textarea', 'text', 'numeric'), width = '100%', height = NULL,
                           placeholder = NULL, solution = NULL, solution_quoted = FALSE, comp = comp_digits(3, 1),
                           label = "Type your answer below.", hide_label = FALSE, mandatory = FALSE, id = NULL,
                           title_container = h6, static_title = NULL,
                           mathjax_dollar) {

  points_str <- format_points(points)

  if (is.null(label)) {
    abort("Every question must have a meaningful label")
  }
  type <- match.arg(type)

  if (!isTRUE(solution_quoted)) {
    solution <- enexpr(solution)
  }

  if (!is.null(solution) && !is_expression(solution)) {
    abort("`solution` must be an expression")
  }

  mathjax_dollar <- if (missing(mathjax_dollar)) {
    isTRUE(opts_chunk$get('examinr.mathjax_dollar'))
  } else {
    isTRUE(mathjax_dollar)
  }

  if (length(id) > 0L) {
    id <- as.character(id[[1L]])
    if (str_detect(id, '[^a-zA-Z0-9_-]')) {
      abort("Question id contains invalid characters")
    }
  }

  # Extract body from comparison function
  if (is_function(comp)) {
    comp <- fn_body(comp)
  } else if (!is_expression(comp)) {
    abort("`comp` must be a function taking two arguments: `input` and `answer`.")
  }

  # Test comparison function
  comp_fun <- new_function(list(input = 0, answer = 0), comp, env = baseenv())
  withCallingHandlers(comp_fun(0, 0),
                      error = function (e) {
                        abort("`comp` must be a function taking two arguments: `input` and `answer`.")
                      })

  return(structure(list(input_label = label,
                        label = id,
                        hide_label = isTRUE(hide_label),
                        type = type,
                        mathjax_dollar = mathjax_dollar,
                        title = prepare_title(title, static_title, mathjax_dollar),
                        placeholder = placeholder,
                        title_container = title_container,
                        comp_expr = comp,
                        points_str = points_str,
                        mandatory = isTRUE(mandatory),
                        solution_expr = solution,
                        points = points,
                        container_classes = c('examinr-q-textquestion', paste('examinr-q', type, sep = '-')),
                        width = width,
                        height = height),
                   class = c('textquestion', 'examinr_question')))
}

#' @describeIn text_question compare the user input and the correct answer in absolute terms
#'                           (returns `abs(input - answer) < tol`).
#' @param tol absolute tolerance (for `comp_abs()`) or relative tolerance (for `comp_rel()`).
#' @importFrom rlang expr
#' @export
comp_abs <- function (tol) {
  substitute(abs(input - answer) <= tol)
}

#' @describeIn text_question compare the user input and the correct answer in relative terms
#'                           (returns `abs(input / answer - 1) < tol`).
#' @importFrom rlang expr
#' @export
comp_rel <- function (tol) {
  substitute(abs(input / answer - 1) <= tol)
}

#' @describeIn text_question allow the last digit vary by +/- `pm`. For answers greater than 1 (in absolute value),
#'                           `digits` is the number of digits after the decimal point and an absolute tolerance of
#'                           of `tol = pm * 10^-digits` is used.
#'                           For answers less than 1, `digits` is the number of significant digits and an
#'                           absolute tolerance of `tol = pm * 10^(-shift)` is used (`shift` is taken such that
#'                           the last sign. digit can vary by +/- `pm`). Returns `abs(input - answer) < tol`).
#' @param digits number of digits relevant for comparison (significant digits if the correct answer is less than 1 in
#'   absolute value).
#' @param pm amount by how much the last (significant) digit may vary between the user's input and the correct answer.
#' @export
comp_digits <- function (digits, pm = 1) {
  # use substitute instead of rlang::expr to avoid capturing the srcref
  substitute({
    tol <- if (abs(answer) > 1) {
      pm * 10^(-digits)
    } else {
      shift <- floor(log10(signif(abs(answer), digits = digits))) - 2
      pm * 10^shift
    }
    abs(input - answer) <= tol
  })
}

#' Create a Multiple-Choice Question
#'
#' Show a multiple-choice or single-choice question.
#'
#' @param nr_answers maximum number of answers to display. At least one correct answer will always be shown.
#'   If `NULL`, all answer options are shown. If a vector of length two, the first number specifies the number of
#'   *correct* answers to be shown and the second number specifies the number of *incorrect* answers to be shown.
#' @param checkbox make a multiple response question, i.e., allow the user to select more than one answer.
#' @param label a label to help screen readers describe the purpose of the input element.
#' @param hide_label hide the label from non-screen readers.
#' @param random_answer_order should the order of answers be randomized? Randomization is unique for every user.
#' @param min_points if `points` multiplied by the the sum of the weights of all selected answer options is negative,
#'   where to cut off negative points. If `NULL`, there is no lower bound.
#' @inheritParams text_question
#' @param ... answer options created with [answer()].
#'
#' @importFrom ellipsis check_dots_unnamed
#' @importFrom knitr opts_current
#' @importFrom rlang abort
#' @importFrom htmltools h6 doRenderTags
#' @importFrom digest digest2int
#' @importFrom stringr str_detect
#' @importFrom withr with_seed
#'
#' @family exam question types
#' @export
mc_question <- function(title, ..., points = 1, nr_answers = 5, random_answer_order = TRUE, checkbox = TRUE,
                        label = "Select the correct answer(s).", hide_label = FALSE, min_points = 0,
                        mandatory = FALSE, id = NULL, title_container = h6, static_title = NULL,
                        mathjax_dollar) {
  if (is.null(label)) {
    abort("Every question must have a meaningful label.")
  }

  # Capture and validate answers.
  check_dots_unnamed()
  answers <- list(...)

  total_nr_answers <- length(answers)

  # Validate answer options
  nr_always_show <- sum(vapply(answers, FUN.VALUE = logical(1L), function(answer) {
    if (!inherits(answer, 'examinr_question_answer')) {
      abort("Answer options must be created by `answer()`.")
    }
    return(answer$always_show)
  }))

  mathjax_dollar <- if (missing(mathjax_dollar)) {
    isTRUE(opts_chunk$get('examinr.mathjax_dollar'))
  } else {
    isTRUE(mathjax_dollar)
  }

  # Generate the value to obfuscate, but persist order
  values <- with_seed(digest2int(label), {
    format(as.hexmode(sort.int(sample.int(.Machine$integer.max, total_nr_answers))))
  })
  for (i in seq_along(answers)) {
    answers[[i]]$value <- values[[i]]
  }

  nr_answers <- if (length(nr_answers) == 0L) {
    total_nr_answers
  } else if (length(nr_answers) == 1L) {
    min(nr_answers, total_nr_answers)
  } else if (length(nr_answers) == 2L) {
    if (sum(nr_answers) > total_nr_answers) {
      abort(sprintf("Requested more answers (%d) than available (%d).", sum(nr_answers), total_nr_answers))
    }
    names(nr_answers) <- c('cor', 'inc')
  } else {
    abort("`nr_answers` must be an integer vector with either one or two elements, or NULL.")
  }

  if (sum(nr_answers) < 1L) {
    abort("At least 1 answer option must be displayed.")
  }

  if (nr_always_show > sum(nr_answers)) {
    abort("Number of answers to show is less than the number of answers with `always_show=TRUE`.")
  }

  points_str <- format_points(points)

  if (!is.null(min_points) && !isTRUE(min_points <= 0)) {
    abort("`min_points` must be a single non-positive number or `NULL`.")
  }

  if (length(id) > 0L) {
    id <- as.character(id[[1L]])
    if (str_detect(id, '[^a-zA-Z0-9_-]')) {
      abort("Question id contains invalid characters")
    }
  }

  return(structure(list(input_label = label,
                        label = id,
                        hide_label = isTRUE(hide_label),
                        mathjax_dollar = mathjax_dollar,
                        title = prepare_title(title, static_title, mathjax_dollar),
                        answers = answers,
                        nr_answers = nr_answers,
                        points = points,
                        mandatory = isTRUE(mandatory),
                        min_points = min_points,
                        points_str = points_str,
                        nr_always_show = nr_always_show,
                        random_answer_order = isTRUE(random_answer_order),
                        checkbox = isTRUE(checkbox),
                        title_container = title_container),
                   class = c('mcquestion', 'examinr_question')))
}

#' @importFrom stringr str_detect fixed
prepare_title <- function (title, static_title, mathjax_dollar) {
  static_title <- if (is.null(static_title)) {
    string_is_html(title) || !str_detect(title, fixed('`r '))
  } else {
    isTRUE(static_title)
  }

  if (static_title) {
    return(md_as_html(title, use_rmarkdown = FALSE, mathjax_dollar = mathjax_dollar))
  }
  return(title)
}

#' @param label answer text to show. Supports markdown formatting and inline code chunks of the form `` `r value` ``.
#' @param correct an expression which, evaluated in the rendering environment, determines if the answer is correct
#'   or not. Can also be a simple logical.
#' @param correct_quoted is the expression given in `correct` quoted or not?
#' @param always_show even if answer options are randomized, always show this answer.
#' @param weight the weight of this answer, if selected. By default, correct answers have a weight of 1, and incorrect
#'   answers have a weight of 0. See details for more information.
#'   A negative weight will subtract that proportion of available points from the user's
#'   points (e.g., to penalize for selecting incorrect answer options).
#'   The sum of all displayed **positive** weights is standardized to sum to 1,
#'   **but negative weights are not standardized.**
#'
#' @details
#' The `weight` of an answer option determines how many points are awarded/subtracted for selecting this answer option.
#' If `correct` is an expression and correctness of an answer option can only be determined at run-time, `weight`
#' can be a numeric vector with two elements. The first element is the weight applied if the answer is wrong, the
#' second element is the weight applied if the answer is correct.
#'
#' The sum of weights of all displayed correct answers is standardized to sum to 1 (i.e., users selecting
#' all displayed correct answers will get all points), but negative weights are used as given.
#' For example, if the weight of an incorrect answer option is set to -0.5 and the total number of points available
#' for a question is 4, selecting this answer option will reduce the number of points awarded by 2.
#'
#'
#' @importFrom rlang warn enexpr is_expression
#' @export
#' @rdname mc_question
answer <- function (label, correct = FALSE, always_show = FALSE, weight = c(0, 1), correct_quoted = FALSE) {
  if (!isTRUE(correct_quoted)) {
    correct <- enexpr(correct)
  }

  if (!is.numeric(weight) || length(weight) > 2L) {
    abort("Argument `weight` must be a numeric vector with one or two elements.")
  } else if (length(weight) == 1L) {
    weight <- if (isFALSE(correct)) {
      c(weight, 1)
    } else {
      c(0, weight)
    }
  } else {
    weight <- c(0, 1)
  }

  if (!isTRUE(weight[[2L]] > 0)) {
    warn("Correct answers should not have a non-positive weight.")
  }

  if (!isTRUE(weight[[1L]] >= -1)) {
    warn("A weight less than -1 subtracts more points than assigned to the question.")
  }

  if (!is_expression(correct)) {
    abort("`correct` must be an expression or a logical constant.")
  }

  structure(list(label = enc2utf8(label), correct = correct, always_show = isTRUE(always_show), weight = weight),
            class = 'examinr_question_answer')
}

## Print an exam question
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @method knit_print examinr_question
#' @rdname knit_print
#' @export
#' @keywords internal
#'
#' @importFrom knitr knit_print opts_chunk
#' @importFrom shiny NS htmlOutput
#' @importFrom htmltools div HTML tags
#' @importFrom rlang abort
knit_print.examinr_question <- function (x, ...) {
  chunk_label <- get_chunk_label()
  if (is.null(x$label)) {
    x$label <- chunk_label
  }

  knit_meta_add(list(structure(x$label, class = 'examinr_question_label')))

  mark_chunk_static(chunk_label)

  # Don't print during the first pass
  if (isTRUE(opts_knit$get('examinr.initial_pass'))) {
    return(NULL)
  }

  x$section_id <- opts_chunk$get('examinr.section_id') %||% random_ui_id('unknown_section')
  # add a upper-case "Q" in front of the label to distinguish question inputs from other inputs
  x$input_id <- paste('Q', x$label, sep = '-')
  section_ns <- NS(x$section_id)
  private_ns <- NS(section_ns(x$label))

  x$digits <- getOption('digits') %||% 6
  x$mathjax_dollar <- x$mathjax_dollar %||% opts_chunk$get('examinr.mathjax_dollar')

  question_body_html <- render_question_body(x, section_ns)
  points_container <- tags$span(class = 'badge badge-secondary examinr-points', x$points_str)

  question_title <- if (string_is_html(x$title)) {
    x$title
  } else {
    shiny_prerendered_chunk('server', code = sprintf('examinr:::question_title_server("%s", "%s")',
                                                     serialize_object(x), private_ns(NULL)))

    htmlOutput(private_ns('title'))
  }

  if (length(x$container_classes) == 0L) {
    x$container_classes <- paste('examinr-q', setdiff(class(x), 'examinr_question'), sep = '-')
  }

  if (x$mandatory) {
    x$container_classes <- c(x$container_classes, 'examinr-mandatory-question')
  }


  ui <- div(class = paste(c('card', 'examinr-question', x$container_classes), collapse = ' '),
            role = 'group',
            `data-questionlabel` = x$label,
            `data-maxpoints` = x$points,
            trigger_mathjax(x$title_container(question_title, points_container, class = 'card-header')),
            div(class = paste('card-body', if (x$hide_label) { 'hide-label' } else { NULL }), question_body_html))

  knit_print(ui, ...)
}

## Render question body
## @param question question object
## @param ns the namespace function (created with shiny::NS)
render_question_body <- function (question, ns, ...) {
  UseMethod("render_question_body", question)
}

#' @importFrom shiny textAreaInput textInput numericInput NS
#' @importFrom rlang exec
#' @importFrom htmltools tagAppendAttributes
render_question_body.textquestion <- function (question, ns, ...) {
  args <- with(question, list(inputId = ns(input_id), label = input_label, value = '', width = width,
                              placeholder = placeholder))

  if (question$type == 'textarea') {
    args$width <- '100%'
    args$height <- question$height
  } else if (question$type == 'numeric') {
    args$placeholder <- NULL
  }

  input_fun <- switch(question$type,
                      textarea = 'textAreaInput',
                      text = 'textInput',
                      numeric = 'textInput')

  input <- exec(input_fun, !!!args)

  shiny_prerendered_chunk('server', sprintf('examinr:::render_textquestion_server("%s", "%s")',
                                            serialize_object(question), ns(NULL)))

  if (question$type == 'textarea') {
    return(tagAppendAttributes(input, style = sprintf('width: %s;', question$width)))
  }
  return(input)
}

#' @importFrom rmarkdown shiny_prerendered_chunk
#' @importFrom shiny checkboxGroupInput radioButtons NS
render_question_body.mcquestion <- function (question, ns, ...) {
  # The input groups are empty at first.
  input_group <- if (question$checkbox) {
    checkboxGroupInput(ns(question$input_id), label = question$input_label, choices = c('N/A' = 'N/A'), selected = '')
  } else {
    radioButtons(ns(question$input_id), label = question$input_label, choices = c('N/A' = 'N/A'), selected = '')
  }

  question$mathjax_dollar <- question$mathjax_dollar %||% opts_chunk$get('examinr.mathjax_dollar')

  shiny_prerendered_chunk('server', sprintf('examinr:::render_mcquestion_server("%s", "%s")',
                                            serialize_object(question), ns(NULL)))

  return(input_group)
}
