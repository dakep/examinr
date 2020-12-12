#' Authentication Providers
#'
#' Every exam attempt is tied to a single _user_.
#' The exam document format does not determine the user, but invokes the authentication provider configured with
#' [exam_config()] to determine the user's identification.
#'
#'
#' @param session the shiny session object.
#' @return a list with user information. The list **must** contain an element `user_id` with the user's unique
#' identifier as character (it will be forcefully cast to `character`).
#' The user object may also contain the following
#' \describe{
#'   \item{`display_name`}{a character string which will be displayed for grading. If missing, the user id is
#'                         displayed for grading.}
#'   \item{`grading`}{if `TRUE`, the user has permissions to grade attempts.}
#' }
#' The user object can optionally include any number of additional entries which will be stored alongside
#' the exam data.
#' **Warning:** this could pose serious privacy issues. Either don't add additional information or ensure the data is
#' stored encrypted and secure.
#'
#' Any additional information will be proxied to all callback functions receiving a `user` object.
#'
#' @seealso [rsconnect_auth()] for an authentication provider using the user information from RStudio Connect.
#' @seealso [ui_auth()] for an authentication provider displaying a login user interface before the exam begins.
#'
#' @examples
#' # Use a "dummy" authentication provider which assigns everyone the same user id
#' # and does not allow anyone to grade submitted attempts.
#' exam_config(auth_provider = function (session) {
#'   return(list(
#'     user_id = "E-L",
#'     display_name = "Eager Learner",
#'     grading = FALSE
#'   ))
#' })
#'
#' @name authentication_provider
#' @family access configuration
NULL

#' RStudio Connect Authentication Provider
#'
#' Simple [authentication provider][authentication_provider] using the current user authenticated with RStudio Connect.
#' The `user_id` is the user's username and grading permission are determined by the user's group membership.
#'
#' @param grading_groups users who are members of any of these groups will have grading permissions.
#'
#' @return an authentication provider to use in [exam_config()].
#'
#' @examples
#' # Create an authentication provider which grants grading permissions to users which
#' # are members of either the "instructor" or the "assistant" group.
#' auth_prov <- rsconnect_auth(c('instructor', 'assistant'))
#' exam_config(auth_provider = auth_prov)
#'
#' @export
#' @family access configuration
rsconnect_auth <- function (grading_groups = NULL) {
  return(function (session) {
    if (is.null(session$user)) {
      abort("Cannot detect RStudio Connect user.")
    }
    return(list(user_id = session$user,
                grading = any(match(session$groups, grading_groups, nomatch = 0L) > 0L)))
  })
}

#' Authenticate Users Via User Interface
#'
#' Present the user with a login interface before the exam begins.
#'
#' This authentication provider matches the given username and password against the data frame `users`.
#' The data frame `users` must have at least two columns: _username_ and _password_.
#' The _password_ column must contain **hashed** passwords created with [sodium::password_store()]
#' (e.g., `sodium::password_store("password")`, or a SHA-256 HMAC created with [digest::hmac()]
#' (`digest::hmac("exam_id", "password", algo = "sha256")`).
#'
#' If the `users` data frame also contains columns *display_name* and/or _grading_, they are added to the user object
#' (and used as described in the [authentication provider documentation][authentication_provider]).
#'
#' @param users a data frame with user authentication information (username and **hashed** password).
#'   See below for details.
#' @param username_label label for the username input field.
#' @param password_label label for the password input field.
#' @param title title of the dialog.
#' @param button_label label for the login button.
#' @param username_empty,password_empty error messages for empty username/password field.
#' @param unauthorized error message for incorrect username/password.
#'
#' @export
#' @family access configuration
#' @importFrom rlang abort
#' @importFrom stringr str_starts
#' @importFrom digest hmac
ui_auth <- function (users, username_label = 'Username', password_label = 'Password', title = 'Login',
                     button_label = 'Login', username_empty = 'Username cannot be empty.',
                     password_empty = 'Passwort cannot be empty.',
                     unauthorized = 'The username/password are incorrect.') {
  use_sodium <- FALSE
  if (!is.character(users$username)) {
    abort("Argument `users` must contain a character column `username`.")
  }
  if (!is.character(users$password)) {
    abort("Argument `users` must contain a character column `password` with hashed passwords (64 characters each).")
  }
  use_sodium <- all(str_starts(users$password, fixed('$7$C6')))
  if (!use_sodium && !all(nchar(users$password) == 64L)) {
    abort("Argument `users$password` must either be passwords hashed with `sodium::password_store()` or a SHA-256 HMAC.")
  }

  if (use_sodium) {
    if (!requireNamespace('sodium', quietly = TRUE)) {
      abort("Package sodium is required to verify the hashed passwords in `ui_auth()`.")
    }
  }

  users$username <- enc2utf8(users$username)
  users$password <- enc2utf8(users$password)

  # Define the user interface for the login screen.
  # `inputs` can be a list of arbitrary length, each item defining one input
  ui <- list(
    title = title,
    btnLabel = button_label,
    inputs = list(list(name = 'username', label = username_label, emptyError = username_empty),
                  list(name = 'password', label = password_label, emptyError = password_empty, type = 'password')))

  # The callback is called when the user clicks the login button.
  # It gets an argument `input` which is a named list with the user's input values.
  # The name is the `name` from the input in the UI definition.
  # If the callback returns anything but `TRUE`, the return value is interpreted as error message that
  # should be shown to the user.
  callback <- function (input, session, exam_metadata) {
    if (length(input$username) != 1L || !nzchar(input$username)) {
      return(username_empty)
    }
    if (length(input$password) != 1L || !nzchar(input$password)) {
      return(username_empty)
    }
    input$username <- enc2utf8(input$username)
    input$password <- enc2utf8(input$password)
    user_match <- which(match(users$username, input$username, nomatch = 0L) == 1L)
    if (length(user_match) != 1L) {
      return(unauthorized)
    }
    pw_match <- if (use_sodium) {
      sodium::password_verify(users$password[[user_match]], input$password)
    } else {
      hashed_pw <- hmac(exam_metadata$id, input$password, algo = 'sha256', serialize = FALSE)
      identical(users$password[[user_match]], hashed_pw)
    }
    if (!isTRUE(pw_match)) {
      return(unauthorized)
    }

    session$userData[['__examinr_ui_auth_login_info']] <- list(
      user_id = users$username[[user_match]],
      display_name = users$display_name[[user_match]],
      grading = isTRUE(users$grading[[user_match]])
    )
    return(TRUE)
  }

  # This is the actual authentication provider which needs the session information populated by
  # the callback.
  auth_provider <- function (session) {
    return(session$userData[['__examinr_ui_auth_login_info']])
  }

  structure(list(
    ui = ui,
    callback = callback,
    auth = auth_provider
  ), class = 'ui_authentication_provider')
}
