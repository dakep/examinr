## Initialize feedback display
#' @importFrom shiny observe getDefaultReactiveDomain observeEvent parseQueryString
#' @importFrom rlang abort warn
initialize_feedback <- function (session, exam_metadata, sections) {
  session_env <- get_session_env(session)
  user <- get_current_user(session)

  feedback_available <- FALSE
  session_env$feedback_attempts <- reactiveVal(list(), 'feedback_attempts')
  session_env$feedback_all_users <- NULL
  session_env$feedback_grading <- isTRUE(user$grading)
  session_env$feedback_grading_download <- NULL
  session_env$feedback_points_cache <- list()

  # Initialize section state (display all sections at once)
  initialize_section_state(session, sections, TRUE)

  # Determine the user from the URL query
  query_str <- parseQueryString(isolate(reactiveValuesToList(session$clientData)$url_search))

  clean_env <- new.env(parent = getNamespace('examinr'))
  clean_env$exam_metadata <- exam_metadata

  if (session_env$feedback_grading) {
    # Get all attempts for all users
    all_attempts <- sp_get_attempts(user = NULL, exam_id = exam_metadata$id, exam_version = exam_metadata$version)
    user_ids <- vapply(all_attempts, FUN.VALUE = character(1L), function (at) {
      at$user$user_id
    })
    unique_user_ids <- which(!duplicated(user_ids))

    if (length(unique_user_ids) > 0L) {
      session_env$feedback_all_users <- lapply(all_attempts[unique_user_ids], `[[`, 'user')
      names(session_env$feedback_all_users) <- user_ids[unique_user_ids]
      user_order <- vapply(session_env$feedback_all_users, FUN.VALUE = character(1L), function (user) {
        user$display_name %||% user$user_id
      })
      session_env$feedback_all_users <- session_env$feedback_all_users[sort.list(user_order)]

      # Initialize using the latest finished attempt (or the latest started attempt) for
      # the selected user (if available) or the first user otherwise.
      selected_user_id <- if (!is.null(query_str$user) &&
                              isTRUE(query_str$user %in% user_ids)) {
        query_str$user
      } else {
        session_env$feedback_all_users[[1L]]$user_id
      }

      user_attempts_finished <- vapply(all_attempts, FUN.VALUE = numeric(1L), function (at) {
        if (identical(at$user$user_id, selected_user_id)) {
          return(as.numeric(at$finished_at) %|NA|% -as.numeric(at$started_at))
        }
        return(NA_real_)
      })
      latest_attempt <- which.max(user_attempts_finished)
      selected_attempt <- if (user_attempts_finished[[latest_attempt]] < 0) {
        all_attempts[[latest_attempt]]
      } else {
        # no finished attempt, use the last started attempt
        all_attempts[[which.min(user_attempts_finished)]]
      }
      initialize_attempt_state(session, 'feedback', selected_attempt)

      # Register grades download endpoint
      session_env$feedback_grading_download <- session$registerDataObj('examinr-grades', exam_metadata,
                                                                       grades_download_handler)

      observe({
        # Observe changes in the selected user
        session <- getDefaultReactiveDomain()
        session_env <- get_session_env(session)
        new_user_id <- session$input[['__.examinr.__-gradingUserSel']] %||% 1L

        # Load all attempts for selected user
        user <- session_env$feedback_all_users[[new_user_id]]
        if (!is.null(user)) {
          all_attempts <- ordered_attempts(user, exam_metadata, only_finished = FALSE)

          # Separate the feedback from the attempts
          session_env$feedback_points_cache <- lapply(all_attempts, function (at) {
            at$points
          })
          names(session_env$feedback_points_cache) <- vapply(all_attempts, FUN.VALUE = character(1L), `[[`, 'id')

          all_attempts <- lapply(all_attempts, function (at) {
            at$points <- NULL
            return(at)
          })

          # Set the attempts for the new user (this triggers feedback being sent to the client).
          session_env$feedback_attempts(all_attempts)
        }
      }, domain = session, env = clean_env, label = 'select user for grading')

      observe({
        # Observe new feedback
        session <- getDefaultReactiveDomain()
        session_env <- get_session_env(session)
        new_feedback <- session$input[['__.examinr.__-saveFeedback']]
        if (!is.null(new_feedback)) {
          user <- get_current_user(session)
          if (!isTRUE(user$grading)) {
            send_status_message('authenticationError', type = 'error', action = 'reload', session = session)
            warn(sprintf("User %s does not have permission to save feedback.", user$user_id))
          }
          current_attempt <- isolate(get_current_attempt(session))

          warn(c(i = paste0("Received updated feedback for attempt ", new_feedback$attempt, " in session",
                            "for attempt ", current_attempt$id),
                 ">" = paste("QID:", new_feedback$qid),
                 ">" = paste("Points:", new_feedback$points)))

          if (identical(current_attempt$id, new_feedback$attempt)) {
            qid <- new_feedback$qid %||% NA_character_
            attempt_feedback <- session_env$feedback_points_cache[[current_attempt$id]] %||% list()

            if (is.null(attempt_feedback[[qid]])) {
              attempt_feedback[[qid]] <- new_question_feedback(max_points = new_feedback$maxPoints %||% 0)
            }
            # Update points. If NULL or non-numeric, set the points to NA.
            withCallingHandlers(attempt_feedback[[qid]]$points <- as.numeric(new_feedback$points %||% NA_real_),
                                warning = function (w) { warn("Received non-numeric points:", new_feedback$points) })

            # Update comment. If NULL, remove the comment.
            attempt_feedback[[qid]]$comment <- new_feedback$comment

            # Save new feedback.
            sp_grade_attempt(current_attempt$id, attempt_feedback)

            # Update points (without triggering a re-rendering!)
            session_env$feedback_points_cache[[current_attempt$id]] <- attempt_feedback
          } else {
            warn("Attempt ID for new feedback does not match currently active attempt.")
            send_status_message(type = 'warning', message = list(body = 'Cannot save feedback: attempt is invalid.'))
          }
        }
      }, domain = session, env = clean_env, label = 'new feedback')
    } else {
      send_status_message(message = list(title = "No attempts available",
                                         body = "No attempts available for grading at the moment."),
                          type = 'error', action = 'none', session = session)
      return(FALSE)
    }
  } else if (identical(exam_metadata$feedback, 'immediately') || isTRUE(exam_metadata$feedback < Sys.time())) {
    # Feedback is released. Check if there's an attempt available
    # Load all finished attempts for current user
    finished_attempts <- ordered_attempts(user, exam_metadata)

    if (length(finished_attempts) > 0L) {
      # Initialize attempt state to the latest attempt.
      initialize_attempt_state(session, status = 'feedback', attempt = finished_attempts[[1L]])
      session_env$feedback_attempts(finished_attempts)
    } else {
      send_status_message('feedbackUnavailable', type = 'locked', session = session)
      return(FALSE)
    }
  } else {
    send_status_message('feedbackUnavailable', type = 'locked', session = session)
    return(FALSE)
  }

  # Observe changes in the finished attempts (i.e., when the user changes) and the selected attempt.
  observe({
    session <- getDefaultReactiveDomain()
    session_env <- get_session_env(session)

    # Trigger when the previous attempts change, or when the selected attempt changes.
    all_attempts <- session_env$feedback_attempts()
    new_attempt_id <- session$input[['__.examinr.__-attemptSel']]

    if (length(all_attempts) > 0L) {
      attempt_obj <- all_attempts[[new_attempt_id %||% 1L]]
      if (!is.null(attempt_obj)) {
        # "activate" attempt
        update_attempt_state(session, status = 'feedback', attempt = attempt_obj)
      }
      # send feedback to client
      send_feedback(attempt_obj, all_attempts, session = session)
    } else if (isTRUE(session_env$feedback_grading)) {
      send_feedback(NULL, all_attempts, session = session)
    } else {
      # No attempts available
      send_status_message('feedbackUnavailable', type = 'warning', session = session)
    }
  }, domain = session, env = clean_env, label = 'select attempt for grading')
}

send_feedback <- function (attempt, all_attempts, session) {
  session_env <- get_session_env(session)

  # Compile feedback for all sections
  feedback <- list()

  if (!is.null(attempt)) {
    all_sections_data <- sp_get_section_data(attempt$id, section = NULL)

    if (!is.null(all_sections_data)) {
      feedback_cache <- session_env$feedback_points_cache[[attempt$id]]

      feedback <- unlist(lapply(all_sections_data, function (sd) {
        lapply(names(sd$section_data), function (qid) {
          feedback <- attempt$points[[qid]] %||% feedback_cache[[qid]] %||% list()

          comment_html <- if (!is.null(feedback$comment)) {
            md_as_html(feedback$comment, use_rmarkdown = FALSE)
          } else {
            NULL
          }

          answer <- sd$section_data[[qid]]
          list(qid = qid,
               points = feedback$points,
               comment = feedback$comment,
               commentHtml = comment_html,
               maxPoints = feedback$max_points,
               solution = feedback$solution,
               answer = feedback$answer %||% sd$section_data[[qid]])
        })
      }), recursive = FALSE, use.names = FALSE)
    }
    attempt <- list(id = attempt$id, finishedAt = as.numeric(attempt$finished_at),
                    userId = attempt$user$user_id)
  }

  all_attempts <- unname(lapply(all_attempts, function (at) {
    list(id = at$id, finishedAt = as.numeric(at$finished_at), startedAt = as.numeric(at$started_at))
  }))

  user_ids <- unname(lapply(session_env$feedback_all_users, function (user) {
    list(id = user$user_id, displayName = user$display_name %|NA|% user$user_id)
  }))

  # send feedback to client
  send_message('feedback', session = session, message = list(
    grading = session_env$feedback_grading,
    gradesDownloadUrl = session_env$feedback_grading_download,
    users = user_ids,
    attempt = attempt,
    allAttempts = all_attempts,
    feedback = feedback %||% list()
  ))
}

ordered_attempts <- function (user, exam_metadata, only_finished = TRUE) {
  # Load all attempts for current user
  prev_attempts <- sp_get_attempts(user, exam_metadata$id, exam_metadata$version)

  if (length(prev_attempts) == 0L) {
    return(list())
  }

  # Order attempts by time they were finished and skip un-finished attempts.
  attempts_order <- if (isTRUE(only_finished)) {
    order(vapply(prev_attempts, FUN.VALUE = numeric(1L), function (at) {
      as.numeric(at$finished_at %||% NA_real_)
    }), decreasing = TRUE, na.last = NA)
  } else {
    sort.list(vapply(prev_attempts, FUN.VALUE = numeric(1L), function (at) {
      as.numeric(at$finished_at %||% at$started_at %||% NA_real_)
    }), decreasing = TRUE)
  }
  prev_attempts <- prev_attempts[attempts_order]
  names(prev_attempts) <- vapply(prev_attempts, FUN.VALUE = character(1L), `[[`, 'id')

  return(prev_attempts)
}

#' @importFrom rlang warn cnd_message
#' @importFrom utils write.csv
grades_download_handler <- function (exam_metadata, req) {
  if (identical(req$REQUEST_METHOD, 'GET')) {
    tryCatch({
      all_attempts <- sp_get_attempts(user = NULL, exam_id = exam_metadata$id, exam_version = exam_metadata$version)
      fname <- sprintf("grades_%s_%s_%s.csv", exam_metadata$id, exam_metadata$version,
                       strftime(Sys.time(), format = '%Y%m%dT%H%M%S%Z'))

      grades <- lapply(all_attempts, function (at) {
        if (length(at$points) > 0L) {
          submitted <- if (is.null(at$finished_at)) {
            NA_character_
          } else {
            strftime(at$finished_at, '%Y%m%dT%H%M%S%z')
          }
          list(user_id = rep.int(at$user$user_id, length(at$points)),
               attempt = rep.int(at$id, length(at$points)),
               submitted = rep.int(submitted, length(at$points)),
               question = names(at$points),
               points = vapply(at$points, `[[`, 'points', FUN.VALUE = numeric(1L), USE.NAMES = FALSE),
               max_points = vapply(at$points, `[[`, 'max_points', FUN.VALUE = numeric(1L), USE.NAMES = FALSE))
        } else {
          NULL
        }
      })
      grades <- grades[!vapply(grades, is.null, logical(1L), USE.NAMES = FALSE)]

      user_id <- unlist(lapply(grades, `[[`, 'user_id'), recursive = FALSE, use.names = FALSE)

      grades_df <- data.frame(
        exam = rep.int(exam_metadata$id, length(user_id)),
        exam_version = rep.int(exam_metadata$version, length(user_id)),
        user_id = user_id,
        attempt = unlist(lapply(grades, `[[`, 'attempt'), recursive = FALSE, use.names = FALSE),
        question = unlist(lapply(grades, `[[`, 'question'), recursive = FALSE, use.names = FALSE),
        submitted = unlist(lapply(grades, `[[`, 'submitted'), recursive = FALSE, use.names = FALSE),
        points = unlist(lapply(grades, `[[`, 'points'), recursive = FALSE, use.names = FALSE),
        points_available = unlist(lapply(grades, `[[`, 'max_points'), recursive = FALSE, use.names = FALSE),
        stringsAsFactors = FALSE
      )

      # Use an anonymous file for writing the CSV
      csv_fh <- file()
      on.exit(close(csv_fh))
      write.csv(grades_df, file = csv_fh, row.names = FALSE, fileEncoding = 'UTF-8')
      fcontent <- paste(readLines(csv_fh, encoding = 'UTF-8'), '', collapse = '', sep = '\n')

      structure(list(status = 200L, content = fcontent,
                     headers = list('Cache-Control' = 'no-store; max-age=0',
                                    'Content-Disposition' = sprintf('attachment; filename="%s"', fname)),
                     content_type = "text/csv; charset=UTF-8"),
                class = 'httpResponse')
    }, error = function (e) {
      warn(paste("Cannot download grades: ", cnd_message(e)))
      return(structure(list(status = 500L, content = 'Grades unavailable.',
                            headers = list('Cache-Control' = 'no-store; max-age=0'),
                            content_type = "text/plain; charset=UTF-8"),
                       class = 'httpResponse'))
    })
  } else {
    structure(list(status = 405L, content = "Method not allowed",
                        content_type = "text/plain; charset=UTF-8"),
                   class = 'httpResponse')
  }
}
