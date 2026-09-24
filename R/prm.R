#' TreeScan parameter files
#'
#' A parameter file (`.prm`) is stored as its raw lines (comments included)
#' with class `ts_prm`. Values are set by key name, without needing to know
#' the `[Section]` they belong to.
#'
#' @param path Path to a `.prm` file.
#' @param prm A `ts_prm` object.
#' @param ... Named values to set, e.g. `"monte-carlo-replications" = 999`.
#' Dates are formatted as `yyyy/mm/dd`, logicals as `y`/`n`.
#' @return `ts_prm_read()`, `ts_prm_template()`, and `ts_prm_set()` return a
#' `ts_prm` object. `ts_prm_get()` returns a character value.
#' `ts_prm_write()` returns `path` invisibly.
#' @name ts_prm
#' @examples
#' prm <- ts_prm_template() |>
#'   ts_prm_set("monte-carlo-replications" = 999)
#' ts_prm_get(prm, "monte-carlo-replications")
#' ts_prm_write(prm, tempfile(fileext = ".prm"))
NULL

#' @rdname ts_prm
#' @export
ts_prm_read <- function(path) {
  structure(readLines(path, warn = FALSE), class = "ts_prm")
}

#' @rdname ts_prm
#' @details `ts_prm_template()` returns the template bundled with the package
#' (TreeScan v2.4.1, tree-temporal Poisson scan, 9,999 replications).
#' @export
ts_prm_template <- function() {
  ts_prm_read(system.file("extdata", "Parameter_File_template.prm",
                          package = "treescanr"))
}

#' @rdname ts_prm
#' @export
ts_prm_set <- function(prm, ...) {
  values <- list(...)
  if (length(values) && (is.null(names(values)) || any(!nzchar(names(values)))))
    stop("All values passed to `ts_prm_set()` must be named.", call. = FALSE)

  for (key in names(values)) {
    pattern <- paste0("^", key, "=")
    idx <- grep(pattern, prm)
    if (!length(idx))
      stop("Unknown TreeScan parameter: '", key, "'.", call. = FALSE)
    prm[idx] <- paste0(key, "=", .prm_value(values[[key]]))
  }

  prm
}

#' @rdname ts_prm
#' @param key Parameter name.
#' @export
ts_prm_get <- function(prm, key) {
  line <- grep(paste0("^", key, "="), prm, value = TRUE)
  if (!length(line))
    stop("Unknown TreeScan parameter: '", key, "'.", call. = FALSE)
  sub("^[^=]*=", "", line[1L])
}

#' @rdname ts_prm
#' @export
ts_prm_write <- function(prm, path) {
  writeLines(unclass(prm), path)
  invisible(path)
}

#' @export
print.ts_prm <- function(x, ...) {
  x <- unclass(x)
  cat(x[!grepl("^\\s*;", x) & nzchar(trimws(x))], sep = "\n")
  invisible(x)
}

.prm_value <- function(x) {
  if (inherits(x, "Date"))
    return(format(x, "%Y/%m/%d"))
  if (is.logical(x))
    return(ifelse(x, "y", "n"))
  paste(x, collapse = ",")
}

.prm_range <- function(from, to) {
  paste0("[", .prm_value(as.Date(from)), ",", .prm_value(as.Date(to)), "]")
}

# TreeScan wants forward slashes; keep leading "//" for UNC paths
.prm_path <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (grepl("^//", path)) sub("^/+", "//", path) else path
}
