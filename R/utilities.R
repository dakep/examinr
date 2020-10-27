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

    if (isTRUE(use_rmarkdown == 'auto')) {
      use_rmarkdown <- str_detect(text, fixed('```{'))
    }

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
        markdown_html(text, smart = TRUE, extensions = TRUE)
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
    if (!(class(x)[[1L]] == 'numeric') || is.na(x) || x == 0) {
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

  if (is.null(label) || str_starts(label, fixed(default_label))) {
    if (required) {
      abort("Exercise and question chunks must have a label.")
    } else {
      warn("Exercise and question chunks must have a label.")
    }
  }
  return(label)
}

#' @importFrom htmltools tagList HTML tags
trigger_mathjax <- function(...) {
  tagList(..., htmltools::tags$script(
    HTML('if(typeof MathJax !== "undefined") { MathJax && MathJax.Hub.Queue(["Typeset", MathJax.Hub]) }')))
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
get_session_env <- function (session) {
  if (missing(session)) {
    session <- getDefaultReactiveDomain()
  }
  if (!exists('__.examinr_session_env.__', envir = session$userData, mode = 'environment', inherits = FALSE)) {
    assign('__.examinr_session_env.__', new.env(parent = emptyenv()), envir = session$userData)
  }
  get('__.examinr_session_env.__', envir = session$userData, mode = 'environment', inherits = FALSE)
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
