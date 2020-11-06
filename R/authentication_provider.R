#' Authentication Providers
#'
#' Every exam attempt is tied to a single _user_.
#' Each attempt can get a different randomization of the exam and all attempts are tied to a user.
#' The exam document format does not determine the user, but invokes the authentication provider configured with
#' [exam_config()] to determine the user's identification.
#'
#' @param shiny_session the shiny session object.
#' @return a list with user information. The list **must** contain an element `user_id` with the user's unique
#' identifier as character (it will be forcefully cast to `character`).
#' The user information list can optionally include any number of additional objects, which will be stored alongside
#' the exam data.
#' **Warning:** this could pose serious privacy issues. Either not add additional information or ensure the data is
#' stored encrypted and secure.
#'
#' Any additional information will be proxied to all callback functions receiving a `user` object.
#'
#'
#' @name authentication_provider
NULL

#' @describeIn authentication_provider use the name of the user authenticated with RStudio Connect as user id.
#' @importFrom rlang abort
#' @export
rsconnect_authentication_provider <- function (shiny_session) {
  user_id <- shiny_session$user
  if (is.null(user_id)) {
    abort("Cannot detect rstudio-connect user.")
  }
  return(list(user_id = user_id))
}
