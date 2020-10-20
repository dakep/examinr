#' Storage Providers
#'
#' Exam data is stored via _storage providers_.
#' Each user action will trigger a storage event for which a callback function is called.
#' See [dbi_storage_provider()] for an implementation storing/retrieving section data from a DBI backend.
#'
#' @section Callback functions:
#' All callback functions must accept the following arguments:
#'
#' - `user` the user object (as returned from the configured [authentication provider][authentication_provider]).
#' - `exam_id` the exam id as given in the Rmd file.
#' - `exam_version` the exam version string as given in the Rmd file.
#' - `...` for future extensions.
#'
#' Furthermore, each callback function is called with the following optional arguments:
#'
#' - `shiny_session` the shiny session object.
#'
#' @return a list of callback functions:
#'
#' - `save_section_data(section_data, ...)`: Save the given section data.
#'    The section data is an R list with with arbitrary elements. Should return `TRUE` if the data is saved
#'    successfully or `FALSE` in case of an error.
#' - `get_section_data(...)`: Return the most recent section data for the given user.
#'    The returned object must be in the same format as the section data provided to `save_section_data()`.
#'    In case of an error, should return `NULL`.
#'
#' See the section _Callback functions_ for more details on the additional arguments `...`.
#'
#' @name storage_provider
NULL


#' DBI-Backed Exam Storage
#'
#' Store exam data in an SQL database using DBI.
#' **Note that exam data may contain sensitive information.**
#' To avoid potential privacy issues, the DBI storage provider supports hashing the user id, but this may require
#' external identification of users for grading.
#'
#' Exam data is stored in a table which requires the following columns:
#'
#' - `user_id` stored as character data. The required length depends on the authentication provider and if hashing is
#'   used.
#' - `exam_id` stored as character data. Ensure it can hold enough characters for the exam ids used in your exams.
#' - `exam_version` stored as character data. Ensure it can hold enough characters for the exam version strings
#'   used in your exams.
#' - `timestamp` the UTC time at which the section data was last saved (of type _TIMESTAMP_)
#' - `section_data` stored as text of arbitrary length.
#'
#' A sample definition of the table for PostgreSQL is as follows:
#'
#' ```
#' CREATE TABLE section_data (
#'   id serial PRIMARY KEY,
#'   user_id character varying(64) NOT NULL,
#'   exam_id character varying(255) NOT NULL,
#'   exam_version character varying(64) NOT NULL,
#'   timestamp timestamp NOT NULL DEFAULT current_timestamp,
#'   section_data text);
#' CREATE INDEX section_data_index on section_data (user_id, exam_id, exam_version);
#' ```
#'
#'
#' @param conn a [DBIConnection][DBI::DBIConnection-class] object, as returned by [dbConnect()][DBI::dbConnect()]
#' @param table_name the name of the table to store the exam data in.
#' @param hash_user store the user id as a SHA256 hash to protect the identity.
#'
#' @importFrom digest digest
#' @importFrom rlang abort
#' @export
dbi_storage_provider <- function (conn, table_name, hash_user = FALSE) {
  if (!requireNamespace('DBI', quietly = TRUE)) {
    abort("DBI package is required for this storage provider.")
  }

  # Check if table exists
  db_table <- tryCatch({
    db_table <- DBI::dbQuoteIdentifier(conn, table_name)
    DBI::dbBegin(conn)
    test_insert_stmt <- sprintf('INSERT INTO %s (user_id, exam_id, exam_version, timestamp, section_data)
                                 VALUES ($1,$2,$3,$4,$5)', db_table)
    stmt <- DBI::dbSendStatement(conn, test_insert_stmt, immediate = FALSE)

    test_user_id <- if (isTRUE(hash_user)) {
      digest('user_id', algo = 'sha256', serialize = FALSE)
    } else {
      'user_id'
    }

    DBI::dbBind(stmt, list(test_user_id, 'exam id string', '0.0.0.0', as.numeric(Sys.time()),
                           serialize_object(list(x = 1, y = 2))))
    DBI::dbGetRowsAffected(stmt)
    DBI::dbClearResult(stmt)
    db_table
  }, finally = {
    tryCatch(DBI::dbRollback(conn), error = function (...) {})
  }, error = function (e) {
    abort(paste('Table "', table_name, '" does not seem to exist or is not writable (error: ', as.character(e), ')'))
  })

  return(list(
    get_section_data = function (user, exam_id, exam_version, shiny_session, ...) {
      user_id <- if (isTRUE(hash_user)) {
        digest(user$user_id, algo = 'sha256', serialize = FALSE)
      } else {
        user$user_id
      }

      tryCatch({
        read_stmt <- sprintf('SELECT t.section_data FROM %s t INNER JOIN (
                                SELECT user_id, exam_id, exam_version, MAX(timestamp) timestamp
                                FROM %s GROUP BY user_id, exam_id, exam_version
                              ) ft ON(t.user_id = ft.user_id AND t.exam_id = ft.exam_id AND
                                      t.exam_version = ft.exam_version AND t.timestamp = ft.timestamp)
                              WHERE t.user_id = $1 AND t.exam_id = $2 AND t.exam_version = $3',
                             db_table, db_table)
        stmt <- DBI::dbSendQuery(conn, read_stmt, immediate = FALSE)

        DBI::dbBind(stmt, list(test_user_id, as.character(exam_id), as.character(exam_version), as.numeric(Sys.time()),
                               serialize_object(section_data)))
        section_data <- DBI::dbFetch(stmt, n = 1L)
        DBI::dbClearResult(stmt)

        unserialize_object(section_data)
      }, error = function (e) {
        warn(paste("Cannot read section data:", as.character(e)))
        return(NULL)
      })
    },
    save_section_data = function (user, exam_id, exam_version, shiny_session, section_data, ...) {
      user_id <- if (isTRUE(hash_user)) {
        digest(user$user_id, algo = 'sha256', serialize = FALSE)
      } else {
        user$user_id
      }

      tryCatch({
        DBI::dbBegin(conn)
        insert_stmt <- sprintf('INSERT INTO %s (user_id, exam_id, exam_version, timestamp, section_data)
                                 VALUES ($1,$2,$3,$4,$5)', db_table)
        stmt <- DBI::dbSendStatement(conn, insert_stmt, immediate = FALSE)

        DBI::dbBind(stmt, list(test_user_id, as.character(exam_id), as.character(exam_version), as.numeric(Sys.time()),
                               serialize_object(section_data)))
        affected_rows <- DBI::dbGetRowsAffected(stmt)
        DBI::dbClearResult(stmt)

        isTRUE(affected_rows == 1L)
      }, finally = {
        tryCatch(DBI::dbCommit(conn), error = function (e) {
          warn(paste("Cannot save section data:", as.character(e)))
        })
      }, error = function (e) {
        tryCatch(DBI::dbRollback(conn), error = function (...) {})
        warn(paste("Cannot save section data:", as.character(e)))
        return(FALSE)
      })
    }
  ))
}

