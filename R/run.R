#' Run TreeScan on a count file
#'
#' Writes the count file and a parameter file into `dir`, runs the TreeScan
#' binary, and reads the results. The data time range and temporal windows
#' are set from the `end_date` and `study_days` stored in `counts`.
#'
#' @param counts Output of [ts_counts()].
#' @param tree Path to the TreeScan tree file (long format, e.g.
#' `Tree_File_2027.csv`).
#' @param dir Output directory. Defaults to a temporary directory; for routine
#' use pass a persistent location such as
#' `file.path(tools::R_user_dir("treescanr", "data"), Sys.Date(), "lag1")`.
#' @param prm A `ts_prm` object used as template (see [ts_prm_template()]).
#' @param not_evaluated Optional path to a file of nodes not to evaluate
#' (e.g. `Do_not_evaluate_nodes.csv`).
#' @param processes Number of parallel processes used by TreeScan.
#' @param binary Path to the TreeScan binary (see [ts_binary()]).
#' @return A `ts_result` object (see [ts_results()]).
#' @export
#' @examples
#' \dontrun{
#' dir <- tools::R_user_dir("treescanr", "data")
#' res <- read.csv("visits.csv") |>
#'   ts_visits() |>
#'   ts_counts(end_date = Sys.Date() - 1, tree_wide = "Tree_File_2026_wide_format.txt") |>
#'   ts_run(tree = "Tree_File_2027.csv", dir = file.path(dir, Sys.Date(), "lag1"))
#' res
#' }
ts_run <- function(
    counts,
    tree,
    dir = tempfile("treescanr_"),
    prm = ts_prm_template(),
    not_evaluated = NULL,
    processes = 2L,
    binary = ts_binary()
) {
  end_date <- attr(counts, "end_date")
  study_days <- attr(counts, "study_days")
  if (is.null(end_date) || is.null(study_days))
    stop("`counts` must be the output of `ts_counts()`.", call. = FALSE)
  if (!file.exists(tree))
    stop("Tree file not found: ", tree, call. = FALSE)

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir <- normalizePath(dir, winslash = "/")
  files <- list(
    counts = file.path(dir, "counts.txt"),
    prm = file.path(dir, "parameters.prm"),
    results = file.path(dir, "results.txt"),
    log = file.path(dir, "treescan.log")
  )

  utils::write.table(
    counts[, c("code", "date", "n")], files$counts, sep = "\t",
    row.names = FALSE, quote = FALSE, fileEncoding = "ASCII"
  )

  range <- .prm_range(end_date - study_days, end_date)
  prm <- ts_prm_set(
    prm,
    "tree-filename" = .prm_path(tree),
    "count-filename" = .prm_path(files$counts),
    "results-filename" = .prm_path(files$results),
    "data-time-range" = range,
    "window-start-range" = range,
    "window-end-range" = range,
    "parallel-processes" = as.integer(processes),
    "restrict-evaluated-nodes" = !is.null(not_evaluated),
    "not-evaluated-nodes-file" = if (is.null(not_evaluated)) "" else
      .prm_path(not_evaluated)
  )
  ts_prm_write(prm, files$prm)

  status <- system2(binary, shQuote(files$prm), stdout = files$log,
                    stderr = files$log)
  if (!identical(as.integer(status), 0L)) {
    log <- readLines(files$log, warn = FALSE)
    stop("TreeScan failed (exit status ", status, "). Last lines of ",
         files$log, ":\n", paste(utils::tail(log, 20L), collapse = "\n"),
         call. = FALSE)
  }

  ts_results(dir)
}
