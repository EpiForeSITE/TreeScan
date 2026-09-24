# Generates the small synthetic datasets in inst/extdata from the full tree
# files in treescan_project/data. Run from the repository root.
library(data.table)

blocks <- c("A00-A09", "J00-J06", "R10-R19", "R50-R69")

# Wide tree: all codes in the selected blocks
wide <- fread("treescan_project/data/Tree_File_2026_wide_format.txt")
wide <- wide[Level3 %in% blocks]
fwrite(wide, "inst/extdata/toy_tree_wide.txt", sep = "\t")

# Long tree (TreeScan input): the selected nodes and all their ancestors
tree <- fread("treescan_project/data/Tree_File_2027.csv")
nodes <- c(outer(c("0-", "1-", "2-"), c(wide$Name, blocks, "Root"), paste0))
repeat {
  more <- setdiff(tree[child %in% nodes & parent != "", parent], nodes)
  if (!length(more)) break
  nodes <- c(nodes, more)
}
tree <- tree[child %in% nodes]
# Empty fields must be written empty (not as "") or TreeScan reads them as node ids
for (col in names(tree)) set(tree, which(tree[[col]] == ""), col, NA)
fwrite(tree, "inst/extdata/toy_tree.csv", na = "")

# Synthetic visits: 16 months ending 2026-06-30 with a cluster of viral
# gastroenteritis (A08.4) in the last 10 days
set.seed(20260623)
codes <- c(sample(wide$Name, 60), "J45.909", "Z00.00", "U07.1")
dates <- seq(as.Date("2025-03-01"), as.Date("2026-06-30"), by = "day")

n_pat <- 2000
n_vis <- sample(1:4, n_pat, replace = TRUE, prob = c(.6, .25, .1, .05))
visits <- as.data.table(list(
  key = rep(sprintf("P%05d", seq_len(n_pat)), n_vis),
  date = sample(dates, sum(n_vis), replace = TRUE)
))
visits[, diagnosis_codes := vapply(
  sample(1:3, .N, replace = TRUE),
  function(k) paste(sample(codes, k), collapse = " "), character(1)
)]

cluster <- as.data.table(list(
  key = sprintf("C%05d", 1:40),
  date = sample(as.Date("2026-06-21") + 0:9, 40, replace = TRUE),
  diagnosis_codes = "A08.4 R11.2"
))
visits <- rbind(visits, cluster)
visits[, severity := sample(c("A", "V"), .N, replace = TRUE, prob = c(.2, .8))]
# Mimic NSSP formatting: codes without dots for some visits
visits[sample(.N, .N %/% 2), diagnosis_codes := gsub(".", "", diagnosis_codes, fixed = TRUE)]
setorder(visits, date, key)
fwrite(visits, "inst/extdata/toy_visits.csv")
