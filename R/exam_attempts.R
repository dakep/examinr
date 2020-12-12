#' @include state_frame.R
.attempts_config <- state_frame(list(global = list(), overrides = list()))

#' Configure an Attempt for Specific Users
#'
#' Override the global settings for attempts for specific users. Any unspecified setting will fall back to
#' the global setting. This function can only be called from a _server-start_ context.
#'
#' If the configuration seems to conflict with the global configuration, a warning is displayed.
#' Conflicts are if the global configuration does specify an option, but the user-specific
#' override explicitly disables an option (e.g., a global time-limit, but no time-limit for some users).
#'
#' @param user_ids a character vector of user id's, matched against the user id as determined by the authentication
#'   provider specified in [exam_config()].
#' @param max_attempts maximum number of attempts allowed. Can also be `Inf` to allow for unlimited number of attempts.
#' @param timelimit the time limit for a single attempt either as a single number in minutes or as _HH:MM_.
#'   Can also be `Inf` to give users unlimited time.
#' @param opens,closes the opening and closing date/time of the exam for the given users,
#'   in the format _YYYY-MM-DD HH:MM Timezone_ (e.g., `2020-10-15 19:15 Europe/Vienna`
#'   for October 15th, 2020 at 19:15 in Vienna, Austria).
#'   The exam is only accessible within this time frame.
#'   Can also be `NA` to either make the exam available immediately, indefinitely, or both.
#' @param grace_period number of seconds of "grace" period given to users before an active attempt is disabled.
#'
#' @return `configure_attempts()` returns the updated settings, invisibly.
#'
#' @importFrom rlang abort warn
#' @importFrom knitr opts_knit
#' @family access configuration
#' @export
configure_attempts <- function (user_ids, opens, closes, max_attempts, timelimit, grace_period) {
  if (!is_knitr_context('server-start')) {
    abort("`configure_attempts()` must be called in a context='server-start' chunk.")
  }

  if (!is.character(user_ids) || length(user_ids) == 0L) {
    abort("`user_ids` must be a character vector with at least one element.")
  }

  settings <- parse_attempt_settings(opens, closes, max_attempts, timelimit, grace_period)
  # Retain only the non-NULL settings
  settings <- settings[!vapply(settings, is.null, FUN.VALUE = logical(1L))]
  if (length(settings) > 0L) {
    # Verify user settings against global configuration
    lapply(names(settings), warn_enabled_for_some, settings = settings, global = .attempts_config$get('global'))

    # Don't persist attempts configuration in initial pass
    if (!isTRUE(opts_knit$get('examinr.initial_pass'))) {
      # Merge new overrides with existing overrides
      user_overrides <- .attempts_config$get('overrides')
      for (user_id in user_ids) {
        if (is.null(user_overrides[[user_id]])) {
          user_overrides[[user_id]] <- settings
        } else {
          user_overrides[[user_id]][names(settings)] <- settings
        }
      }
      .attempts_config$set(overrides = user_overrides)
    }
  }

  return(invisible(settings))
}

#' @importFrom rlang warn
warn_enabled_for_some <- function (what, settings, global) {
  label <- switch(what,
                  opens = "Opening date-time",
                  closes = "Closing date-time",
                  max_attempts = "A maximum number of attempts",
                  timelimit = "A time-limit",
                  grace_period = "A grace period",
                  what)

  if (!is.null(settings[[what]]) && !isTRUE(is.na(settings[[what]]) == is.na(global[[what]]))) {
    warn(sprintf("%s is %s for some users but %s for all others", label,
                 if (isTRUE(is.na(settings[[what]]))) 'disabled' else 'enabled',
                 if (isTRUE(is.na(global[[what]]))) 'disabled' else 'enabled'))
  }
}

set_attempts_config_from_metadata <- function (opens, closes, max_attempts, timelimit, grace_period) {
  config <- parse_attempt_settings(opens, closes, max_attempts, timelimit, grace_period)
  .attempts_config$set(global = config)
  return(config)
}

## Register the attempts configuration
register_attempts_config <- function (config) {
  config <- unserialize_object(config)
  .attempts_config$set(global = config)
}

## Parse the settings for the attempt. Any setting which is missing, NULL, or NA, will be set to NULL
#' @importFrom stringr str_detect
#' @importFrom rlang abort
parse_attempt_settings <- function (opens, closes, max_attempts, timelimit, grace_period) {
  if (is_missing(max_attempts) || is.null(max_attempts) || all(is.na(max_attempts))) {
    max_attempts <- NULL
  } else {
    withCallingHandlers({
      max_attempts <- floor(as.numeric(max_attempts[[1L]]))
      if (is.na(max_attempts)) {
        abort("Invalid value")
      }
    }, warning = function (w) {
      abort(paste("Invalid specification of max_attempts:", max_attempts))
    }, error = function (w) {
      abort(paste("Invalid specification of max_attempts:", max_attempts))
    })
  }

  if (is_missing(timelimit) || is.null(timelimit) || all(is.na(timelimit))) {
    timelimit <- NULL
  } else {
    timelimit <- tryCatch(as.numeric(timelimit[[1L]]),
                          warning = function (w) { timelimit[[1L]] },
                          error = function (e) { timelimit[[1L]] })

    if (!is.numeric(timelimit)) {
      hm_match <- str_match(timelimit[[1L]], '^(\\d+)\\:(\\d{1,2})$')
      if (is.na(hm_match[[1L]]) || is.na(hm_match[[2L]])) {
        abort(paste("Invalid specification of timelimit:", timelimit[[1L]]))
      }
      timelimit <- 60L * as.integer(hm_match[[2L]]) + as.integer(hm_match[[3L]])
    }
    # Translate the time limit from minutes to seconds (as this is the unit assumed by `+.POSIXct`)
    timelimit <- timelimit * 60
  }

  if (is_missing(grace_period) || is.null(grace_period) || all(is.na(grace_period))) {
    grace_period <- NULL
  } else {
    withCallingHandlers({
      grace_period <- floor(as.numeric(grace_period[[1L]]))
      if (is.na(grace_period)) {
        abort("Invalid value")
      }
    }, warning = function (w) {
      abort(paste("Invalid specification of grace_period:", grace_period))
    }, error = function (w) {
      abort(paste("Invalid specification of grace_period:", grace_period))
    })
  }

  settings <- list(opens = parse_datetime(opens),
                   closes = parse_datetime(closes),
                   max_attempts = max_attempts,
                   grace_period = grace_period,
                   timelimit = timelimit)

  return(settings)
}

#' @rdname configure_attempts
#'
#' @description
#' For verifying the attempts configurations, the current configurations and all overrides can be displayed in an
#' interactive document via `show_attempts_configuration()`. This is only meant for verification purposes and should
#' not be used in the actual exam!
#'
#' @return `show_attempts_configuration()` creates an output table to show the attempts configurations.
#'  It only shows the global configuration as well as users which have *different* settings than the global settings.
#'
#' @export
show_attempts_configuration <- function () {
  return(structure(list(), class = 'examinr_attempts_config_display'))
}

## Print the attempts configuration
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @importFrom knitr opts_chunk
#' @importFrom shiny NS tableOutput
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @method knit_print examinr_attempts_config_display
#' @rdname knit_print
#' @export
#' @keywords internal
knit_print.examinr_attempts_config_display <- function (x, ...) {
  id <- random_ui_id(get_chunk_label(required = FALSE))
  mark_chunk_static()
  ns <- NS(id)
  shiny_prerendered_chunk('server', sprintf('examinr:::attempts_config_display_server("%s")', ns(NULL)))

  knit_print(tableOutput(ns('tbl')), ...)
}

#' @importFrom shiny renderTable
attempts_config_display_server <- function (id) {
  moduleServer(id, function (input, output, session) {
    output$tbl <- renderTable({
      global <- .attempts_config$get('global')
      overrides <- .attempts_config$get('overrides')

      data.frame(`User ID` = c('--', names(overrides)),
                 Opens = c(format(global$opens %||% ''),
                           vapply(overrides, FUN.VALUE = character(1L),
                                  function (x) format(x$opens %||% ''))),
                 Closes = c(format(global$closes %||% ''),
                            vapply(overrides, FUN.VALUE = character(1L),
                                   function (x) format(x$closes %||% ''))),
                 `Time-limit` = c(format_hm(global$timelimit %||% ''),
                                  vapply(overrides, FUN.VALUE = character(1L),
                                         function (x) format_hm(x$timelimit) %||% '')),
                 `Max. attempts` = c(format(global$max_attempts %||% ''),
                                     vapply(overrides, FUN.VALUE = character(1L),
                                            function (x) format(x$max_attempts %||% ''))),
                 `Grace period (sec)` = c(format(global$grace_period %||% ''),
                                          vapply(overrides, FUN.VALUE = character(1L),
                                                 function (x) format(x$grace_period %||% ''))),
                 stringsAsFactors = FALSE, check.names = FALSE)
    }, striped = TRUE, hover = TRUE, width = '100%', align = 'lrrrrr')
  })
}

## Format a duration (in seconds) as string in the format "XYh XYm"
format_hm <- function (duration) {
  if (is_missing(duration) || is.null(duration)) {
    return(NULL)
  }
  if (!is.finite(duration)) {
    return('Inf')
  }
  duration <- as.integer(duration / 60) # discard the seconds
  hrs <- duration %/% 60L
  if (isTRUE(hrs > 0L)) {
    sprintf('%dh %02dm', hrs, duration %% 60L)
  } else {
    sprintf('%02dm', duration %% 60L)
  }
}

## Get the attempts configuration for a given user
get_attempts_config <- function (user_id) {
  global <- .attempts_config$get('global')
  overrides <- .attempts_config$get('overrides')[[user_id]]
  settings <- lapply(names(global), function (name) {
    overrides[[name]] %||% global[[name]]
  })
  names(settings) <- names(global)
  return(settings)
}

## Initialize the current attempt.
#' @importFrom digest digest2int
#' @importFrom stringr str_replace fixed
#' @importFrom rlang abort warn cnd_message
#' @importFrom shiny reactiveVal observeEvent observe
initialize_attempt <- function (session, exam_id, exam_version) {
  session_env <- get_session_env(session)
  current_time <- Sys.time()

  # Get currently authenticated user
  attempt <- list(user = get_current_user(session), exam_id = exam_id, exam_version = exam_version,
                  started_at = Sys.time(), seed = NULL)

  # Get the user's attempts configuration
  config <- get_attempts_config(attempt$user$user_id)
  if (!isTRUE(is.na(config$opens)) && !isTRUE(config$opens <= current_time)){
    msg <- get_status_message('examClosed')
    msg$body <- str_replace(msg$body, fixed('{opens}'), sprintf('<span class="examinr-timestamp">%.0f</span>',
                                                                as.numeric(config$opens)))
    send_status_message(message = msg, type = 'locked', session = session)
    return(FALSE)
  } else if (!isTRUE(is.na(config$closes)) && !isTRUE(config$closes > current_time)){
    send_status_message('examExpired', type = 'locked', session = session)
    return(FALSE)
  }

  # Get all previous attempts
  prev_attempts <- sp_get_attempts(attempt$user, attempt$exam_id,attempt$exam_version)

  # Check if a previous attempt is still unfinished (and is still within the time limits)
  valid_attempts <- which(vapply(prev_attempts, FUN.VALUE = logical(1L), function (at) {
    is.na(at$finished_at) && (current_time < at$started_at + config$timelimit)
  }))

  if (length(valid_attempts) > 0L) {
    # At least one attempt is not yet finished and still valid. Continue this attempt.
    attempt <- prev_attempts[[valid_attempts[[1L]]]]
  } else {
    # No attempt can be continued.
    # Check if a new attempt can be started.
    if (!isTRUE(length(prev_attempts) < config$max_attempts)) {
      send_status_message('noMoreAttempts', type = 'locked', session = session)
      initialize_attempt_state(session, NA, NULL)
      return(FALSE)
    }

    # Determine the seed
    attempt$seed <- seed_attempt(attempt$user, prev_attempts)

    # Create the new attempt
    attempt$id <- do.call(sp_create_attempt, attempt)

    if (is.null(attempt$id)) {
      send_status_message('startError', type = 'error', action = 'reload', session = session)
      initialize_attempt_state(session, NA, NULL)
      return(FALSE)
    }
  }

  # Start/continue the attempt
  initialize_attempt_state(session, TRUE, attempt)

  examinr_ns <- getNamespace('examinr')
  # Determine when the attempt needs to be finished
  if (config$timelimit < Inf) {
    attempt_timeout <- min(as.numeric(attempt$started_at) + config$timelimit, as.numeric(config$closes), na.rm = TRUE)
    # Automatically finish the attempt at the timeout.
    observe(expr({
      timeout <- !!attempt_timeout - as.numeric(Sys.time())
      if (timeout < 0) {
        isolate(finish_current_attempt(timeout = TRUE))
      } else {
        attempt_timeout_from_now <- 1000 * (timeout + max(!!config$grace_period, 1, na.rm = TRUE))
        invalidateLater(attempt_timeout_from_now)
      }
    }), quoted = TRUE, env = examinr_ns, label = 'attempted timed out')
  } else {
    attempt_timeout <- 'Inf'
  }

  # Update the client at every new section or when the attempt changes
  # Make handler independent of current context
  observe(expr({
    session <- getDefaultReactiveDomain()
    current_section <- get_current_section(session)
    status <- get_session_env(session)$attempt_state$status
    # Notify the client if the status is still valid or the attempt changed due to a timeout
    if (isTRUE(status) || identical(status, 'timeout')) {
      send_message('attemptStatus', session = session,
                   list(active = isTRUE(status), status = status, timelimit = !!attempt_timeout,
                        gracePeriod = !!config$grace_period))
    }
  }), env = getNamespace('examinr'), quoted = TRUE, domain = session)

  return(TRUE)
}

#' @importFrom rlang abort
#' @importFrom shiny reactiveValues
initialize_attempt_state <- function (session, status, attempt) {
  session_env <- get_session_env(session)
  if (is.null(session_env$attempt_state)) {
    session_env$attempt_state <- reactiveValues(status = status %||% NULL, current = attempt %||% NULL)
  } else {
    session_env$attempt_state$status <- status
    session_env$attempt_state$current <- attempt
  }
  return(session_env$attempt_state)
}

#' @importFrom rlang abort
update_attempt_state <- function (session, status, attempt) {
  session_env <- get_session_env(session)
  if (is.null(session_env$attempt_state)) {
    abort("Attempt state not initialized")
  }
  if (!missing(status)) {
    session_env$attempt_state$status <- status
  }
  if (!missing(attempt)) {
    session_env$attempt_state$current <- attempt
  }
}

#' @importFrom shiny getDefaultReactiveDomain
#' @importFrom rlang abort
get_current_attempt <- function (session = getDefaultReactiveDomain()) {
  session_env <- get_session_env(session)
  if (is.null(session_env$attempt_state)) {
    initialize_attempt_state(session)$current
  } else {
    session_env$attempt_state$current
  }
}

## Get the status of the current attempt.
##
## Possible return values:
##   TRUE ... an attempt is active
##   "timeout" ... the attempt is finished because it timed out
##   "user_finished" ... the attempt is finished because the user finished it
##   "feedback" ... the attempt is finished and shown for feedback
##   NA,FALSE ... no attempt is available
#' @importFrom shiny getDefaultReactiveDomain
get_attempt_status <- function (session = getDefaultReactiveDomain()) {
  session_env <- get_session_env(session)
  if (is.null(session_env$attempt_state)) {
    initialize_attempt_state(session)$status
  } else {
    session_env$attempt_state$status
  }
  # return(get_session_env(session)$attempt_state$status)
}

#' @importFrom shiny getDefaultReactiveDomain
#' @importFrom rlang warn
finish_current_attempt <- function (session = getDefaultReactiveDomain(), timeout = FALSE) {
  session_env <- get_session_env()
  current_attempt <- session_env$attempt_state$current

  # Only continue if the attempt is still active.
  if (!is.null(current_attempt) && isTRUE(isolate(session_env$attempt_state$status))) {
    # First invalidate the attempt.
    session_env$attempt_state$status <- if (isTRUE(timeout)) { 'timeout' } else { 'user_finished' }

    # If the reason for invalidating the attempt is because of a timeout,
    # save the data for the current section(s), but don't try to finish the attempt again.
    if (isTRUE(timeout)) {
      current_section <- isolate(session_env$section_state$current)
      if (!isTRUE(current_section)) {
        moduleServer(current_section$id, session = session, function (input, output, section_session) {
          save_section_data(section_session)
        })
      } else {
        save_section_data(session)
      }
    }

    sp_finish_attempt(current_attempt$id, Sys.time())
  }
}

