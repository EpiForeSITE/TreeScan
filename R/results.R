#' Read TreeScan results
#'
#' Reads the CSV results written by TreeScan, e.g., from a previous
#' [ts_run()] stored in a persistent directory.
#'
#' @param path A directory created by [ts_run()] or a TreeScan results `.csv`.
#' @return A `ts_result` object: a list with `results` (a `data.frame`, one row
#' per cut, as written by TreeScan), `dir`, `files`, and `prm` (the
#' parameter file used, if found).
#' @export
#' @examples
#' \dontrun{
#' dir <- tools::R_user_dir("treescanr", "data")
#' ts_results(file.path(dir, "2026-09-23", "lag1"))
#' }
ts_results <- function(path) {
  if (dir.exists(path)) {
    dir <- path
    csv <- file.path(dir, "results.csv")
  } else {
    dir <- dirname(path)
    csv <- path
  }
  if (!file.exists(csv))
    stop("TreeScan results not found: ", csv, call. = FALSE)

  prm_file <- file.path(dir, "parameters.prm")
  structure(
    list(
      results = utils::read.csv(csv, check.names = TRUE),
      dir = normalizePath(dir, winslash = "/"),
      files = list.files(dir, full.names = TRUE),
      prm = if (file.exists(prm_file)) ts_prm_read(prm_file)
    ),
    class = "ts_result"
  )
}

#' @export
print.ts_result <- function(x, n = 10L, ...) {
  res <- x$results
  cat("TreeScan results:", nrow(res), "cuts\n")
  cat("Directory:", x$dir, "\n")
  if (nrow(res)) {
    if ("P.value" %in% names(res))
      res <- res[order(res$P.value), , drop = FALSE]
    cols <- intersect(c("Node.Identifier", "Time.Window.Start", "Time.Window.End",
                        "Cases.in.Window", "Expected.Cases", "P.value",
                        "Recurrence.Interval"), names(res))
    if (length(cols)) res <- res[, cols, drop = FALSE]
    print(utils::head(res, n), row.names = FALSE)
  }
  invisible(x)
}
