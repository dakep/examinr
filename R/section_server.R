#' @importFrom shiny moduleServer renderUI eventReactive getDefaultReactiveDomain
#' @importFrom htmltools HTML
#' @importFrom rlang warn
section_chunk_server <- function (metadata, content) {
  metadata <- unserialize_object(metadata)
  content <- unserialize_object(content)
  global_domain <- getDefaultReactiveDomain()
  moduleServer(metadata$chunk_ns, function (input, output, session) {
    observe_section_change(metadata$id, {
      output$out <- renderUI(trigger_mathjax(render_markdown_as_html(content, env = get_rendering_env())))
    })
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

  moduleServer(metadata$ui_id, function (input, output, session) {
    observeEvent(input$`btn-next`, {
      if (is_attempt_active()) {
        saved <- save_section_data(global_session %||% session, session$ns('btn-next'))
        if (isTRUE(saved)) {
          goto_next_section()
        }
      }
    })
  })
}

## Initialize section navigation
#' @importFrom shiny getDefaultReactiveDomain
#' @importFrom rlang abort warn cnd_message
#' @importFrom withr with_seed
initialize_sections_server <- function (user_sections, options) {
  session <- getDefaultReactiveDomain()

  if (is.null(session)) {
    abort("shiny session is not available")
  }

  user_sections <- unserialize_object(user_sections)
  options <- unserialize_object(options)
  session_env <- get_session_env(session)

  # Determine the order of sections. This is fixed for a given attempt
  attempt <- get_current_attempt(session)

  if (!is.null(attempt)) {
    if (isTRUE(options$progressive)) {
      if (isTRUE(options$order == 'random')) {
        not_fixed_sections <- which(!vapply(user_sections, FUN.VALUE = logical(1L), function (section) {
          section$overrides$fixed %||% FALSE
        }))

        shuffled_sections <- with_seed(attempt$seed, sample(not_fixed_sections))
        user_sections[not_fixed_sections] <- user_sections[shuffled_sections]
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

    # find last section with a button
    sections_with_button <- which(vapply(user_sections, FUN.VALUE = logical(1L), `[[`, 'has_button'))
    finish_attempt_section <- if (length (sections_with_button > 0L)) {
      max(sections_with_button)
    } else {
      # No section has a button. Assume that submitting the last section finishes the attempt.
      length(user_sections)
    }

    session_env$sections <- user_sections
    session_env$last_section_id <- user_sections[[finish_attempt_section]]$id
    session_env$section_state <- reactiveValues(current = current_section)

    # Observe changes in the current section and relay to the client
    # This should run first so that the elements are visible on the client-side.
    examinr_ns <- asNamespace('examinr')
    observeEvent(quote(get_current_section()),
                 quote(send_message('sectionChange', list(current = get_current_section()))),
                 priority = 100, handler.env = examinr_ns, event.env = examinr_ns, handler.quoted = TRUE,
                 event.quoted = TRUE)
  }
}

## Execute the handler expression when a section is made visible on the client and the attempt is still valid.
##
## @param ... arguments passed on to [observeEvent()].
#' @importFrom shiny exprToFunction observeEvent getDefaultReactiveDomain
observe_section_change <- function (section_id, handlerExpr, handler.env = parent.frame(), handler.quoted = FALSE, ...,
                                    eventExpr = NULL, event.env = NULL, event.quoted = NULL) {
  handler_fun <- exprToFunction(handlerExpr, handler.env, handler.quoted)
  observeEvent(eventExpr = quote(get_current_section()), event.quoted = TRUE,
               handlerExpr = quote({
                 current_section <- get_current_section()
                 if (is_attempt_active() && (isTRUE(current_section) || isTRUE(current_section$id == section_id))) {
                   handler_fun()
                 }
               }), handler.quoted = TRUE, ...)
}

get_current_section <- function () {
  get_session_env()$section_state$current
}

#' @importFrom stringr str_detect fixed str_ends
#' @importFrom shiny reactiveValuesToList
save_section_data <- function (session, btn_id = NULL) {
  session_env <- get_session_env(session)
  transformers <- session_env$transformer %||% list()
  isolate({
    input_names <- names(session$input)
    input_names <- input_names[str_detect(input_names, fixed('Q-'))]
    input_values <- reactiveValuesToList(session$input)[input_names]
    current_section <- session_env$section_state$current
  })

  input_values <- lapply(input_names, function (name) {
    transf <- which(str_ends(names(transformers), fixed(name)))
    if (length(transf) == 1L) {
      transformers[[transf]](input_values[[name]], session)
    } else {
      input_values[[name]]
    }
  })
  names(input_values) <- str_remove(input_names, '^.*Q\\-')

  current_section_id <- if (isTRUE(current_section)) {
    '*'
  } else {
    current_section$id
  }

  current_attempt_id <- get_current_attempt()$id
  if (!is.null(current_attempt_id)) {
    data_saved <- sp_save_section_data(current_attempt_id, current_section_id, input_values)

    if (isTRUE(data_saved)) {
      # Section data is saved. Check if this is the final section (or the last section with a button)
      if (isTRUE(current_section) || isTRUE(current_section_id == session_env$last_section_id)) {
        finish_current_attempt(session)
      }
    } else {
      # In case of an error, give the user the option to retry, but delay the trigger for 2 seconds to prevent
      # too many retries in a short period of time.
      send_status_message('storageError', type = 'error', action = 'trigger', session,
                          trigger_id = btn_id, trigger_event = 'click', trigger_delay = 2)
      return(FALSE)
    }
  }
  return (TRUE)
}

goto_next_section <- function () {
  session_env <- get_session_env()
  current_section <- isolate(session_env$section_state$current)
  if (!isTRUE(current_section)) {
    current_index <- which(names(session_env$sections) == current_section$id)
    if (current_index < length(session_env$sections)) {
      session_env$section_state$current <- session_env$sections[[current_index + 1L]]
    }
  }
}
