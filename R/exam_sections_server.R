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

#' @importFrom shiny NS moduleServer
#' @importFrom htmltools HTML
section_end_server <- function (metadata) {
  metadata <- unserialize_object(metadata)
  moduleServer(metadata$ui_id, function (input, output, session) {
    observeEvent(input$`btn-next`, goto_next_section())
  })
}

register_section <- function (section_id, section_ui_id) {
  new_section <- list(list(id = section_id, ui_id = section_ui_id))
  if (!is.null(.sections_data$get('sections')[[section_id]])) {
    sections <- .sections_data$get('sections')
    sections[[section_id]] <- new_section[[1L]]
    .sections_data$set(sections = sections)
  } else {
    names(new_section) <- section_id
    .sections_data$append(sections = new_section)
  }
}

## Initialize section navigation
#' @importFrom shiny getDefaultReactiveDomain
#' @importFrom rlang abort
#' @importFrom withr with_seed
initialize_sections <- function (options) {
  options <- unserialize_object(options)
  session <- getDefaultReactiveDomain()

  if (is.null(session)) {
    abort("shiny session is not available")
  }

  user_sections <- .sections_data$get('sections')
  session_env <- get_session_env()

  current_section <- if (isTRUE(options$progressive)) {
    # Determine the order of sections. This is fixed for a given user.
    user <- get_current_user(session)

    if (isTRUE(options$order == 'random')) {
      not_fixed_sections <- which(!vapply(user_sections, FUN.VALUE = logical(1L), function (section) {
        options$specific[[section$id]]$fixed %||% FALSE
      }))

      shuffled_sections <- with_seed(user$seed, sample(not_fixed_sections))
      user_sections[not_fixed_sections] <- user_sections[shuffled_sections]
      names(user_sections) <- vapply(user_sections, FUN.VALUE = character(1L), `[[`, 'id')
    }
    user_sections[[1L]]
  } else {
    TRUE
  }
  session_env$sections <- user_sections
  session_env$section_state <- reactiveValues(current = current_section)

  # Observe changes in the current section and relay to the client
  # This should run first so that the elements are visible on the client-side.
  observeEvent(get_current_section(), priority = 100, {
    session$sendCustomMessage('__.examinr.__-sectionChange', list(current = get_current_section()))
  })
}

## Execute the handler expression *after* a section is made visible on the client.
##
## @param ... arguments passed on to [observeEvent()].
#' @importFrom shiny exprToFunction observeEvent getDefaultReactiveDomain
observe_section_change <- function (section_id, handlerExpr, handler.env = parent.frame(), handler.quoted = FALSE, ...,
                                    eventExpr = NULL, event.env = NULL, event.quoted = NULL) {
  handler_fun <- exprToFunction(handlerExpr, handler.env, handler.quoted)
  observeEvent(eventExpr = quote(get_current_section()), event.quoted = TRUE,
               handlerExpr = quote({
                 current_section <- get_current_section()
                 if (isTRUE(current_section) || isTRUE(current_section$id == section_id)) {
                   handler_fun()
                 }
               }), handler.quoted = TRUE, ...)
}

get_current_section <- function () {
  get_session_env()$section_state$current
}

goto_next_section <- function () {
  session_env <- get_session_env()
  current_section <- isolate(session_env$section_state$current)
  current_index <- which(names(session_env$sections) == current_section$id)
  if (current_index < length(session_env$sections)) {
    session_env$section_state$current <- session_env$sections[[current_index + 1L]]
  }
}
