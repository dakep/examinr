#' Storage Providers
#'
#' Exam data is stored via a _storage provider_, which is a list of functions.
#' Each user action will trigger a storage event for which one of the functions provided by the storage provider
#' is called.
#' See [dbi_storage_provider()] for an implementation based on a DBI backend.
#'
#' Storage providers must implement all of the functions listed under _Storage functions_.
#'
#' @section Arguments:
#' The arguments to the storage functions are:
#'
#' \describe{
#'  \item{`user`}{the user object (as returned from the configured [authentication provider][authentication_provider]).
#'                May be `NULL` for `get_section_data()`, in which case data for *all* users is requested.}
#'  \item{`exam_id`}{the exam id as given in the Rmd file.}
#'  \item{`exam_version`}{the exam version string as given in the Rmd file.}
#'  \item{`seed`}{an integer representing the random seed associated with the attempt.}
#'  \item{`started_at`}{the timestamp when the attempt was started (as [POSIXct][base::DateTimeClasses] object
#'    in the system's timezone).}
#'  \item{`finished_at`}{the timestamp when the attempt was finished (as [POSIXct][base::DateTimeClasses] object
#'    in the system's timezone).}
#'  \item{`attempt_id`}{the attempt identifier as returned by `start_attempt()` or `get_attempts()`.}
#'  \item{`section`}{the section identifier string. May be `NULL` for `get_section_data()`, in which case data for
#'                   *all* sections is requested.}
#'  \item{`section_data`}{an R list object with arbitrary elements. The storage function should not
#'                        make any assumptions on the make-up of this list.}
#'  \item{`points`}{an R list object with arbitrary elements. The storage function should not make any assumptions
#'                  on the make-up of this list.}
#'  \item{`...`}{additional arguments for future extensions.}
#' }
#'
#' @section Storage functions:
#'
#' ## `create_attempt(user, exam_id, exam_version, seed, started_at, ...)`
#' Create a new attempt with the given seed and start time.
#' The function should return a unique identifier for the attempt.
#' In case of an error, the function should return `FALSE`.
#'
#' ## `finish_attempt(attempt_id, finished_at, ...)`
#' Mark the attempt as finished.
#' The function should return `TRUE` if the data is saved successfully and `FALSE` in case of an error.
#'
#' ## `grade_attempt(attempt_id, points, ...)`
#' Grade the given attempt, i.e., assign the given points to the attempt.
#' The function should return `TRUE` if the points are saved successfully and `FALSE` in case of an error.
#'
#' ## `get_attempts(user, exam_id, exam_version, ...)`
#' Return a list of all previous attempts for the given filter.
#' The argument `user` can be `NULL`, in which case the function should return the attempts for *all* users.
#' The function must return a list of attempts. Each list object must contain the following:
#'
#' \describe{
#'  \item{`id`}{the identifier associated with this attempt.}
#'  \item{`user`}{the user object associated with this attempt.}
#'  \item{`started_at`}{the time (as [POSIXct][base::DateTimeClasses] object in the system's timezone) the attempt
#'    was started.}
#'  \item{`finished_at`}{the time (as [POSIXct][base::DateTimeClasses] object in the system's timezone) the attempt
#'    was finished, or `NULL` if it has not been finished.}
#'  \item{`points`}{the R list object as given to `grade_attempt()`, or `NULL` if the attempt is not yet graded.}
#' }
#'
#' In case there are no attempts associated with this user and exam, or in the case of an error,
#' the function should return an empty list.
#'
#' ## `save_section_data(attempt_id, section, section_data, ...)`
#' Save the given section data.
#' The function should return `TRUE` if the data is saved successfully and `FALSE` in case of an error.
#'
#' ## `get_section_data(attempt_id, section, ...)`
#' Query the most recent section data for the given attempt.
#' If `section` is `NULL`, the function should not filter data for this criterion.
#' In this case the function should return only the most recent section data available for the given attempt.
#' The function must return a list of section data objects matching the given filter. Each object must contain the
#' following:
#'
#' \describe{
#'  \item{`section`}{the section identifier string as given in the call to `save_section_data()`.}
#'  \item{`timestamp`}{the time (as [POSIXct][base::DateTimeClasses] object in the system's timezone) the section data
#'                     was saved.}
#'  \item{`section_data`}{the section data object as given in the call to `save_section_data()`.}
#' }
#'
#' In case of an error, or if there is no data available for the given filter, the function should return an empty
#' list.
#'
#' ## `get_last_section(attempt_id, ...)`
#' Get the identifier of the section for which the most recent data is available.
#' The function should return a character with the section identifier of the section for which data was saved
#' most recently.
#' In case of an error, or if there is no data available for the given filter, the function should return `NULL`.
#'
#' @name storage_provider
#' @family storage configuration
NULL

#' @importFrom rlang warn
#' @importFrom uuid UUIDgenerate
.void_storage_provider <- function () {
  return(list(
    create_attempt = function (...) {
      warn("No storage provider configured. Data is not saved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_write_warning')
      UUIDgenerate()
    },
    finish_attempt = function (...) {
      warn("No storage provider configured. Data is not saved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_write_warning')
      TRUE
    },
    grade_attempt = function (...) {
      warn("No storage provider configured. Data is not saved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_write_warning')
      TRUE
    },
    get_attempts = function (...) {
      warn("No storage provider configured. Data cannot be retrieved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_read_warning')
      list()
    },
    get_last_section = function (...) {
      warn("No storage provider configured. Data cannot be retrieved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_read_warning')
      NULL
    },
    get_section_data = function (...) {
      warn("No storage provider configured. Data cannot be retrieved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_read_warning')
      list()
    },
    save_section_data = function (...) {
      warn("No storage provider configured. Data is not saved.", .frequency = 'regularly',
           .frequency_id = 'examinr_void_storage_provider_write_warning')
      TRUE
    }))
}

#' DBI-Backed Exam Storage
#'
#' Store exam data in an SQL database using DBI.
#' **Note that exam data may contain sensitive information.**
#' To avoid potential privacy issues, the DBI storage provider supports hashing the user id, but this may require
#' external identification of users for grading.
#'
#' Attempts are stored in a table which requires the following columns:
#' \describe{
#' \item{`attempt_id`}{a unique identifier (a UUID) for the attempt, stored as character data.}
#' \item{`user_id`}{stored as character data. The required length depends on the authentication provider and if
#'                  hashing is used.}
#' \item{`exam_id`}{stored as character data. Ensure it can hold enough characters for the exam ids used in your exams.}
#' \item{`exam_version`}{stored as character data. Ensure it can hold enough characters for the exam version strings
#'                       used in your exams.}
#' \item{`started_at`}{unix timestamp at which the attempt was started.}
#' \item{`seed`}{the integer used to seed the RNG for this attempt.}
#' \item{`finished_at`}{unix timestamp at which the attempt was finished.}
#' \item{`user_obj`}{the user object (_less the identifier_) as returned by the authentication provider stored as character
#'                   data of arbitrary length.}
#' \item{`points`}{the points awarded for the attempt, as character data of arbitrary length.}
#' }
#'
#' Exam data is stored in a table which requires the following columns:
#'
#' \describe{
#' \item{`attempt_id`}{the attempt identifier of type _UUID_.}
#' \item{`section`}{the section identifier, as character data.}
#' \item{`saved_at`}{unix timestamp at which the section data was last saved.}
#' \item{`section_data`}{stored as character data of arbitrary length.}
#' }
#'
#' `dbi_storage_provider()` reads/writes unix timestamps as type _numeric_, and some database systems (e.g., PostgreSQL)
#' do not accept numeric input for timestamps. For these database systems, it is best to create the columns of type
#' `double precision`.
#'
#' A sample definition of the tables for PostgreSQL is as follows:
#'
#' ```
#' CREATE TABLE attempts (
#'   attempt_id UUID PRIMARY KEY,
#'   user_id character varying(256) NOT NULL,
#'   exam_id character varying(64) NOT NULL,
#'   exam_version character varying(64) NOT NULL,
#'   started_at double precision NOT NULL,
#'   seed integer NOT NULL,
#'   user_obj text NOT NULL,
#'   finished_at double precision,
#'   points text);
#'
#' CREATE INDEX attempts_index ON attempts
#'   (user_id, exam_id, exam_version);
#'
#' CREATE TABLE section_data (
#'   id serial PRIMARY KEY,
#'   attempt_id UUID NOT NULL REFERENCES attempts (attempt_id)
#'     ON DELETE CASCADE ON UPDATE CASCADE,
#'   section character varying (256) NOT NULL,
#'   saved_at double precision NOT NULL,
#'   section_data text);
#'
#' CREATE INDEX section_data_index ON section_data
#'   (attempt_id, section);
#' ```
#'
#'
#' @param conn a [DBIConnection][DBI::DBIConnection-class] object, as returned by [dbConnect()][DBI::dbConnect()]
#' @param attempts_table the name of the table to store the attempts data in.
#' @param section_data_table the name of the table to store the section data in.
#' @param hash_user store the user id as a SHA256 HMAC to protect the identity.
#' @param hash_key if `hash_user=TRUE`, the pre-shared secret key. If `TRUE` (the default), uses the concatenated
#'  *exam_id* and *exam_version*. If `NULL`, uses no HMAC but a plain SHA256 hash of the user id
#'  (**strongly discouraged**). Anything else is cast to [character][base::character]
#'  (or kept as [raw][base::raw] vector) and used as key.
#'
#' @importFrom digest digest hmac
#' @importFrom rlang abort warn cnd_message
#' @importFrom uuid UUIDgenerate
#' @family storage configuration
#' @export
dbi_storage_provider <- function (conn, attempts_table, section_data_table, hash_user = FALSE, hash_key = TRUE) {
  if (!requireNamespace('DBI', quietly = TRUE)) {
    abort("DBI package is required for this storage provider.")
  }

  conn_is_pool <- FALSE

  if (inherits(conn, 'Pool')) {
    if (!requireNamespace('pool', quietly = TRUE)) {
      abort("Connection object is from a pool, but the pool package cannot be loaded.")
    }
    conn_is_pool <- TRUE
  }

  if (!isTRUE(hash_key) && !is.null(hash_key) && !is.raw(hash_key)) {
    tryCatch({
      hash_key <- as.character(hash_key)
      stopifnot(length(hash_key) == 1L)
      hash_key <- charToRaw(hash_key)
    }, error = function (e) {
      abort("`hash_key` cannot be cast to a single character string")
    })
  }

  get_user_id <- function (user, exam_id, exam_version) {
    if (isTRUE(hash_user) && !isTRUE(attr(user, 'hashed', TRUE))) {
      if (isTRUE(hash_key)) {
        hmac(paste(exam_id, exam_version, sep = ''), user$user_id, algo = 'sha256', serialize = FALSE)
      } else if (is.null(hash_key)) {
        digest(user$user_id, algo = 'sha256', serialize = FALSE)
      } else {
        hmac(hash_key, user$user_id, algo = 'sha256', serialize = FALSE)
      }
    } else {
      user$user_id
    }
  }

  # Get the UNIX epoch at UTC (i.e., as.numeric(unix_epoch) == 0)
  unix_epoch <- as.POSIXct('1970-01-01', tz = 'UTC')

  # Check if tables exist
  attempts_table <- DBI::dbQuoteIdentifier(conn, attempts_table)
  section_data_table <- DBI::dbQuoteIdentifier(conn, section_data_table)

  local(tryCatch({
    if (conn_is_pool) {
      conn <- pool::poolCheckout(conn)
    }
    DBI::dbBegin(conn)

    attempt_id <- UUIDgenerate()
    tryCatch({
      attempts_insert_sql <- sprintf('INSERT INTO %s (attempt_id, user_id, exam_id, exam_version, started_at,
                                                      finished_at, seed, user_obj, points)
                                    VALUES ($1,$2,$3,$4,$5,$6,$7,$8, $9)', attempts_table)
      test_user_id <- get_user_id(list(user_id = 'user'), 'exam id string', '0.0.0')

      DBI::dbExecute(conn, attempts_insert_sql, params = list(
        attempt_id, test_user_id, 'exam id string', '0.0.0.0', as.numeric(Sys.time()),
        as.numeric(Sys.time()) + 1, 1L, serialize_object(list('user object')),
        serialize_object(list('points'))))
    }, error = function (e) {
      abort(paste('Table ', attempts_table, ' does not seem to exist or is not writable (error: ',
                  cnd_message(e), ')', sep = ''))
    })

    tryCatch({
      test_insert_sql <- sprintf('INSERT INTO %s (attempt_id, section, saved_at, section_data)
                                 VALUES ($1,$2,$3,$4)', section_data_table)
      DBI::dbExecute(conn, test_insert_sql, params = list(
        attempt_id, 'section', as.numeric(Sys.time()), serialize_object(list('section data'))))
    }, error = function (e) {
      abort(paste('Table ', section_data_table, ' does not seem to exist or is not writable (error: ',
                  cnd_message(e), ')', sep = ''))
    })
  }, finally = {
    tryCatch(DBI::dbRollback(conn), error = function (...) {}, warning = function (...) {})
    if (conn_is_pool) {
      pool::poolReturn(conn)
    }
  }))

  ## Storage functions
  return(list(
    # Start a new attempt
    create_attempt = function (user, exam_id, exam_version, seed, started_at, ...) {
      user_id <- get_user_id(user, exam_id, exam_version)
      user$user_id <- NULL  # strip the user id for saving the user object

      attempt_id <- UUIDgenerate()
      tryCatch({
        if (conn_is_pool) {
          conn <- pool::poolCheckout(conn)
        }
        DBI::dbBegin(conn)
        insert_stmt <- sprintf('INSERT INTO %s (attempt_id, user_id, exam_id, exam_version, started_at, seed, user_obj)
                                VALUES ($1,$2,$3,$4,$5,$6,$7)', attempts_table)

        DBI::dbExecute(conn, insert_stmt, params = list(
          attempt_id, user_id, as.character(exam_id), as.character(exam_version),
          as.numeric(started_at), as.integer(seed), serialize_object(user)))

        DBI::dbCommit(conn)
        attempt_id
      }, error = function (e) {
        tryCatch(DBI::dbRollback(conn), error = function (...) {}, warning = function (...) {})
        warn(paste("Cannot start new attempt:", cnd_message(e)))
        return(NULL)
      }, finally = {
        if (conn_is_pool) {
          pool::poolReturn(conn)
        }
      })
    },

    # Finish an attempt
    finish_attempt = function (attempt_id, finished_at, ...) {
      tryCatch({
        if (conn_is_pool) {
          conn <- pool::poolCheckout(conn)
        }
        DBI::dbBegin(conn)
        update_sql <- sprintf('UPDATE %s SET finished_at = $1 WHERE attempt_id = $2', attempts_table)
        affected_rows <- DBI::dbExecute(conn, update_sql, params = list(
          as.numeric(finished_at), attempt_id))
        DBI::dbCommit(conn)
        isTRUE(affected_rows == 1L)
      }, error = function (e) {
        tryCatch(DBI::dbRollback(conn), error = function (...) {}, warning = function (...) {})
        warn(paste("Cannot finish attempt:", cnd_message(e)))
        return(FALSE)
      }, finally = {
        if (conn_is_pool) {
          pool::poolReturn(conn)
        }
      })
    },

    # Grade an attempt
    grade_attempt = function (attempt_id, points, ...) {
      warn(c(i = paste0("Grading attempt ", attempt_id, " with serialized points")))
      for (line in str_split_width(serialize_object(points), 80)) {
        warn(c(">" = line))
      }
      tryCatch({
        if (conn_is_pool) {
          conn <- pool::poolCheckout(conn)
        }
        DBI::dbBegin(conn)
        update_sql <- sprintf('UPDATE %s SET points = $1 WHERE attempt_id = $2', attempts_table)
        affected_rows <- DBI::dbExecute(conn, update_sql, params = list(
          serialize_object(points), attempt_id))
        DBI::dbCommit(conn)
        warn(paste0("Committed grading for attempt ", attempt_id,
                    ". Affected rows: ", affected_rows))
        isTRUE(affected_rows == 1L)
      }, error = function (e) {
        tryCatch(DBI::dbRollback(conn), error = function (...) {}, warning = function (...) {})
        warn(paste("Cannot grade attempt:", cnd_message(e)))
        return(FALSE)
      }, finally = {
        if (conn_is_pool) {
          pool::poolReturn(conn)
        }
      })
    },

    get_attempts = function (user, exam_id, exam_version, ...) {
      filter_sql <- 'exam_id = $1 AND exam_version = $2'
      filter_data <- list(as.character(exam_id), as.character(exam_version))
      if (!is.null(user)) {
        filter_data <- c(filter_data, get_user_id(user, exam_id, exam_version))
        filter_sql <- paste(filter_sql, 'user_id = $3', sep = ' AND ')
      }

      tryCatch({
        query_sql <- sprintf('SELECT
                                user_id, attempt_id, started_at, finished_at, seed, user_obj, points
                              FROM
                                %s
                              WHERE %s', attempts_table, filter_sql)
        db_tbl <- DBI::dbGetQuery(conn, query_sql, params = filter_data)

        if (nrow(db_tbl) > 0L) {
          lapply(seq_len(nrow(db_tbl)), function (i) {
            user_obj <- unserialize_object(db_tbl$user_obj[[i]])
            user_obj$user_id <- db_tbl$user_id[[i]]
            attr(user_obj, 'hashed') <- TRUE

            list(id = db_tbl$attempt_id[[i]],
                 started_at = as.POSIXct(db_tbl$started_at[[i]], origin = unix_epoch),
                 finished_at = as.POSIXct(db_tbl$finished_at[[i]], origin = unix_epoch),
                 seed = db_tbl$seed[[i]],
                 user = user_obj,
                 points = if (!is.na(db_tbl$points[[i]])) { unserialize_object(db_tbl$points[[i]]) } else { NULL })
          })
        } else {
          list()
        }
      }, error = function (e) {
        warn(paste("Cannot query attempts:", cnd_message(e)))
        return(list())
      })
    },

    # Get the identifier of the last section with saved data
    get_last_section = function (attempt_id, ...) {
      tryCatch({
        read_stmt <- sprintf('SELECT
                                 section
                              FROM %s
                              WHERE attempt_id = $1
                              ORDER BY saved_at DESC
                              LIMIT 1', section_data_table)
        db_tbl <- DBI::dbGetQuery(conn, read_stmt, params = list(attempt_id), n = 1L)
        if (nrow(db_tbl) > 0L) {
          db_tbl$section[[1L]]
        } else {
          NULL
        }
      }, error = function (e) {
        warn(paste("Cannot find last section:", cnd_message(e)))
        return(NULL)
      })
    },

    # Get section data
    get_section_data = function (attempt_id, section, ...) {
      filter_sql <- 'attempt_id = $1'
      filter_data <- list(attempt_id)
      if (!is.null(section)) {
        filter_data <- c(filter_data, as.character(section))
        filter_sql <- paste(filter_sql, 'section = $2', sep = ' AND ')
      }

      tryCatch({
        read_stmt <- sprintf('SELECT section, saved_at, section_data FROM %s WHERE %s',
                             section_data_table, filter_sql)

        db_tbl <- DBI::dbGetQuery(conn, read_stmt, params = filter_data)
        if (nrow(db_tbl) > 0L) {
          lapply(seq_len(nrow(db_tbl)), function (i) {
            list(section = db_tbl$section[[i]],
                 saved_at = as.POSIXct(db_tbl$saved_at[[i]], origin = unix_epoch),
                 section_data = unserialize_object(db_tbl$section_data[[i]]))
          })
        } else {
          list()
        }
      }, error = function (e) {
        warn(paste("Cannot read section data:", cnd_message(e)))
        return(list())
      })
    },

    # Save section data
    save_section_data = function (attempt_id, section, section_data, ...) {
      tryCatch({
        if (conn_is_pool) {
          conn <- pool::poolCheckout(conn)
        }
        DBI::dbBegin(conn)
        # Drop old section data (if present)
        drop_old_stmt <- sprintf('DELETE FROM %s WHERE attempt_id = $1 AND section = $2', section_data_table)
        DBI::dbExecute(conn, drop_old_stmt, params = list(attempt_id, as.character(section)))

        # Insert new section data
        insert_stmt <- sprintf('INSERT INTO %s (attempt_id, section, saved_at, section_data)
                                 VALUES ($1,$2,$3,$4)', section_data_table)
        affected_rows <- DBI::dbExecute(conn, insert_stmt, params = list(
          attempt_id, as.character(section), as.numeric(Sys.time()), serialize_object(section_data)))
        DBI::dbCommit(conn)
        isTRUE(affected_rows == 1L)
      }, error = function (e) {
        tryCatch(DBI::dbRollback(conn), error = function (...) {}, warning = function (...) {})
        warn(paste("Cannot save section data:", cnd_message(e)))
        return(FALSE)
      }, finally = {
        if (conn_is_pool) {
          pool::poolReturn(conn)
        }
      })
    }
  ))
}

