# AGENTS.md

Notes for AI coding agents working on this repository.

## Project

- `treescanr` is an R package at the repository root (`R/`, `inst/`, `vignettes/`).
- `treescan_project/` holds the original epiENGAGE scripts. Keep them as they
  are: they are the reference for the port (see `r-package-port.md`).
- Conventions: minimal dependencies (tinyverse), `data.table` for heavy
  processing, functions pipeable with `|>`, tinytest integration tests
  (`inst/tinytest/`), quarto for `README.qmd` and the vignettes, 2 cores by
  default, and `NEWS.md` updated with user-facing changes.

## Use the devcontainer when podman or docker is available

If the environment has `podman` or `docker`, it is generally easier to run
things inside the devcontainer image. It already has R, Quarto, the package
dependencies, and the TreeScan(TM) binary (`TREESCAN_BIN`). This means the
tests that call TreeScan run instead of being skipped:

```sh
# The TreeScan Linux binary is x86-64 only, hence --platform
podman run --rm --platform linux/amd64 -v "$PWD":/src:ro \
  ghcr.io/epiforesite/treescanr-dev:latest bash -c '
    cp -r /src /tmp/pkg && cd /tmp/pkg &&
    R CMD build . && R CMD check --no-manual treescanr_*.tar.gz'
```

- The image is private: pull it after `podman login ghcr.io` with a token
  that has `read:packages`.
- To rebuild it, run `.devcontainer/build.sh <treescan-linux-tarball>`.
  Never commit the TreeScan binary or tarball: its license requires every
  user to agree to it.

Without a container, the TreeScan tests are skipped unless `TREESCAN_BIN`
points to a local binary.

## Common tasks

- Documentation: `Rscript -e 'roxygen2::roxygenise()'`
- README: edit `README.qmd`, then run `quarto render README.qmd`
- Tests: `Rscript -e 'tinytest::test_package("treescanr")'` (package installed)
- Website: `pkgdown::build_site()` (needs the package installed, because the
  quarto vignette renders in a separate process). It is deployed by
  `.github/workflows/pkgdown.yaml`.
