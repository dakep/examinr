## Handle exercise chunks in the *first* knitr pass
#' @importFrom rlang abort
opts_hook_possible_exercise_initial_pass <- function (options, ...) {
  if (isTRUE(options[['exercise']])) {
    # Mark exercise chunks as static
    options$eval <- FALSE
    options$echo <- TRUE
    options$highlight <- FALSE
    options$comment <- NA

    if (is.null(knit_code$get(options$label))) {
      abort(sprintf("Exercise chunk '%s' is completely empty. Add at least one empty line inside the code chunk.",
                    options$label))
    }
    mark_chunk_static(options$label)

    knit_meta_add(list(structure(options$label, class = 'examinr_question_label')))

    # Collect the support chunks
    support_code <- list(setup = extract_support_code(options$exercise.setup),
                         solution = extract_support_code(options$exercise.solution))

    options$exercise.support_code <- support_code

    if (!is.null(support_code$setup)) {
      mark_chunk_static(options$exercise.setup)
    }
    if (!is.null(support_code$solution)) {
      mark_chunk_static(options$exercise.solution)
    }
  } else {
    # Check if the chunk is a support chunk for any exercise.
    associated_exercises <- if (identical(options$label, options$exercise.setup) ||
                                identical(options$label, options$exercise.solution)) {
      # First check if the chunk is a globally set support chunk
      options$label
    } else {
      # Combining the two expressions into one does not work.
      filter_expr_setup <- substitute(all_labels(isTRUE(exercise) && identical(exercise.setup, label)),
                                      list(label = options$label))
      filter_expr_solution <- substitute(all_labels(isTRUE(exercise) && identical(exercise.solution, label)),
                                         list(label = options$label))
      c(eval(filter_expr_setup), eval(filter_expr_solution))
    }

    if (length(associated_exercises) > 0L) {
      # Don't evaluate or print the code chunk, but we'll leave the user settings for printing
      # untouched.
      options$eval <- FALSE
    }
  }
  return(options)
}

#' @importFrom rlang abort expr
#' @importFrom stringr str_ends fixed str_sub
#' @importFrom knitr all_labels knit_code
#' @importFrom rmarkdown shiny_prerendered_chunk
opts_hook_possible_exercise_second_pass <- function (options, ...) {
  options <- opts_hook_possible_exercise_initial_pass(options)
  if (isTRUE(options[['exercise']]) && isTRUE(options$exercise.autocomplete %||% TRUE)) {
    shiny_prerendered_chunk(context = 'server-start', sprintf('examinr:::prepare_exercise_autocomplete("%s", "%s")',
                                                              options$label,
                                                              serialize_object(options$exercise.support_code)))
    # bind the exercise auto-completion handler, but only once.
    shiny_prerendered_chunk(context = 'server', 'examinr:::bind_exercise_autocomplete()', singleton = TRUE)
  }
  return(options)
}

#' @importFrom knitr all_labels knit_code
#' @importFrom rlang expr
extract_support_code <- function (support_label) {
  if (!is.null(support_label) && nzchar(support_label) && (support_label %in% all_labels())) {
    return(knit_code$get(support_label))
  }
  return(NULL)
}

## Extract options from exercise / exercise support chunks which should be re-established
## when evaluation the user code.
extract_relevant_chunk_options <- function (options) {
  options[names(options) %in% c('results', 'dev.args', 'dpi', 'fig.width', 'fig.height', 'fig.asp', 'fig.dim',
                                'out.width', 'out.height', 'fig.retina', 'engine', 'df_print', 'dev.args')]
}

#' @importFrom rlang abort
#' @importFrom stringr str_remove fixed
#' @importFrom htmltools tagList tags HTML
#' @importFrom shiny NS
#' @importFrom rmarkdown shiny_prerendered_chunk
knit_hook_exercise <- function (before, options, envir, ...) {
  # skip if the chunk is not an exercise or if it's the first pass
  if (!isTRUE(options[['exercise']])) {
    return(NULL)
  }

  if (before) {
    label <- get_chunk_label(options)

    section_ns <- NS(opts_chunk$get('examinr.section_id') %||% random_ui_id('unknown_section'))
    points <- options$exercise.points %||% 1
    points_str <- format_points(points)

    # Use a transparent background for png's by default
    options$dev.args <- c(options$dev.args %||% list(), list(bg = 'transparent'))
    options$df_print <- options$exercise.df_print %||% options$df_print %||% 'default'

    ex_data_srv <- list(label = label,
                        points = points,
                        support_code = options$exercise.support_code,
                        chunk_options = extract_relevant_chunk_options(options),
                        input_id = section_ns(paste('Q', label, sep = '-')),
                        output_id = section_ns(paste(label, 'out', sep = '-')),
                        engine = tolower(options$engine %||% 'r'),
                        timelimit = options$exercise.timeout %||% 5)

    ex_data_js <- list(label = label,
                       inputLabel = options$exercise.label %||% get_status_message('exercise')$label,
                       inputId = ex_data_srv$input_id,
                       outputId = ex_data_srv$output_id,
                       points = points_str,
                       buttonLabel = options$exercise.button %||% get_status_message('exercise')$buttonLabel,
                       title = options$exercise.title %||% get_status_message('exercise')$panelTitle,
                       lines = options$exercise.lines %||% 5,
                       autocomplete = options$exercise.autocomplete %||% TRUE)

    shiny_prerendered_chunk('server', sprintf('examinr:::exercise_chunk_server("%s")', serialize_object(ex_data_srv)))

    exercise_div <- tags$div(class = 'examinr-exercise examinr-question examinr-q-exercise',
                             `data-questionlabel` = label, `data-maxpoints` = points,
                             tags$script(type = 'application/json', HTML(to_json(ex_data_js))))

    return(str_remove(as.character(exercise_div), fixed('</div>')))
  } else {
    return('</div>')
  }
}

