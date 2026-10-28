# Data sources

## UKHSA monthly C. difficile infection counts (England)

- **Publisher:** UK Health Security Agency (UKHSA), Antimicrobial Resistance and Healthcare-Associated Infection Division.
- **Status:** accredited official statistics (reviewed by the Office for Statistics Regulation, May 2022).
- **Collection:** mandatory enhanced surveillance of C. difficile infection (CDI) for NHS acute trusts, patients aged 2 years and over. Trusts submit patient-level data monthly to UKHSA's data capture system; the published tables are aggregated counts.
- **Licence:** Open Government Licence v3.0.

### Where the files come from

UKHSA publishes a new rolling 13-month spreadsheet each month and later moves older ones to annual pages, so the 81 files used here come from two kinds of place:

| Where | Files | Windows end | Released |
|---|---|---|---|
| Live GOV.UK pages: *C. difficile infection: monthly data by prior trust exposure* and the annual pages *MRSA, MSSA, Gram-negative bacteraemia and CDI: monthly data 2024 to 2025* / *2025 to 2026* | 43 | Mar 2023 to Aug 2026 | Jun 2023 to Oct 2026 |
| UK Government Web Archive snapshot of the first page, 10 May 2023 | 12 | Apr 2022 to Mar 2023 | Jun 2022 to May 2023 |
| Web Archive snapshot, 6 May 2022 | 14 | Mar 2020 to Mar 2022 | Jun 2021 to May 2022 |
| Web Archive snapshot, 6 May 2021 | 12 | Apr 2020 to Mar 2021 | Jun 2020 to May 2021 |

A fourth snapshot (6 May 2020) was inspected but is not used: its windows start before April 2019 (see below). A test (`test-config-sources.R`) checks that the listed files leave no month uncovered.

Release dates come from the update history shown on each page. Exact addresses are in `config/sources.csv`. Retrieval dates and MD5 checksums of the files actually used are written to `data/raw/RETRIEVAL_LOG.csv`.

### Why the series starts in April 2019

UKHSA's page describes the prior-trust-exposure data (HOHA, COHA, COIA, COCA) as starting in April 2019. Files whose windows begin earlier may not use the same case categories, and the Cover sheet says trusts have been asked for prior-admission information only since April 2017, so months before April 2019 are **not** used and no attempt has been made to splice them in. (Checking whether older months could be made comparable is on the roadmap.)

### Facts from the UKHSA Cover sheet that shape the analysis

- Cases are attributed to the **trust whose laboratory processed the specimen**, which may not be where the infection was acquired.
- Trust chief executives must **sign off** each month's data on day 15 of the following month; missing sign-off "can be indicative of missing data".
- Trusts can request changes **at any time**; "frequently minor changes or additions to the most recent 3 data months" occur. This is why the latest three months are treated as provisional.
- The same cases appear under **NHS acute trust**, **Sub-ICB location** (and, from 2024, **National**). They must never be added together.
- The data are explicitly **not** "a basis for comparisons between trusts": counts are not adjusted for hospital demographics or case mix, and no denominator is published.
- Documented mergers (also in `data/reference/organisation_changes.csv`): Apr 2022 RBZ into RH8; Apr 2023 RA4 into RH5; Jul 2023 RVY into RBN; Jan 2025 RAP into RAL.

### Layout changes across the files (all handled in `R/parse.R`)

| Feature | Variants seen |
|---|---|
| Data sheet name | `data` (2019 to 2024), `raw_data`, `Table_2_raw_data` (2024 on) |
| Header row | row 1 or row 4 |
| Centre column | `PHE Centre` (older) / `UKHSA centre` |
| Geography columns | `STP` (older) / `ICB`; `Region name` absent in the earliest files |
| Commissioner rows | `CCG` (older) / `Sub-ICB` |
| Metric labels | with and without hyphens ("healthcare associated" / "healthcare-associated") |
| National rows | present only from 2024 |

### Other UKHSA documents worth reading

- Quality and Methodology Information (QMI) report for mandatory HCAI surveillance.
- Quarterly and annual epidemiological commentaries on MRSA, MSSA, Gram-negative bacteraemia and CDI.
- The revisions and amendments policy for mandatory HCAI data.
