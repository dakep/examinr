#' Create a Question With Text Input
#'
#' Render a question which asks the user to input a value. Questions of _numeric_ support auto-grading.
#'
#' The solution is computed by evaluating the expression given in `solution` in the rendering environment.
#' The expression must yield either a single character string or, if the question is of type _numeric_, a numeric value.
#' The result of the expression is rendered with [commonmark][commonmark::markdown_html()].
#' To auto-grade _numeric_ questions, the `solution` expression can yield a numeric value or a character value with
#' attribute `answer`. This number is compared against the user's answer (with tolerance `accuracy`).
#'
#' @param title question title. Markdown is supported and by default the title will be rendered dynamically if it
#'   contains inline R code.
#' @param points total number of points for the question. Set to `NULL` to not give any points for the question.
#'   Will be shown next to the question text, formatted using the `points_format` given in [exam_config()].
#' @param type can be one of `textarea` (default), `text` or `numeric`.
#' @param width the width of the input, e.g., '300px' or '100%'; see [shiny::validateCssUnit()].
#' @param height the height of the input, e.g., '300px' or '100%'; see [shiny::validateCssUnit()]. Only relevant for
#'  `type="textarea"`.
#' @param placeholder A character string giving the user a hint as to what can be entered into the control.
#'   Internet Explorer 8 and 9 do not support this option.
#' @param markdown_html() numeric accuracy for grading inputs with `type="numeric"`.
#' @param label a label to help screen readers describe the purpose of the input element.
#' @param hide_label hide the label from non-screen readers.
#' @param title_container a function to generate an HTML element to contain the question title.
#' @param static_title if `NULL`, the title will be rendered statically if it doesn't contain inline R code, otherwise
#'   it will be rendered dynamically. If `TRUE`, always render the title statically. If `FALSE`, always render the
#'   title dynamically on the server.
#' @param solution an expression to compute the solution to the answer.
#'   The expression is evaluated in the environment returned by the data provider set up via [exam_config()].
#'   See below for details on how to auto-grade questions of type _numeric_.
#' @param solution_quoted is the `solution` expression quoted?
#'
#' @export
#' @importFrom htmltools h6
#' @importFrom rlang abort enexpr is_expression
text_question <- function (title, points = 1, type = c('textarea', 'text', 'numeric'), width = '100%', height = NULL,
                           placeholder = NULL, title_container = h6, static_title = NULL, accuracy = 1e-3,
                           solution = NULL, solution_quoted = FALSE,
                           label = "Type your answer below.", hide_label = FALSE) {

  points_str <- format_points(points)

  if (is.null(label)) {
    abort("Every question must have a meaningful label")
  }
  type <- match.arg(type)

  if (!is.numeric(accuracy) || length(accuracy) == 0L || anyNA(accuracy) || !isTRUE(accuracy >= 0)) {
    abort("`accuracy` must be a non-negative number.")
  }

  if (!isTRUE(solution_quoted)) {
    solution <- enexpr(solution)
  }

  if (!is.null(solution) && !is_expression(solution)) {
    abort("`solution` must be an expression")
  }

  return(structure(list(label = get_chunk_label(),
                        input_label = label,
                        hide_label = isTRUE(hide_label),
                        type = type,
                        title = prepare_title(title, static_title),
                        placeholder = placeholder,
                        title_container = title_container,
                        accuracy = accuracy,
                        points_str = points_str,
                        solution_expr = solution,
                        points = points,
                        container_class = paste('examinr-q-textquestion', paste('examinr-q', type, sep = '-'),
                                                sep = ' '),
                        width = width,
                        height = height),
                   class = c('textquestion', 'examinr_question')))
}

#' Create a Multiple-Choice Question
#'
#' Render a multiple- or single-choice question.
#'
#' @inheritParams text_question
#' @param ... answer options created with [answer()].
#' @param nr_answers maximum number of answers to display. At least one correct answer will always be shown.
#'   If `NULL`, all answer options are shown. If a vector of length two, the first number specifies the number of
#'   *correct* answers to be shown and the second number specifies the number of *incorrect* answers to be shown.
#' @param mc show as multiple choice, i.e., allow the user to select more than one answer.
#' @param label a label to help screen readers describe the purpose of the input element.
#' @param hide_label hide the label from non-screen readers.
#' @param random_answer_order should the order of answers be randomized? Randomization is unique for every user.
#' @param min_points if `points` multiplied by the the sum of the weights of all selected answer options is negative,
#'   where to cut off negative points. If `NULL`, there is no lower bound.
#'
#' @importFrom ellipsis check_dots_unnamed
#' @importFrom knitr opts_current
#' @importFrom rlang abort
#' @importFrom htmltools h6 doRenderTags
#' @importFrom digest digest2int
#' @importFrom stringr str_detect
#' @importFrom withr with_seed
#'
#' @export
mc_question <- function(title, ..., points = 1, nr_answers = 5, random_answer_order = TRUE, mc = TRUE,
                        title_container = h6, static_title = NULL, label = "Select the correct answer(s).",
                        hide_label = FALSE, min_points = 0) {
  if (is.null(label)) {
    abort("Every question must have a meaningful label")
  }

  # Capture and validate answers.
  check_dots_unnamed()
  answers <- list(...)

  total_nr_answers <- length(answers)

  # Generate the value to obfuscate, but persist order
  values <- with_seed(digest2int(label), {
    format(as.hexmode(sort.int(sample.int(.Machine$integer.max, total_nr_answers))))
  })
  for (i in seq_along(answers)) {
    answers[[i]]$value <- values[[i]]
  }

  is_correct <- unlist(lapply(answers, function(answer) {
    if (!inherits(answer, 'examinr_question_answer')) {
      abort("Answer options must be created by `answer()`.")
    }
    answer$correct
  }), recursive = FALSE, use.names = FALSE)

  answers <- split(answers, factor(is_correct, levels = c(FALSE, TRUE), labels = c('incorrect', 'correct')))

  if (length(answers[['correct']]) == 0L) {
    abort("At least one correct answer must be provided.")
  }

  nr_always_show <- vapply(answers, FUN.VALUE = integer(1L), USE.NAMES = TRUE, function (ans) {
    sum(vapply(ans, `[[`, 'always_show', FUN.VALUE = TRUE, USE.NAMES = FALSE))
  })

  nr_answers <- if (is.null(nr_answers)) {
    total_nr_answers
  } else if (length(nr_answers) > 1L) {
    if (nr_answers[[1L]] > length(answers$correct)) {
      warn(sprintf("Requested more correct answers (%d) than available (%d). Showing only %d correct answers.",
                   nr_answers[[1L]], length(answers$correct), length(answers$correct)))
      nr_answers[[1L]] <- length(answers$correct)
    }
    if (nr_answers[[2L]] > length(answers$incorrect)) {
      warn(sprintf("Requested more incorrect answers (%d) than available (%d). Showing only %d incorrect answers.",
                   nr_answers[[2L]], length(answers$incorrect), length(answers$incorrect)))
      nr_answers[[2L]] <- length(answers$correct)
    }

    if (nr_always_show[['correct']] > nr_answers[[1L]]) {
      abort("Number of shown correct answers is less than the number of correct answers with `always_show=TRUE`.")
    }
    if (nr_always_show[['incorrect']] > nr_answers[[2L]]) {
      abort("Number of shown incorrect answers is less than the number of incorrect answers with `always_show=TRUE`.")
    }

    names(nr_answers)[1:2] <- c('correct', 'incorrect')
    nr_answers[1:2]
  } else {
    min(nr_answers, total_nr_answers)
  }

  if (sum(nr_answers) < 2L) {
    abort("At least 2 answer options must be displayed.")
  }

  if (sum(nr_always_show) > sum(nr_answers)) {
    abort("Number of shown answers is less than the number of answers with `always_show=TRUE`.")
  }

  points_str <- format_points(points)

  if (!is.null(min_points) && !isTRUE(min_points <= 0)) {
    abort("`min_points` must be a single non-positive number or `NULL`.")
  }

  return(structure(list(label = get_chunk_label(),
                        input_label = label,
                        hide_label = isTRUE(hide_label),
                        title = prepare_title(title, static_title),
                        answers = answers,
                        nr_answers = nr_answers,
                        points = points,
                        min_points = min_points,
                        points_str = points_str,
                        nr_always_show = nr_always_show,
                        random_answer_order = isTRUE(random_answer_order),
                        mc = isTRUE(mc),
                        title_container = title_container),
                   class = c('mcquestion', 'examinr_question')))
}

#' @importFrom stringr str_detect fixed
prepare_title <- function (title, static_title) {
  static_title <- if (is.null(static_title)) {
    string_is_html(title) || !str_detect(title, fixed('`r '))
  } else {
    isTRUE(static_title)
  }

  if (static_title) {
    return(render_markdown_as_html(title, use_rmarkdown = FALSE))
  }
  return(title)
}

#' @param label answer text to show. Supports markdown formatting and inline code chunks of the form `` `r value` ``.
#' @param correct if the answer is correct or not.
#' @param always_show even if answer options are randomized, always show this answer.
#' @param weight the weight of this answer, if selected. By default, correct answers have a weight of 1, and incorrect
#'   answers have a weight of 0. A negative weight will subtract that proportion of available points from the user's
#'   points (e.g., penalizing for selecting incorrect answer options).
#'   The sum of all displayed **positive** weights is standardized to sum to 1,
#'   **but negative weights are not standardized.**
#'
#' @importFrom rlang warn
#'
#' @export
#' @rdname mc_question
answer <- function (label, correct = FALSE, always_show = FALSE, weight = correct) {
  correct <- isTRUE(correct)
  if (correct && !isTRUE(weight > 0)) {
    warn("Correct answers should not have a non-positive weight.")
  } else if (!correct && isTRUE(weight < -1)) {
    warn("A weight less than -1 subtracts more points than assigned to the question.")
  }
  structure(list(label = enc2utf8(label), correct = correct, always_show = isTRUE(always_show),
                 weight = as.numeric(weight[[1L]])),
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
  mark_chunk_static(x$label)

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

  question_body_html <- render_question_body(x, section_ns)

  points_container <- tags$span(class = 'badge badge-secondary examinr-points', x$points_str)

  question_title <- if (string_is_html(x$title)) {
    x$title
  } else {
    shiny_prerendered_chunk('server', code = sprintf('examinr:::question_title_server("%s", "%s")',
                                                     serialize_object(x), private_ns(NULL)))

    htmlOutput(private_ns('title'))
  }

  if (is.null(x$container_class)) {
    x$container_class <- paste('examinr-q', setdiff(class(x), 'examinr_question'), sep = '-', collapse = ' ')
  }

  ui <- div(class = paste('card examinr-question', x$container_class, sep = ' '), role = 'group',
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
    args <- c(args, question$numeric_args)
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
  input_group <- if (question$mc) {
    checkboxGroupInput(ns(question$input_id), label = question$input_label, choices = c('N/A' = 'N/A'), selected = '')
  } else {
    radioButtons(ns(question$input_id), label = question$input_label, choices = c('N/A' = 'N/A'), selected = '')
  }

  # Split the answer options into 'sample' (those to sample from) and 'always' (those to always show)
  question$answers <- lapply(question$answers, function (ans) {
    split(ans, factor(vapply(ans, `[[`, 'always_show', FUN.VALUE = logical(1L), USE.NAMES = FALSE),
                      levels = c(FALSE, TRUE), labels = c('sample', 'always')))
  })

  shiny_prerendered_chunk('server', sprintf('examinr:::render_mcquestion_server("%s", "%s")',
                                            serialize_object(question), ns(NULL)))

  return(input_group)
}
