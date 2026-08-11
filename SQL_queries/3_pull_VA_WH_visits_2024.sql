/* PROC to pull WH utilization and create consolidated visits table with exclusions applied */
/* updated 06/22/2022 | Claire Chen */

use OPCCCT_CIH;
go

drop proc if exists dflt.pull_VA_WH_visits;
go
create proc dflt.pull_VA_WH_visits (
	@CIHType varchar(25), -- to be updated by user
	@CIHTypeExclusion1 varchar(25) = '', -- default value is empty string; to be updated by user
	@CIHTypeExclusion2 varchar(25) = '', -- default value is empty string; to be updated by user
	@CIHTypeExclusion3 varchar(25) = '', -- default value is empty string; to be updated by user
	@StartDateTime varchar(25),
	@EndDateTime varchar(25)
	)
AS
BEGIN

/*** limit CDWWork.Outpat.Visit to specified date range ***/

DROP TABLE IF EXISTS #outpat_visit;
SELECT DISTINCT A.VisitSID
	, A.PatientSID
	, A.LocationSID
	, A.PrimaryStopCodeSID
	, A.SecondaryStopCodeSID
	, B.Sta6a
	, A.VisitDateTime
INTO #outpat_visit
FROM [CDWWORK].[Outpat].[Visit] A
	LEFT JOIN CDWWork.Dim.Division B
		ON A.DivisionSID = B.DivisionSID 
WHERE A.VisitDateTime >= CONVERT(datetime2(0), @StartDateTime)
	AND A.VisitDateTime <= CONVERT(datetime2(0), @EndDateTime); 

/*** collect inclusions ***/

/*** CPT ***/
drop table if exists #CPT;
select distinct A.VisitSID
	, C.CPTCode
	, C.CPTSID
	, C.CIHType
	, method = 'CPT'
INTO #CPT
FROM #outpat_visit A
	INNER JOIN [cdwwork].[Outpat].[VProcedure] B
		ON A.VisitSID = B.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].CPT C				
		ON B.CPTSID = C.CPTSID
WHERE C.CIHType in (@CIHType);

--convert CPT info to wide format
DROP TABLE IF EXISTS #CPT_wide;
WITH all_visits as (
	SELECT VisitSID
		, CIHType
		, COUNT(DISTINCT CPTSID) as CPT_num_terms
	FROM #CPT
	GROUP BY VisitSID, CIHType
), CPT_terms_wide as (
	SELECT DISTINCT a.VisitSID
		, a.CIHType
		, STUFF((SELECT '; ' + CPTCode
			FROM #CPT b
			WHERE (a.VisitSID = b.VisitSID
				AND a.CIHType = b.CIHType)
			FOR XML PATH('')), 1, 1, '') as CPT_codes
	FROM #CPT a
)
SELECT DISTINCT a.VisitSID
	, a.CIHType
	, a.CPT_num_terms
	, term.CPT_codes
INTO #CPT_wide
FROM all_visits a
LEFT JOIN CPT_terms_wide term
	on a.VisitSID = term.VisitSID
		AND a.CIHType = term.CIHType;

/*** Char4 ***/
/*drop table if exists #CHAR4;
select distinct A.VisitSID
	, B.NationalChar4 as CHAR4_code
	, B.CIHType
	, method = 'CHAR4'
into #CHAR4 
from #outpat_visit A 
	inner join [OPCCCT_CIH].[dflt].CHAR4 B
		on A.LocationSID = B.LocationSID
WHERE B.CIHType in (@CIHType);*/

/*** STOP CODE ***/
drop table if exists #StopCode;
select distinct A.VisitSID 
	, CASE WHEN B.CIHType in (@CIHType)
		THEN B.CIHType ELSE C.CIHType END AS CIHType
	, method = 'StopCode'
into #StopCode
FROM #outpat_visit A 
	LEFT JOIN [OPCCCT_CIH].[dflt].StopCodes B
		on A.PrimaryStopCodeSID = B.StopCodeSID
	LEFT JOIN [OPCCCT_CIH].[dflt].StopCodes C
		on A.SecondaryStopCodeSID = C.StopCodeSID
WHERE (B.CIHType in (@CIHType)
	or C.CIHType in (@CIHType));

/*** Location Name ***/
drop table if exists #LocName;
select DISTINCT A.VisitSID
	, L.CIHType
	, L.LocationName
	, L.Inclusions as LN_inclusions
	, method = 'LOC'
into #LocName
from #outpat_visit A
	inner join [OPCCCT_CIH].[dflt].LocationNames L 
		on A.LocationSID = L.LocationSID
WHERE L.CIHType in (@CIHType)
	AND L.GenExcl is null 
	AND L.SpecExcl is null;

/*** Note titles ***/
drop table if exists #NT;
select DISTINCT A.VisitSID
	, L.TIUDocumentDefinition
	, L.TIUDocumentDefinitionSID
	, L.CIHType
	, L.Inclusions
	, method = 'NT'
INTO #NT
from #outpat_visit A
	INNER JOIN [cdwwork].[TIU].[TIUDocument] B
		on A.VisitSID = B.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].NoteTitles L 
		on B.TIUDocumentDefinitionSID = L.TIUDocumentDefinitionSID
WHERE L.CIHType in (@CIHType)
	AND L.GenExcl is null 
	AND L.SpecExcl is null;

--convert note title info to wide format
DROP TABLE IF EXISTS #NT_wide;
WITH all_visits as (
	SELECT VisitSID
		, CIHType
		, COUNT(DISTINCT TIUDocumentDefinitionSID) as NT_num_terms
	FROM #NT
	GROUP BY VisitSID, CIHType
), unique_incl_terms as (
	SELECT DISTINCT VisitSID
		, CIHType
		, Inclusions
	FROM #NT
), NT_incl_wide as (
	SELECT DISTINCT a.VisitSID
		, a.CIHType
		, STUFF((SELECT '; ' + Inclusions
			FROM unique_incl_terms b
			WHERE (a.VisitSID = b.VisitSID
				AND a.CIHType = b.CIHType)
			FOR XML PATH(''), type
			).value('.', 'varchar(max)'), 1, 1, '') as NT_inclusions
	FROM unique_incl_terms a
), NT_terms_wide as (
	SELECT DISTINCT a.VisitSID
		, a.CIHType
		, STUFF((SELECT '; ' + TIUDocumentDefinition
			FROM #NT b
			WHERE (a.VisitSID = b.VisitSID
				AND a.CIHType = b.CIHType)
			FOR XML PATH(''), type
			).value('.', 'varchar(max)'), 1, 1, '') as NT_terms
	FROM #NT a
)
SELECT DISTINCT a.VisitSID
	, a.CIHType
	, a.NT_num_terms
	, term.NT_terms
	, incl.NT_inclusions
INTO #NT_wide
FROM all_visits a
LEFT JOIN NT_incl_wide incl
	on a.VisitSID = incl.VisitSID
		AND a.CIHType = incl.CIHType
LEFT JOIN NT_terms_wide term
	on a.VisitSID = term.VisitSID
		AND a.CIHType = term.CIHType;

/*** Health Factors ***/
drop table if exists #HF;
select DISTINCT A.VisitSID
	, L.HealthFactorType
	, L.HealthFactorTypeSID
	, L.CIHType
	, L.Inclusions
	, method = 'HF'
	, L.SpecExcl
into #HF
from #outpat_visit A
	INNER JOIN cdwwork.[HF].[HealthFactor] B
		on A.VisitSID = B.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].HealthFactors L 
		on B.HealthFactorTypeSID = L.HealthFactorTypeSID
WHERE L.CIHType in (@CIHType)
	AND L.GenExcl is null 
	AND L.SpecExcl is null;

--convert health factors info to wide format
DROP TABLE IF EXISTS #HF_wide;
WITH all_visits as (
	SELECT VisitSID
		, CIHType
		, COUNT(DISTINCT HealthFactorTypeSID) as HF_num_terms
	FROM #HF
	GROUP BY VisitSID, CIHType
), unique_incl_terms as (
	SELECT DISTINCT VisitSID
		, CIHType
		, Inclusions
	FROM #HF
), HF_incl_wide as (
	SELECT DISTINCT a.VisitSID
		, a.CIHType
		, STUFF((SELECT '; ' + Inclusions
			FROM unique_incl_terms b
			WHERE (a.VisitSID = b.VisitSID
				AND a.CIHType = b.CIHType)
			FOR XML PATH(''), type
			).value('.', 'varchar(max)'), 1, 1, '') as HF_inclusions
	FROM unique_incl_terms a
), HF_terms_wide as (
	SELECT DISTINCT a.VisitSID
		, a.CIHType
		, STUFF((SELECT '; ' + HealthFactorType
			FROM #HF b
			WHERE (a.VisitSID = b.VisitSID
				AND a.CIHType = b.CIHType)
			FOR XML PATH(''), type
			).value('.', 'varchar(max)'), 1, 1, '') as HF_terms
	FROM #HF a
)
SELECT DISTINCT a.VisitSID
	, a.CIHType
	, a.HF_num_terms
	, term.HF_terms
	, incl.HF_inclusions
INTO #HF_wide
FROM all_visits a
LEFT JOIN HF_incl_wide incl
	on a.VisitSID = incl.VisitSID
		AND a.CIHType = incl.CIHType
LEFT JOIN HF_terms_wide term
	on a.VisitSID = term.VisitSID
		AND a.CIHType = term.CIHType;


/*** compile a consolidated list of all visits and by which methods they were found ***/
/* have a separate process for acupuncture */
DROP TABLE IF EXISTS #consolidated_methods;
CREATE TABLE #consolidated_methods (
	VisitSID bigint,
	CIHType nvarchar(25),
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

drop table if exists #cons_visits;
with intermed as (
	select VisitSID from #CPT
	union
	/*select VisitSID from #CHAR4
	union*/
	select VisitSID from #StopCode
	union 
	select VisitSID from #LocName
	union
	select VisitSID from #NT_wide
	union
	select VisitSID from #HF_wide
	)
select distinct A.VisitSID
	, CIHType = @CIHType
	, case when E.VisitSID is not null then 1 else 0 end as 'CPT'
	, E.CPT_num_terms
	, E.CPT_codes
	, case when F.VisitSID is not null then 1 else 0 end as 'NT'
	, F.NT_num_terms
	, F.NT_terms
	, F.NT_inclusions
	, case when G.VisitSID is not null then 1 else 0 end as 'LocName'
	, G.LocationName
	, G.LN_inclusions
	, case when H.VisitSID is not null then 1 else 0 end as 'HF'
	, H.HF_num_terms
	, H.HF_terms
	, H.HF_inclusions
	/*, case when I.VisitSID is not null then 1 else 0 end as 'CHAR4'
	, I.CHAR4_code*/
	, case when J.VisitSID is not null then 1 else 0 end as 'StopCode'
into #cons_visits
from intermed A
	LEFT JOIN #CPT_wide	E	on A.VisitSID = E.VisitSID
	LEFT JOIN #NT_wide	F	on A.VisitSID = F.VisitSID
	LEFT JOIN #LocName  G	on A.VisitSID = G.VisitSID
	LEFT JOIN #HF_wide	H	on A.VisitSID = H.VisitSID
	/*LEFT JOIN #CHAR4	I	on A.VisitSID = I.VisitSID*/
	LEFT JOIN #StopCode J	on A.VisitSID = J.VisitSID;
INSERT INTO #consolidated_methods SELECT * FROM #cons_visits;


/*** collect exclusions ***/

/*** CPT ***/
drop table if exists #CPT_Excl;
select distinct A.VisitSID, method = 'CPT_excl'
INTO #CPT_Excl
FROM #consolidated_methods M
	INNER JOIN [cdwwork].[Outpat].[VProcedure] A
		ON M.VisitSID = A.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].CPT C				
		ON A.cptsid = C.cptsid
WHERE C.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3);

/*** Char4 ***/
/*drop table if exists #CHAR4_Excl;
select distinct A.VisitSID, method = 'CHAR4_excl'
into #CHAR4_Excl
from #consolidated_methods M
	INNER JOIN #outpat_visit A 
		on M.VisitSID = A.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].CHAR4 B
		on A.LocationSID = B.LocationSID
WHERE B.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3);*/

/*** STOP CODE ***/
drop table if exists #StopCode_Excl;
select distinct A.VisitSID, method = 'StopCode_excl'
into #StopCode_Excl
FROM #consolidated_methods M
	INNER JOIN #outpat_visit A 
		on M.VisitSID = A.VisitSID
	LEFT JOIN [OPCCCT_CIH].[dflt].StopCodes B
		on A.PrimaryStopCodeSID = B.StopCodeSID
	LEFT JOIN [OPCCCT_CIH].[dflt].StopCodes C
		on A.SecondaryStopCodeSID = C.StopCodeSID
WHERE B.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3)
	OR C.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3);

/*** Location Name ***/
drop table if exists #LocName_Excl;
select DISTINCT A.VisitSID, method = 'LOC_excl'
into #LocName_Excl
from #consolidated_methods M
	INNER JOIN #outpat_visit A 
		on M.VisitSID = A.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].LocationNames L 
		on A.LocationSID = L.LocationSID
WHERE L.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3)
	AND L.GenExcl is null 
	AND L.SpecExcl is null;

/*** Note titles ***/
drop table if exists #NT_Excl;
select DISTINCT M.VisitSID, method = 'NT_excl'
into #NT_Excl
from #consolidated_methods M
	INNER JOIN cdwwork.[TIU].[TIUDocument] B
		on M.VisitSID = B.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].NoteTitles L 
		on B.TIUDocumentDefinitionSID = L.TIUDocumentDefinitionSID
WHERE L.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3)
	AND L.GenExcl is null 
	AND L.SpecExcl is null;

/*** Health Factors ***/
drop table if exists #HF_Excl;
select DISTINCT A.VisitSID, method = 'HF_excl'
into #HF_Excl
from #consolidated_methods M
	INNER JOIN cdwwork.[HF].[HealthFactor] A
		on M.VisitSID = A.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].HealthFactors L 
		on A.HealthFactorTypeSID = L.HealthFactorTypeSID
WHERE L.CIHType in (@CIHTypeExclusion1, @CIHTypeExclusion2, @CIHTypeExclusion3)
	AND L.GenExcl is null 
	AND L.SpecExcl is null;

/******* get additional visit info *******/
drop table if exists #consolidated_methods2;
SELECT DISTINCT C.ScrSSN
		, C.PatientSID
		, A.VisitSID
		, CONVERT(date, B.VisitDateTime) as VisitDate
		, A.CIHType
		, B.Sta6a
		, CASE WHEN TH.LocationSID is not NULL THEN 1 ELSE 0 END AS 'Tele'
		, SC1.StopCode as PrimaryStopCode
		, SC2.StopCode as SecondaryStopCode
		, CPT
		, CPT_num_terms
		, CPT_codes
		, NT
		, NT_num_terms
		, NT_terms
		, NT_inclusions		
		, LocName
		, A.LocationName
		, LN_inclusions
		, HF
		, HF_num_terms
		, HF_terms
		, HF_inclusions		
		, CHAR4
		, CHAR4_code
		, A.StopCode
		, CASE WHEN CPE.VisitSID is not NULL THEN 1 ELSE 0 END AS 'CPT_Excl'
		/*, CASE WHEN CE.VisitSID is not NULL THEN 1 ELSE 0 END AS 'CHAR4_Excl'*/
		, CASE WHEN SE.VisitSID is not NULL THEN 1 ELSE 0 END AS 'StopCode_Excl'
		, CASE WHEN HE.VisitSID is not NULL THEN 1 ELSE 0 END AS 'HF_Excl'
		, CASE WHEN LE.VisitSID is not NULL THEN 1 ELSE 0 END AS 'LocName_Excl'
		, CASE WHEN NE.VisitSID is not NULL THEN 1 ELSE 0 END AS 'NT_Excl'
INTO #consolidated_methods2
FROM #consolidated_methods A
	INNER JOIN #outpat_visit B
		on A.VisitSID = B.VisitSID
	INNER JOIN cdwwork.[SPatient].[SPatient] C
		on B.PatientSID = C.PatientSID
	LEFT JOIN [OPCCCT_CIH].[dflt].Telehealth TH
		on B.LocationSID = TH.LocationSID
	LEFT JOIN CDWWork.Dim.StopCode SC1
		on B.PrimaryStopCodeSID = SC1.StopCodeSID
	LEFT JOIN CDWWork.Dim.StopCode SC2
		on B.SecondaryStopCodeSID = SC2.StopCodeSID
	LEFT JOIN #CPT_Excl CPE
		on A.VisitSID = CPE.VisitSID
	/*LEFT JOIN #CHAR4_Excl CE
		on A.VisitSID = CE.VisitSID*/
	LEFT JOIN #StopCode_Excl SE
		on A.VisitSID = SE.VisitSID
	LEFT JOIN #HF_Excl HE
		on A.VisitSID = HE.VisitSID
	LEFT JOIN #LocName_Excl LE
		on A.VisitSID = LE.VisitSID
	LEFT JOIN #NT_Excl NE
		on A.VisitSID = NE.VisitSID;

/* remove community care stop codes */
DROP TABLE IF EXISTS #consolidated_methods3;
SELECT * INTO #consolidated_methods3 FROM #consolidated_methods2
WHERE (PrimaryStopCode is null or PrimaryStopCode not in ('459', '655','656','660', '669', '679')) 
		and (SecondaryStopCode is null or SecondaryStopCode not in ('459', '655','656','660', '669', '679'));

/**** find and exclude certain visits found only by location name ****/
DROP TABLE IF EXISTS #location_name_only_exclusions;
SELECT DISTINCT A.VisitSID 
INTO #location_name_only_exclusions
FROM #consolidated_methods3 A
	INNER JOIN cdwwork.[TIU].[TIUDocument] B
		on A.VisitSID = B.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].CIHWHLocationOnlyExclusions C
		ON B.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
WHERE CPT = 0 AND NT = 0 AND LocName = 1 AND HF= 0 AND CHAR4 = 0 AND StopCode = 0
	AND C.CIHType = @CIHType
	AND (C.GenExcl is not null OR C.SpecExcl is not null);

DROP TABLE IF EXISTS #consolidated_methods_excl1;
SELECT A.*
	, CASE WHEN B.VisitSID is not NULL THEN 1 ELSE 0 END AS 'LocOnly_Excl'
INTO #consolidated_methods_excl1 
FROM #consolidated_methods3 A
	LEFT JOIN #location_name_only_exclusions B
		ON A.VisitSID = B.VisitSID;

/**** find and exclude certain visits found only by note titles ****/
DROP TABLE IF EXISTS #note_title_only_exclusions;
SELECT DISTINCT A.VisitSID 
INTO #note_title_only_exclusions
FROM #consolidated_methods3 A
	INNER JOIN #outpat_visit B
		on A.VisitSID = B.VisitSID
	INNER JOIN [OPCCCT_CIH].[dflt].CIHWHNoteTitleOnlyExclusions C
		ON B.LocationSID = C.LocationSID
WHERE CPT = 0 AND NT = 1 AND LocName = 0 AND HF= 0 AND CHAR4 = 0 AND StopCode = 0
	AND C.CIHType = @CIHType
	AND (C.GenExcl is not null OR C.SpecExcl is not null);

DROP TABLE IF EXISTS #consolidated_methods_excl2;
SELECT A.*
	, CASE WHEN B.VisitSID is not NULL THEN 1 ELSE 0 END AS 'NTOnly_Excl'
INTO #consolidated_methods_excl2 
FROM #consolidated_methods_excl1 A
	LEFT JOIN #note_title_only_exclusions B
		ON A.VisitSID = B.VisitSID;

/****   apply exclusions on overlapping WH visits to consolidated methods table   ****/

DROP TABLE IF EXISTS #consolidated_methods_exclude;
SELECT DISTINCT VisitSID
INTO #consolidated_methods_exclude
FROM #consolidated_methods_excl2
WHERE CPT_Excl = 1
	/*OR CHAR4_Excl = 1*/
	OR StopCode_Excl = 1
	OR HF_Excl = 1
	OR LocName_Excl = 1
	OR NT_Excl = 1
	OR LocOnly_Excl = 1
	OR NTOnly_Excl = 1; 

DROP TABLE IF EXISTS WH_CIH.temp_consolidated_methods;
SELECT ScrSSN
	, PatientSID
	, VisitSID
	, VisitDate
	, CIHType
	, Sta6a
	, Tele
	, PrimaryStopCode
	, SecondaryStopCode
	, CPT
	, CPT_num_terms
	, CPT_codes
	, NT
	, NT_num_terms
	, NT_terms
	, NT_inclusions		
	, LocName
	, LocationName
	, LN_inclusions
	, HF
	, HF_num_terms
	, HF_terms
	, HF_inclusions	
	, CHAR4
	, CHAR4_code
	, StopCode
INTO [OPCCCT_CIH].[dflt].temp_consolidated_methods
FROM #consolidated_methods_excl2
WHERE VisitSID NOT IN (SELECT DISTINCT VisitSID FROM #consolidated_methods_exclude); 

END