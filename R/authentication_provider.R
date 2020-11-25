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
#' @seealso [rsconnect_auth()] for a simple authentication provider using the user information from RStudio Connect.
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
NULL

#' RStudio Connect Authentication Provider
#'
#' Simple [authentication provider][authentication_provider] using the current user authenticated with RStudio Connect.
#' The `user_id` is the user's username and grading permission are determined by the user's group membership.
#'
#' @param grading_group users who are members of any of these groups will have grading permissions.
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
rsconnect_auth <- function (grading_groups = NULL) {
  return(function (session) {
    if (is.null(session$user)) {
      abort("Cannot detect RStudio Connect user.")
    }
    return(list(user_id = session$user,
                grading = any(match(session$groups, grading_groups, nomatch = 0L) > 0L)))
  })
}
