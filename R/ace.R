
ace_cdn_resources <- function () {
  list(base_href = 'https://cdnjs.cloudflare.com/ajax/libs/ace',
       version = '1.4.12',
       scripts = list(
         list(src = 'ace.min.js',
              integrity = 'sha512-GoORoNnxst42zE3rYPj4bNBm0Q6ZRXKNH2D9nEmNvVF/z24ywVnijAWVi/09iBiVDQVf3UlZHpzhAJIdd9BXqw=='),
         list(src = 'ext-language_tools.min.js',
              integrity = 'sha512-8qx1DL/2Wsrrij2TWX5UzvEaYOFVndR7BogdpOyF4ocMfnfkw28qt8ULkXD9Tef0bLvh3TpnSAljDC7uyniEuQ=='),
         list(src = 'mode-r.min.js',
              integrity = 'sha512-Ywj4QTNVz4uBn0XqobDKK5pgwN5/bK1/RBAUxDq+2luI+mvA6pteiuuWXZZ4i6UQUnUMwa/UD+9MqOr2hn9H9g=='),
         list(src = 'theme-textmate.min.js',
              integrity = 'sha512-EfT0yrRqRKdVeJXcphL/4lzFc33WZJv6xAe34FMpICOAMJQmlfsTn/Bt/+eUarjewh1UMJQcdoFulncymeLUgw==')))
}

#' @importFrom htmltools htmlDependency
html_dependency_ace <- function (use_cdn) {
  res <- ace_cdn_resources()

  if (isTRUE(use_cdn)) {
    script_tags <- vapply(res$scripts, FUN.VALUE = character(1L), function (script) {
      sprintf('<script src="%s/%s/%s" integrity="%s" crossorigin="anonymous"></script>',
              res$base_href, res$version, script$src, script$integrity)
    })

    htmlDependency('ace', res$version, c(href = paste(res$base_href, res$version, sep = '/')),
                   head = paste(script_tags, collapse = ''))
  } else {
    htmlDependency('ace', res$version, package = 'examinr', src = 'lib', script = sprintf('ace-%s.js', res$version))
  }
}

