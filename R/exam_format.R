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
#'   [configure_attemptss()]. Can also be `Inf` to allow for unlimited number of attempts (the default).
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
#' @param use_cdn load javascript libraries from external content delivery networks (CDNs).
#'   Use this if the shiny server is slow at serving static resources, but beware of the downsides of
#'   relying on content from a third-party!
#' @param question_context,points_context,exercise_button_context,next_button_context contextual style classes for
#'   question panels, points labels, exercise buttons, and section navigation buttons.
#'   Can be `default` or any of the bootstrap 3 contextual classes listed at
#'   <https://getbootstrap.com/docs/3.3/css/#helper-classes-colors>.
#'   These can also be set on a per-question or per-exercise level by specifying code chunk options
#'   `exam.question_context`, `exam.points_context` and `exercise.button_context`.
#'   A section-specific button context can be set via [section_config()].
#' @param ... passed on to [html_document()][rmarkdown::html_document()]. Parameters `section_divs` and `toc` are not
#'   supported.
#'
#' @importFrom rmarkdown output_format html_document html_dependency_jquery shiny_prerendered_chunk
#' @importFrom htmltools htmlDependency
#' @importFrom stringr str_starts str_sub
#' @importFrom utils packageVersion
#' @importFrom knitr knit_meta knit
#' @importFrom tools file_path_sans_ext
#'
#' @export
exam_document <- function (id = 'exam', version = '0.1', use_cdn = FALSE, render = c('server', 'static'),
                           progressive = FALSE, order = c('random', 'fixed'),
                           max_attempts = Inf, timelimit = Inf, opens = NA, closes = NA, grace_period = 120,
                           next_button_context = 'primary', question_context = 'default',
                           points_context = 'info', exercise_button_context = 'primary', ...) {
  html_document_args <- list(...)
  html_document_args$section_divs <- TRUE
  html_document_args$anchor_sections <- FALSE
  html_document_args$toc <- FALSE

  # Parse attempts configuration
  attempts_config <- set_attempts_config_from_metadata(opens = opens, closes = closes, max_attempts = max_attempts,
                                                       timelimit = timelimit, grace_period = grace_period)

  # Verify exam metadata
  exam_metadata <- list(id = as.character(id)[[1L]],
                        version = as.character(numeric_version(version[[1L]])),
                        render = match.arg(render),
                        progressive = isTRUE(progressive),
                        order = match.arg(order),
                        section_btn_context = next_button_context,
                        section_btn_label = get_status_message('sections')$nextButtonLabel)

  html_document_args$extra_dependencies <- c(html_document_args$extra_dependencies %||% list(), list(
    html_dependency_jquery(),
    html_dependency_ace(use_cdn),
    htmlDependency('exam', packageVersion('examinr'),
                   package = 'examinr', src = 'www',
                   script = 'exam.min.js', stylesheet = 'exam.min.css')))

  out <- output_format(
    pandoc = list(to = 'html5'),
    post_knit = function (metadata, input, runtime, encoding, ...) {
      if (tolower(tools::file_ext(input)) != 'rmd') {
        return(NULL)
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
      knitr::opts_knit$set(examinr.initial_pass = FALSE)
      knitr::knit_hooks$set(exercise = knit_hook_exercise)
      knitr::opts_chunk$set(examinr.exam = TRUE,
                            exam.question_context = question_context,
                            exam.points_context = points_context)
      knitr::opts_hooks$set(examinr.sectionchunk = exam_section_opts_hook)

      # Register the attempts configuration in the server process
      shiny_prerendered_chunk('server-start', sprintf('examinr:::register_attempts_config("%s")',
                                                      serialize_object(attempts_config)))
      # Initialize the exam session
      shiny_prerendered_chunk('server', sprintf('examinr:::initialize_exam_session("%s")',
                                                serialize_object(exam_metadata)))

      knit_env <- new.env(parent = parent.frame())
      knitr::knit(input = new_rmd, output = output, quiet = TRUE, envir = knit_env, encoding = encoding)

      return(NULL)
    },
    # pre_processor = function (...) {
    #   browser()
    # },
    # post_processor = function (metadata, input_file, output_file, clean, verbose, ...) {
    #   if (exam_pass > 1L) {
    #     output_file
    #   } else {
    #     create_exam_md(input_file = rmd_input_file,
    #                    static_chunks = first_pass_stats$static_chunks,
    #                    exam_metadata = exam_metadata,
    #                    section_config_overrides = first_pass_stats$section_config_overrides,
    #                    output_file = output_file, verbose = verbose, clean = clean, metadata = metadata, ...)
    #   }
    # },
    base_format = do.call(html_document, html_document_args),
    knitr = list(opts_chunk = list(examinr.exam = TRUE),
                 opts_knit = list(examinr.initial_pass = TRUE),
                 opts_hooks = list(examinr.exam = opts_hook_exam_format)))

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

  if (!isTRUE(opts_knit$get('rmarkdown.runtime') == 'shiny_prerendered')) {
    abort("examinr exams can only be used with `runtime: shiny_prerendered`.")
  }

  if (is.null(options[['context']]) || isTRUE(options[['context']] == 'render')) {
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

## Initialize a new exam session
initialize_exam_session <- function (exam_metadata) {
  exam_metadata <- unserialize_object(exam_metadata)
  initialize_attempt(exam_id = exam_metadata$id, exam_version = exam_metadata$version)
}
