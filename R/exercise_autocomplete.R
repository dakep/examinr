#' @include state_frame.R
.autocompletion_envirs <- state_frame()

#' @importFrom withr local_dir local_tempdir
prepare_exercise_autocomplete <- function (exercise_label, support_code) {
  # Reproduce all code before the user code
  support_code <- unserialize_object(support_code)
  # 1. Generate the exercise data
  exercise_env <- get_exercise_user_env(exercise_label, attempt = NULL, session = NULL)
  parent.env(exercise_env) <- globalenv()

  # 2. Run the setup code (if necessary)
  if (!is.null(support_code$setup)) {
    # The setup code is run in it's own directory to ensure auto-completion has access
    # to file names.
    sandbox_wd <- 'examinr_autocompletion_sandbox'
    if (!dir.exists(sandbox_wd)) {
      if (!isTRUE(dir.create(sandbox_wd, mode = '0700'))) {
        # Cannot create the directory. Use a temporary directory instead.
        sandbox_wd <- local_tempdir('wd')
      }
    }
    local_dir(sandbox_wd)
    # Run the setup code
    eval(parse(text = support_code$setup), exercise_env)
  }

  # The environment is now built up. Preserve only the names.
  skeleton <- list(extract_env_skeleton(exercise_env))
  names(skeleton) <- exercise_label
  .autocompletion_envirs$set(skeleton)
}

#' @importFrom rlang enexpr
#' @importFrom withr defer local_dir
with_searchpath_and_dir <- function (envir, dir, expr) {
  name <- format(envir)
  attach(envir, name = name, warn.conflicts = FALSE)
  defer(detach(name, character.only = TRUE))
  if (dir.exists(dir)) {
    local_dir(dir)
  }
  eval.parent(enexpr(expr))
}

#' @importFrom shiny observeEvent
#' @importFrom rlang warn
#' @importFrom stringr str_split fixed str_sub
bind_exercise_autocomplete <- function () {
  moduleServer('__.examinr.__', function (input, output, session) {
    observeEvent(input$autocomplete, ignoreNULL = TRUE, {
      payload <- input$autocomplete
      envir <- list2env(.autocompletion_envirs$get(payload$label), parent = emptyenv())
      completions <- if (is.null(envir)) {
        # No auto-completion environment available. Return an empty selection
        list()
      } else {
        tryCatch({
          utils <- asNamespace('utils')
          utils$.assignLinebuffer(payload$code)
          utils$.assignEnd(nchar(payload$code))
          utils$.guessTokenFromLine()

          with_searchpath_and_dir(envir, 'examinr_autocompletion_sandbox', {
            utils$.completeToken()
            # Split the completions at the ns token. We don't care if it's an exported or unexported object,
            # as the namespace will be stripped (unless the element on the right is empty)
            completions <- str_split(as.character(utils$.retrieveCompletions()), ':{2,3}', n = 2L)

            lapply(completions, function (symbol_ns) {
              ns <- globalenv()
              ns_name <- ''
              symbol <- symbol_ns[[1L]]
              if (length(symbol_ns) == 1L) {
                ns_name <- tryCatch(getNamespaceName(environment(get(symbol)))[[1L]], error = function (e) '')
              } else {
                ns <- asNamespace(symbol_ns[[1L]])
                symbol <- if (nzchar(symbol_ns[[2L]])) {
                  ns_name <- symbol_ns[[1L]]
                  symbol_ns[[2L]]
                } else {
                  paste(symbol, '::', sep = '')
                }
              }
              is_fun <- nzchar(symbol) && exists(symbol, envir = ns, mode = 'function')
              list(ns_name, symbol, is_fun)
            })
          })
        }, error = function (e) {
          warn(sprintf("Cannot build auto-completion suggestions: %s", as.character(e)),
               class = 'autocompletion', .frequency = 'once', .frequency_id = 'autocompletion-failed')
          list()
        })
      }

      if (length(completions) > 0L) {
        send_message('autocomplete', completions, session)
      }
    })
  })
}

extract_env_skeleton <- function (env) {
  dummy_fun <- function() {}
  environment(dummy_fun) <- emptyenv()

  symbols <- if (is.environment(env)) {
    ls(env)
  } else {
    names(env)
  }

  skeleton <- lapply(symbols, function (s) {
    if (!is.null(names(env[[s]]))) {
      return(extract_env_skeleton(env[[s]]))
    } else if (is.function(env[[s]])) {
      return(dummy_fun)
    }
    return(NA)
  })

  names(skeleton) <- symbols
  return(skeleton)
}
