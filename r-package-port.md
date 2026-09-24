# How the TreeScan scripts were ported to `treescanr`

This note maps each file of the original `treescan_project/` onto the R package
at the repository root. The original scripts are still in `treescan_project/`,
unchanged. The package does not use them.

In short, the global variables (`parent_dir`, `final_date`, `initial_lags`,
`server`, ...) became function arguments. `setwd()` and the fixed folder tree
became a single `dir` argument. The package now covers steps 0 and 2–5. The
other steps are planned (see [Not ported yet](#not-ported-yet)).

## Pipeline scripts (`treescan_project/code/`)

| Original | Package | Notes |
|---|---|---|
| `run_full_pipeline.R` | `ts_visits() \|> ts_counts() \|> ts_run()` | The settings at the top of the script are now function arguments. There are no interactive prompts, and no scripts edit their own source to store lags. Several lags are run with `lapply()` (see the vignette). |
| `0_locate_treescan.R` | `ts_binary()` (`R/binary.R`) | The `server` flag is replaced by an explicit path taken from `options(treescanr.binary)`, `TREESCAN_BIN`, or the `PATH`. |
| `1_download_data.R` | — | Not ported yet. Its daily CSVs can be read and passed to `ts_visits_nssp()`. |
| `1.1_subset_downloaded_data.R` | — | Not ported. Filter the data by `Region` before calling `ts_visits_nssp()`. |
| `2_clean_downloaded_data.R` | `ts_visits()`, `ts_visits_nssp()` (`R/visits.R`) | Builds the same `key, date, diagnosis_codes, severity` table from any data source. The lag-assessment subset it also saved is not ported. |
| `2.1_assess_lag.R`, `2.2_pick_lags.R`, `2.3_quick_lag_check.R` | — | Not ported yet. The lag is simply `end_date = run_date - lag` in `ts_counts()`. |
| `2.4_data_artifact_check.R` | — | Not ported yet. |
| `3_create_count_file.R` | `ts_counts()` (`R/counts.R`) | Line-by-line port of the algorithm. `process_patient_faster()` became `.incident()`. The unused `process_patient()` was dropped. The rarest-code tie-break can be seeded (`seed`). The `v2/lag*.csv` table is returned as `attr(counts, "incident")`. A test checks that the output matches this script exactly on the toy data. |
| `4_update_parameter_file.R` | `ts_prm_*()` (`R/prm.R`), and `ts_run()` fills in the values | `update_prm_file()` became generic helpers that set any parameter by name. `ts_run()` fills in the paths, date ranges, processes (2 by default), and not-evaluated nodes. |
| `5_run_treescan.R` | `ts_run()` (`R/run.R`) | A single `system2()` call writes a log. If TreeScan fails, R stops with the end of the log. |
| `6_create_signal_linelist.R`, `6.1_download_background_for_interpretation.R` | — | Not ported yet. Results are available as `ts_results()$results`. |
| `7_create_signal_report.R`, `7.1_create_signal_report_standalone.R` | — | Not ported yet. |
| `8_WC_signal_review.R` | — | Specific to the World Cup. Planned as an example script rather than package code. |

## Data and parameters

| Original | Package | Notes |
|---|---|---|
| `params/Parameter_File_lag1.prm` (v2.4.1) | `inst/extdata/Parameter_File_template.prm`, `ts_prm_template()` | Same settings, but the paths and dates are blank (`ts_run()` fills them in) and `parallel-processes=2`. |
| `params/Parameter_File*.prm`, `params (v2.4.0)/` | — | Replaced by the single template. |
| `data/Tree_File_2027.csv` | `tree` argument of `ts_run()` | Not bundled (50 MB). Users pass the path. |
| `data/Tree_File_2026_wide_format.txt` | `tree_wide` argument of `ts_counts()` | Not bundled (20 MB). Users pass the path. |
| `data/Do_not_evaluate_nodes.csv` | `not_evaluated` argument of `ts_run()` | Not bundled. Users pass the path. |
| `data/Common_cause.csv` | — | Used only by steps 6 and 7 (not ported yet). |
| Output folders (`raw_data/`, `results/`, `lag/`, ...) | `dir` argument of `ts_run()` | One folder per run: `counts.txt`, `parameters.prm`, `results.*`, `treescan.log`. The vignette suggests the layout `<dir>/<date>/lag<L>/`. |
| `TS_linux/`, `TS_windows/` | Private devcontainer image | TreeScan is bundled in `ghcr.io/epiforesite/treescanr-dev` (`.devcontainer/`), which is used by CI. |
| — | `inst/extdata/toy_*` | A small subset of the 2026/2027 trees plus synthetic visits, for examples and tests (`data-raw/toy_data.R`). |

## Behavior kept as is (to review)

`ts_counts()` deliberately reproduces some behavior of `3_create_count_file.R`
that the original team may want to review:

- When deciding if a diagnosis is incident, "prior visit" means an earlier
  *row*. Rows are ordered by code (after the tree merge), not by date.
- `search2[i]` is indexed by the admission counter `i` instead of the row
  (`this_row`) (marked with a `NOTE` in `R/counts.R`).
- The TreeScan data time range is `[end_date - 90, end_date]` (91 days), while
  the counts cover 90 days.

Step 3 also used the 2026 wide tree while step 4 used the 2027 tree. In the
package, both are explicit arguments.

## Not ported yet

In order of priority: NSSP download (1, 1.1), lag assessment (2.1–2.3),
artifact scores (2.4), signal linelist and background data (6, 6.1), and
reports (7, 7.1).
