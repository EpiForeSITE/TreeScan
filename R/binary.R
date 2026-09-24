#' Locate the TreeScan command-line binary
#'
#' Checks that the TreeScan binary exists and is executable. The non-graphical
#' (command-line) version of TreeScan can be downloaded from
#' <https://www.treescan.org/download_treescan.html>.
#'
#' @param path Path to the binary (e.g., `treescan64` or `treescan64.exe`).
#' Defaults to the `treescanr.binary` option, then the `TREESCAN_BIN`
#' environment variable, then `treescan64` on the `PATH`.
#' @return The normalized path to the binary.
#' @export
#' @examples
#' \dontrun{
#' options(treescanr.binary = "~/TreeScan/treescan64")
#' ts_binary()
#' }
ts_binary <- function(
    path = getOption("treescanr.binary", Sys.getenv("TREESCAN_BIN"))
) {
  if (is.null(path) || !nzchar(path))
    path <- Sys.which(c("treescan64", "treescan64.exe"))[1L]

  if (is.na(path) || !nzchar(path) || !file.exists(path))
    stop(
      "TreeScan binary not found. Download the command-line version from ",
      "https://www.treescan.org/download_treescan.html and set ",
      "`options(treescanr.binary = <path>)` or the TREESCAN_BIN environment ",
      "variable.", call. = FALSE
    )

  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type == "unix" && file.access(path, 1L) != 0L)
    Sys.chmod(path, mode = "0755")

  path
}
