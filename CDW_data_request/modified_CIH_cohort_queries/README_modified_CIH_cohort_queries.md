# Modified CIH Cohort Queries

This folder contains copied and modified versions of the newer CIH SQL
scripts. The original files in `newer SQL queries` were not changed.

## How to run

Run `Make_patday_table_FY22_thru_FY26.sql` from this folder with SQLCMD
mode enabled. The shell now loads the dimension-table script and all
stored-procedure scripts before running the FY22-FY26 VA/community-care
patient-day build.

The FY22-FY26 window is:

- Start: `2021-10-01 00:00:00`
- End: `2026-09-30 23:59:59`

The VA, PIT, and IVC/CDS sections in the shell all use this same
FY22-FY26 window. For FY22-FY26 community-care data, IVC/CDS remains
the preferred current source based on the original script notes.

## What changed

- Added SQLCMD `:r` includes to the shell for:
  - `dim_tables_2024.sql`
  - `proc_pull_VA_CIH_visits_2024.sql`
  - `proc_apply_VA_CIH_exclusions.sql`
  - `proc_pull_VA_WH_visits_2024.sql`
  - `proc_make_VA_CIH_WH_patday.sql`
  - `proc_pull_PIT_CIH_patday_2024.sql`
  - `proc_pull_IVC_CDS_patday_2024.sql`
- Added `GO` after each include so procedure definitions are closed
  before shell code resumes.
- Added `WH_CIH` schema creation if the schema does not already exist.
- Replaced duplicate `@StartDateTime_` / `@EndDateTime_` declarations
  with separate VA, PIT, and IVC date variables.
- Fixed the trailing comma in `#consolidated_methods_wh`.
- Added cleanup for `WH_CIH.temp_ivccds_cih_patday`.
- Updated the shell date ranges and output table names to FY22-FY26.

## Remaining assumptions

These scripts still assume the original project environment exists:

- Database: `ORD_Fix_202309007D`
- Schema: `WH_CIH`
- Cohort table: `[ORD_Fix_202309007D].[Dflt].[CohortForJamie]`
- Source schema/tables such as `[Src].[Outpat_Visit]`,
  `[Src].[Outpat_VProcedure]`, and archive PIT tables

If those objects are not available in the execution environment, the
queries will still need environment-specific object-name changes.
