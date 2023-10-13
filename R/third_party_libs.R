ace_cdn_resources <- function () {
  list(base_href = 'https://cdn.jsdelivr.net/npm/ace-builds@1.29.0/src-min-noconflict/',
       version = '1.29.0',
       script = list(
         list(src = 'ace.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-cxrfBHbaLPI3lVC1iw+ME3/QRho4EOCqZ2VsI5V5qUhgU2iyChWbZhEs5cBlo/STqYZK/TV5NyhLaJj+9EGwbg=='),
         list(src = 'ext-language_tools.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-WMIrRhl85As2c7/zoDfLnxA9Uc9789+2E62sOmJ0Mv6zazEOdSLOFnbBfxEm5uTD8Nnge3lFO3PVj+DPv1Nivw=='),
         list(src = 'mode-r.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-FrymP32K+iWh0//6Nr117A5xFPlU6P+GQzcQEXHaoo9d37a0W5A0xj9IYz9F7O+ptLpFk0E36PQRUh4JYobEAQ=='),
         list(src = 'theme-textmate.js',
              crossorigin = "anonymous",
              `data-external` = 1,
              integrity = 'sha512-AGNKkjH7RPAeiMO+odFbruySZShoIEdxRieeMZHfhsfrspxhdmQe0rgSYhqI8RNVhK4Xr6MtdBvedIwt87lcPg==')))
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

