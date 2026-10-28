# Design decisions

Short records of choices that shape the code, with the reason for each.

| Decision | Reason |
|---|---|
| **One geography only (NHS acute trust) in every analysis** | The same cases are published under three geographies; summing them double-counts. A QC check confirms they agree each month. |
| **Latest release wins; earlier releases are kept** | Counts are revised after publication. The newest value is the best estimate, and keeping the older ones makes revisions measurable. |
| **Fail loudly, never guess** | An unrecognised metric label, organisation type or header row stops the build with the evidence. A silent mis-mapping in surveillance data is worse than a stop. |
| **Corrections are data, not code** | `config/corrections.csv` records each fix with its reason; every applied row is logged. Reviewers can audit them without reading R. |
| **Compare units with themselves, not each other** | UKHSA states the counts do not support comparisons between trusts, and no denominator is published. Indices against a unit's own baseline need no denominator. |
| **Three exceedance methods, compared** | No single threshold is "right". Agreement and disagreement between simple methods is more informative than one arbitrary rule. |
| **COVID window excluded from model training, not from plots** | It would bias seasonal baselines, but removing it from view would hide the biggest feature of the series. |
| **Functions in `R/`, thin scripts on top** | Functions can be tested without side effects; scripts only orchestrate. |
| **File-based cache (not a pipeline framework)** | Parsing the spreadsheets is the slow step. A hash-keyed per-file cache removes it on re-runs with no extra dependency. A pipeline tool such as `targets` is a reasonable later migration. |
| **PSOCK workers that source the function files** | Works on Windows, macOS and Linux without forking tricks or fragile closure serialisation. |
| **Demo mode on synthetic data** | Lets reviewers and CI exercise every figure and the report without downloading anything. Demo output goes to its own folder and is stamped SYNTHETIC. |
| **Colour-blind-safe palette, one colour per onset category** | Consistent reading across figures; accessible by default. |
