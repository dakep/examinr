#' Authentication Providers
#'
#' Exams are tied to a single _user_.
#' Each user has a unique randomization of the exam and all answers are tied to the user.
#' The exam format does not determine the user, but invokes the authentication provider configured with `setup_exam()`
#' to determine the user's identification.
#'
#'
#' @param shiny_session the shiny session object.
#' @return a list with user information. The list must contain the following elements:
#'
#'   - `user_id` ... the user's id.
#'   - `seed` ... the seed for the random number generator.
#'
#'   Any additional information will be proxied to all callback functions receiving a `user` object.
#'
#' @name authentication_provider
NULL

#' @describeIn authentication_provider use the rstudio-connect user.
#' @importFrom digest digest2int
#' @importFrom rlang warn
#' @export
rsconnect_authentication_provider <- function (shiny_session) {
  user_id <- shiny_session$user
  if (is.null(user_id)) {
    abort("Cannot detect rstudio-connect user. Falling back to dummy authentication provider.")
  }
  return(list(user_id = user_id, seed = digest2int(user_id)))
}

