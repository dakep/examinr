## Create a new Rmd file with sections
#' @importFrom rmarkdown render
#' @importFrom knitr knit_meta
#' @importFrom rlang abort inform
#' @importFrom stringi stri_trim_both
#' @importFrom stringr str_detect str_starts fixed str_match str_sub str_replace_all str_remove regex
#' @importFrom tools file_path_sans_ext
create_exam_rmd <- function (input_rmd, static_chunks, exam_metadata, section_config_overrides, attempts_config,
                             encoding, ...) {
  new_rmd <- tempfile(pattern = file_path_sans_ext(basename(input_rmd)), tmpdir = dirname(input_rmd), fileext = '.Rmd')

  out_con <- file(new_rmd, open = 'wt', encoding = encoding)
  on.exit(close(out_con), add = TRUE, after = FALSE)

  in_con <- file(input_rmd, open = 'rt', encoding = encoding)
  on.exit(close(in_con), add = TRUE, after = FALSE)

  exam_metadata_serialized <- serialize_object(exam_metadata)

  # Does the R chunk need to be extracted and put into the section chunk?
  move_rchunk_into_section <- function (line, static_chunks) {
    label <- str_match(line, '```\\{r\\s+([^,\\}\\s]+)')[[2L]]
    # Check if the chunk label
    if (!is.na(label) && isTRUE(label %in% static_chunks)) {
      return(FALSE)
    }
    # Check if the chunk has any of the options
    return(!any(str_detect(line, c('r\\s+setup,', 'context\\s*=\\s*[\'"]server(?:\\-start)?[\'"]',
                                   'exam\\.exercise\\s*=\\s*T(?:RUE)?',
                                   'exam\\.static\\s*=\\s*T(?:RUE)?'))))
  }

  # Write a section chunk
  write_section_chunk <- function (content, section_id, chunk_counter) {
    if (length(content) > 0L) {
      content <- unlist(content, recursive = FALSE, use.names = FALSE)

      # If the section content is to be rendered on the client, or if it's only empty lines,
      # output content as-is
      if (!isTRUE(exam_metadata$render == 'server') || all(!nzchar(content))) {
        writeLines(content, out_con)
      } else {
        content_enc <- serialize_object(content)
        writeLines(c('```{r, examinr.sectionchunk=TRUE}',
                     sprintf('examinr:::section_chunk("%s", "%s", %d)', section_id, content_enc, chunk_counter),
                     '```'), con = out_con)
      }
    }
  }

  write_section_start <- function (section_id) {
    writeLines(c('```{r, examinr.sectionchunk=TRUE}',
                 sprintf('examinr:::section_start("%s")', section_id),
                 '```\n'), con = out_con)
  }

  write_section_end <- function (section_name, section_id) {
    btn_label <- section_config_overrides[[section_name]]$btn_label %||% exam_metadata$section_btn_label

    if (!is.na(btn_label)) {
      btn_label <- paste('"', btn_label, '"', sep =  '')
    }

    writeLines(c('\n```{r, examinr.sectionchunk=TRUE}',
                 sprintf('examinr:::section_end("%s", "%s", "%s", %s)',
                         section_name, section_id, exam_metadata_serialized, btn_label),
                 '```\n'), con = out_con)
  }

  ## Write the exam initialization which requires the section
  write_init_exam <- function () {
    writeLines(c('```{r, examinr.sectionchunk=TRUE}',
                 sprintf('examinr:::initialize_exam("%s", "%s", "%s")',
                         exam_metadata_serialized, serialize_object(attempts_config),
                         serialize_object(section_config_overrides)),
                 '```'), con = out_con)
  }

  input_lines <- enc2utf8(readLines(in_con, warn = FALSE))

  inside_section <- FALSE
  inside_fixed_section <- FALSE
  current_section_name <- ''
  current_section_id <- ''
  section_chunk_counter <- 1L
  inside_code_chunk <- FALSE
  run_chunk_server <- FALSE
  section_content <- vector('list')

  fixed_sections <- unlist(lapply(section_config_overrides, function (x) {
    if (isTRUE(x$fixed)) {
      return(x$section)
    }
    return(NULL)
  }))

  for (line in input_lines) {
    if (inside_code_chunk) {
      ## Inside a code chunk
      if (run_chunk_server) {
        section_content <- c(section_content, line)
      } else {
        writeLines(line, out_con)
      }
      if (identical(line, '```')) {
        run_chunk_server <- FALSE
        inside_code_chunk <- FALSE
      }
    } else if (str_starts(line, fixed('# '))) {
      ## A new section starts
      if (inside_section) {
        # a new section starts. output previous section.
        write_section_chunk(section_content, current_section_id, section_chunk_counter)
        section_chunk_counter <- section_chunk_counter + 1L
        section_content <- vector('list')
      }
      if (inside_section || inside_fixed_section) {
        write_section_end(current_section_name, current_section_id)
      }

      inside_section <- TRUE
      inside_fixed_section <- FALSE
      current_section_name <- normalize_string(line)
      current_section_id <- paste(normalize_string(exam_metadata$id), normalize_string(exam_metadata$version),
                                  current_section_name, sep = '-')
      section_chunk_counter <- 1L

      # capture a new section, unless the next section is a "fixed" section
      if (isTRUE(current_section_name %in% fixed_sections)) {
        inside_fixed_section <- TRUE
        inside_section <- FALSE
      }

      writeLines('\n', out_con)
      writeLines(line, out_con)
      writeLines('\n', out_con)
      write_section_start(current_section_id)

    } else if (str_starts(line, fixed('```{'))) {
      ## A code chunk begins
      inside_code_chunk <- TRUE
      run_chunk_server <- FALSE

      if (inside_section) {
        # Check if the chunk is to be run on the server
        run_chunk_server <- move_rchunk_into_section(line, static_chunks)
        if (run_chunk_server) {
          section_content <- c(section_content, line)
        } else {
          write_section_chunk(section_content, current_section_id, section_chunk_counter)
          section_chunk_counter <- section_chunk_counter + 1L
          section_content <- vector('list')

          writeLines(line, out_con)
        }
      } else {
        writeLines(line, out_con)
      }
    } else if (inside_section) {
      ## Inside a section
      section_content <- c(section_content, line)
    } else {
      ## Neither inside a section, nor a code chunk.
      writeLines(line, out_con)
    }
  }

  if (inside_section) {
    write_section_chunk(section_content, current_section_id, section_chunk_counter)
  }
  if (inside_fixed_section || inside_section) {
    write_section_end(current_section_name, current_section_id)
  }

  write_init_exam()

  return(new_rmd)
}
