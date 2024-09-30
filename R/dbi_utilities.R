#' Setup a DBI-Backed Database for Exams
#'
#' Helper function to setup a "default" database in a form suitable for use with
#' [dbi_storage_provider()].
#' This function creates two tables (*attempts* and *sections*) and the proper indices
#' to ensure uniqueness of entries.
#'
#' Currently implemented only for RPostgres or RSQLite backends.
#'
#' @family storage configuration
#' @importFrom DBI dbExecute
#' @importFrom rlang abort
#' @export
setup_database <- function (db_con) {
  if (inherits(db_con, 'Pool')) {
    if (!requireNamespace('pool', quietly = TRUE)) {
      abort("Connection object is from a pool, but the pool package cannot be loaded.")
    }
    db_con <- pool::poolCheckout(db_con)
    on.exit(pool::poolReturn(db_con), add = TRUE)
  }

  if (inherits(db_con, "SQLiteConnection")) {
    # Create the attempts table
    dbExecute(db_con, 'CREATE TABLE attempts (
                          attempt_id   varchar(36) PRIMARY KEY,
                          user_id      varchar(64) NOT NULL,
                          exam_id      varchar(64) NOT NULL,
                          exam_version varchar(64) NOT NULL,
                          user_obj     text        NOT NULL,
                          seed         integer     NOT NULL,
                          started_at   timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          finished_at  timestamp,
                          points       text
                        )')
    # Create an index on the attempts table
    dbExecute(db_con, 'CREATE INDEX attempts_index ON attempts (user_id, exam_id, exam_version)')

    # Create the section data table
    dbExecute(db_con, 'CREATE TABLE section_data (
                          id           integer      PRIMARY KEY,
                          attempt_id   varchar(36)  NOT NULL,
                          section      varchar(64)  NOT NULL,
                          saved_at     timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          section_data text
                        )')
    # Create an index on the section data table
    dbExecute(db_con, 'CREATE INDEX section_data_index ON section_data (attempt_id, section)')
  } else if (inherits(db_con, "PqDriver")) {
    # Create the attempts table
    dbExecute(db_con, 'CREATE TABLE attempts (
                          attempt_id   uuid              PRIMARY KEY,
                          user_id      character varying NOT NULL,
                          exam_id      character varying NOT NULL,
                          exam_version character varying NOT NULL,
                          started_at   double precision  NOT NULL,
                          seed         integer           NOT NULL,
                          user_obj     text              NOT NULL,
                          finished_at  double precision,
                          points       text
                      )')
    # Create an index on the attempts table
    dbExecute(db_con, 'CREATE INDEX attempts_index ON attempts (user_id, exam_id, exam_version)')

    # Create the section data table
    dbExecute(db_con, 'CREATE TABLE section_data (
                          id           serial            PRIMARY KEY,
                          attempt_id   uuid              NOT NULL REFERENCES attempts (attempt_id)
                                                            ON DELETE CASCADE ON UPDATE CASCADE,
                          section      character varying NOT NULL,
                          saved_at     double precision  NOT NULL,
                          section_data text
                        )')
    # Create an index on the section data table
    dbExecute(db_con, 'CREATE INDEX section_data_index ON section_data (attempt_id, section)')
  } else {
    abort(paste("Unknown database backend. Automatic setup of examinr database only supported for",
                "RSQLite or RPostgres backends."))
  }
}
