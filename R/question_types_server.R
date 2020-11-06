#' @importFrom shiny moduleServer updateCheckboxGroupInput updateRadioButtons
#' @importFrom withr with_seed
render_mcquestion_server <- function (question, ns) {
  question <- unserialize_object(question)
  moduleServer(ns, function (input, output, session) {
    with_seed(get_current_user()$seed, {
      # How many "correct" answer options to display
      nr_sample_correct <- if (isTRUE(question$mc) && length(question$nr_answers) == 1L) {
        max_sample <- min(length(question$answers$correct$sample), question$nr_answers - sum(question$nr_always_show))
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

      # How many "incorrect" answer options to display
      nr_sample_incorrect <- if (length(question$nr_answers) == 1L) {
        max_sample <- min(length(question$answers$incorrect$sample),
                          question$nr_answers - nr_sample_correct - sum(question$nr_always_show))
        if (max_sample > 0L) {
          sample.int(max_sample, 1L)
        } else {
          0L
        }
      } else {
        question$nr_answers[['incorrect']] - question$nr_always_show[['incorrect']]
      }

      # Randomly select the answers to display
      shown_answers <- with(question$answers,
                            c(sample(correct$sample, nr_sample_correct),
                              sample(incorrect$sample, nr_sample_incorrect),
                              correct$always, incorrect$always))

      # Extract the values and render the labels for the displayed answer options.
      rendering_env <- get_rendering_env()
      values <- vapply(shown_answers, `[[`, 'value', FUN.VALUE = character(1L), USE.NAMES = FALSE)
      labels <- with_options(list(digits = question$digits), {
        lapply(shown_answers, function (answer) {
          trigger_mathjax(render_markdown_as_html(answer$label, use_rmarkdown = FALSE, env = rendering_env))
        })
      })

      # Determine the order of the shown answer options
      answer_order <- if (question$random_answer_order) {
        sample.int(length(shown_answers))
      } else {
        order(values)
      }

      values <- values[answer_order]
      labels <- labels[answer_order]
    })

    # Send the answer options to the client
    latest_valid_input <- 'N/A'

    if (isTRUE(question$mc)) {
      observe_section_change(question$section_id,
                             updateCheckboxGroupInput(session, inputId = question$input_id,
                                                      selected = latest_valid_input, choiceValues = values,
                                                      choiceNames = labels))
    } else {
      observe_section_change(question$section_id,
                             updateRadioButtons(session, inputId = question$input_id, selected = latest_valid_input,
                                                choiceValues = values, choiceNames = labels))
    }
  })
}
