# Data Preparation — Power Query

Documentation of the ingestion and cleansing layer behind the HR analytics report. All data is synthetic; source paths are generic placeholders.

The source system delivers HR data the way most HRIS exports arrive in practice: split across sites, with concatenated allowance strings, inconsistent casing, single-letter gender codes, and performance ratings held in a wide quarterly layout. This layer resolves those into a clean star schema.

\---

## Query inventory

|Query|Source shape|Output grain|
|-|-|-|
|`AppendMasterData`|Three per-site Excel extracts|One row per employee|
|`FinalMasterData`|`AppendMasterData` + dimension joins|One row per employee, enriched|
|`MonthlyAttendance`|Folder of monthly attendance files|One row per employee per month|
|`GroupByAttendance`|Same folder, aggregated|One row per employee|
|`PerformanceRecord`|Wide quarterly ratings sheet|One row per employee per quarter|
|`Separations`|Single exit log|One row per exit event|

\---

## AppendMasterData

Consolidates three site-level employee extracts (Doha HQ, Wakra, Al Khor) into a single master.

**Transformations**

* **Append** — `Table.Combine` across the three site tables. Sites maintain separate extracts; analysis needs one population.
* **Split concatenated allowances** — source delivers a single `Allowances` field formatted `Housing:4000|Transport:1500`. Split on `|`, then on `:`, discard the label fragments, retain the numeric values as `Housing` and `Transport`.
* **Trim** — whitespace stripped from all text fields. Multi-site manual entry reliably introduces trailing spaces, which break joins and split what should be one category into two.
* **Proper case** — applied to `FullName`, `Nationality`, `Gender`. Source contained mixed casing.
* **Standardise gender codes** — `F` and `M` expanded to `Female` and `Male`. Uses `Replacer.ReplaceValue` (whole-value match) rather than `Replacer.ReplaceText`, so the substitution cannot corrupt other values.
* **Derive `Age`** — days between date of birth and the refresh date, divided by 365, rounded to 2dp.
* **Derive `AgeBand`** — Under 25 / 25-34 / 35-44 / 45-54 / 55-64 / Over 65.
* **Derive `ServiceYrs` and `TenureBand`** — same approach from hire date. Bands: Under 1Yr / 1-3Yrs / 4-10Yrs / 11-20Yrs / Over 20Yrs.
* **Deduplicate** — `Table.Distinct` on `EmployeeID`.
* **Derive `TotalSalary`** — basic plus housing plus transport. `List.Sum` ignores nulls, so employees without an allowance are not lost.
* **Derive `HasEmail` / `HasContactInfo`** — data completeness flags, allowing the report to show contactability without exposing the underlying values.

**Design decisions**

*Age is calculated at refresh time.* This means `Age`, `ServiceYrs` and their bands change on every refresh, and a report run today will not reproduce last quarter's figures. Acceptable for a live operational dashboard; not acceptable where reports must be reproducible after the fact. Production HR reporting normally calculates age as of a fixed effective date passed as a parameter, so historical outputs remain stable. Documented here as a deliberate tradeoff rather than an oversight.

*Deduplication keeps the first matching row.* With three site files, an employee appearing in more than one — a transfer mid-period, for example — resolves arbitrarily to whichever file loaded first. On production data this would be preceded by a sort on a last-modified timestamp so the most recent record wins.

*Allowance labels are discarded, not validated.* The split assumes `Housing` always precedes `Transport` in the concatenated string. A source change in ordering would silently swap the two columns. A more defensive version would parse by label rather than position.

\---

## FinalMasterData

Enriches the master with dimension attributes and derived classifications.

**Transformations**

* **Left-outer joins** to Departments, Jobs, Locations and SalaryGrades. Left-outer rather than inner: an employee with an unmatched department code should still appear in headcount, with a blank department, rather than silently disappearing. Inner joins are a common cause of headcount that doesn't reconcile.
* **Expand salary band** — brings `MinSalaryQAR`, `MidSalaryQAR`, `MaxSalaryQAR` alongside actual salary, enabling compa-ratio and band-placement analysis.
* **Derive `Nationality Type`** — collapses nationality to Qatari / Non-Qatari, supporting nationalisation ratio reporting without carrying the full nationality list into every visual.

\---

## MonthlyAttendance

Ingests a folder of monthly attendance files.

**Transformations**

* **Folder ingestion** — `Folder.Files` with the generated Transform File function. New months are picked up automatically on refresh; no query edit required. This is the main reason to use folder-based ingestion over individual file connections.
* **Hidden file filter** — excludes system and lock files that would otherwise fail the transform.
* **Derive `MonthStart`** — `#date(\[Year], \[Month], 1)` builds a real date key from separate year and month integers, enabling the relationship to the date table. Without this, time intelligence is not possible.
* **Derive `Month Name`** — month number expanded to name for display.
* **Explicit typing** on all numeric measures, so aggregations in DAX do not silently coerce.

\---

## GroupByAttendance

Aggregates the same attendance folder to employee level: total working days, days present, sick leave, annual leave, unplanned absences, and overtime hours.

Provides a pre-aggregated employee-level summary for visuals that do not need monthly granularity.

\---

## PerformanceRecord

**Transformations**

* **Unpivot** — source arrives wide, one column per quarter (`Q1\_2025` … `Q4\_2025`). `Table.UnpivotOtherColumns` reshapes to one row per employee per quarter. This is the single most important transformation in the file: wide quarterly layouts cannot be filtered by a date dimension, and adding 2026 columns to a wide table would break every visual. Long format absorbs new periods without a schema change.
* **Rename** — `Attribute` and `Value` to `Quarter` and `Rating`.

\---

## Separations

Exit events, loaded with explicit typing on `SeparationDate`, `SeparationType`, `Reason`, `ExitInterviewDone` and `Rehirable`.

Held as a separate fact table rather than a status flag on the employee master. Separations are an event stream; headcount is a point-in-time snapshot. Combining them is the most common cause of double-counted turnover in HR dashboards, and separating them is what allows attrition to be calculated against average headcount rather than a closing figure.

\---

## Known limitations

* Age and tenure are refresh-date dependent (see above).
* Deduplication has no recency rule.
* Allowance parsing is position-dependent rather than label-driven.
* Source paths are hardcoded rather than parameterised; a production version would use a Power Query parameter for the root folder so the file moves between environments without edits.

