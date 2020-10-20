#' Create a Text Question
#'
#' Text questions are not auto-graded.
#'
#' @param title question title. Markdown is supported and by default the title will be rendered dynamically if it
#'   contains inline R code.
#' @param points total number of points for the question. Set to `NULL` to not give any points for the question.
#'   Will be shown next to the question text, formatted using the `points_format` given in [exam_options()].
#' @param type can be one of `textarea` (default), `text` or `numeric`.
#' @param width the width of the input, e.g., '300px' or '100%'; see [shiny::validateCssUnit()].
#' @param height the height of the input, e.g., '300px' or '100%'; see [shiny::validateCssUnit()]. Only relevant for
#'  `type="textarea"`.
#' @param placeholder A character string giving the user a hint as to what can be entered into the control.
#'   Internet Explorer 8 and 9 do not support this option.
#' @param min,max,step if `type="numeric"`, gives the minimum and maximum allowed value as well as the interval
#'   for stepping between min and max.
#' @param accuracy numeric accuracy for grading inputs with `type="numeric"`.
#' @param label an optional label displayed above the input element.
#' @param title_container a function to generate an HTML element to contain the question title.
#' @param static_title if `NULL`, the title will be rendered statically if it doesn't contain inline R code, otherwise
#'   it will be rendered dynamically. If `TRUE`, always render the title statically. If `FALSE`, always render the
#'   title dynamically on the server.
#'
#' @export
#' @importFrom htmltools h5
#' @importFrom rlang abort
text_question <- function (title, points = 1, type = c('textarea', 'text', 'numeric'), width = '100%', height = NULL,
                           placeholder = NULL, title_container = h5, static_title = NULL, min = NA, max = NA, step = NA,
                           accuracy = step, label = NULL) {

  points_str <- if (!is.null(points)) {
    if (points[[1L]] < 0) {
      abort("`points` must be non-negative.")
    }
    .exam_data$get('points_format')(points[[1L]])
  } else {
    ''
  }

  return(structure(list(label = get_chunk_label(),
                        input_label = label,
                        type = match.arg(type),
                        title = prepare_title(title, static_title),
                        placeholder = placeholder,
                        title_container = title_container,
                        accuracy = accuracy,
                        points_str = points_str,
                        points = points,
                        width = width,
                        numeric_args = list(min = min, max = max, step = step),
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
#' @param random_answer_order should the order of answers be randomized? Randomization is unique for every user.
#'
#' @importFrom ellipsis check_dots_unnamed
#' @importFrom knitr opts_current
#' @importFrom rlang abort
#' @importFrom htmltools h5 doRenderTags
#' @importFrom digest digest2int
#' @importFrom stringr str_detect
#'
#' @export
mc_question <- function(title, ..., points = 1, nr_answers = 5, random_answer_order = TRUE, mc = TRUE,
                        title_container = h5, static_title = NULL, label = NULL) {
  # Capture and validate answers.
  check_dots_unnamed()
  answers <- list(...)

  total_nr_answers <- length(answers)

  for (i in seq_along(answers)) {
    answers[[i]]$value <- as.character(i)
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

  points_str <- if (!is.null(points)) {
    if (points[[1L]] < 0) {
      abort("`points` must be non-negative.")
    }
    .exam_data$get('points_format')(points[[1L]])
  } else {
    ''
  }

  return(structure(list(label = get_chunk_label(),
                        input_label = label,
                        title = prepare_title(title, static_title),
                        answers = answers,
                        nr_answers = nr_answers,
                        points = points,
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
#'
#' @export
#' @rdname mc_question
answer <- function (label, correct = FALSE, always_show = FALSE) {
  structure(list(label = enc2utf8(label), correct = isTRUE(correct), always_show = isTRUE(always_show)),
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
  section_ns <- NS(opts_chunk$get('examinr.section_ns') %||% opts_chunk$get('examinr.section_id') %||%
                     random_ui_id('unknown_section'))

  private_ns <- NS(section_ns(x$label))

  .exam_data$append(implied_static_chunks = x$label)

  x$digits <- getOption('digits') %||% 6
  x$panel_class <- add_prefix('panel-', opts_current$get('exam.question_context') %||% 'default')
  x$label_class <- add_prefix('label-', opts_current$get('exam.points_context') %||% 'info')

  question_body_html <- render_question_body(x, section_ns)

  question_title <- if (string_is_html(x$title)) {
    x$title_container(x$title, tags$span(class = paste('label', x$label_class), x$points_str), trigger_mathjax(),
                      class = 'panel-title')
  } else {
    shiny_prerendered_chunk('server', code = sprintf(
      'examinr:::render_question_title("%s", ns_str = "%s")', serialize_object(x), private_ns(NULL)))

    htmlOutput(private_ns('title'), container = x$title_container, class = 'panel-title')
  }

  ui <- div(class = paste('panel', x$panel_class, sep = ' '),
            div(class = 'panel-heading', question_title),
            div(class = 'panel-body', question_body_html))

  knit_print(ui, ...)
}

#' @importFrom shiny moduleServer renderUI
#' @importFrom htmltools tagList tags
render_question_title <- function (question, ns_str) {
  question <- unserialize_object(question)
  moduleServer(ns_str, function (input, output, session) {
    data_env <- get_rendering_env(session)

    output$title <- renderUI({
      opts <- options(digits = question$digits)
      ui <- trigger_mathjax(
        render_markdown_as_html(question$title, use_rmarkdown = FALSE, env = data_env),
        tags$span(class = paste('label', question$label_class), question$points_str))

      options(opts)

      ui
    })
  })
}

## Render question body
## @param question question object
## @param ns the namespace function (created with shiny::NS)
render_question_body <- function (question, ns, ...) {
  UseMethod("render_question_body", question)
}

#' @importFrom shiny textAreaInput textInput numericInput NS
#' @importFrom rlang call2
#' @importFrom htmltools tagAppendAttributes
render_question_body.textquestion <- function (question, ns, ...) {
  args <- with(question, list(inputId = ns(label), label = input_label, value = '', width = width,
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
                      numeric = 'numericInput')

  input <- eval(call2(input_fun, !!!args))

  if (question$type == 'textarea') {
    tagAppendAttributes(input, style = sprintf('width: %s;', question$width))
  } else {
    return(input)
  }
}

#' @importFrom rmarkdown shiny_prerendered_chunk
#' @importFrom shiny checkboxGroupInput radioButtons NS
render_question_body.mcquestion <- function (question, ns, ...) {
  # The input groups are empty at first.
  input_group <- if (question$mc) {
    checkboxGroupInput(ns(question$label), label = question$input_label, choices = c('N/A' = 'N/A'), selected = '')
  } else {
    radioButtons(ns(question$label), label = question$input_label, choices = c('N/A' = 'N/A'), selected = '')
  }

  shiny_prerendered_chunk('server', sprintf('examinr:::render_mcquestion_server("%s", "%s")',
                                            serialize_object(question), ns(NULL)))

  return(input_group)
}

#' @importFrom shiny moduleServer updateCheckboxGroupInput updateRadioButtons
render_mcquestion_server <- function (question, ns) {
  question <- unserialize_object(question)
  moduleServer(ns, function (input, output, session) {
    opts <- options(digits = question$digits)

    answers <- lapply(question$answers, function (ans) {
      split(ans, factor(vapply(ans, `[[`, 'always_show', FUN.VALUE = logical(1L), USE.NAMES = FALSE),
                        levels = c(FALSE, TRUE), labels = c('sample', 'always')))
    })

    nr_sample_correct <- if (isTRUE(question$mc) && length(question$nr_answers) == 1L) {
      max_sample <- min(length(answers$correct$sample), question$nr_answers - sum(question$nr_always_show))
      if (max_sample > 0L) {
        sample.int(max_sample, 1L)
      } else {
        0L
      }
    } else if (!isTRUE(question$mc)) {
      1L
    } else {
      question$nr_answers[['correct']] - question$nr_always_show[['correct']]
    }

    nr_sample_incorrect <- if (length(question$nr_answers) == 1L) {
      max_sample <- min(length(answers$incorrect$sample),
                        question$nr_answers - nr_sample_correct - sum(question$nr_always_show))
      if (max_sample > 0L) {
        sample.int(max_sample, 1L)
      } else {
        0L
      }
    } else {
      question$nr_answers[['incorrect']] - question$nr_always_show[['incorrect']]
    }


    rendering_env <- get_rendering_env()
    set.seed(get_current_user()$seed)
    shown_answers <- c(sample(answers$correct$sample, nr_sample_correct),
                       sample(answers$incorrect$sample, nr_sample_incorrect),
                       answers$correct$always, answers$incorrect$always)

    values <- vapply(shown_answers, `[[`, 'value', FUN.VALUE = character(1L), USE.NAMES = FALSE)
    labels <- lapply(shown_answers, function (answer) {
      trigger_mathjax(render_markdown_as_html(answer$label, use_rmarkdown = FALSE, env = rendering_env))
    })

    ans_order <- if (question$random_answer_order) {
      sample.int(length(values))
    } else {
      order(values)
    }
    values <- values[ans_order]
    labels <- labels[ans_order]

    latest_valid_input <- 'N/A'

    if (isTRUE(question$mc)) {
      updateCheckboxGroupInput(session, inputId = question$label, selected = latest_valid_input,
                               choiceValues = values, choiceNames = labels)
    } else {
      updateRadioButtons(session, inputId = question$label, selected = latest_valid_input,
                         choiceValues = values, choiceNames = labels)
    }

    options(opts)
  })
}
