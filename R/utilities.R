## Serialize an R object into a base64 encoded string
#' @importFrom base64enc base64encode
serialize_object <- function (x) {
  base64encode(serialize(x, connection = NULL, xdr = FALSE))
}

## Un-serialize an object encoded by `serialized_object`
#' @importFrom base64enc base64decode
unserialize_object <- function (x) {
  unserialize(base64decode(x))
}

## Render markdown text as HTML
##
## If only a single line of HTML is rendered, the surrounding block element is stripped.
##
## @param text the markdown text to be parsed as HTML
## @param use_rmarkdown treat the markdown as R markdown and evaluate R code chunks. If 'auto', rmarkdown is used
##   only if the markdown text contains code chunks starting with "```{".
##   If `FALSE` use the much faster commonmark package for rendering.
## @param env if use_rmarkdown is TRUE, environment in which the markdown is rendered (parameter
##   `rmarkdown::render(envir=)`).
## @param mathjax_dollar translate "$" and "$$" blocks into mathjax's "\\(" and "\\[".
## @return a HTML container with the parsed markdown.
#' @importFrom rmarkdown render output_format html_fragment
#' @importFrom commonmark markdown_html
#' @importFrom stringr str_trim str_remove str_detect str_replace_all regex str_sub
#' @importFrom rlang parse_expr
#' @importFrom xml2 read_xml xml_text
render_markdown_as_html <- function (text, use_rmarkdown = 'auto', env = parent.frame(), mathjax_dollar = TRUE) {
  if (string_is_html(text)) {
    return(text)
  }

  if (!is.null(text) && length(text) > 0L) {
    if (length(text) > 1L) {
      text <- paste(text, collapse = '\n')
    }

    if (identical(use_rmarkdown, 'auto')) {
      use_rmarkdown <- str_detect(text, fixed('```{'))
    }

    text <- enc2utf8(text)

    html_string <- if (isTRUE(use_rmarkdown)) {
      tmpfolder <- tempfile('rendermd')
      dir.create(tmpfolder, mode = '0700')
      on.exit(unlink(tmpfolder, force = TRUE, recursive = TRUE), add = TRUE, after = FALSE)

      mdfile <- file.path(tmpfolder, 'file.Rmd')
      writeLines(text, mdfile)

      fragment_format <- output_format(pandoc = list(to = 'html5', args = c('--metadata', 'pagetitle="Fragment"')),
                                       knitr = NULL, base_format = html_fragment())

      rendered_file <- render(mdfile, output_format = fragment_format, envir = env %||% parent.frame(), quiet = TRUE)
      str_trim(paste(enc2utf8(readLines(rendered_file, encoding = 'UTF-8')), collapse = '\n'))
    } else {
      if (isTRUE(mathjax_dollar)) {
        # Manually replace $ and $$ with mathjax's "\(\)" and "\[ \]".
        # Note: commonmark swallows one level of escape characters (\)
        text <- str_replace_all(text, regex('([^\\\\\\$]?)\\$\\$(.+?)\\$\\$', dotall = TRUE),
                                '\\1<span class="math display">\\\\\\\\[\\2\\\\\\\\]</span>')
        text <- str_replace_all(text, regex('([^\\\\\\$]?)\\$(.+?)\\$', dotall = TRUE),
                                '\\1<span class="math inline">\\\\\\\\(\\2\\\\\\\\)</span>')
      }
      if (str_detect(text, fixed('`r '))) {
        # Markdown contains inline r code.
        unevaled_html <- markdown_html(text, smart = TRUE, extensions = TRUE)

        str_replace_all(unevaled_html, regex('<code>r .+?</code>', dotall = TRUE), function (rcode) {
          # strip "<code>r" and "</code>"
          rcode <- str_sub(xml_text(read_xml(rcode)), 2)
          tryCatch({
            exp <- parse_expr(rcode)
            res <- eval(exp, envir = env)
            paste(format_inline_results(res), collapse = ', ')
          }, error = function (e) {
            sprintf('<strong style="color:red;">%s</strong>', as.character(e))
          })
        })
      } else {
        enc2utf8(markdown_html(text, smart = TRUE, extensions = TRUE))
      }
    }
    if (str_detect(html_string, '^\\s*<p>.*</p>\\s*$')) {
      html_string <- str_remove(str_remove(html_string, '^\\s*<p>'), '</p>\\s*$')
    }
    return(HTML(html_string))
  }

  return(NULL)
}

#' @importFrom stringr str_replace
format_inline_results <- function (results) {
  vapply(results, FUN.VALUE = character(1L), USE.NAMES = FALSE, function (x) {
    if (!identical(class(x), 'numeric') || is.na(x) || x == 0) {
      return(as.character(x))
    }
    if (is.infinite(x)) {
      return(sprintf('%s&infin;', ifelse(x < 0, '&minus;', '')))
    }
    lx <- floor(log10(abs(x)))
    if (abs(lx) < getOption('scipen') + 4L) {
      return(as.character(round(x, getOption('digits'))))
    }
    b <- as.character(round(x / 10^lx, getOption('digits')))
    b[b %in% c('1', '-1')] <- ''
    sprintf('%s%s10<sup>%s</sup>', str_replace(b, fixed('-'), '&minus;'), ifelse(b == '', '', ' &times; '), lx)
  })
}

string_is_html <- function (text) {
  return(inherits(text, 'html') || inherits(text, "shiny.tag") || inherits(text, "shiny.tag.list"))
}

## Choose the first argument which is not missing and not NULL
#' @importFrom rlang is_missing
`%||%` <- function (x, y) {
  if (is_missing(x) || is.null(x)) {
    return(y)
  }
  return(x)
}
## Choose the first argument which is not missing, not NULL, and not NA
#' @importFrom rlang is_missing
`%|NA|%` <- function (x, y) {
  if (is_missing(x) || is.null(x) || anyNA(x)) {
    return(y)
  }
  return(x)
}

#' @importFrom rlang is_missing
choose_one <- function (left, right, prefer_left = TRUE) {
  if (prefer_left) {
    return(left %||% right)
  } else {
    return(right %||% left)
  }
}

#' @importFrom rlang is_missing missing_arg
null_as_missing <- function (arg) {
  if (is_missing(arg) || is.null(arg)) {
    return(missing_arg())
  }
  return(arg)
}

## Generate a random UI id
random_ui_id <- function (prefix = NULL) {
  if (is.null(prefix)) {
    prefix <- as.hexmode(sample.int(.Machine$integer.max, 1L))
  }
  paste(prefix, as.hexmode(sample.int(.Machine$integer.max, 1L)), sep = '-')
}

#' @importFrom rlang abort warn
#' @importFrom knitr opts_knit opts_current
#' @importFrom stringr str_starts fixed
get_chunk_label <- function (options, required = TRUE) {
  default_label <- opts_knit$get('unnamed.chunk.label') %||% ''

  label <- if (missing(options)) {
    opts_current$get('label')
  } else {
    options$label
  }

  if (required && (is.null(label) || str_starts(label, fixed(default_label)))) {
    abort("Exercise and question chunks must have a label.")
  }
  return(label)
}

#' @importFrom htmltools tagList HTML tags tagAppendAttributes tagHasAttribute tagGetAttribute
trigger_mathjax <- function(tag, ...) {
  if (nargs() == 1L && is.list(tag)) {
    is_dummy <- 'false'
    id <- tagGetAttribute(tag, 'id')
    if (is.null(id)) {
      id <- random_ui_id('mathjax-triggered')
      tag <- tagAppendAttributes(tag, id = id)
    } else {
    }
  } else {
    id <- random_ui_id('mathjax-triggered')
    is_dummy <- 'true'
    tag <- div(tag, ..., id = id)
  }

  tagList(tag, tags$script(HTML(sprintf('if(window.Exam) { window.Exam.utils.triggerMathJax("%s", %s) }',
                                        id, is_dummy))))
}

## Like base::pmatch, but returns NULL if the given value is NULL
pmatch_null <- function (value, choices) {
  match <- pmatch(value[[1L]], choices, nomatch = 1L)
  if (length(match) == 0L) {
    return(NULL)
  }
  choices[[match]]
}

#' @importFrom shiny getDefaultReactiveDomain
#' @importFrom rlang is_missing
get_session_env <- function (session) {
  if (is_missing(session)) {
    session <- getDefaultReactiveDomain()
  }
  if (!exists('__.examinr_session_env.__', envir = session$userData, mode = 'environment', inherits = FALSE)) {
    assign('__.examinr_session_env.__', new.env(parent = emptyenv()), envir = session$userData)
  }
  get('__.examinr_session_env.__', envir = session$userData, mode = 'environment', inherits = FALSE)
}

#' @importFrom shiny getDefaultReactiveDomain
register_transformer <- function (input_id, fun, envir = TRUE, session = getDefaultReactiveDomain()) {
  session_env <- get_session_env(session)
  if (!is.null(envir)) {
    if (isTRUE(envir)) {
      # Use the examinr namespace as environment for the auto-grader
      envir <- parent.env(environment())
    }
    environment(fun) <- envir
  }

  if (is.null(session_env$transformer)) {
    session_env$transformer <- list()
  }
  session_env$transformer[[input_id]] <- fun
}

## Template for question feedback
new_question_feedback <- function (max_points, points = NA_real_, comment = NULL, solution = NULL, answer = NULL) {
  list(max_points = max_points, points = points, comment = comment, solution = solution, answer = answer)
}

## Register a function to evaluate user answers
#' @importFrom shiny getDefaultReactiveDomain
register_autograder <- function (input_id, fun, envir = TRUE, session = getDefaultReactiveDomain()) {
  session_env <- get_session_env(session)
  if (!is.null(envir)) {
    if (isTRUE(envir)) {
      # Use the examinr namespace as environment for the auto-grader
      envir <- parent.env(environment())
    }
    environment(fun) <- envir
  }
  if (is.null(session_env$autograders)) {
    session_env$autograders <- list()
  }
  session_env$autograders[[input_id]] <- fun
}

## Register a simple autograder returning the feedback template
register_static_autograder <- function (input_id, max_points, ..., session) {
  # let R CMD check know that `feedback` is available
  feedback <- new_question_feedback(max_points, ...)
  ag_env <- new.env(parent = getNamespace('examinr'))
  ag_env$feedback <- feedback
  register_autograder(input_id, function (...) { return(feedback) }, envir = ag_env, session = session)
}

#' @importFrom jsonlite toJSON
to_json <- function (object) {
  toJSON(object, force = TRUE, auto_unbox = TRUE, digits = NA, null = 'null')
}

## Add a prefix (if it is not yet present)
#' @importFrom stringr str_detect fixed
add_prefix <- function (prefix, text) {
  need_prefix <- which(!str_starts(text, fixed(prefix)))
  if (length(need_prefix) > 0L) {
    text[need_prefix] <- paste(prefix, text[need_prefix], sep = '')
  }
  return(text)
}

#' @importFrom shiny getDefaultReactiveDomain
global_shiny_session <- function (session = getDefaultReactiveDomain()) {
  if (inherits(session, 'session_proxy')) {
    session <- .subset2(session, 'parent')
    global_shiny_session(session)
  }
  return(session)
}

#' @importFrom shiny getDefaultReactiveDomain
send_message <- function(type, message, session) {
  if (is_missing(session)) {
    session <- getDefaultReactiveDomain()
  }
  session$sendCustomMessage(paste('__.examinr.__', type, sep = '-'), message)
}

#' @importFrom shiny observe
send_status_message <- function (msg_id, type = c('error', 'locked', 'warning', 'info'),
                                 action = c('close', 'trigger', 'reload', 'none'), session, message,
                                 trigger_id = NULL, trigger_event = NULL, trigger_delay = NULL) {
  msg_obj <- list(
    type = match.arg(type),
    content = message %||% get_status_message(msg_id),
    action = match.arg(action),
    triggerId = trigger_id,
    triggerDelay = trigger_delay * 1000,
    triggerEvent = trigger_event
  )
  observe(send_message('statusMessage', msg_obj, session))
}

## Check if the current chunk is in the given context.
## If knitr is not in progress, always returns `TRUE`.
is_knitr_context <- function (context) {
  return (!isTRUE(getOption('knitr.in.progress')) || identical(opts_current$get('context'), context) ||
            identical(opts_current$get('label'), context))
}

## Normalize a string for use as HTML identifier
##  - strip any header attributes (the trailing "{...}") and leading/trailing white-space
##  - replace any sequence of non-alphanumeric character with a single instance of `replace`
##  - make lower-case
#' @importFrom stringi stri_trim_both
#' @importFrom stringr str_detect str_starts fixed str_match str_replace_all
normalize_string <- function (str, replace = '-') {
  has_identifiers <- which(str_detect(str, '\\s*\\{.*\\}\\s*$'))
  if (length(has_identifiers) > 0L) {
    str[has_identifiers] <- str_match(str[has_identifiers], '^#?\\s*(.+)\\s*\\{.*\\}\\s*$')[, 2]
  }
  stri_trim_both(str_replace_all(tolower(str), '[^\\p{Alphabetic}\\p{Decimal_Number}]+', replace),
                 pattern = '[^\\p{Wspace}\\-#]')
}

#' @importFrom stringr str_match
#' @importFrom rlang abort
parse_datetime <- function (datetime) {
  if (is_missing(datetime) || is.null(datetime)) {
    return(NULL)
  } else if (all(is.na(datetime))) {
    return(NA)
  }

  date <- str_match(datetime, '^([0-9\\: \\-]+)(?: +(\\P{Decimal_Number}.+))?$')

  if (is.na(date[[1L]]) || is.na(date[[2L]])) {
    abort(paste("Format of date-time is invalid:", datetime))
  }

  tz_str <- if (!is.na(date[[3L]])) { date[[3L]] } else { '' }
  withCallingHandlers({
    parsed <- strptime(date[[2L]], format = '%Y-%m-%d %H:%M', tz = tz_str)
    if (is.na(parsed)) {
      abort("Invalid date-time string")
    }
    return(parsed)
  }, warning = function (w) {
    abort(paste("Format of date-time is invalid:", datetime), parent = w)
  }, error = function (e) {
    abort(paste("Format of date-time is invalid:", datetime), parent = e)
  })
}
