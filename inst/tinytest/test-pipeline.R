# Integration tests: the full treescanr pipeline on the bundled toy data.
# Everything is written to temporary directories.
ex <- function(f) system.file("extdata", f, package = "treescanr")

# Visits -> counts ------------------------------------------------------------
visits <- read.csv(ex("toy_visits.csv")) |> ts_visits()
expect_equal(names(visits), c("key", "date", "diagnosis_codes", "severity"))
expect_true(all(visits$severity %in% c("A", "V")))

counts <- visits |>
  ts_counts(end_date = "2026-06-30", tree_wide = ex("toy_tree_wide.txt"), seed = 1)

# Same output as the legacy script (treescan_project/code/3_create_count_file.R)
# run on the same data with set.seed(1)
legacy <- data.table::fread("legacy_counts_lag1.txt", colClasses = "character")
legacy[, n := as.integer(n)]
data.table::setorder(legacy, code, date)
expect_equal(
  as.data.frame(counts[order(code, date), list(code, date, n)]),
  as.data.frame(legacy)
)
expect_equal(attr(counts, "end_date"), as.Date("2026-06-30"))
expect_true(all(as.Date(counts$date, "%Y/%m/%d") > as.Date("2026-06-30") - 90))

# Seed does not alter the global RNG state
set.seed(123); before <- runif(1)
set.seed(123); invisible(ts_counts(visits, "2026-06-30", ex("toy_tree_wide.txt"), seed = 1))
expect_equal(runif(1), before)

# NSSP adapter
nssp <- data.frame(
  C_Unique_Patient_ID = c("a", "b"),
  C_Visit_Date_Time = c("2026-01-01 10:00:00", "2026-01-02 08:00:00"),
  DischargeDiagnosis = c(";A084;R112;", ";J069;;"),
  HasBeenAdmitted = c(1, NA)
)
expect_equal(ts_visits_nssp(nssp)$diagnosis_codes, c("A084 R112", "J069"))
expect_equal(ts_visits_nssp(nssp)$severity, c("A", "V"))

# Parameter files ---------------------------------------------------------------
prm_file <- tempfile(fileext = ".prm")
prm <- ts_prm_template() |>
  ts_prm_set("monte-carlo-replications" = 999, "data-time-range" = "[2026/04/01,2026/06/30]")
ts_prm_write(prm, prm_file)
expect_identical(ts_prm_read(prm_file), prm)
expect_equal(ts_prm_get(prm, "monte-carlo-replications"), "999")
expect_equal(ts_prm_get(prm, "parallel-processes"), "2")
expect_error(ts_prm_set(prm, "not-a-parameter" = 1), "Unknown")

# Running TreeScan (only when the binary is available) --------------------------
if (nzchar(Sys.getenv("TREESCAN_BIN"))) {
  dir <- tempfile("treescanr_")
  res <- counts |>
    ts_run(tree = ex("toy_tree.csv"), dir = dir,
           prm = ts_prm_set(ts_prm_template(), "monte-carlo-replications" = 999,
                            "early-termination-threshold" = 50))
  expect_inherits(res, "ts_result")
  expect_true(nrow(res$results) > 0)
  # The injected A08.4 cluster is the most likely cut
  top <- res$results[order(res$results$P.value), "Node.Identifier"][1:5]
  expect_true(any(grepl("A08", top)))
  expect_true(file.exists(file.path(dir, "parameters.prm")))
  expect_equal(nrow(ts_results(dir)$results), nrow(res$results))
}
