/* PROC to create patday table from consolidated methods tables for VA WH/CIH visits  */
/* uses combined consolidated_methods tables from proc_pull_VA_WH_visits and proc_apply_VA_CIH_exclusions (all therapies) */
/* updated 03/11/2022 | Claire Chen */

use ORD_Fix_202309007D;
go

drop proc if exists WH_CIH.make_VA_CIH_WH_patday;
go
create proc WH_CIH.make_VA_CIH_WH_patday
AS
BEGIN

/****   reduce to patient-day table   ****/

DROP TABLE IF EXISTS WH_CIH.temp_va_patday;
CREATE TABLE WH_CIH.temp_va_patday (
	ScrSSN varchar(50),
	PatientSID varchar(50),
	Sta6a varchar(50),
	Sta3n varchar(50),
	VisitDate date,
	InPerson int,
	AnyTele int,
	any_CPT int,
	any_NT int,
	any_LocName int,
	any_HF int,
	any_CHAR4 int,
	any_StopCode int,
	CIHType nvarchar(25)
);

INSERT INTO WH_CIH.temp_va_patday select ScrSSN
	, PatientSID
	, Sta6a
	, SUBSTRING(Sta6a, 1, 3) AS Sta3n
	, VisitDate
	, case when min(tele) = 0 then 1 else 0 end as InPerson
	, case when max(tele) = 1 then 1 else 0 end as AnyTele
	, max(CPT) as any_CPT
	, max(NT) as any_NT
	, max(LocName) as any_LocName
	, max(HF) as any_HF
	, max(CHAR4) as any_CHAR4
	, max(StopCode) as any_StopCode
	, CIHType 
from WH_CIH.temp_combined_visits
group by Scrssn, PatientSID, Sta6a, VisitDate, CIHType;

END
