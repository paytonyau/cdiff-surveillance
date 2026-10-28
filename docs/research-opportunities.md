# Research opportunities

An honest assessment of what could become a publishable piece of work from this repository, and what could not.

## What is *not* publishable on its own
Descriptive trends in national C. difficile counts. UKHSA already publishes quarterly and annual epidemiological commentary on these data, so a descriptive report adds little new. The value here is the **pipeline**, the **data-quality evidence**, and **methods questions** the data can answer.

## Stronger angles (ordered by feasibility)

1. **How stable are provisional HCAI surveillance counts?** The 81 overlapping releases form a complete *vintage* dataset. Quantifying revisions by release lag (already implemented: `revision_profile()`), by trust and by onset category is a data-quality contribution that is rarely published and useful to anyone using provisional data. *Needs:* a clear question (e.g. how long until counts can be treated as final?), a precise definition of revision, and care that revisions are trust-initiated, not errors.
2. **Real-time performance of simple exceedance methods.** Compare flags raised on first-release data with flags on final data, and validate against seeded outbreaks. Contribution: whether simple methods remain usable on provisional data. *Needs:* the validation work listed in the roadmap; real outbreak records would be ideal but are not public.
3. **Rates and geography.** Adding bed-day and population denominators allows rate maps and funnel plots. Valuable, but check what UKHSA and NHS England already publish before claiming novelty.
4. **Four-nations comparison.** Interesting if case definitions can be aligned, which needs careful, source-by-source work.
5. **Software paper.** If the pipeline were packaged and documented for reuse, a software or data-resource note (for example JOSS or a methods journal) is a realistic target. JOSS requires a research purpose, tests, documentation and evidence of use beyond the author.

## Possible venues (check scope and current guidance before submitting)
*Journal of Hospital Infection*, *Epidemiology & Infection*, *Eurosurveillance* (short reports), *BMC Public Health*, *Wellcome Open Research*, *JOSS*.

## Before any submission
- Define the research question and analysis plan *before* looking at more results.
- Have an epidemiologist or UKHSA colleague review the case definitions and interpretation.
- Be explicit that data are aggregated, public, and not rates; avoid inference about individual trusts.
- Check ethics/governance expectations of the target venue (public aggregated data usually needs no ethics approval, but confirm).
