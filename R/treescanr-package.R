#' treescanr: Tree-Based Scan Statistics for Syndromic Surveillance
#'
#' A pipeable workflow around the 'TreeScan' command-line software:
#' [ts_visits()] -> [ts_counts()] -> [ts_run()] -> [ts_results()].
#'
#' @import data.table
#' @keywords internal
"_PACKAGE"

# data.table non-standard evaluation
utils::globalVariables(c(
  ".", ".N", ".SD", "code", "date", "key", "severity", "diagnosis_codes",
  "Level2", "Level3", "Name1", "visit_count", "searchf", "Freq", "n"
))
