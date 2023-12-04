#' @importFrom shiny moduleServer renderUI eventReactive getDefaultReactiveDomain
#' @importFrom htmltools HTML
#' @importFrom rlang warn
section_chunk_server <- function (metadata, content) {
  metadata <- unserialize_object(metadata)
  content <- unserialize_object(content)
  global_domain <- getDefaultReactiveDomain()
  moduleServer(metadata$chunk_ns, function (input, output, session) {
    observe_section_change(section_id = metadata$id, {
      output$out <- renderUI(trigger_mathjax(
        md_as_html(content, id_prefix = metadata$chunk_ns,
                   mathjax_dollar = !isFALSE(metadata$mathjax_dollar),
                   env = get_rendering_env(session))))
    }, domain = session)
  })
}

#' @importFrom shiny moduleServer getDefaultReactiveDomain
#' @importFrom htmltools HTML
section_end_server <- function (metadata) {
  metadata <- unserialize_object(metadata)

  global_session <- if (!isTRUE(metadata$progressive)) {
    getDefaultReactiveDomain()
  } else {
    NULL
  }

  moduleServer(metadata$id, function (input, output, session) {
    observeEvent(input$`btn-next`, {
      session <- global_session %||% session
      if (isTRUE(get_attempt_status(session))) {
        saved <- save_section_data(session, session$ns('btn-next'))
        if (isTRUE(saved)) {
          goto_next_section()
        }
      }
    })
  })
}

## Initialize section navigation
#' @importFrom rlang abort warn cnd_message
#' @importFrom withr with_seed
initialize_sections_server <- function (session, user_sections, exam_metadata) {
  # Determine the order of sections. This will be fixed for the session and not changed when the attempt changes!
  attempt <- isolate(get_current_attempt(session))

  if (!is.null(attempt)) {
    if (isTRUE(exam_metadata$progressive)) {
      if (identical(exam_metadata$order, 'random')) {
        fixed_sections <- vapply(user_sections, FUN.VALUE = logical(1L), function (section) {
          section$overrides$fixed %||% FALSE
        })
        # The last section is always fixed!
        fixed_sections[[length(fixed_sections)]] <- TRUE
        not_fixed_sections <- which(!fixed_sections)
        if (length(not_fixed_sections) > 1L) {
          shuffled_sections <- with_seed(attempt$seed, sample(not_fixed_sections))
          user_sections[not_fixed_sections] <- user_sections[shuffled_sections]
        }
      }
      names(user_sections) <- vapply(user_sections, FUN.VALUE = character(1L), `[[`, 'id')

      # number sections consecutively
      for (i in seq_along(user_sections)) {
        user_sections[[i]]$order <- i
      }

      last_section <- sp_get_last_section(attempt$id)
      if (is.null(last_section)) {
        # No last section.
        next_section_index <- 1L
      } else {
        last_section_index <- which(names(user_sections) == last_section)

        if (length(last_section_index) == 0L) {
          warn(sprintf("Last section (%s) is unknown.", last_section))
          1L
        } else if (last_section_index < length(user_sections)) {
          next_section_index <- last_section_index + 1L
        } else {
          # The attempt was at the end of the exam, but the attempt was not finished.
          next_section_index <- last_section_index
        }
      }
      current_section <- user_sections[[next_section_index]]
    } else {
      current_section <- TRUE
    }

    if (identical(exam_metadata$feedback, 'immediately')) {
      # Append a "dummy" section to redirect the user to the feedback afterwards.
      user_sections <- c(user_sections, list(list(feedback = TRUE)))
    }

    initialize_section_state(session, user_sections, current_section)

    # Observe changes in the current section and relay to the client
    # This should run first so that the elements are visible on the client-side.
    examinr_ns <- asNamespace('examinr')

    observeEvent(quote(get_current_section()),
                 quote(send_message('sectionChange', get_current_section())),
                 priority = 100, handler.env = examinr_ns, event.env = examinr_ns, handler.quoted = TRUE,
                 event.quoted = TRUE)
  }
}

## Initialize the session
#' @importFrom rlang abort
#' @importFrom shiny reactiveValues
initialize_section_state <- function (session, sections, current_section = TRUE) {
  session_env <- get_session_env(session)
  session_env$sections <- sections
  session_env$last_section_id <- sections[[max(2L, length(sections)) - 1L]]$id
  if (!is.null(session_env$section_state)) {
    abort("Section state already initialized")
  }
  session_env$section_state <- reactiveValues(current = current_section)
}

## Execute the handler expression `x` either when the section changes or when the attempt changes (but is still valid)
##
## @param section_id if not null, execute `x` only if the section with id `section_id` is visible.
## @param ... arguments passed on to [observe()].
#' @importFrom shiny exprToFunction observe getDefaultReactiveDomain
observe_section_change <- function (x, section_id = NULL, ..., label = NULL, env = parent.frame(), quoted = FALSE) {
  handler_fun <- exprToFunction(x, env, quoted)

  observe(x = {
    session <- getDefaultReactiveDomain()
    current_attempt <- get_current_attempt(session)
    attempt_status <- isolate(get_attempt_status(session)) # Don't trigger if the status changes.
    current_section <- get_current_section(session)
    if ((isTRUE(attempt_status) || identical(attempt_status, 'feedback')) &&
        (isTRUE(current_section) || is.null(section_id) || identical(current_section$id, section_id))) {
      isolate(handler_fun())
    }
  }, label = label, ...)
}

#' @importFrom shiny getDefaultReactiveDomain
get_current_section <- function (session = getDefaultReactiveDomain()) {
  session_env <- get_session_env(session)
  current_section <- session_env$section_state$current
  if (is.list(current_section)) {
    current_section$attempt_is_finished <- identical(current_section$id, session_env$last_section_id)
  }
  return(current_section)
}

#' @importFrom stringr str_detect fixed str_remove
#' @importFrom shiny reactiveValuesToList
#' @importFrom rlang warn cnd_message
save_section_data <- function (session, btn_id = NULL) {
  current_attempt <- isolate(get_current_attempt(session))
  attempt_status <- isolate(get_attempt_status(session))

  # Save section data if the current attempt is valid and not-null
  if (!is.null(current_attempt) &&
      (isTRUE(attempt_status) || identical(attempt_status, 'soft_timeout'))) {
    session_env <- get_session_env(session)
    transformers <- session_env$transformer %||% list()
    autograders <- session_env$autograders %||% list()

    # Get the full names of all inputs containing the string "Q-", which are all the
    # inputs pertaining to actual questions.
    isolate({
      session_input_names <- names(session$input)
      session_input_names <- session_input_names[str_detect(session_input_names, fixed('Q-'))]
      input_values <- reactiveValuesToList(session$input)[session_input_names]
      current_section <- session_env$section_state$current
    })

    # Get the fully-qualified input names and update the names of the input values.
    fq_input_names <- vapply(session_input_names, FUN.VALUE = character(1L), session$ns)
    names(input_values) <- fq_input_names
    names(fq_input_names) <- fq_input_names

    # Transform input values (now the input values will have the names
    input_values <- lapply(fq_input_names, function (name) {
      if (!is.null(transformers[[name]])) {
        tryCatch({
          transformers[[name]](input_values[[name]], session)
        }, error = function (e) {
          warn(sprintf("Transformer for input %s raises error: %s", name, cnd_message(e)))
          return(input_values[[name]])
        })
      } else {
        input_values[[name]]
      }
    })

    # Auto-grade input values (after transformation!)
    grades <- lapply(fq_input_names, function (name) {
      if (!is.null(autograders[[name]])) {
        tryCatch({
          autograders[[name]](input_values[[name]], session)
        }, error = function (e) {
          warn(sprintf("Auto-grader for input %s raises error: %s", name, cnd_message(e)))
          return(NULL)
        })
      } else {
        NULL
      }
    })
    grades <- grades[!vapply(grades, FUN.VALUE = logical(1L), is.null)]

    current_section_id <- if (isTRUE(current_section)) {
      '*'
    } else {
      current_section$id
    }

    # Drop the prefix from the fully-qualified name and only save the actual question label
    names(input_values) <- str_remove(names(input_values), '^.+Q-')
    names(grades) <- str_remove(names(grades), '^.+Q-')

    data_saved <- sp_save_section_data(current_attempt$id, current_section_id, input_values)

    if (isTRUE(data_saved)) {
      # If any of the questions were auto-graded, update the grades for this attempt
      if (length(grades) > 0L) {
        if (!is.null(session_env$attempt_points)) {
          session_env$attempt_points[names(grades)] <- grades
        } else {
          session_env$attempt_points <- grades
        }
        # Save the grades. A failure will not be communicated to the user!
        sp_grade_attempt(current_attempt$id, session_env$attempt_points)
      }

      # Check if this is the final section (or the last section with a button)
      if (isTRUE(current_section) || identical(current_section_id, session_env$last_section_id)) {
        return(finish_current_attempt(session))
      }
    } else {
      # In case of an error, give the user the option to retry, but delay the trigger for 2 seconds to prevent
      # too many retries in a short period of time.
      send_status_message('storageError', type = 'error', action = 'trigger', session,
                          trigger_id = btn_id, trigger_event = 'click', trigger_delay = 2)
      return(FALSE)
    }
  }
  return(TRUE)
}

goto_next_section <- function () {
  session_env <- get_session_env()
  current_section <- isolate(session_env$section_state$current)
  if (!isTRUE(current_section)) {
    current_index <- which(names(session_env$sections) == current_section$id)
    if (current_index < length(session_env$sections)) {
      session_env$section_state$current <- session_env$sections[[current_index + 1L]]
    }
  } else {
    # Immediately go to the last section.
    session_env$section_state$current <- session_env$sections[[length(session_env$sections)]]
  }
}
