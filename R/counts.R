#' Build a TreeScan count file of incident diagnoses
#'
#' Port of the epiENGAGE count-file algorithm (Ramona Lall and Alison
#' Levin-Rector, NYC DOHMH). Starting from visit-level data it:
#'
#' 1. splits diagnosis codes and removes ineligible ones (`ineligible`);
#' 2. keeps codes present in the tree and looks up their level-3 parent;
#' 3. keeps only **incident** diagnoses: a level-3 group seen for the same
#'    patient within `lookback_days` is dropped, with special handling of
#'    admissions;
#' 4. restricts to the `study_days` ending on `end_date`;
#' 5. keeps the rarest code per level-3 group within a visit (random
#'    tie-break, see `seed`);
#' 6. aggregates counts by node (`0-` = not admitted, `1-` = admitted) and day.
#'
#' `visits` should cover `study_days + lookback_days` so every day in the study
#' period has a full lookback.
#'
#' @param visits Output of [ts_visits()].
#' @param end_date Last day of the study period (e.g., `Sys.Date() - lag`).
#' @param tree_wide Wide-format tree (path or `data.frame`) with columns
#' `Name1` (code without dot), `Level2`, and `Level3`.
#' @param study_days Length of the study period in days.
#' @param lookback_days Window used to define incident diagnoses.
#' @param ineligible Regular expression of codes to exclude.
#' @param seed Optional seed for the tie-break. The global RNG state is
#' restored on exit.
#' @return A `data.table` with columns `code`, `date` (`yyyy/mm/dd`), and `n`,
#' with attributes `end_date`, `study_days`, and `incident` (the incident
#' visit-code table, one row per `date`, `key`, `dispo`, `code`).
#' @export
#' @examples
#' ex <- function(f) system.file("extdata", f, package = "treescanr")
#' counts <- read.csv(ex("toy_visits.csv")) |>
#'   ts_visits() |>
#'   ts_counts(end_date = "2026-06-30", tree_wide = ex("toy_tree_wide.txt"), seed = 1)
#' head(counts)
ts_counts <- function(
    visits,
    end_date,
    tree_wide,
    study_days = 90L,
    lookback_days = 365L,
    ineligible = ts_ineligible_pattern(),
    seed = NULL
) {
  if (!is.null(seed)) {
    old_seed <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(
      if (is.null(old_seed)) rm(".Random.seed", envir = globalenv())
      else assign(".Random.seed", old_seed, envir = globalenv())
    )
    set.seed(seed)
  }

  end_date <- as.Date(end_date)
  visits <- as.data.table(visits)[, list(key, date, diagnosis_codes, severity)]
  visits[, `:=`(
    date = as.Date(date),
    diagnosis_codes = trimws(gsub("\\s+", " ", diagnosis_codes))
  )]

  if (!is.data.frame(tree_wide))
    tree_wide <- fread(tree_wide, select = c("Name1", "Level2", "Level3"))
  tree_wide <- as.data.table(tree_wide)[
    !is.na(Level2) & !is.na(Level3), list(Name1, Level2, Level3)
  ]

  # One row per visit-code, most severe outcome per patient-day
  long <- .explode(visits, "diagnosis_codes", " ")
  long[, code := gsub(".", "", gsub("\\s+", "", code), fixed = TRUE)]
  long <- long[!is.na(code) & code != "" & !grepl("^[0-9]", code) &
                 grepl("\\d", code)]
  long[, severity := if ("A" %in% severity) "A" else "V", by = list(date, key)]
  long <- unique(long)
  long <- long[!grepl(ineligible, code)]
  long <- merge(long, tree_wide[, list(Name1, Level2, Level3)],
                by.x = "code", by.y = "Name1", sort = TRUE)

  # One row per visit
  all_visits <- long[, list(
    Level3 = paste(Level3, collapse = ","),
    code = paste(code, collapse = ",")
  ), by = list(date, key, severity)]
  all_visits[, Level3 := gsub("-", "_", Level3, fixed = TRUE)]
  all_visits[, visit_count := .N, by = key]

  single <- all_visits[visit_count == 1, list(date, key, severity, code)]
  multiple <- all_visits[visit_count >= 2, list(date, key, severity, code, Level3)]
  multiple <- multiple[, .incident(.SD, lookback_days), by = key]

  # Replace non-incident codes by REMOVE
  multiple[, Level3 := mapply(function(l3, s) gsub(s, "REMOVE", l3),
                              Level3, searchf, USE.NAMES = FALSE)]
  multiple[, code := mapply(function(cd, l3) {
    cd <- strsplit(cd, ",", fixed = TRUE)[[1L]]
    cd[strsplit(l3, ",", fixed = TRUE)[[1L]] == "REMOVE"] <- "REMOVE"
    paste0(cd, collapse = ",")
  }, code, Level3, USE.NAMES = FALSE)]

  cohort <- rbindlist(list(single, multiple[, list(date, key, severity, code)]))
  study <- cohort[date >= end_date - study_days + 1 & date <= end_date]
  study <- .explode(study, "code", ",")[code != "REMOVE"]

  # Keep the rarest code per level-3 group within a visit
  all_codes <- unlist(strsplit(visits$diagnosis_codes, " ", fixed = TRUE),
                      use.names = FALSE)
  all_codes <- gsub(".", "", all_codes[all_codes != ""], fixed = TRUE)
  freq <- as.data.table(table(all_codes))
  setnames(freq, c("code", "Freq"))

  study <- merge(study, freq, by = "code", all.x = TRUE, sort = FALSE)
  study <- merge(study, tree_wide[, list(Name1, Level3)], by.x = "code",
                 by.y = "Name1", all.x = TRUE, sort = FALSE)
  study <- .keep_rarest(study)

  incident <- study[, list(date = as.Date(date), key = as.character(key),
                           dispo = severity, code)]

  counts <- study[, list(n = sum(n)), by = list(code, severity, date)]
  counts[nchar(code) >= 4L,
         code := paste0(substr(code, 1L, 3L), ".", substr(code, 4L, nchar(code)))]
  counts[, code := paste0(fifelse(severity == "V", "0-", "1-"), trimws(code))]
  counts <- counts[, list(
    code, date = format(as.Date(date), "%Y/%m/%d"), n = as.integer(n)
  )]

  setattr(counts, "end_date", end_date)
  setattr(counts, "study_days", as.integer(study_days))
  setattr(counts, "incident", incident)
  counts[]
}

#' @rdname ts_counts
#' @details `ts_ineligible_pattern()` returns the default exclusions: COVID-19,
#' influenza, allergic rhinitis, asthma, anaphylaxis, most Z codes, neoplasms,
#' and congenital malformations.
#' @export
ts_ineligible_pattern <- function() {
  paste(
    "U071|J09|J10|J11|\\bJ301\\b|\\bJ302\\b|\\bJ3089\\b|\\bJ309\\b|J45|T7840",
    "Z0|Z10|Z1152|Z12|Z13|Z14|Z15|Z17|Z18|Z19|Z21|Z28|Z30|Z3|Z4|Z50|Z51|Z52|Z53|Z55|Z56|Z62|Z63|Z64|Z66|Z67|Z68|Z76|Z78|Z8|Z90|Z91|Z92|Z93|Z94|Z95|Z96|Z97|Z98",
    "\\bC|\\bD0|\\bD1|\\bD2|\\bD3|\\bD4|\\bQ",
    sep = "|"
  )
}

# Split a delimited column into one row per element
.explode <- function(dt, col, split) {
  parts <- strsplit(dt[[col]], split, fixed = TRUE)
  out <- dt[rep.int(seq_len(.N), lengths(parts))]
  out[, (col) := NULL]
  out[, code := unlist(parts, use.names = FALSE)]
  out
}

# Search strings of non-incident level-3 codes for one patient (rows as
# ordered in the data). Port of `process_patient_faster()`.
.incident <- function(patient_data, lookback_days = 365) {
  n <- nrow(patient_data)
  dates_num <- as.numeric(patient_data$date)
  severity <- patient_data$severity
  level3 <- patient_data$Level3

  search <- search2 <- search3 <- searchf <- rep(NA_character_, n)
  level3_split_space <- strsplit(gsub(",", " ", level3, fixed = TRUE), " ", fixed = TRUE)
  level3_split_comma <- strsplit(level3, ",", fixed = TRUE)

  # search: level-3 codes from prior rows within the lookback
  for (i in seq_len(n)) {
    prior_idx <- which(seq_len(n) < i & abs(dates_num - dates_num[i]) <= lookback_days)
    if (!length(prior_idx)) {
      search[i] <- "NONE"
    } else {
      prior_codes <- unlist(level3_split_space[prior_idx], use.names = FALSE)
      search[i] <- paste0(unique(prior_codes[!is.na(prior_codes)]), collapse = "|")
    }
  }

  admit_idx <- which(severity == "A")
  n_admit <- length(admit_idx)

  if (n_admit >= 1L) {
    admit_dates <- dates_num[admit_idx]

    # search2: admit codes propagated to visits in the preceding lookback
    for (i in seq_len(n_admit)) {
      this_row <- admit_idx[i]
      this_date <- dates_num[this_row]

      if (!any(seq_len(n_admit) < i & abs(admit_dates - admit_dates[i]) <= lookback_days))
        search2[this_row] <- "NONE"

      prior_visit_idx <- which(dates_num - this_date < 0 &
                                 dates_num - this_date >= -lookback_days &
                                 severity == "V")
      if (length(prior_visit_idx)) {
        # NOTE: indexes search2 by `i` (not `this_row`), as in the original
        existing <- unlist(strsplit(search2[i], "\\|"), use.names = FALSE)
        new_codes <- level3_split_comma[[this_row]]
        search2[prior_visit_idx] <- paste0(
          unique(c(existing[!is.na(existing)], new_codes[!is.na(new_codes)])),
          collapse = "|"
        )
      }
    }

    # search3: admit codes not seen in prior admits within the lookback
    if (n_admit >= 2L) {
      for (i in 2:n_admit) {
        this_row <- admit_idx[i]
        prior_rows <- admit_idx[admit_dates - dates_num[this_row] < 0 &
                                  admit_dates - dates_num[this_row] >= -lookback_days]
        prior_codes <- unlist(strsplit(paste0(level3[prior_rows], collapse = ","),
                                       ",", fixed = TRUE), use.names = FALSE)
        search3[this_row] <- paste0(setdiff(level3_split_comma[[this_row]], prior_codes),
                                    collapse = "|")
      }
    }
  }

  for (i in seq_len(n)) {
    if (!is.na(search3[i]))
      search[i] <- gsub(search3[i], "", search[i])

    searchf[i] <- if (is.na(search2[i])) {
      search[i]
    } else if (search2[i] != "NONE" && search[i] == "NONE") {
      search2[i]
    } else if (search2[i] == "NONE") {
      "NONE"
    } else {
      paste0(c(search[i], search2[i]), collapse = "|")
    }
  }

  patient_data$searchf <- searchf
  patient_data
}

# One code per (key, date, Level3): the least frequent, ties broken at random
.keep_rarest <- function(study) {
  setorder(study, key, date, Level3, Freq)
  study[, n := seq_len(.N), by = list(key, date, Level3)]

  ties <- study[, .SD[.N >= 2L & Freq == Freq[1L]], by = list(key, date, Level3)]
  ties <- ties[, {
    tmp <- copy(.SD)
    tmp[, n := sample(seq_along(Freq), size = .N, replace = FALSE)]
    tmp[n == 1L]
  }, by = list(key, date, Level3)]

  singles <- study[, .SD[!(.N >= 2L & Freq == Freq[1L]) & n == 1L],
                   by = list(key, date, Level3)]

  rbindlist(list(singles, ties), use.names = TRUE, fill = TRUE)
}
