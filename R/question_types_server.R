#' @importFrom shiny moduleServer renderUI
#' @importFrom htmltools tagList tags
#' @importFrom withr with_options
question_title_server <- function (question, ns_str, section_id) {
  question <- unserialize_object(question)
  moduleServer(ns_str, function (input, output, session) {
    observe_section_change(section_id = question$section_id, {
      output$title <- renderUI({
        rendering_env <- get_rendering_env(session)
        title_html <- with_options(list(digits = question$digits),
                                   render_markdown_as_html(question$title, use_rmarkdown = FALSE, env = rendering_env))

        trigger_mathjax(title_html)
      })
    })
  })
}

#' @importFrom shiny NS observeEvent getDefaultReactiveDomain
#' @importFrom rlang warn
render_textquestion_server <- function (question, ns) {
  question <- unserialize_object(question)
  ns <- NS(ns)

  if (!is.null(question$solution_expr)) {
    # The question has an expression to render the solution.
    ag_env <- new.env(parent = getNamespace('examinr'))
    ag_env$question <- question

    register_autograder(ns(question$input_id), envir = ag_env, function (input_value, session) {
      # compute the solution
      rendering_env <- get_rendering_env(session)
      solution <- tryCatch(eval(question$solution_expr, envir = rendering_env),
                           error = function (e) {
                             warn(sprintf("Cannot compute solution to question %s: %s",
                                          question$label, cnd_message(e)))
                             return(NULL)
                           })
      earned_points <- NA_real_
      correct_num_answer <- NULL
      if (length(solution) > 0L) {
        if (identical(question$type, 'numeric')) {
          correct_num_answer <- attr(solution, 'answer', exact = TRUE)
          attr(solution, 'answer') <- NULL

          if (is.numeric(solution)) {
            correct_num_answer <- solution
            solution <- as.character(solution)
          }

          if (length(correct_num_answer) > 0L && (!is.numeric(correct_num_answer) || anyNA(correct_num_answer))) {
            warn(sprintf("Invalid numeric answer to question %s: %s", question$label,
                         paste(correct_num_answer, collapse = ', ')))
            correct_num_answer <- NULL
          }
        }
        solution <- render_markdown_as_html(solution, use_rmarkdown = FALSE, env = rendering_env)
      }

      # auto-grade numeric questions
      if (!is.null(input_value) && length(correct_num_answer) == 1L) {
        num_val <- tryCatch(as.numeric(input_value[[1L]]),
                            warning = function (w) { return(NA_real_) },
                            error = function (w) { return(NA_real_) })

        # compare answer
        earned_points <- if (isTRUE(abs(correct_num_answer - num_val) <= question$accuracy)) {
          question$points
        } else {
          0
        }
      }
      return(new_question_feedback(max_points = question$points, points = earned_points, solution = solution))
    })
  } else {
    # No solution. The auto-grader simply returns an empty feedback template
    register_static_autograder(ns(question$input_id), max_points = question$points)
  }
}

#' @importFrom shiny moduleServer updateCheckboxGroupInput updateRadioButtons
#' @importFrom withr with_seed
#' @importFrom rlang warn cnd_message
#' @importFrom htmltools HTML
render_mcquestion_server <- function (question, ns) {
  question <- unserialize_object(question)
  moduleServer(ns, function (input, output, session) {
    # Filter out the N/A option from the input. The option is added to ensure the input
    # is captured when saving the section data!
    register_transformer(session$ns(question$input_id), function (input_value, session) {
      input_value[match(input_value, 'N/A', nomatch = 0L) == 0L]
    }, session = session)

    observe_section_change(section_id = question$section_id, label = 'render mc question', {
      current_attempt <- get_current_attempt(session)
      rendering_env <- get_rendering_env(session)

      # Determine the correct and incorrect answers
      answers <- sample_answers(question, current_attempt$seed, rendering_env)

      if (length(answers) > 0L) {
        # Extract the values and render the labels for the displayed answer options.
        values <- enc2utf8(vapply(answers, `[[`, 'value', FUN.VALUE = character(1L), USE.NAMES = FALSE))
        labels <- with_options(list(digits = question$digits), {
          lapply(answers, function (answer) {
            trigger_mathjax(render_markdown_as_html(answer$label, use_rmarkdown = FALSE, env = rendering_env))
          })
        })

        # Register the auto-grader if the attempt is active
        if (isTRUE(get_attempt_status(session))) {
          weights <- vapply(answers, FUN.VALUE = numeric(1L), `[[`, 'weight')
          # standardize positive weights
          weights[weights > 0] <- weights[weights > 0] / sum(weights[weights > 0])
          names(weights) <- values

          ag_env <- new.env(parent = getNamespace('examinr'))
          ag_env$weights <- question$points * weights
          ag_env$feedback <- new_question_feedback(max_points = question$points, points = 0,
                                                   solution = as.list(names(ag_env$weights[weights > 0])))
          ag_env$min_points <- question$min_points

          register_autograder(session$ns(question$input_id), function (input_value, session) {
            if (!is.null(input_value) && length(input_value) > 0L && !anyNA(input_value)) {
              input_value <- enc2utf8(input_value)
              feedback$points <- max(min_points, sum(weights[input_value]))
              feedback$answer <- unname(mapply(weight = weights[input_value], value = input_value, FUN = list,
                                               SIMPLIFY = FALSE))
            }
            return(feedback)
          }, envir = ag_env)
        }
      } else {
        values <- 'error'
        labels <- HTML('<strong class="text-danger">Error: no answer options!</strong>')
      }

      # Send the answer options to the client. Add the 'N/A' option to ensure the input
      # is captured when saving section data.
      if (isTRUE(question$mc)) {
        updateCheckboxGroupInput(session, inputId = question$input_id, selected = 'N/A',
                                 choiceValues = c('N/A', values), choiceNames = c('N/A', labels))
      } else {
        updateRadioButtons(session, inputId = question$input_id, selected = 'N/A',
                           choiceValues = c('N/A', values), choiceNames = c('N/A', labels))
      }
    })
  })
}

sample_answers <- function (question, seed, rendering_env) {
  # Determine the correct and incorrect answers
  answers <- lapply(question$answers, function (ans) {
    ans$correct <- tryCatch(isTRUE(eval(ans$correct, envir = rendering_env)),
                            error = function (e) {
                              warn(sprintf("Cannot determine correctness of answer '%s' to question %s: %s",
                                           ans$label, question$label, cnd_message(e)))
                              return(NA)
                            })
    if (!is.na(ans$correct)) {
      ans$weight <- ans$weight[[1L + ans$correct]]
      return(ans)
    } else {
      return(NULL)
    }
  })
  answers <- answers[!vapply(answers, FUN.VALUE = logical(1L), is.null)]
  if (length(answers) == 0L) {
    warn(sprintf("No valid answer options for question %s", question$label))
    return(list())
  }

  # Split the answer options into 'cor_sample' (correct answers to sample from),
  # 'cor_always' (correct answers to always show), 'inc_sample', and 'inc_always'.
  ans_group <- factor(vapply(answers, FUN.VALUE = character(1L), USE.NAMES = FALSE, function (ans) {
    paste(if (ans$correct) { 'cor' } else { 'inc' },
          if (ans$always_show) { 'always' } else { 'sample' },
          sep = '_')
  }), levels = c('cor_always', 'cor_sample', 'inc_always', 'inc_sample'))

  answers <- split(answers, ans_group)

  with_seed(seed, {
    nr_sample_answers <- c(cor = 0L, inc = 0L)
    nr_always_show <- c(cor = length(answers$cor_always), inc = length(answers$inc_always))
    if (length(question$nr_answers) == 1L) {
      # How many answers, in addition to the always shown answers, are necessary
      total_nr_sample_answers <- question$nr_answers - sum(nr_always_show)

      nr_sample_answers[['cor']] <- if (isTRUE(question$mc)) {
        # Sample at most as many correct answers as available
        max_sample <- min(length(answers$cor_sample), total_nr_sample_answers)
        # Sample at least as many correct answers as needed to have
        # (a) at least one correct answer displayed, and
        # (b) enough incorrect answer options to fill up the required number of answers
        min_sample <- max(nr_always_show[['cor']] == 0L, total_nr_sample_answers - length(answers$inc_sample))

        if (max_sample > 0L) {
          min_sample + sample.int(max_sample - min_sample + 1L, 1L) - 1L
        } else {
          0L
        }
      } else {
        # For single-choice questions sample at most 1 correct answer
        min(1L, total_nr_sample_answers)
      }

      nr_sample_answers[['inc']] <- total_nr_sample_answers - nr_sample_answers[['cor']]
    } else {
      nr_sample_answers <- question$nr_answers - nr_always_show

      displayed_cor_answers <- nr_sample_answers[['cor']] + length(answers$cor_always)
      displayed_inc_answers <- nr_sample_answers[['inc']] + length(answers$inc_always)

      if (!isTRUE(displayed_cor_answers == question$nr_answers[['cor']])) {
        warn(sprintf("Cannot display as many correct answers as requested (%d) for question %s in attempt %s.",
                     question$nr_answers[['cor']], question$label, current_attempt$id))
      }
      if (!isTRUE(displayed_inc_answers == question$nr_answers[['inc']])) {
        warn(sprintf("Cannot display as many incorrect answers as requested (%d) for question %s in attempt %s.",
                     question$nr_answers[['inc']], question$label, current_attempt$id))
      }
    }

    # Randomly select the answers to display
    shown_answers <- with(answers, c(sample(cor_sample, nr_sample_answers[['cor']]),
                                     sample(inc_sample, nr_sample_answers[['inc']]),
                                     cor_always, inc_always))


    # Determine the order of the shown answer options
    answer_order <- if (question$random_answer_order) {
      sample.int(length(shown_answers))
    } else {
      order(enc2utf8(vapply(shown_answers, `[[`, 'value', FUN.VALUE = character(1L), USE.NAMES = FALSE)))
    }
  })

  return(shown_answers[answer_order])
}
