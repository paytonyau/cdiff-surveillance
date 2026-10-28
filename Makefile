# Common tasks. Run `make help` for the list.
R ?= Rscript

.PHONY: help all demo data analyse report test refresh clean-cache

help:  ## list the available tasks
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-12s %s\n", $$1, $$2}'

all:  ## fetch, build, analyse and render the report (real data)
	$(R) run.R

demo:  ## preview the full report on SYNTHETIC data (outputs/demo/)
	$(R) run.R --demo

data:  ## download and build the cleaned dataset only
	$(R) scripts/01_fetch.R && $(R) scripts/02_build_dataset.R

analyse:  ## figures and tables from the cleaned dataset
	$(R) scripts/03_analyse.R

report:  ## render outputs/report.html
	$(R) scripts/04_report.R

refresh:  ## ignore the parse cache and re-read every file
	$(R) run.R --refresh

test:  ## run the test suite
	$(R) tests/testthat.R

clean-cache:  ## delete the parse cache (raw downloads are kept)
	rm -rf data/cache/parsed
