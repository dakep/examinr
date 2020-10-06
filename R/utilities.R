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

random_ui_id <- function (prefix = NULL) {
  if (is.null(prefix)) {
    prefix <- as.hexmode(sample.int(.Machine$integer.max, 1L))
  }
  paste(prefix, as.hexmode(sample.int(.Machine$integer.max, 1L)), sep = '-')
}
