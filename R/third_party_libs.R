ace_cdn_resources <- function () {
  list(base_href = 'https://cdn.jsdelivr.net/npm/ace-builds@1.4.12/src-min-noconflict',
       version = '1.4.12',
       script = list(
         list(src = 'ace.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-/dKd0i2hsDGJ3wt6bxcDYJ2OVlLJ5ESbNfAY6DDtgWzRgapY8kj697G0822znletXHFRKRau/XxlLEWGITPORQ=='),
         list(src = 'ext-language_tools.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-7ImS2lSEfm0F1+W5+GZB2syQZ25HmpjX2wYwaWa8u15F9e2GrHoja313iAPZOYh7ZAIfMHdbNNJi1WnUpeG49Q=='),
         list(src = 'mode-r.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-FrymP32K+iWh0//6Nr117A5xFPlU6P+GQzcQEXHaoo9d37a0W5A0xj9IYz9F7O+ptLpFk0E36PQRUh4JYobEAQ=='),
         list(src = 'theme-textmate.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-LVjh1gAshO/oQ0jxbGHe6IDpn26hMls2DAu5xkvZ9DNT/04SkaiwWE8a/1G0o0cbanKqc0ZW2xI9qYedIXy0YA==')))
}

#' @importFrom htmltools htmlDependency
html_dependency_ace <- function (use_cdn) {
  res <- ace_cdn_resources()

  if (isTRUE(use_cdn)) {
    htmlDependency('ace', version = res$version, src = c(href = res$base_href), script = res$script)
  } else {
    htmlDependency('ace', version = res$version, src = system.file('lib', package = 'examinr', mustWork = TRUE),
                   script = sprintf('ace-%s.js', res$version))
  }
}

