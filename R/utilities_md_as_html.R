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
## @param id_prefix prefix for IDs generated in the HTML fragment. If
##   missing a random string of the form "fragment-%s" is used.
## @return a HTML container with the parsed markdown.
#' @importFrom rmarkdown render output_format html_fragment
#' @importFrom commonmark markdown_html
#' @importFrom stringr str_trim str_remove str_detect str_replace_all regex str_sub
#' @importFrom rlang parse_expr
md_as_html <- function (text, use_rmarkdown = 'auto', env = parent.frame(), mathjax_dollar = TRUE,
                        id_prefix) {
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

      if (missing(id_prefix)) {
        id_prefix <- random_ui_id('fragment')
      }

      fragment_format <- output_format(pandoc = list(to = 'html5',
                                                     args = c('--metadata', 'pagetitle="Fragment"',
                                                              '--highlight-style', 'tango',
                                                              '--id-prefix', id_prefix)),
                                       knitr = NULL, base_format = html_fragment())

      rendered_file <- render(mdfile, output_format = fragment_format, envir = env %||% parent.frame(), quiet = TRUE)
      str_trim(paste(enc2utf8(readLines(rendered_file, encoding = 'UTF-8')), collapse = '\n'))
    } else {
      # First evaluate any inline r code
      if (str_detect(text, fixed('`r '))) {
        text <- str_replace_all(text, regex('`r .+?`', dotall = TRUE), function (rcode) {
          rcode <- str_sub(rcode, 3, -2)
          tryCatch({
            exp <- parse_expr(rcode)
            res <- eval(exp, envir = env)
            paste(format_inline_results(res), collapse = ', ')
          }, error = function (e) {
            sprintf('<strong style="color:red;">%s</strong>', as.character(e))
          })
        })
      }
      if (isTRUE(mathjax_dollar)) {
        # Manually replace $ and $$ with mathjax's "\(\)" and "\[ \]".
        # Note: commonmark swallows one level of escape characters (\)
        text <- str_replace_all(text, regex('([^\\\\\\$]?)\\$\\$(.+?)\\$\\$', dotall = TRUE),
                                '\\1<span class="math display">\\\\\\\\[\\2\\\\\\\\]</span>')
        text <- str_replace_all(text, regex('([^\\\\\\$]?)\\$(.+?)\\$', dotall = TRUE),
                                '\\1<span class="math inline">\\\\\\\\(\\2\\\\\\\\)</span>')
      }

      # Render markdown to HTML
      enc2utf8(markdown_html(text, smart = TRUE, extensions = TRUE))
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
