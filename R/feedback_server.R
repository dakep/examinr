## Initialize feedback display
initialize_feedback <- function (session, exam_metadata, sections) {
  feedback_available <- FALSE

  if (identical(exam_metadata$feedback, 'immediately') || isTRUE(exam_metadata$feedback < Sys.time())) {
    # Check if there's an attempt available
    user <- get_current_user(session)
    prev_attempts <- sp_get_attempts(user, exam_metadata$id, exam_metadata$version)

    attempts_finished_at <- vapply(prev_attempts, FUN.VALUE = numeric(1L), function (at) {
      at$finished_at %||% NA
    })

    names(prev_attempts) <- vapply(prev_attempts, FUN.VALUE = character(1L), `[[`, 'id')

    if (any(!is.na(attempts_finished_at))) {
      feedback_available <- TRUE

      # Activate most recent attempt
      latest_attempt <- prev_attempts[[which.max(attempts_finished_at)]]
      initialize_attempt_state(session, 'feedback', latest_attempt)

      # Initialize the section state (show *all* sections)
      initialize_section_state(session, sections)

      available_attempts <- unname(lapply(prev_attempts[!is.na(attempts_finished_at)], function (at) {
        list(id = at$id, finishedAt = as.numeric(at$finished_at))
      }))

      send_feedback(latest_attempt, available_attempts, session = session)

      observe({
        new_attempt_id <- session$input[['__.examinr.__-attemptSel']]
        if (!is.null(new_attempt_id) && !is.null(new_attempt_id) && !is.null(prev_attempts)) {
          attempt_obj <- prev_attempts[[new_attempt_id]]
          if (!is.null(attempt_obj)) {
            # "activate" attempt
            initialize_attempt_state(session, 'feedback', attempt_obj)
            # send feedback to client
            send_feedback(attempt_obj, available_attempts, session = session)
          }
        }
      }, domain = session)
    }
  }

  if (!feedback_available) {
    send_status_message('feedbackUnavailable', type = 'locked', session = session)
    return(FALSE)
  }
}

send_feedback <- function (attempt, available_attempts, session) {
  # Compile feedback for all sections
  all_sections_data <- sp_get_section_data(attempt$id, section = NULL)

  if (!is.null(all_sections_data)) {
    feedback <- unlist(lapply(all_sections_data, function (sd) {
      lapply(names(sd$section_data), function (qid) {
        feedback <- attempt$points[[qid]] %||% list()

        answer <- sd$section_data[[qid]]
        list(qid = qid,
             points = feedback$points,
             comment = feedback$comment,
             maxPoints = feedback$available,
             solution = feedback$solution,
             answer = feedback$answer %||% sd$section_data[[qid]])
      })
    }), recursive = FALSE, use.names = FALSE)
    # send feedback to client
    send_message('feedback', session = session, message = list(
      attempt = list(id = attempt$id, finishedAt = as.numeric(attempt$finished_at)),
      otherAttempts = available_attempts,
      feedback = feedback
    ))
  } else {
    send_status_message(type = 'warning', session = session, message = list(body = 'Feedback unavailable.'))
  }
}
