/* PROC to pull CIH utilization and create consolidated visits table (pre-CIH exclusions) */
/* updated 06/22/2022 | Claire Chen */

use [ORD_Fix_202309007D];
go

drop proc if exists WH_CIH.pull_VA_CIH_visits;
go
create proc WH_CIH.pull_VA_CIH_visits (
	@CIHType varchar(25), -- to be updated by user
	@CIHType1 varchar(25) = '', -- leave as default value (will be updated by proc if CIHType is Acupuncture)
	@CIHType2 varchar(25) = '', -- leave as default value (will be updated by proc if CIHType is Acupuncture)
	@StartDateTime varchar(25),
	@EndDateTime varchar(25)
	)
AS
BEGIN

IF @CIHType in ('Acupuncture') 
BEGIN
	SET @CIHType1 = 'Acup-Trad'
	SET @CIHType2 = 'Acup-BFA'
END

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
FROM [Src].[Outpat_Visit] A
	inner join [ORD_Fix_202309007D].[Dflt].[CohortForJamie] coh--narrow to cohort patients
		on a.patientsid=coh.patientsid --narrow to cohort patients
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
	INNER JOIN [Src].[Outpat_VProcedure] B
		ON A.VisitSID = B.VisitSID
	inner join ORD_Fix_202309007D.WH_CIH.CPT C				
		ON B.cptsid = C.cptsid
WHERE C.CIHType in (@CIHType, @CIHType1, @CIHType2);

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
drop table if exists #CHAR4;
select distinct A.VisitSID
	, B.NationalChar4 as CHAR4_code
	, B.CIHType
	, method = 'CHAR4'
into #CHAR4 
from #outpat_visit A 
	inner join ORD_Fix_202309007D.WH_CIH.CHAR4 B
		on A.LocationSID = B.LocationSID
WHERE B.CIHType in (@CIHType, @CIHType1, @CIHType2);

/*** STOP CODE ***/
drop table if exists #StopCode;
select distinct A.VisitSID 
	, CASE WHEN B.CIHType in (@CIHType, @CIHType1, @CIHType2)
		THEN B.CIHType ELSE C.CIHType END AS CIHType
	, method = 'StopCode'
into #StopCode
FROM #outpat_visit A 
	LEFT JOIN ORD_Fix_202309007D.WH_CIH.StopCodes B
		on A.PrimaryStopCodeSID = B.StopCodeSID
	LEFT JOIN ORD_Fix_202309007D.WH_CIH.StopCodes C
		on A.SecondaryStopCodeSID = C.StopCodeSID
WHERE (B.CIHType in (@CIHType, @CIHType1, @CIHType2) 
	or C.CIHType in (@CIHType, @CIHType1, @CIHType2));

/*** Location Name ***/
drop table if exists #LocName;
WITH intermed AS (
	select DISTINCT A.VisitSID
		, L.CIHType
		, L.LocationName
		, L.Inclusions as LN_inclusions
		, MIN(L.CIHType) OVER (PARTITION BY A.VisitSID) as min_CIHType
	from #outpat_visit A
	inner join ORD_Fix_202309007D.WH_CIH.LocationNames L 
		on A.LocationSID = L.LocationSID
	WHERE L.CIHType in (@CIHType, @CIHType1, @CIHType2)
		AND L.GenExcl is null
		AND L.SpecExcl is null
)
SELECT VisitSID
	, CIHType
	, LocationName
	, LN_inclusions
	, method = 'LOC'
INTO #LocName
FROM intermed
WHERE CIHType = min_CIHType;

/*** Note titles ***/
drop table if exists #NT;
WITH intermed AS (
	SELECT DISTINCT A.VisitSID
		, L.TIUDocumentDefinition
		, L.TIUDocumentDefinitionSID
		, L.CIHType
		, L.Inclusions
		, MIN(L.CIHType) OVER (PARTITION BY A.VisitSID) as min_CIHType
	from #outpat_visit A
	INNER JOIN [Src].[TIU_TIUDocument] B
		on A.VisitSID = B.VisitSID
	INNER JOIN ORD_Fix_202309007D.WH_CIH.NoteTitles L 
		on B.TIUDocumentDefinitionSID = L.TIUDocumentDefinitionSID
	WHERE L.CIHType in (@CIHType, @CIHType1, @CIHType2)
		AND L.GenExcl is null 
		AND L.SpecExcl is null
)
SELECT VisitSID
	, TIUDocumentDefinition
	, TIUDocumentDefinitionSID
	, CIHType
	, Inclusions
	, method = 'NT'
INTO #NT
FROM intermed
WHERE CIHType = min_CIHType;

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
WITH intermed AS (
select DISTINCT A.VisitSID
	, L.HealthFactorType
	, L.HealthFactorTypeSID
	, L.CIHType
	, L.Inclusions
	, MIN(L.CIHType) OVER (PARTITION BY A.VisitSID) as min_CIHType
from #outpat_visit A
	INNER JOIN [Src].[HF_HealthFactor] B
		on A.VisitSID = B.VisitSID
	INNER JOIN ORD_Fix_202309007D.WH_CIH.HealthFactors L 
		on B.HealthFactorTypeSID = L.HealthFactorTypeSID
WHERE L.CIHType in (@CIHType, @CIHType1, @CIHType2)
	AND L.GenExcl is null 
	AND L.SpecExcl is null
)
SELECT VisitSID
	, HealthFactorType
	, HealthFactorTypeSID
	, CIHType
	, Inclusions
	, method = 'HF'
INTO #HF
FROM intermed
WHERE CIHType = min_CIHType;

--convert health factors into to wide format
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
drop table if exists #cons_visits_acup;
IF @CIHType in ('Acupuncture')
	BEGIN
	with intermed as (
		select VisitSID from #CPT
		union
		select VisitSID from #CHAR4
		union
		select VisitSID from #StopCode
		union 
		select VisitSID from #LocName
		union
		select VisitSID from #NT_wide
		union
		select VisitSID from #HF_wide
		)
	select distinct A.VisitSID
		, CASE WHEN E.CIHType = 'Acup-BFA'
			or F.CIHType = 'Acup-BFA'
			or G.CIHType = 'Acup-BFA'
			or H.CIHType = 'Acup-BFA'
			or I.CIHType = 'Acup-BFA'
			or J.CIHType = 'Acup-BFA'
			THEN 'Acup-BFA' ELSE 'Acup-Trad' END AS CIHType
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
		, case when I.VisitSID is not null then 1 else 0 end as 'CHAR4'
		, I.CHAR4_code
		, case when J.VisitSID is not null then 1 else 0 end as 'StopCode'
	into #cons_visits_acup
	from intermed A
		LEFT JOIN #CPT_wide	E	on A.VisitSID = E.VisitSID
		LEFT JOIN #NT_wide	F	on A.VisitSID = F.VisitSID
		LEFT JOIN #LocName  G	on A.VisitSID = G.VisitSID
		LEFT JOIN #HF_wide	H	on A.VisitSID = H.VisitSID
		LEFT JOIN #CHAR4	I	on A.VisitSID = I.VisitSID
		LEFT JOIN #StopCode J	on A.VisitSID = J.VisitSID;
	PRINT('DID ACUP STUFF')
	INSERT INTO #consolidated_methods SELECT * FROM #cons_visits_acup;
	END
ELSE
	BEGIN
	with intermed as (
		select VisitSID from #CPT
		union
		select VisitSID from #CHAR4
		union
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
		, case when I.VisitSID is not null then 1 else 0 end as 'CHAR4'
		, I.CHAR4_code
		, case when J.VisitSID is not null then 1 else 0 end as 'StopCode'
	into #cons_visits
	from intermed A
		LEFT JOIN #CPT_wide	E	on A.VisitSID = E.VisitSID
		LEFT JOIN #NT_wide	F	on A.VisitSID = F.VisitSID
		LEFT JOIN #LocName  G	on A.VisitSID = G.VisitSID
		LEFT JOIN #HF_wide	H	on A.VisitSID = H.VisitSID
		LEFT JOIN #CHAR4	I	on A.VisitSID = I.VisitSID
		LEFT JOIN #StopCode J	on A.VisitSID = J.VisitSID;
	PRINT('DID NON-ACUP STUFF')
	INSERT INTO #consolidated_methods SELECT * FROM #cons_visits;
	END

/**** exclusions are not collected per therapy for CIH (applied in separate proc) ****/

/**** get additional visit info ****/
drop table if exists #consolidated_methods2;
SELECT DISTINCT C.ScrSSN
		, c.PatientSID
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
		, CASE WHEN CPT = 1 OR NT = 1 OR HF = 1 or CHAR4 = 1 THEN 1 ELSE 0 END AS strong_evid
		, CASE WHEN LocName = 1 OR A.StopCode = 1 THEN 1 ELSE 0 END AS weak_evid
INTO #consolidated_methods2
FROM #consolidated_methods A
	INNER JOIN #outpat_visit B
		on A.VisitSID = B.VisitSID
	INNER JOIN [Src].[SPatient_SPatient] C
		on B.PatientSID = C.PatientSID
	LEFT JOIN ORD_Fix_202309007D.WH_CIH.Telehealth TH
		on B.LocationSID = TH.LocationSID
	LEFT JOIN CDWWork.Dim.StopCode SC1
		on B.PrimaryStopCodeSID = SC1.StopCodeSID
	LEFT JOIN CDWWork.Dim.StopCode SC2
		on B.SecondaryStopCodeSID = SC2.StopCodeSID;

/**** remove community care stop codes ****/
DROP TABLE IF EXISTS #consolidated_methods3;
SELECT * INTO #consolidated_methods3 FROM #consolidated_methods2
WHERE (PrimaryStopCode is null or PrimaryStopCode not in ('459', '655','656','660', '669', '679')) 
		and (SecondaryStopCode is null or SecondaryStopCode not in ('459', '655','656','660', '669', '679'));

/**** find and exclude certain visits found only by location name ****/
DROP TABLE IF EXISTS #location_name_only_exclusions;
SELECT DISTINCT A.VisitSID 
INTO #location_name_only_exclusions
FROM #consolidated_methods3 A
	INNER JOIN [Src].[TIU_TIUDocument] B
		on A.VisitSID = B.VisitSID
	INNER JOIN ORD_Fix_202309007D.WH_CIH.CIHWHLocationOnlyExclusions C
		ON B.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
WHERE CPT = 0 AND NT = 0 AND LocName = 1 AND HF= 0 AND CHAR4 = 0 AND StopCode = 0
	AND C.CIHType = @CIHType
	AND (C.GenExcl is not null OR C.SpecExcl is not null);

DROP TABLE IF EXISTS #consolidated_methods_excl1;
SELECT * INTO #consolidated_methods_excl1 FROM #consolidated_methods3
WHERE VisitSID NOT IN (SELECT DISTINCT VisitSID FROM #location_name_only_exclusions);

/**** find and exclude certain visits found only by note titles ****/
DROP TABLE IF EXISTS #note_title_only_exclusions;
SELECT DISTINCT A.VisitSID 
INTO #note_title_only_exclusions
FROM #consolidated_methods3 A
	INNER JOIN #outpat_visit B
		on A.VisitSID = B.VisitSID
	INNER JOIN ORD_Fix_202309007D.WH_CIH.CIHWHNoteTitleOnlyExclusions C
		ON B.LocationSID = C.LocationSID
WHERE CPT = 0 AND NT = 1 AND LocName = 0 AND HF= 0 AND CHAR4 = 0 AND StopCode = 0
	AND C.CIHType = @CIHType
	AND (C.GenExcl is not null OR C.SpecExcl is not null);

DROP TABLE IF EXISTS WH_CIH.temp_consolidated_methods;
SELECT * INTO WH_CIH.temp_consolidated_methods FROM #consolidated_methods_excl1
WHERE VisitSID NOT IN (SELECT DISTINCT VisitSID FROM #note_title_only_exclusions);

END