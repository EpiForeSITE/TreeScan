#' Standardize visit-level data
#'
#' Turns visit-level emergency department data (one row per visit) into the
#' input expected by [ts_counts()]: a `data.table` with columns `key`
#' (patient identifier), `date`, `diagnosis_codes` (space-separated ICD-10-CM
#' codes), and `severity` (`"A"` = admitted, `"V"` = visit only).
#'
#' @param data A `data.frame` with one row per visit.
#' @param key,date,codes,admitted Names of the columns in `data` holding the
#' patient identifier, visit date (or date-time), diagnosis codes (separated
#' by spaces, commas, or semicolons), and admission status (logical, 0/1, or
#' `"A"`/`"V"`). Missing admission status is treated as not admitted.
#' @return A `data.table`.
#' @export
#' @examples
#' visits <- read.csv(system.file("extdata", "toy_visits.csv", package = "treescanr"))
#' ts_visits(visits) |> head()
ts_visits <- function(
    data,
    key = "key",
    date = "date",
    codes = "diagnosis_codes",
    admitted = "severity"
) {
  missing_cols <- setdiff(c(key, date, codes, admitted), names(data))
  if (length(missing_cols))
    stop("Columns not found in `data`: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)

  adm <- data[[admitted]]
  if (!(is.character(adm) && all(adm %in% c("A", "V", NA))))
    adm <- ifelse(as.logical(as.integer(adm)) %in% TRUE, "A", "V")
  adm[is.na(adm)] <- "V"

  dx <- strsplit(as.character(data[[codes]]), "[;,[:space:]]+")
  dx <- vapply(dx, function(x) {
    x <- unique(x[!is.na(x) & nzchar(x) & x != "NA"])
    if (length(x)) paste(x, collapse = " ") else NA_character_
  }, character(1))

  out <- as.data.table(list(
    key = as.character(data[[key]]),
    date = as.Date(data[[date]]),
    diagnosis_codes = dx,
    severity = adm
  ))

  out[!is.na(diagnosis_codes) & !is.na(date)]
}

#' @rdname ts_visits
#' @details `ts_visits_nssp()` is a shortcut for NSSP ESSENCE DataDetails
#' extracts (columns `C_Unique_Patient_ID`, `C_Visit_Date_Time`,
#' `DischargeDiagnosis`, and `HasBeenAdmitted`).
#' @export
ts_visits_nssp <- function(data) {
  ts_visits(
    data,
    key = "C_Unique_Patient_ID",
    date = "C_Visit_Date_Time",
    codes = "DischargeDiagnosis",
    admitted = "HasBeenAdmitted"
  )
}
