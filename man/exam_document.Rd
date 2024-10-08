% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/exam_format.R
\name{exam_document}
\alias{exam_document}
\title{Exam Output Format}
\usage{
exam_document(
  id = "exam",
  version = "0.1",
  use_cdn = FALSE,
  render = c("server", "static"),
  progressive = FALSE,
  order = c("random", "fixed"),
  max_attempts = Inf,
  timelimit = Inf,
  opens = NA,
  closes = NA,
  feedback = NA,
  grace_period = 120,
  self_contained = TRUE,
  fig_width = 7,
  fig_height = 5,
  fig_retina = 2,
  fig_caption = TRUE,
  keep_md = FALSE,
  dev = "png",
  highlight = "tango",
  df_print = "default",
  css = NULL,
  mathjax = "default",
  mathjax_dollar = TRUE,
  md_extensions = NULL,
  extra_dependencies = NULL,
  ...
)
}
\arguments{
\item{id}{the exam id string. To ensure compatibility with most \link[=storage_provider]{storage providers},
should be a short yet unique identifier with only alphanumeric characters and \verb{-_.}.}

\item{version}{the exam version string. Must only contain numbers and the \code{.} character, e.g., \code{1}, \code{0.5}, \verb{2.3.4},
etc.}

\item{use_cdn}{load javascript libraries from external content delivery networks (CDNs).
Use this if the shiny server is slow at serving static resources, but beware of the downsides of
relying on content from a third-party!
Note that the default MathJax library is \emph{always} loaded from a CDN.}

\item{render}{render section content on the server (\code{"server"}) or statically when rendering the document
(\code{"static"}). If rendered on the server, the section content will only be sent to the user's browser
when the section is displayed. This ensures users do not see the section content before they are supposed to.}

\item{progressive}{are sections displayed one after another or all at once? If all sections are displayed at
once, only the last section button is shown.}

\item{order}{if \code{progressive=TRUE}, the order in which sections will be shown. Can be either \emph{random}, in which
case the order is randomized using the seed from the attempt, or \emph{fixed}, in which case the order in the exam
document is kept.}

\item{max_attempts}{maximum number of attempts allowed. This can be overridden for individual users by
\code{\link[=configure_attempts]{configure_attempts()}}. Can also be \code{Inf} to allow for unlimited number of attempts (the default).}

\item{timelimit}{the time limit for a single attempt either as a single number in minutes or as \emph{HH:MM}.
This can be overridden for individual users with \code{\link[=configure_attempts]{configure_attempts()}}.
Can also be \code{Inf} to give users unlimited time (the default).}

\item{opens, closes}{the opening and closing time for the exam, in the format \emph{YYYY-MM-DD HH:MM Timezone}
(e.g., \verb{2020-10-15 19:15 Europe/Vienna} for October 15th, 2020 at 19:15 in Vienna, Austria).
The exam is only accessible within this time frame.
This can be overridden for individual users with \code{\link[=configure_attempts]{configure_attempts()}}.
Can also be \code{NA} to either make the exam available immediately, indefinitely, or both (the default).}

\item{feedback}{the date/time on which the solution and feedback are available, \code{"immediately"} for showing
feedback immediately after the exam is submitted, or \code{NA}, in which case no feedback view is available.
Note that if feedback is shown immediately after the exam is submitted, the last section is treated as
a regular section.}

\item{grace_period}{number of seconds of "grace" period given to users before an active attempt is disabled.
This can be overridden for individual users with \code{\link[=configure_attempts]{configure_attempts()}}.}

\item{self_contained}{produce a HTML file with all external dependencies included using \verb{data:} URIs.
Note that the default MathJax library is always loaded from an external CDN (see \code{use_cdn} for details).}

\item{fig_width}{default width (in inches) for figures.}

\item{fig_height}{default height (in inches) for figures.}

\item{fig_retina}{scaling to perform for retina displays. Set to \code{NULL} to prevent retina scaling.
See \code{\link[rmarkdown:html_document]{rmarkdown::html_document()}} for details.}

\item{fig_caption}{\code{TRUE} to render figures with captions.}

\item{keep_md}{Keep the markdown file generated by knitting.}

\item{dev}{graphics device to use for figure output (defaults to png).}

\item{highlight}{Enable syntax highlighting style via pandoc.
Supported styles include "tango", "pygments", "kate", "monochrome", "espresso", "zenburn", "haddock".
Pass \code{NULL} to prevent syntax highlighting.}

\item{df_print}{method to be used for printing data frames.
Valid values include "default", "kable", "tibble", and "paged". See \code{\link[rmarkdown:html_document]{rmarkdown::html_document()}} for details.}

\item{css}{one or more CSS files to include in the document.}

\item{mathjax}{if and how to include MathJax. The "default" option uses MathJax v3 from a CDN.
You can pass an alternate URL or pass \code{NULL} to disable MathJax entirely.}

\item{mathjax_dollar}{Use the dollar sign (\code{$}, \verb{$$}) to denote equations.
Can cause issues with the dollar sign in inline code.}

\item{md_extensions}{markdown extensions to be added or removed from the default definition of R Markdown.
See \code{\link[rmarkdown:rmarkdown_format]{rmarkdown::rmarkdown_format()}} for details.}

\item{extra_dependencies, ...}{additional arguments passed on to the base R Markdown HTML output
\code{\link[rmarkdown:html_document_base]{rmarkdown::html_document_base()}}.}
}
\description{
Exam Output Format
}
