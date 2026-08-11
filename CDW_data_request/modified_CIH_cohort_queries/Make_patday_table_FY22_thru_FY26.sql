/*
Modified CIH/WH cohort shell

Run this script from the modified_CIH_cohort_queries folder with
SQLCMD mode enabled. The :r lines below load the dimension tables and
stored procedures before this shell executes the FY22-FY26 patday build.

This copy keeps the original ORD_Fix_202309007D / WH_CIH / Src /
CohortForJamie assumptions from the newer scripts, but fixes the
shell-level issues that prevented the original shell from running as a
single orchestrator script.
*/

/* pull all CIH utilization and combine into one table (pre-exclusions) */

use [ORD_Fix_202309007D];
go

IF SCHEMA_ID('WH_CIH') IS NULL
	EXEC('CREATE SCHEMA WH_CIH');
go

:r .\dim_tables_2024.sql
go
:r .\proc_pull_VA_CIH_visits_2024.sql
go
:r .\proc_apply_VA_CIH_exclusions.sql
go
:r .\proc_pull_VA_WH_visits_2024.sql
go
:r .\proc_make_VA_CIH_WH_patday.sql
go
:r .\proc_pull_PIT_CIH_patday_2024.sql
go
:r .\proc_pull_IVC_CDS_patday_2024.sql
go

use [ORD_Fix_202309007D];
go

select count (*) from [ORD_Fix_202309007D].[Dflt].[CohortForJamie]
select top 10 *  from [ORD_Fix_202309007D].[Dflt].[CohortForJamie]

DROP TABLE IF EXISTS WH_CIH.temp_cih_visits_long;
CREATE TABLE WH_CIH.temp_cih_visits_long (
	ScrSSN varchar(50),
	PatientSID varchar(50),
	VisitSID varchar(50),
	VisitDate date,
	CIHType varchar(50),
	Sta6a varchar(50),
	Tele int,
	PrimaryStopCode varchar(50),
	SecondaryStopCode varchar(50),
	CPT int,
	CPT_num_terms int,
	CPT_codes nvarchar(100),
	NT int,
	NT_num_terms int,
	NT_terms nvarchar(4000),
	NT_inclusions nvarchar(800),
	LocName int,
	LocationName nvarchar(100),
	LN_inclusions nvarchar(800),
	HF int,
	HF_num_terms int,
	HF_terms nvarchar(4000),
	HF_inclusions nvarchar(800),
	CHAR4 int,
	CHAR4_code nvarchar(25),
	StopCode int,
	strong_evid int,
	weak_evid int
);

DECLARE @VAStartDateTime nvarchar(25) = '2021-10-01 00:00:00';
DECLARE @VAEndDateTime nvarchar(25) = '2026-09-30 23:59:59';

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Acupuncture',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Biofeedback',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;
	
EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Chiropractic',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Guided Imagery',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Hypnosis',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Massage',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Meditation',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Physical Therapy',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'TaiChi',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_CIH_visits
	@CIHType = 'Yoga',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO WH_CIH.temp_cih_visits_long SELECT * fROM WH_CIH.temp_consolidated_methods; 


select min(visitdate), max(visitdate) from WH_CIH.temp_cih_visits_long

select cihtype, count(*)
from WH_CIH.temp_cih_visits_long
group by cihtype 
/* apply exclusions to compiled CIH visits */

EXEC WH_CIH.apply_VA_CIH_exclusions; --started 4/24/24 at 1:11pm

/* pull all WH utilization and combine into one table */

DROP TABLE IF EXISTS WH_CIH.temp_consolidated_methods;

DROP TABLE IF EXISTS #consolidated_methods_wh;
CREATE TABLE #consolidated_methods_wh (
	ScrSSN varchar(50),
	PatientSID varchar(50),
	VisitSID varchar(50),
	VisitDate date,
	CIHType varchar(50),
	Sta6a varchar(50),
	Tele int,
	PrimaryStopCode varchar(50),
	SecondaryStopCode varchar(50),
	CPT int,
	CPT_num_terms int,
	CPT_codes nvarchar(100),
	NT int,
	NT_num_terms int,
	NT_terms nvarchar(4000),
	NT_inclusions nvarchar(800),
	LocName int,
	LocationName nvarchar(100),
	LN_inclusions nvarchar(800),
	HF int,
	HF_num_terms int,
	HF_terms nvarchar(4000),
	HF_inclusions nvarchar(800),
	CHAR4 int,
	CHAR4_code nvarchar(25),
	StopCode int
);

EXEC WH_CIH.pull_VA_WH_visits
	@CIHType = 'WH-Clinical',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO #consolidated_methods_wh SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_WH_visits
	@CIHType = 'WH-Coach',
	@CIHTypeExclusion1 = 'WH-Clinical',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO #consolidated_methods_wh SELECT * fROM WH_CIH.temp_consolidated_methods;

EXEC WH_CIH.pull_VA_WH_visits
	@CIHType = 'WH-Activities',
	@CIHTypeExclusion1 = 'WH-Clinical',
	@CIHTypeExclusion2 = 'WH-Coach',
	@StartDateTime = @VAStartDateTime,
	@EndDateTime = @VAEndDateTime;
INSERT INTO #consolidated_methods_wh SELECT * fROM WH_CIH.temp_consolidated_methods; --run 4/24/2024 1:51pm



/****   combine WH/CIH consolidated methods table   ****/

DROP TABLE IF EXISTS WH_CIH.temp_combined_visits;
WITH intermed as (
	SELECT * FROM WH_CIH.temp_consolidated_methods_cih
	UNION
	SELECT * FROM #consolidated_methods_wh
	)
SELECT * INTO WH_CIH.temp_combined_visits FROM intermed;


DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.WH_CIH_FY22thuFY26_Visits_VA; 
SELECT * INTO ORD_Fix_202309007D.WH_CIH.WH_CIH_FY22thuFY26_Visits_VA FROM WH_CIH.temp_combined_visits; 


/****   reduce to patient-day table   ****/

EXEC WH_CIH.make_VA_CIH_WH_patday; 

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.WH_CIH_PatdayFY22thuFY26_VA;
SELECT * INTO ORD_Fix_202309007D.WH_CIH.WH_CIH_PatdayFY22thuFY26_VA FROM WH_CIH.temp_va_patday; 



/**** pull CIH and WH utilization (community care) ****/

DECLARE @PITStartDateTime nvarchar(25) = '2021-10-01 00:00:00';
DECLARE @PITEndDateTime nvarchar(25) = '2026-09-30 23:59:59';

EXEC ORD_Fix_202309007D.WH_CIH.MakePITCIHPatday
	@StartDateTime = @PITStartDateTime, 
	@EndDateTime = @PITEndDateTime; 



DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_PIT;
SELECT * 
INTO ORD_Fix_202309007D.WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_PIT 
from WH_CIH.temp_pit_cih_patday;

select min (VisitDate) from WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_PIT 
select max (VisitDate) from WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_PIT 

/**** pull CIH and WH utilization from IVC ****/


DECLARE @IVCStartDateTime nvarchar(25) = '2021-10-01 00:00:00';
DECLARE @IVCEndDateTime nvarchar(25) = '2026-09-30 23:59:59';

EXEC WH_CIH.MakeIVCCDS_CIHPatday
	@StartDateTime = @IVCStartDateTime, 
	@EndDateTime = @IVCEndDateTime; 

DROP TABLE IF EXISTS WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_IVCCDS;
SELECT * 
INTO WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_IVCCDS
from WH_CIH.temp_ivccds_cih_patday;

select top 100 * from WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_IVCCDS
select min (VisitDate) from WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_IVCCDS
select max (VisitDate) from WH_CIH.WH_CIH_PatdayFY22thuFY26_CC_IVCCDS

/**** drop temp tables ****/

DROP TABLE IF EXISTS WH_CIH.temp_consolidated_methods;
DROP TABLE IF EXISTS WH_CIH.temp_cih_visits_long;
DROP TABLE IF EXISTS WH_CIH.temp_consolidated_methods_cih;
DROP TABLE IF EXISTS WH_CIH.temp_combined_visits;
DROP TABLE IF EXISTS WH_CIH.temp_va_patday;
DROP TABLE IF EXISTS WH_CIH.temp_pit_cih_patday;
DROP TABLE IF EXISTS WH_CIH.temp_ivccds_cih_patday;
