#' Exam Output Format
#'
#' @param id the exam id string. To ensure compatibility with most [storage providers][storage_provider],
#'   should be a short yet unique identifier with only alphanumeric characters and `-_.`.
#' @param version the exam version string. Must only contain numbers and the `.` character, e.g., `1`, `0.5`, `2.3.4`,
#'   etc.
#' @param progressive are sections displayed one after another or all at once? If all sections are displayed at
#'   once, only the last section button is shown.
#' @param order if `progressive=TRUE`, the order in which sections will be shown. Can be either _random_, in which
#'   case the order is randomized using the seed from the attempt, or _fixed_, in which case the order in the exam
#'   document is kept.
#' @param render render section content on the server (`"server"`) or statically when rendering the document
#'   (`"static"`). If rendered on the server, the section content will only be sent to the user's browser
#'   when the section is displayed. This ensures users do not see the section content before they are supposed to.
#' @param max_attempts maximum number of attempts allowed. This can be overridden for individual users by
#'   [configure_attempts()]. Can also be `Inf` to allow for unlimited number of attempts (the default).
#' @param timelimit the time limit for a single attempt either as a single number in minutes or as _HH:MM_.
#'   This can be overridden for individual users with [configure_attempts()].
#'   Can also be `Inf` to give users unlimited time (the default).
#' @param grace_period number of seconds of "grace" period given to users before an active attempt is disabled.
#'   This can be overridden for individual users with [configure_attempts()].
#' @param opens,closes the opening and closing time for the exam, in the format _YYYY-MM-DD HH:MM Timezone_
#'   (e.g., `2020-10-15 19:15 Europe/Vienna` for October 15th, 2020 at 19:15 in Vienna, Austria).
#'   The exam is only accessible within this time frame.
#'   This can be overridden for individual users with [configure_attempts()].
#'   Can also be `NA` to either make the exam available immediately, indefinitely, or both (the default).
#' @param feedback the date/time on which the solution and feedback are available, `"immediately"` for showing
#'   feedback immediately after the exam is submitted, or `NA`, in which case no feedback view is available.
#'   Note that if feedback is shown immediately after the exam is submitted, the last section is treated as
#'   a regular section.
#' @param use_cdn load javascript libraries from external content delivery networks (CDNs).
#'   Use this if the shiny server is slow at serving static resources, but beware of the downsides of
#'   relying on content from a third-party!
#'   Note that the default MathJax library is *always* loaded from a CDN.
#' @param fig_width default width (in inches) for figures.
#' @param fig_height default height (in inches) for figures.
#' @param fig_retina scaling to perform for retina displays. Set to `NULL` to prevent retina scaling.
#'   See [rmarkdown::html_document()] for details.
#' @param fig_caption `TRUE` to render figures with captions.
#' @param dev graphics device to use for figure output (defaults to png).
#' @param keep_md Keep the markdown file generated by knitting.
#' @param df_print method to be used for printing data frames.
#'   Valid values include "default", "kable", "tibble", and "paged". See [rmarkdown::html_document()] for details.
#' @param self_contained produce a HTML file with all external dependencies included using `data:` URIs.
#'   Note that the default MathJax library is always loaded from an external CDN (see `use_cdn` for details).
#' @param highlight Enable syntax highlighting style via pandoc.
#'   Supported styles include "tango", "pygments", "kate", "monochrome", "espresso", "zenburn", "haddock".
#'   Pass `NULL` to prevent syntax highlighting.
#' @param mathjax if and how to include MathJax. The "default" option uses MathJax v3 from a CDN.
#'   You can pass an alternate URL or pass `NULL` to disable MathJax entirely.
#' @param mathjax_dollar Use the dollar sign (`$`, `$$`) to denote equations.
#'   Can cause issues with the dollar sign in inline code.
#' @param css one or more CSS files to include in the document.
#' @param md_extensions markdown extensions to be added or removed from the default definition of R Markdown.
#'   See [rmarkdown::rmarkdown_format()] for details.
#' @param extra_dependencies,... additional arguments passed on to the base R Markdown HTML output
#'  [rmarkdown::html_document_base()].
#'
#' @importFrom rmarkdown output_format html_document_base shiny_prerendered_chunk from_rmarkdown knitr_options_html
#' @importFrom rmarkdown pandoc_options
#' @importFrom htmltools htmlDependency
#' @importFrom stringr str_starts str_sub
#' @importFrom utils packageVersion
#' @importFrom knitr knit_meta knit opts_knit knit_hooks opts_chunk opts_hooks
#' @importFrom tools file_path_sans_ext file_ext
#'
#' @export
exam_document <- function (id = 'exam', version = '0.1', use_cdn = FALSE, render = c('server', 'static'),
                           progressive = FALSE, order = c('random', 'fixed'), max_attempts = Inf, timelimit = Inf,
                           opens = NA, closes = NA, feedback = NA, grace_period = 120, self_contained = TRUE,
                           fig_width = 7, fig_height = 5, fig_retina = 2, fig_caption = TRUE, keep_md = FALSE,
                           dev = 'png', highlight = 'tango',  df_print = 'default', css = NULL,
                           mathjax = 'default', mathjax_dollar = TRUE, md_extensions = NULL,
                           extra_dependencies = NULL, ...) {
  # Parse attempts configuration
  attempts_config <- set_attempts_config_from_metadata(opens = opens, closes = closes, max_attempts = max_attempts,
                                                       timelimit = timelimit, grace_period = grace_period)

  if (length(id) == 0L) {
    abort("Exam documents must have an id!")
  }

  if (!all(is.na(feedback)) && !is.null(feedback) && !isFALSE(feedback) && !identical(feedback, 'immediately')) {
    feedback <- parse_datetime(feedback)
  }

  # Verify exam metadata
  exam_metadata <- list(id = as.character(id)[[1L]],
                        version = as.character(numeric_version(version[[1L]])),
                        feedback = feedback,
                        render = match.arg(render),
                        progressive = isTRUE(progressive),
                        order = match.arg(order))
  # build pandoc args
  pandoc_args <- c('--standalone', '--section-divs', '--variable', 'enable-high-contrast:1')

  # template path and assets
  template_file <- normalizePath(system.file('templates', 'exam.html', package = 'examinr', mustWork = TRUE))

  pandoc_args <- c(pandoc_args, '--template', normalizePath(template_file))

  extra_dependencies <- c(extra_dependencies %||% list(), list(
    html_dependency_ace(use_cdn),
    htmlDependency('exam', packageVersion('examinr'),
                   src = system.file('www', package = 'examinr', mustWork = TRUE),
                   script = 'exam.min.js', stylesheet = 'exam.min.css')))

  if (identical(mathjax, 'default')) {
    pandoc_args <- c(pandoc_args, '--mathjax', '--variable', 'mathjax-v3-cdn:1')
    mathjax <- NULL
  }

  # highlighting using pandoc's highlighters
  pandoc_args <- c(pandoc_args, '--highlight-style', highlight)

  # add all user-specified CSS files
  for (path in css) {
    pandoc_args <- c(pandoc_args, "--css", normalizePath(path))
  }

  post_knit <- function (metadata, input, runtime, encoding, ...) {
    if (!identical(tolower(file_ext(input)), 'rmd')) {
      return(NULL)
    }
    # Detach data from the data provider.
    for (env_name in knit_meta('examinr_data_provider_env') %||% list()) {
      detach(env_name, character.only = TRUE)
    }
    # Check for duplicate question labels
    question_labels <- unclass(knit_meta('examinr_question_label') %||% character(0L))
    dupl_question_labels <- duplicated(question_labels)
    if (any(dupl_question_labels)) {
      abort(paste("Duplicate question ids:", paste(unique(question_labels[dupl_question_labels]), collapse = ', ')))
    }

    # Using the information collected in the first pass, create a new Rmd file and knit it again.
    # Collect stats from the first run
    first_pass_stats <- list(
      section_config_overrides = section_config_overrides(),
      static_chunks = unlist(knit_meta('examinr_static_chunk_label'), FALSE, FALSE) %||% character(0L)
    )
    # Create a new Rmd file with exam sections
    new_rmd <- create_exam_rmd(input_rmd = input, static_chunks = first_pass_stats$static_chunks,
                               exam_metadata = exam_metadata, attempts_config = attempts_config,
                               section_config_overrides = first_pass_stats$section_config_overrides,
                               encoding = encoding)

    on.exit(unlink(new_rmd, recursive = FALSE, force = TRUE), add = TRUE, after = FALSE)

    ## Knit the new Rmd file into the original markdown file
    output <- file.path(dirname(input), sprintf('%s.knit.md', file_path_sans_ext(basename(input))))

    # clean the metadata from the first run
    knit_meta()

    # set the options for knitting the exam
    opts_knit$set(examinr.initial_pass = FALSE)
    knit_hooks$set(exercise = knit_hook_exercise)
    opts_chunk$set(examinr.exam = TRUE,
                   exercise.df_print = df_print)
    opts_hooks$set(examinr.sectionchunk = exam_section_opts_hook)

    # Register the attempts configuration in the server process
    shiny_prerendered_chunk('server-start', sprintf('examinr:::register_attempts_config("%s")',
                                                    serialize_object(attempts_config)))

    knit_env <- new.env(parent = parent.frame())
    knit(input = new_rmd, output = output, quiet = TRUE, envir = knit_env, encoding = encoding)

    return(NULL)
  }

  knitr_options <- knitr_options_html(fig_width, fig_height, fig_retina, keep_md, dev)
  knitr_options$opts_chunk <- c(knitr_options$opts_chunk %||% list(),
                                list(examinr.exam = TRUE,
                                     examinr.mathjax_dollar = isTRUE(mathjax_dollar)))
  knitr_options$opts_knit <- c(knitr_options$opts_knit %||% list(), list(examinr.initial_pass = TRUE))
  knitr_options$opts_hooks <- c(knitr_options$opts_hooks %||% list(), list(examinr.exam = opts_hook_exam_format))

  # Additional stuff for the HTML header
  html_header_extra <- tempfile(fileext = '.html')
  cat('<script type="application/javascript">',
      sprintf('const EXAMINR_EXAM_METADATA = %s;', to_json(exam_metadata)),
      '</script>',
      sep = '\n',
      file = html_header_extra)

  pandoc_args <- c(pandoc_args, '--include-in-header', html_header_extra)

  out <- output_format(
    pandoc = pandoc_options(to = 'html5',
                            from = from_rmarkdown(fig_caption, md_extensions),
                            args = pandoc_args),
    knitr = knitr_options,
    keep_md = keep_md,
    clean_supporting = TRUE,
    df_print = df_print,
    post_knit = post_knit,
    on_exit = function (...) {
      unlink(html_header_extra, recursive = FALSE, force = TRUE)
    },
    base_format = html_document_base(theme = NULL,
                                     self_contained = self_contained,
                                     mathjax = mathjax,
                                     template = NULL,
                                     extra_dependencies = extra_dependencies,
                                     ...))
  return(out)
}

#' @importFrom knitr knit_meta_add
mark_chunk_static <- function (label) {
  if (is_missing(label)) {
    label <- opts_current$get('label')
  }
  force(label)
  knit_meta_add(list(structure(label, class = 'examinr_static_chunk_label')))
  return(NULL)
}

## Hook called for every chunk in an exam document in the second pass
#' @importFrom knitr opts_knit knit_meta_add
#' @importFrom rmarkdown metadata
#' @importFrom rlang abort
opts_hook_exam_format <- function (options, ...) {
  if (!isTRUE(getOption('knitr.in.progress'))) {
    return(options)
  }

  if (!identical(opts_knit$get('rmarkdown.runtime'), 'shiny_prerendered')) {
    abort("examinr exams can only be used with `runtime: shiny_prerendered`.")
  }

  if (is.null(options[['context']]) || identical(options[['context']], 'render')) {
    # Check all chunks within the "render" context for R exercise
    if (isTRUE(opts_knit$get('examinr.initial_pass'))) {
      return(opts_hook_possible_exercise_initial_pass(options, ...))
    } else {
      return(opts_hook_possible_exercise_second_pass(options, ...))
    }
  } else {
    return(options)
  }
}

## Initialize all components.
## This must be called at the end of the document to ensure all section information has been collected.
#' @importFrom rlang abort
initialize_exam <- function (exam_metadata, attempts_config, section_config_overrides) {
  exam_metadata <- unserialize_object(exam_metadata)
  attempts_config <- unserialize_object(attempts_config)
  section_config_overrides <- unserialize_object(section_config_overrides)

  # Merge section information with section configuration overrides
  sections <- knit_meta('examinr_section')

  sections <- lapply(sections, function (section) {
    section$overrides <- section_config_overrides[[section$name]] %||% list()
    return(section)
  })

  # Validate sections
  if (identical(exam_metadata$feedback, 'immediately')) {
    if (length(sections) < 1L) {
      abort("Exam documents with `feedback = 'immediately'` must have at least one section!")
    }
  } else if (length(sections) < 2L) {
    abort("Exam documents must have at least two sections!")
  }

  return(structure(list(exam_metadata = exam_metadata,
                        attempts_config = attempts_config,
                        sections = sections),
                   class = 'examinr_exam_init'))
}

## Print section initialization
#' Overrides for knit_print.
#' @inheritParams knitr::knit_print
#' @method knit_print examinr_exam_init
#' @rdname knit_print
#' @importFrom rmarkdown shiny_prerendered_chunk
#' @importFrom htmltools tagList
#' @export
#' @keywords internal
knit_print.examinr_exam_init <- function (x, ...) {
  shiny_prerendered_chunk('server', sprintf('examinr:::initialize_exam_server("%s")', serialize_object(x)))

  ui_attempts_config <- list(totalSections = length(x$sections) - 1L,
                             haveTimelimit = isTRUE(x$attempts_config$timelimit < Inf),
                             progressive = isTRUE(x$exam_metadata$progressive),
                             progressbar = isTRUE(x$exam_metadata$progress_bar))

  ui_sections_config <- list(progressive = isTRUE(x$exam_metadata$progressive),
                             hideLastSection = !identical(x$exam_metadata$feedback, 'immediately'))

  ui <- tagList(tags$script(type = 'application/json', class = 'examinr-attempts-config',
                            HTML(to_json(ui_attempts_config))),
                tags$script(type = 'application/json', class = 'examinr-sections-config',
                            HTML(to_json(ui_sections_config))),
                tags$script(type = 'application/json', class = 'examinr-status-messages',
                            HTML(to_json(get_status_message()))))
  knit_print(ui, ...)
}

## Initialize a new exam session
#' @importFrom shiny parseQueryString getDefaultReactiveDomain reactiveValuesToList
#' @importFrom rlang warn cnd_message
#' @importFrom stringr str_detect fixed
initialize_exam_server <- function (config) {
  config <- unserialize_object(config)
  session <- getDefaultReactiveDomain()

  if (is.null(session)) {
    abort("shiny session not available")
  }

  # display the feedback url in the logs
  isolate(with(reactiveValuesToList(session$clientData), {
    feedback_url <- sprintf('%s//%s', url_protocol, url_hostname)
    if (!identical(url_port, 80) || !identical(url_port, 443)) {
      feedback_url <- paste(feedback_url, url_port, sep = ':')
    }
    if (nzchar(url_pathname)) {
      feedback_url <- paste(feedback_url, url_pathname, sep = '/')
    }
    feedback_url <- if (nzchar(url_search)) {
      if (str_detect(url_search, fixed('display=feedback'))) {
        paste(feedback_url, url_search, sep = '')
      } else {
        sprintf('%s%s&display=feedback', feedback_url, url_search)
      }
    } else {
      paste(feedback_url, 'display=feedback', sep = '?')
    }
    signal_feedback_url(feedback_url)
  }))

  # log in user
  login_ui <- get_login_ui()
  if (!is.null(login_ui)) {
    send_message('loginscreen', login_ui$ui, session = session)

    obs <- observe({
      login_data <- session$input[['__.examinr.__-login']]
      if (!is.null(login_data)) {
        tryCatch({
          input_vals <- lapply(login_data$inputs, `[[`, 'value')
          names(input_vals) <- vapply(login_data$inputs, `[[`, 'name', FUN.VALUE = character(1L))

          login_res <- login_ui$callback(input_vals, session, config$exam_metadata)
          msg <- if (isTRUE(login_res)) {
            send_message('login', list(status = TRUE), session = session)
            obs$destroy()
            # Continue the exam initialization.
            continue_initialize_exam_server(config, session)
          } else {
            send_message('login', list(status = FALSE, error = as.character(login_res)), session = session)
          }
        }, error = function (e) {
          warn(paste("Login UI throws an error:", cnd_message(e)))
          send_message('login', list(
            status = FALSE,
            errorTitle = get_status_message('authenticationError')$title,
            error = get_status_message('authenticationError')$body
          ), session = session)
        })
      }
    }, domain = session)
  } else {
    continue_initialize_exam_server(config, session)
  }
}

continue_initialize_exam_server <- function (config, session) {
  query <- parseQueryString(isolate(session$clientData$url_search))

  if (identical(query$display, 'feedback')) {
    initialize_feedback(session, config$exam_metadata, config$sections)
  } else {
    initialize_attempt(session, exam_id = config$exam_metadata$id, exam_version = config$exam_metadata$version)
    initialize_sections_server(session, config$sections, config$exam_metadata)
  }
}
