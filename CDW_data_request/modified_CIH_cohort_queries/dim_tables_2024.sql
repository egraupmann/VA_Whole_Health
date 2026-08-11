
/* make Dim tables for inclusion/exclusion criteria used in WH/CIH utilization querying */
/* last updated: 4/12/23 */

/*
Dim tables:
	- CHAR4
	- CPT
	- Stop codes
	- Health factors
	- location names
	- note titles	
	- location name only exclusions
	- note title only exclusions
	- telehealth
*/

/********************************/
/****** CHAR4 *******************/
/********************************/

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.CHAR4;
SELECT C.LocationSID
	, B.DSSLocationSID
	, A.DSSLocationStopCodeSID
	, A.Sta3n
	, D.Sta6a
	, A.NationalChar4
	, A.NationalChar4Description
	, CASE 
		WHEN A.NationalChar4 in ('ACUP') THEN 'Acup-Trad'
		WHEN A.NationalChar4 in ('IACT') THEN 'Acup-BFA'
		WHEN A.NationalChar4 in ('BIOF') THEN 'Biofeedback'
		WHEN A.NationalChar4 in ('RHGC') THEN 'Chiropractic'
		WHEN A.NationalChar4 in ('GIMA') THEN 'Guided Imagery'
		WHEN A.NationalChar4 in ('HYPN') THEN 'Hypnosis'
		WHEN A.NationalChar4 in ('MANT', 'MBSR', 'MDTN', 'MMMT') THEN 'Meditation'
		WHEN A.NationalChar4 in ('TAIC', 'CGQC') THEN 'TaiChi'
		WHEN A.NationalChar4 in ('YOGA') THEN 'Yoga'
		WHEN A.NationalChar4 in ('IDHC', 'SCVT', 'SNVC', 'WCGC') THEN 'WH-Clinical'
		WHEN A.NationalChar4 in ('SCHC', 'HTAC','HTFC','RLFX','WCEC') THEN 'WH-Activities'
		WHEN A.NationalChar4 in ('WCDC','WCHC') THEN 'WH-Coach'
		END AS CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
INTO ORD_Fix_202309007D.WH_CIH.CHAR4
FROM CDWWork.Dim.DSSLocationStopCode A
	INNER JOIN CDWWork.Dim.DSSLocation B
		on A.DSSLocationStopCodeSID = B.DSSLocationStopCodeSID
	INNER JOIN CDWWork.Dim.[Location] C
		on B.LocationSID = C.LocationSID
	INNER JOIN CDWWork.Dim.Division D
		on C.DivisionSID = D.DivisionSID
WHERE A.NationalChar4 in (
	'ACUP', 'IACT', 'BIOF', 'RHGC', 'GIMA', 'HYPN', 
	'MANT', 'MBSR', 'MDTN', 'MMMT',
	'TAIC', 'CGQC',
	'YOGA',
	'IDHC', 'SCVT', 'SNVC', 'WCGC',
	'SCHC','HTAC','HTFC','RLFX','WCEC',
	'WCDC','WCHC');

/********************************/
/******** CPT *******************/
/********************************/

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.CPT;
SELECT CPTSID
	, Sta3n
	, CPTCode
	, CPTName
	, CPTDescription
	, CASE 
		WHEN CPTCode in ('97810', '97811', '97813', '97814') THEN 'Acup-Trad'
		WHEN CPTCode in ('90901', '90911', '90875', '90876') THEN 'Biofeedback'
		WHEN CPTCode in ('98941', '98940', '98942', '98943') THEN 'Chiropractic'
		WHEN CPTCode in ('90880') THEN 'Hypnosis'
		WHEN CPTCode in ('97124') THEN 'Massage'
		WHEN CPTCode in ('97161', '97162', '97163', '97165', '97166', '97167',
			'97110', '97350', '97112', '97150', '97035', '97032', 
			'97012', '97140', '97001', '97002', '97750', '97113', 
			'97116', '97033', '97034', '97039','97003','97004','G0152') THEN 'Physical Therapy'
		/* no Tai Chi CPT codes */
		/* no Guided Imagery CPT codes */
		/* no Meditation CPT codes */
		WHEN CPTCode in ('0591T', '0592T', '0593T') THEN 'WH-Coach'
		END AS CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
INTO ORD_Fix_202309007D.WH_CIH.CPT
FROM CDWWork.Dim.CPT
WHERE CPTCode in (
	'97810', '97811', '97813', '97814',
	'90901', '90911', '90875', '90876',
	'98941', '98940', '98942', '98943',
	'90880',
	'97124',
	'97161', '97162', '97163', '97165', '97166', '97167',
	'97110', '97350', '97112', '97150', '97035', '97032', 
	'97012', '97140', '97001', '97002', '97750', '97113', 
	'97116', '97033', '97034', '97039','97003','97004','G0152',
	'0591T', '0592T', '0593T');

	
/********************************/
/****** Stop codes **************/
/********************************/

drop table if exists ORD_Fix_202309007D.WH_CIH.StopCodes;
select distinct StopCodeSID
	, StopCode
	, StopCodeName
	, CASE
		WHEN StopCode in (436) THEN 'Chiropractic'
		WHEN StopCode in (205) THEN 'Physical Therapy'
		END AS CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
into ORD_Fix_202309007D.WH_CIH.StopCodes
from cdwwork.dim.stopcode
WHERE StopCode in (436, 205);

/********************************/
/****** Health factors **********/
/********************************/

/******************************************************************************/
/**************    general HF exclusions table    *****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFGenExcl;
CREATE TABLE #HFGenExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFGenExcl (ExclString) 
VALUES ('%research%'),('%rsch%'),
   ('%refer%'),
   ('%follo%'),('%f/u%'),('%fup%'),('%fol%'),('%flwup%'),('%fl up%'),('%fll up%'),
   ('%cons%'),('%econs%'),('%e consult%'),('%e-con%'),('%cnslt%'),
   ('%com tx%'),('%comm care%'),('%com care%'),('%choice%'),('% cc %'),('%community%'),
   ('%non va%'),('%non-va%'),('%nonva%'),
   ('%vcp%'),('%outside%'),('%no show%'),('%no-show%'),('%messag%'),('%test%'),
   ('%vcl%'),('%fager%'),('%call attempt%'),('%patient letter%'),('%consent%'),
   ('%appointment request%'),('%instructions%'),('%outcome%'),('%reply%'),('%intake%'),
   ('%eval%'),('%reminder%'),('%discharge%');

/* get all unique HealthFactorTypeSIDs for these exclusions */
/* each SID may show up more than once if it matches more than one exclusion */
DROP TABLE IF EXISTS #HFGenExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFGenExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFGenExcl B on A.HealthFactorType like B.ExclString;

/* collapse to one row per HealthFactorTypeSID */
/* collect all exclusion term matches into one column for future reference */

DROP TABLE IF EXISTS #HFGenExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFGenExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFGenExclWide
FROM #HFGenExclLong a;

/******************************************************************************/
/***********************    HF ACUPUNCTURE - TRADITIONAL  *********************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFAcupExcl;
CREATE TABLE #HFAcupExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFAcupExcl (ExclString) 
VALUES ('%battlefield%'),('%bfa%'),('%acupressure%'),('%yoga%'),('%TCMLH%'),
	/* added 12/13/2021 */ ('%biacuplasty%'),('%plan%'),
	/* added 3/9/2022 */ ('%btl acp%'),('%bf acup%'),('%battlefld%'),
	('%nada%'),('%ear%'),('%auricular%');

DROP TABLE IF EXISTS #HFAcupExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFAcupExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFAcupExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFAcupExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFAcupExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFAcupExclWide
FROM #HFAcupExclLong a;

DROP TABLE IF EXISTS #HFAcupIncl;
CREATE TABLE #HFAcupIncl (
	InclString varchar (50)
	);
INSERT INTO #HFAcupIncl (InclString)
VALUES ('%acup%'),('%acpu%'); 

DROP TABLE IF EXISTS #HFAcupInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFAcupInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFAcupIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFAcupInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFAcupInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFAcupInclWide
FROM #HFAcupInclLong a;

DROP TABLE IF EXISTS #HFAcupTrad;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Acup-Trad' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFAcupTrad
FROM #HFAcupInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFAcupExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID; 

--SELECT * FROM #HFAcupTrad;

/******************************************************************************/
/**************************    HF ACUPUNCTURE - BFA    ************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFAcupBfaExcl;
CREATE TABLE #HFAcupBfaExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFAcupBfaExcl (ExclString)													
VALUES ('%acupressure%'), ('%yoga%'), ('%TCMLH%'),
	/* added 12/13/2021 */ ('%clubface%'),('%plan%'),
	/* added 7/26/2022 */ ('%labfasting%');

DROP TABLE IF EXISTS #HFAcupBfaExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFAcupBfaExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFAcupBfaExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFAcupBfaExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFAcupBfaExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFAcupBfaExclWide
FROM #HFAcupBfaExclLong a;

DROP TABLE IF EXISTS #HFAcupBfaIncl
CREATE TABLE #HFAcupBfaIncl (
	InclString varchar (50)
	);
INSERT INTO #HFAcupBfaIncl (InclString)
VALUES ('%bfa%'),('%battlefield%'),('%btl acp%'),('%bf acup%'),('%battlefld%'),
	('%acup%nada%'),('%acup%ear%'),('%auricular%'); 

DROP TABLE IF EXISTS #HFAcupBfaInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFAcupBfaInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFAcupBfaIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFAcupBfaInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFAcupBfaInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFAcupBfaInclWide
FROM #HFAcupBfaInclLong a;

DROP TABLE IF EXISTS #HFAcupBFA;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Acup-BFA' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFAcupBFA																		
FROM #HFAcupBfaInclWide A
	LEFT JOIN #HFGenExclWide B		ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFAcupBfaExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFAcupBFA WHERE GenExcl is not null or SpecExcl is not null;
--SELECT * FROM #HFAcupBfaExclWide;

/******************************************************************************/
/**************************     HF BIOFEEDBACK    *****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFBioExcl;
CREATE TABLE #HFBioExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFBioExcl (ExclString)													
VALUES ('%offered%'),('%plan%');

DROP TABLE IF EXISTS #HFBioExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFBioExclLong 
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFBioExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFBioExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFBioExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFBioExclWide
FROM #HFBioExclLong a;

DROP TABLE IF EXISTS #HFBioIncl
CREATE TABLE #HFBioIncl (
	InclString varchar (50)
	);
INSERT INTO #HFBioIncl (InclString)
VALUES ('%biofeed%'),('%neurofeed%'),('%bio feed%'),('%neuro feed%'); 

DROP TABLE IF EXISTS #HFBioInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFBioInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFBioIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFBioInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFBioInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFBioInclWide
FROM #HFBioInclLong a;

DROP TABLE IF EXISTS #HFBiofeedback;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Biofeedback' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFBiofeedback																		
FROM #HFBioInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFBioExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFBiofeedback;

/******************************************************************************/
/**************************      HF Guided Imagery   **************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFGimaExcl;
CREATE TABLE #HFGimaExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFGimaExcl (ExclString)													
VALUES ('%core%'), ('%ultrasound%'), ('%biopsy%'),
	/* added by LA team */ ('%lab%'), ('%teach%'),
	/* added 12/13/21 */ ('%discovery%'), ('%maneuvering%'), ('%medit%'), 
	('%guided BX%'),('%plan%');

DROP TABLE IF EXISTS #HFGimaExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFGimaExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFGimaExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFGimaExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFGimaExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFGimaExclWide
FROM #HFGimaExclLong a;

DROP TABLE IF EXISTS #HFGimaIncl
CREATE TABLE #HFGimaIncl (
	InclString varchar (50)
	);
INSERT INTO #HFGimaIncl (InclString)
VALUES ('%gima%'),('%guided%'),('%imagery%'),('%guided image%');

DROP TABLE IF EXISTS #HFGimaInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFGimaInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFGimaIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFGimaInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFGimaInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFGimaInclWide
FROM #HFGimaInclLong a;

DROP TABLE IF EXISTS #HFGIMA;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Guided Imagery' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFGIMA																		
FROM #HFGimaInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFGimaExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFGIMA;
	
/******************************************************************************/
/**************************     HF HYPNOSIS      ******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFHypExcl;
CREATE TABLE #HFHypExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFHypExcl (ExclString)													
VALUES ('%hypnotic%'), 
	/* added by LA team */ ('%tach%'),
	/* added 12/13/21 */ ('%plan%');

DROP TABLE IF EXISTS #HFHypExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFHypExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFHypExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFHypExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFHypExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFHypExclWide
FROM #HFHypExclLong a;

DROP TABLE IF EXISTS #HFHypIncl
CREATE TABLE #HFHypIncl (
	InclString varchar (50)
	);
INSERT INTO #HFHypIncl (InclString)
VALUES ('%HYPN%'),('%hypno%'),('%hypnosis%'),('%hypnotherapy%'); 

DROP TABLE IF EXISTS #HFHypInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFHypInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFHypIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFHypInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFHypInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFHypInclWide
FROM #HFHypInclLong a;

DROP TABLE IF EXISTS #HFHyp;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Hypnosis' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFHyp																		
FROM #HFHypInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFHypExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFHyp;

/******************************************************************************/
/**************************     HF MEDITATION    ******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFMedExcl;
CREATE TABLE #HFMedExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFMedExcl (ExclString)													
VALUES ('%TaiChi%'), ('%TaiC%'), ('%Tai Chi%'), ('%TaiJi%'), ('%Tai Ji%'), 
	('%QiGong%'), ('%Qi Gong%'), ('%yoga%'),('%plan%');

DROP TABLE IF EXISTS #HFMedExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFMedExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFMedExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFMedExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFMedExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFMedExclWide
FROM #HFMedExclLong a;

DROP TABLE IF EXISTS #HFMedIncl
CREATE TABLE #HFMedIncl (
	InclString varchar (50)
	);
INSERT INTO #HFMedIncl (InclString)
VALUES ('%Mindful%'),('%Mantram%'),('%Meditation%')
	,('%iRest%'),('%MBSR%');

DROP TABLE IF EXISTS #HFMedInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFMedInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFMedIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFMedInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFMedInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFMedInclWide
FROM #HFMedInclLong a;

DROP TABLE IF EXISTS #HFMed;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Meditation' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFMed																		
FROM #HFMedInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFMedExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFMed;

/******************************************************************************/
/**************************     HF TAI CHI      *******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFTaicExcl;
CREATE TABLE #HFTaicExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFTaicExcl (ExclString)													
VALUES ('%iRest%'), ('%yoga%'),('%plan%');

DROP TABLE IF EXISTS #HFTaicExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFTaicExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFTaicExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFTaicExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFTaicExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFTaicExclWide
FROM #HFTaicExclLong a;

DROP TABLE IF EXISTS #HFTaicIncl
CREATE TABLE #HFTaicIncl (
	InclString varchar (50)
	);
INSERT INTO #HFTaicIncl (InclString)
VALUES ('%TaiChi%'),('%TaiC%'),('%Tai Chi%')
	,('%TaiJi%'),('%Tai Ji%'),('%QiGong%'),('%Qi Gong%');

DROP TABLE IF EXISTS #HFTaicInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFTaicInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFTaicIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFTaicInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFTaicInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFTaicInclWide
FROM #HFTaicInclLong a;

DROP TABLE IF EXISTS #HFTaiChi;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'TaiChi' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFTaiChi																		
FROM #HFTaicInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFTaicExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFTaiChi;
	
/******************************************************************************/
/**************************     HF YOGA      **********************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFYogaExcl;
CREATE TABLE #HFYogaExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFYogaExcl (ExclString)													
VALUES ('%iRest%'), 
	/* added by LA team */ ('%ordered%'),
	/* added 12/13/21 */ ('%PHP%'),('%plan%');

DROP TABLE IF EXISTS #HFYogaExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFYogaExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFYogaExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFYogaExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFYogaExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFYogaExclWide
FROM #HFYogaExclLong a;

DROP TABLE IF EXISTS #HFYogaIncl
CREATE TABLE #HFYogaIncl (
	InclString varchar (50)
	);
INSERT INTO #HFYogaIncl (InclString)
VALUES ('%Yoga%')

DROP TABLE IF EXISTS #HFYogaInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFYogaInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFYogaIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFYogaInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFYogaInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFYogaInclWide
FROM #HFYogaInclLong a;

DROP TABLE IF EXISTS #HFYoga;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'Yoga' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFYoga																		
FROM #HFYogaInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFYogaExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFYoga WHERE SpecExcl is not null;

/******************************************************************************/
/**************************    HF WH - CLINICAL      **************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFWHClinExcl;
CREATE TABLE #HFWHClinExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFWHClinExcl (ExclString)													
VALUES ('%SPH%'), ('%infusion%'), ('%phine%'), ('%release%'), ('%phil%'),
	('%phic%'), ('%one%'), ('%neg%'), ('%diarrhea%'), ('%mam%'), ('%memphis%'),
	('%constipation%'), ('%graphic%'), ('%refused%'), ('%declined%'),
	/* added 12/13/21 */ ('%plan%');

DROP TABLE IF EXISTS #HFWHClinExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFWHClinExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFWHClinExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFWHClinExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFWHClinExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFWHClinExclWide
FROM #HFWHClinExclLong a;

DROP TABLE IF EXISTS #HFWHClinIncl
CREATE TABLE #HFWHClinIncl (
	InclString varchar (50)
	);
INSERT INTO #HFWHClinIncl (InclString)
VALUES ('VA-WHS - Changing the conversation' )
	, ('VA-WHS - Mapping to the Map')
	, ('VA-WHS - Map to the map') 
	, ('VA-WHS - Integrative Health')
	, ('VA-PHP MAP')
	, ('VA-PHP my Goal')
	, ('VA-PHP Shared Goals')
	, ('VA-WHS - AFHS-IDENTIFY PATIENT PRIORITIES')
	, ('VA-WHS - AFHS-PATIENT PRIORITIES FOLLOW-UP')
	, ('VA-WHS - AGE-FRIENDLY-WHAT MATTERS')
	, ('VA-WHS - AGE-FRIENDLY MEDICATION')
	, ('VA-WHS - AGE-FRIENDLY-4MS')
	, ('VA-WHS - AGE-FRIENDLY-MENTATION')
	, ('VA-WHS - AGE-FRIENDLY-MOBILITY');

DROP TABLE IF EXISTS #HFWHClinInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFWHClinInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFWHClinIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFWHClinInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFWHClinInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFWHClinInclWide
FROM #HFWHClinInclLong a;

DROP TABLE IF EXISTS #HFWHClinical;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'WH-Clinical' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFWHClinical																		
FROM #HFWHClinInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFWHClinExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID;	

--SELECT * FROM #HFWHClinical;

/******************************************************************************/
/**************************     HF WH - ACTIVITIES      ***********************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFWHActExcl;
CREATE TABLE #HFWHActExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFWHActExcl (ExclString)													
VALUES ('%php map%'), ('%php shared goals%'), ('%php-my%'), ('%PHP my Goal%'), ('%PHP Shared Goals%'),
	('%acup%'), ('%bfa%'), ('%yoga%'), ('%qi g%'), ('%qig%'), ('%taic%'), ('%tai c%'),
	('%MBSR%'), ('%medita%'), ('%mindfu%'), ('%hypn%'), ('%guided imag%'), ('%biofeed%'),('%chiro%'),
	('%aroma%'), ('%animal-assiste%'), ('%animal assisted%'), ('%creative art%'), ('%expressive art%'), 
	('%expressive arts%'),('%eye movement%'),('%healing touch%'), ('%therapeutic touch%'), ('%reiki%'), 
	('%pilates%'),('%native american heal%'), ('%massage%'),('%movement therapy%'), ('%progressive relax%'),
	('%reflexo%'), ('%integrative health%'), ('%nutr%'), ('% ntr %'), ('%whole health cog behav%'), 
	/* added by LA team 12/14/20 */ ('%acpu%'), ('%battlefield%'),('%bfa%'), ('%bio feed%'), ('%neuro feed%'), 
	('%gima%'), ('%guided%'), ('%imagery%'), ('%mantra%'), ('%irest%'), ('%Tai Ji%'), ('%Taiji%'),
	/* added by LA team 3/15/21 */ ('%SPH%'), ('%infusion%'), ('%phine%'), ('%release%'), ('%phil%'), ('%phic%'),
	('%one%'), ('%neg%'), ('%diarrhea%'), ('%mam%'), ('%memphis%'), ('%constipation%'), ('%graphic%'),
	('%refused%'), ('%declined%'), ('%acetaminophin%'), ('%dystrophic%'), ('%philip%'), ('%morphine%'), ('%postponed%'),
	('%buprenorphi%'), ('%accepted%'), ('%rocephin%'), ('%fac%'), ('%jb phi%'), ('%syphilis%'), ('%haemophilus%'),
	('%hemophilia%'), ('%catasrophic%'), ('%sphincter%'), ('%mammo%'), ('%neutrophils%'), ('%prosthetics%'), ('%vvc%'),
	('%denies%'), ('%mam benign%'),
	/* added 12/13/21 */ ('%serology%'), ('%PHIS%'), ('%PHIP%'), ('%nephi%'),
	/* added 4/11/23 */ ('%foot%'), ('%elevated%ldl%'), ('%OM/BIO%'), ('%catastrophizing%'), ('%nausea%'), 
	('%od-php%'), ('%tobacco%'),
	/*WH Coach exclusions*/ ('%WHOLE HEALTH COACH%'),('%WH COACH%');

DROP TABLE IF EXISTS #HFWHActExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFWHActExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFWHActExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFWHActExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFWHActExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFWHActExclWide
FROM #HFWHActExclLong a;

DROP TABLE IF EXISTS #HFWHActIncl
CREATE TABLE #HFWHActIncl (
	InclString varchar (50)
	);
INSERT INTO #HFWHActIncl (InclString)
VALUES ('%INTRODUCTION TO WHOLE HEALTH%')
	, ('%TAKING CHARGE LIFE AND HEALTH%')
	, ('%WHOLE HEALTH EDUCATION%') 
	, ('%WH EDUCATION%')
	, ('%my goal update%')
	/*PHP and PHI*/
	, ('%PHP%' )
	, ('%PHI%')
	, ('%Personal health inventory%')
	, ('%Personal health plan%');

DROP TABLE IF EXISTS #HFWHActInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFWHActInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFWHActIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFWHActInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFWHActInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFWHActInclWide
FROM #HFWHActInclLong a;

DROP TABLE IF EXISTS #HFWHActivities;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'WH-Activities' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFWHActivities																		
FROM #HFWHActInclWide A
	LEFT JOIN #HFGenExclWide B	 ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFWHActExclWide C ON A.HealthFactorTypeSID = C.HealthFactorTypeSID; 

/*
SELECT DISTINCT HealthFactorType FROM #HFWHActivities 
WHERE (HealthFactorType like '%phi%' or HealthFactorType like '%php%')
	AND GenExcl IS NULL and SpecExcl IS NULL;
*/

/******************************************************************************/
/**************************     HF WH - Coach      ****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #HFWHCoExcl;
CREATE TABLE #HFWHCoExcl (
	ExclString varchar(50)
	);
INSERT INTO #HFWHCoExcl (ExclString)													
VALUES ('%php map%'), ('%php shared goals%'), ('%php-may%'), ('%PHP my Goal%'), ('%PHP Shared Goals%'),
	('%acup%'), ('%bfa%'), ('%yoga%'), ('%qi g%'), ('%qig%'), ('%taic%'), ('%tai c%'),
	('%MBSR%'), ('%medita%'), ('%mindfu%'), ('%hypn%'), ('%guided imag%'), ('%biofeed%'),('%chiro%'),
	('%aroma%'), ('%animal-assiste%'), ('%animal assisted%'), ('%creative art%'), ('%expressive art%'), 
	('%expressive arts%'),('%eye movement%'),('%healing touch%'), ('%therapeutic touch%'), ('%reiki%'), 
	('%pilates%'),('%native american heal%'), ('%massage%'),('%movement therapy%'), ('%progressive relax%'),
	('%reflexo%'), ('%integrative health%'), ('%nutr%'), ('% ntr %'), ('%whole health cog behav%'), 
	/* added by LA team 12/14/20 */ ('%acpu%'), ('%battlefield%'),('%bfa%'), ('%bio feed%'), ('%neuro feed%'), 
	('%gima%'), ('%guided%'), ('%imagery%'), ('%mantra%'), ('%irest%'), ('%Tai Ji%'), ('%Taiji%'),
	/* added by LA team 3/15/21 */ ('%SPH%'), ('%infusion%'), ('%phine%'), ('%release%'), ('%phil%'), ('%phic%'),
	('%one%'), ('%neg%'), ('%diarrhea%'), ('%mam%'), ('%memphis%'), ('%constipation%'), ('%graphic%'),
	('%refused%'), ('%declined%'), ('%acetaminophin%'), ('%dystrophic%'), ('%philip%'), ('%morphine%'), ('%postponed%'),
	('%buprenorphi%'), ('%accepted%'), ('%rocephin%'), ('%fac%'), ('%jb phi%'), ('%syphilis%'), ('%haemophilus%'),
	('%hemophilia%'), ('%catasrophic%'), ('%sphincter%'), ('%mammo%'), ('%neutrophils%'), ('%prosthetics%'), ('%vvc%'),
	('%denies%'), ('%mam benign%'),
	/* added 12/13/21 */ ('%serology%'), ('%PHIS%'), ('%PHIP%'), ('%nephi%'),
	/* added 6/15/22 */ ('STRESS-WH COACH NO');

DROP TABLE IF EXISTS #HFWHCoExclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.ExclString
INTO #HFWHCoExclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFWHCoExcl B on A.HealthFactorType like B.ExclString;

DROP TABLE IF EXISTS #HFWHCoExclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + ExclString
		FROM #HFWHCoExclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as ExclStrings
INTO #HFWHCoExclWide
FROM #HFWHCoExclLong a;

DROP TABLE IF EXISTS #HFWHCoIncl
CREATE TABLE #HFWHCoIncl (
	InclString varchar (50)
	);
INSERT INTO #HFWHCoIncl (InclString)
VALUES ('%WHOLE HEALTH COACH%')
	, ('%WH COACH%');

DROP TABLE IF EXISTS #HFWHCoInclLong;
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, B.InclString
INTO #HFWHCoInclLong
FROM CDWWork.Dim.HealthFactorType A
	INNER JOIN #HFWHCoIncl B on A.HealthFactorType like B.InclString;

DROP TABLE IF EXISTS #HFWHCoInclWide;
SELECT DISTINCT a.HealthFactorTypeSID
	, a.HealthFactorType
	, (SELECT ' ' + InclString
		FROM #HFWHCoInclLong b
		WHERE (a.HealthFactorTypeSID = b.HealthFactorTypeSID
			AND a.HealthFactorType = b.HealthFactorType)
		FOR XML PATH('')) as InclStrings
INTO #HFWHCoInclWide
FROM #HFWHCoInclLong a;

DROP TABLE IF EXISTS #HFWHCoach;														
SELECT A.HealthFactorTypeSID
	, A.HealthFactorType
	, 'WH-Coach' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #HFWHCoach																		
FROM #HFWHCoInclWide A
	LEFT JOIN #HFGenExclWide B	ON A.HealthFactorTypeSID = B.HealthFactorTypeSID
	LEFT JOIN #HFWHCoExclWide C	ON A.HealthFactorTypeSID = C.HealthFactorTypeSID; 

--SELECT * FROM #HFWHCoach WHERE GenExcl is not null OR SpecExcl is not null;

/******************************************************************************/
/*********************     HF: combine into one dim table      ****************/
/******************************************************************************/

/* no HFs for chiro or massage */

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.HealthFactors;
with intermed as (
	SELECT * FROM #HFAcupTrad
	union
	SELECT * FROM #HFAcupBFA
	union 
	SELECT * FROM #HFBiofeedback
	union
	SELECT * FROM #HFGIMA
	union 
	SELECT * FROM #HFHyp
	union 
	SELECT * FROM #HFMed
	union 
	SELECT * FROM #HFTaiChi
	union 
	SELECT * FROM #HFYoga
	union 
	SELECT * FROM #HFWHClinical
	union 
	SELECT * FROM #HFWHActivities
	union 
	SELECT * FROM #HFWHCoach
	)
select * INTO ORD_Fix_202309007D.WH_CIH.HealthFactors FROM INTERMED;

/********************************/
/****** Location names **********/
/********************************/

/******************************************************************************/
/**************   LN general exclusions table    ******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNGenExcl;
CREATE TABLE #LNGenExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNGenExcl (ExclString) 
VALUES ('%research%'),('%rsch%'),
   ('%refer%'),
   ('%follo%'),('%f/u%'),('%fup%'),('%fol%'),('%flwup%'),('%fl up%'),('%fll up%'),
   ('%cons%'),('%econs%'),('%e consult%'),('%e-con%'),('%cnslt%'),
   ('%com tx%'),('%comm care%'),('%com care%'),('%choice%'),('% cc %'),('%community%'),
   ('%non va%'),('%non-va%'),('%nonva%'),
   ('%vcp%'),('%outside%'),('%no show%'),('%no-show%'),('%messag%'),('%test%'),
   ('%vcl%'),('%fager%'),('%call attempt%'),('%patient letter%'),('%consent%'),
   ('%appointment request%'),('%instructions%'),('%outcome%'),('%reply%'),('%intake%'),
   ('%eval%'),('%reminder%'),('%discharge%');

/* get all unique LocationSIDs for these exclusions */
/* each SID may show up more than once if it matches more than one exclusion */
DROP TABLE IF EXISTS #LNGenExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNGenExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNGenExcl B on A.LocationName like B.ExclString;

/* collapse to one row per LocationSID */
/* collect all exclusion term matches into one column for future reference */

DROP TABLE IF EXISTS #LNGenExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNGenExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNGenExclWide
FROM #LNGenExclLong a;
--SELECT * FROM #LNGenExclWide ORDER BY LocationSID;

/******************************************************************************/
/***********************     LN ACUPUNCTURE - TRADITIONAL    ******************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNAcupTExcl;
CREATE TABLE #LNAcupTExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNAcupTExcl (ExclString) 
VALUES ('%battlefield%'),('%bfa%'),('%BTL ACP%'),('%BF acup%'),('%/battlefield%'),('%battlefld%'),
	('%study%'),('%acupressure%'),
	/*added by LA team*/ ('%labfasting%'),('%secm%'),('%tele%'),('%bacup a%'),
	/*added 12/15/21*/ ('%battle-acu%'),('%battle acu%'),('%acupress%'),('%plan%');

DROP TABLE IF EXISTS #LNAcupTExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNAcupTExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNAcupTExcl B on A.LocationName like B.ExclString;

DROP TABLE IF EXISTS #LNAcupTExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNAcupTExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNAcupTExclWide
FROM #LNAcupTExclLong a;

/*
SELECT * FROM #LNAcupTExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNAcupTExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNAcupTExclWide;
*/

DROP TABLE IF EXISTS #LNAcupTIncl;
CREATE TABLE #LNAcupTIncl (
	InclString varchar (50)
	);
INSERT INTO #LNAcupTIncl (InclString)
VALUES ('%acup%'),('%acpu%'); 

DROP TABLE IF EXISTS #LNAcupTInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNAcupTInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNAcupTIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNAcupTInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNAcupTInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNAcupTInclWide
FROM #LNAcupTInclLong a;

/*
SELECT TOP 100 * FROM #LNAcupTInclWide;
SELECT COUNT(*) FROM #LNAcupTInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNAcupTInclWide;
*/

DROP TABLE IF EXISTS #LNAcupTrad;
SELECT A.LocationSID
	, A.LocationName
	, 'Acup-Trad' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNAcupTrad
FROM #LNAcupTInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNAcupTExclWide C	ON A.LocationSID = C.LocationSID;
--SELECT * FROM #LNAcupTrad;

/******************************************************************************/
/**************************     LN ACUPUNCTURE - BFA      *********************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNAcupBExcl;
CREATE TABLE #LNAcupBExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNAcupBExcl (ExclString) 
VALUES ('%study%'),('%acupressure%'),
	/*added by LA team*/ ('%labfasting%'),('%secm%'),('%tele%'),('%bacup a%'),
	/* added 12/15/21 */ ('%plan%');

DROP TABLE IF EXISTS #LNAcupBExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNAcupBExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNAcupBExcl B on A.LocationName like B.ExclString;

DROP TABLE IF EXISTS #LNAcupBExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNAcupBExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNAcupBExclWide
FROM #LNAcupBExclLong a;

/*
SELECT TOP 1000 * FROM #LNAcupBExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNAcupBExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNAcupBExclWide;
*/

DROP TABLE IF EXISTS #LNAcupBIncl
CREATE TABLE #LNAcupBIncl (
	InclString varchar (50)
	);
INSERT INTO #LNAcupBIncl (InclString)
VALUES ('%battlefield%'),('%bfa%')
	, ('%BTL ACP%'),('%BF acup%')
	, ('%battlefld%'),('%/battlefield%')
	, ('%battle-acu%'),('%battle acu%'); 

DROP TABLE IF EXISTS #LNAcupBInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNAcupBInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNAcupBIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNAcupBInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNAcupBInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNAcupBInclWide
FROM #LNAcupBInclLong a;

/*
SELECT TOP 1000 * FROM #LNAcupBInclWide;
SELECT COUNT(*) FROM #LNAcupBInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNAcupBInclWide;
*/

DROP TABLE IF EXISTS #LNAcupBFA;
SELECT A.LocationSID
	, A.LocationName
	, 'Acup-BFA' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNAcupBFA
FROM #LNAcupBInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNAcupBExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNAcupBFA;
	
/******************************************************************************/
/**************************     LN BIOFEEDBACK      ***************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNBioExcl;
CREATE TABLE #LNBioExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNBioExcl (ExclString) 
VALUES /* added 12/15/21 */ ('%plan%');

DROP TABLE IF EXISTS #LNBioExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNBioExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNBioExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNBioExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNBioExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNBioExclWide
FROM #LNBioExclLong a;

/*
SELECT TOP 1000 * FROM #LNBioExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNBioExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNBioExclWide;
*/

DROP TABLE IF EXISTS #LNBioIncl
CREATE TABLE #LNBioIncl (
	InclString varchar (50)
	);
INSERT INTO #LNBioIncl (InclString)
VALUES ('%biofeed%'),('%bio feed%')
	, ('%neurofeed%'),('%neuro feed%'); 

DROP TABLE IF EXISTS #LNBioInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNBioInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNBioIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNBioInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNBioInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNBioInclWide
FROM #LNBioInclLong a;

/*
SELECT TOP 1000 * FROM #LNBioInclWide;
SELECT COUNT(*) FROM #LNBioInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNBioInclWide;
*/

DROP TABLE IF EXISTS #LNBiofeedback;
SELECT A.LocationSID
	, A.LocationName
	, 'Biofeedback' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNBiofeedback
FROM #LNBioInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNBioExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNBiofeedback;

/******************************************************************************/
/**************************     LN Chiro      *********************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNChiroExcl;
CREATE TABLE #LNChiroExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNChiroExcl (ExclString) 
VALUES ('%care-x%'),('%CC-CHIROPRACTIC-X%'),
	/*added by LA team*/ ('%accu%'),('%ymca%'),('%fee%'),('%bfa%'),
	('%chiron%'),('%secmsg%'),('%secure%'),('%rsvp%'),
	('%plan%');

DROP TABLE IF EXISTS #LNChiroExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNChiroExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNChiroExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNChiroExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNChiroExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNChiroExclWide
FROM #LNChiroExclLong a;

/*
SELECT TOP 1000 * FROM #LNChiroExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNChiroExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNChiroExclWide;
*/

DROP TABLE IF EXISTS #LNChiroIncl
CREATE TABLE #LNChiroIncl (
	InclString varchar (50)
	);
INSERT INTO #LNChiroIncl (InclString)
VALUES ('%chiro%'); 

DROP TABLE IF EXISTS #LNChiroInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNChiroInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNChiroIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNChiroInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNChiroInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNChiroInclWide
FROM #LNChiroInclLong a;

/*
SELECT TOP 1000 * FROM #LNChiroInclWide;
SELECT COUNT(*) FROM #LNChiroInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNChiroInclWide;
*/

DROP TABLE IF EXISTS #LNChiro;
SELECT A.LocationSID
	, A.LocationName
	, 'Chiropractic' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNChiro
FROM #LNChiroInclWide A
	LEFT JOIN #LNGenExclWide B	 ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNChiroExclWide C ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNChiro;

/******************************************************************************/
/**************************     LN Guided Imagery      ************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNGimaExcl;
CREATE TABLE #LNGimaExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNGimaExcl (ExclString) 
VALUES /*added by LA team*/('%biopsy%'),('%rheum%'),('%med%'),('%procedures%'),
	/*added 12/15/21*/ ('%rehearsal%'),('%plan%');

DROP TABLE IF EXISTS #LNGimaExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNGimaExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNGimaExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNGimaExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNGimaExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNGimaExclWide
FROM #LNGimaExclLong a;

/*
SELECT TOP 1000 * FROM #LNGimaExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNGimaExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNGimaExclWide;
*/

DROP TABLE IF EXISTS #LNGimaIncl
CREATE TABLE #LNGimaIncl (
	InclString varchar (50)
	);
INSERT INTO #LNGimaIncl (InclString)
VALUES ('%guided%'),('%guided image%'),('%imagery%'); 

DROP TABLE IF EXISTS #LNGimaInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNGimaInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNGimaIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNGimaInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNGimaInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNGimaInclWide
FROM #LNGimaInclLong a;

/*
SELECT TOP 1000 * FROM #LNGimaInclWide;
SELECT COUNT(*) FROM #LNGimaInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNGimaInclWide;
*/

DROP TABLE IF EXISTS #LNGima;
SELECT A.LocationSID
	, A.LocationName
	, 'Guided Imagery' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNGima
FROM #LNGimaInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNGimaExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNGima;

/******************************************************************************/
/**************************     LN HYPNOSIS      ******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNHypExcl;
CREATE TABLE #LNHypExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNHypExcl (ExclString) 
VALUES /*added 12/15/21*/ ('%hypnotic%'),('%plan%');

DROP TABLE IF EXISTS #LNHypExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNHypExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNHypExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNHypExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNHypExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNHypExclWide
FROM #LNHypExclLong a;

/*
SELECT TOP 1000 * FROM #LNHypExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNHypExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNHypExclWide;
*/

DROP TABLE IF EXISTS #LNHypIncl
CREATE TABLE #LNHypIncl (
	InclString varchar (50)
	);
INSERT INTO #LNHypIncl (InclString)
VALUES ('%HYPNO%'),('%hypn%'),('%hypnosis%'),('%hypnotherapy%'); 

DROP TABLE IF EXISTS #LNHypInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNHypInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNHypIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNHypInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNHypInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNHypInclWide
FROM #LNHypInclLong a;

/*
SELECT TOP 1000 * FROM #LNHypInclWide;
SELECT COUNT(*) FROM #LNHypInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNHypInclWide;
*/

DROP TABLE IF EXISTS #LNHyp;
SELECT A.LocationSID
	, A.LocationName
	, 'Hypnosis' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNHyp
FROM #LNHypInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNHypExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNHyp;

/******************************************************************************/
/**************************     LN MEDITATION      ****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNMedExcl;
CREATE TABLE #LNMedExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNMedExcl (ExclString) 
VALUES /*added by LA team 4/22/20*/ ('%firestone%'),('%eating%'),('%mindful yoga%'),
	/*added 12/15/21*/ ('%firest%'),('%cooking%'),('%yoga%'),('%coping%'),('%plan%');

DROP TABLE IF EXISTS #LNMedExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNMedExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNMedExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNMedExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNMedExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNMedExclWide
FROM #LNMedExclLong a;

/*
SELECT TOP 1000 * FROM #LNMedExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNMedExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNMedExclWide;
*/

DROP TABLE IF EXISTS #LNMedIncl
CREATE TABLE #LNMedIncl (
	InclString varchar (50)
	);
INSERT INTO #LNMedIncl (InclString)
VALUES ('%Mindful%'),('%Mantram%')
	, ('%meditation%'),('%iRest%'),('%MBSR%'); 

DROP TABLE IF EXISTS #LNMedInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNMedInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNMedIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNMedInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNMedInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNMedInclWide
FROM #LNMedInclLong a;

/*
SELECT TOP 1000 * FROM #LNMedInclWide;
SELECT COUNT(*) FROM #LNMedInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNMedInclWide;
*/

DROP TABLE IF EXISTS #LNMed;
SELECT A.LocationSID
	, A.LocationName
	, 'Meditation' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNMed
FROM #LNMedInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNMedExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNMed;

/******************************************************************************/
/**************************    LN TAI CHI      ********************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNTaicExcl;
CREATE TABLE #LNTaicExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNTaicExcl (ExclString) 
VALUES /*added by flagship */('%iRest%'),
	/*added 12/15/21*/ ('% mataic%'),('%yoga%'),('%plan%');

DROP TABLE IF EXISTS #LNTaicExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNTaicExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNTaicExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNTaicExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNTaicExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNTaicExclWide
FROM #LNTaicExclLong a;

/*
SELECT TOP 1000 * FROM #LNTaicExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNTaicExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNTaicExclWide;
*/

DROP TABLE IF EXISTS #LNTaicIncl
CREATE TABLE #LNTaicIncl (
	InclString varchar (50)
	);
INSERT INTO #LNTaicIncl (InclString)
VALUES ('%TaiChi%'),('%TaiJi%')
	, ('%Tai Ji%'),('%TaiC%')
	, ('%Tai Chi%'),('%Qi Gong%'),('%QiGong%'); 

DROP TABLE IF EXISTS #LNTaicInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNTaicInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNTaicIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNTaicInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNTaicInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNTaicInclWide
FROM #LNTaicInclLong a;

/*
SELECT TOP 1000 * FROM #LNTaicInclWide;
SELECT COUNT(*) FROM #LNTaicInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNTaicInclWide;
*/

DROP TABLE IF EXISTS #LNTaiChi;
SELECT A.LocationSID
	, A.LocationName
	, 'TaiChi' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNTaiChi
FROM #LNTaicInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNTaicExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNTaiChi;

/******************************************************************************/
/**************************     LN YOGA      **********************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNYogaExcl;
CREATE TABLE #LNYogaExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNYogaExcl (ExclString) 
VALUES ('%iRest%'),('%plan%');

DROP TABLE IF EXISTS #LNYogaExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNYogaExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNYogaExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNYogaExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNYogaExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNYogaExclWide
FROM #LNYogaExclLong a;

/*
SELECT TOP 1000 * FROM #LNYogaExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNYogaExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNYogaExclWide;
*/

DROP TABLE IF EXISTS #LNYogaIncl
CREATE TABLE #LNYogaIncl (
	InclString varchar (50)
	);
INSERT INTO #LNYogaIncl (InclString)
VALUES ('%Yoga%'); 

DROP TABLE IF EXISTS #LNYogaInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNYogaInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNYogaIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNYogaInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNYogaInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNYogaInclWide
FROM #LNYogaInclLong a;

/*
SELECT TOP 1000 * FROM #LNYogaInclWide;
SELECT COUNT(*) FROM #LNYogaInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNYogaInclWide;
*/

DROP TABLE IF EXISTS #LNYoga;
SELECT A.LocationSID
	, A.LocationName
	, 'Yoga' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNYoga
FROM #LNYogaInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNYogaExclWide C	ON A.LocationSID = C.LocationSID;
--SELECT * FROM #LNYoga;

/******************************************************************************/
/**************************     LN WH - ACTIVITIES      ***********************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNWHActExcl;
CREATE TABLE #LNWHActExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNWHActExcl (ExclString) 
VALUES ('%acup%'),('%bfa%'),('%yoga%'),('%qi g%'),('%qig%'),('%taic%'),('%tai c%'),
	('%MBSR%'),('%medita%'),('%mindfu%'),('%hypn%'),('%guided imag%'),('%biofeed%'),('%chiro%'),
	('%aroma%'),('%animal-assisted%'),('%animal assisted%'),('%creative art%'),('%expressive arts%'),
	('%eye movement%'),('%healing touch%'),('%therapeutic touch%'),('%reiki%'),('%pilates%'),
	('%native american heal%'),('%massage%'),('%movement therapy%'),('%progressive relax%'),
	('%reflexo%'),('%nutr%'),('% ntr %'),('%whole health cog behav%'),
	/*added by LA 12/14/20*/ ('%acpu%'),('%battlefield%'),('%btl acp%'),('%BF acup%'),
	('%battlefld%'),('%bio feed%'),('%neurofeed%'),('%neuro feed%'),('%guided%'),('%imagery%'),
	('%mantra%'),('%irest%'),('%Tai Ji%'),
	/*added by LA 3/15/21*/ ('%phillips%'),('%phic%'),('%phine%'),('%memphis%'),
	('%buprenorphine%'),('%rocephin%'),('%phil%'),('%sapphire%'),('%graphic%'),('%emergency%'),
	/*WH Coach exclusions*/ ('%Whole Health%Coach%'),('%Whole hlth%Coach%'),('%Whl Hlth%Coach%'),
	('%Whole-h%Coach%'),('%WHLHLTH%Coach%'),('%WH%Coach%'),('%CIH%Coach%');

DROP TABLE IF EXISTS #LNWHActExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNWHActExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNWHActExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNWHActExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNWHActExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNWHActExclWide
FROM #LNWHActExclLong a;

/*
SELECT TOP 1000 * FROM #LNWHActExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNWHActExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNWHActExclWide;
*/

DROP TABLE IF EXISTS #LNWHActIncl
CREATE TABLE #LNWHActIncl (
	InclString varchar (50)
	);
INSERT INTO #LNWHActIncl (InclString)
VALUES ('%Taking Charge%')
	, ('%TCMLH%')
	, ('%Introduction to Whole Health%')
	, ('%Introduction to WH%')
	, ('%Whole Health Orientation%')
	, ('%WH Orientation%')
	, ('%Whole Health Introduction%')
	, ('%WH Introduction%')
	, ('%WH%Pathway%')
	, ('%Whole Health%pathway%')
	, ('%Whole hlth%pathway%')
	, ('%Whl Hlth%pathway%')
	, ('%Whole-h%pathway%')
	, ('%WHLHLTH%pathway%')
	, ('%Whole Health Education%')
	, ('%WH Education%')
	, ('%Personal health inventory%')
	, ('%Personal health plan%')
	, ('%Whole Health PHI%')
	, ('%Whole Health PHP%')
	, ('%WH PHI%')
	, ('%WH PHP%')
	, ('%Whole hlth PHP%')
	, ('%Whole hlth PHI%'); 

DROP TABLE IF EXISTS #LNWHActInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNWHActInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNWHActIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNWHActInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNWHActInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNWHActInclWide
FROM #LNWHActInclLong a;

/*
SELECT TOP 1000 * FROM #LNWHActInclWide;
SELECT COUNT(*) FROM #LNWHActInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNWHActInclWide;
*/

DROP TABLE IF EXISTS #LNWHActivities;
SELECT A.LocationSID
	, A.LocationName
	, 'WH-Activities' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNWHActivities
FROM #LNWHActInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNWHActExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNWHActivities;

/******************************************************************************/
/**************************     LN WH - COACH      ****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LNWHCoExcl;
CREATE TABLE #LNWHCoExcl (
	ExclString varchar(50)
	);
INSERT INTO #LNWHCoExcl (ExclString) 
VALUES ('%acup%'),('%bfa%'),('%yoga%'),('%qi g%'),('%qig%'),('%taic%'),('%tai c%'),
	('%MBSR%'),('%medita%'),('%mindfu%'),('%hypn%'),('%guided imag%'),('%biofeed%'),('%chiro%'),
	('%aroma%'),('%animal-assisted%'),('%animal assisted%'),('%creative art%'),('%expressive arts%'),
	('%eye movement%'),('%healing touch%'),('%therapeutic touch%'),('%reiki%'),('%pilates%'),
	('%native american heal%'),('%massage%'),('%movement therapy%'),('%progressive relax%'),
	('%reflexo%'),('%nutr%'),('% ntr %'),('%whole health cog behav%'),
	/*added by LA 12/14/20*/ ('%acpu%'),('%battlefield%'),('%btl acp%'),('%BF acup%'),
	('%battlefld%'),('%bio feed%'),('%neurofeed%'),('%neuro feed%'),('%guided%'),('%imagery%'),
	('%mantra%'),('%irest%'),('%Tai Ji%'),
	/*added by LA 3/15/21*/ ('%phillips%'),('%phic%'),('%phine%'),('%memphis%'),
	('%buprenorphine%'),('%rocephin%'),('%phil%'),('%sapphire%'),('%graphic%'),('%emergency%');

DROP TABLE IF EXISTS #LNWHCoExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #LNWHCoExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNWHCoExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #LNWHCoExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #LNWHCoExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #LNWHCoExclWide
FROM #LNWHCoExclLong a;

/*
SELECT TOP 1000 * FROM #LNWHCoExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #LNWHCoExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNWHCoExclWide;
*/

DROP TABLE IF EXISTS #LNWHCoIncl
CREATE TABLE #LNWHCoIncl (
	InclString varchar (50)
	);
INSERT INTO #LNWHCoIncl (InclString)
VALUES ('%Whole Health%Coach%')
	, ('%Whole hlth%Coach%')
	, ('%Whl Hlth%Coach%')
	, ('%Whole-h%Coach%')
	, ('%WHLHLTH%Coach%')
	, ('%WH%Coach%')
	, ('%CIH%Coach%'); 

DROP TABLE IF EXISTS #LNWHCoInclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.InclString
INTO #LNWHCoInclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #LNWHCoIncl B on A.LocationName like B.InclString; 

DROP TABLE IF EXISTS #LNWHCoInclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + InclString
		FROM #LNWHCoInclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as InclStrings
INTO #LNWHCoInclWide
FROM #LNWHCoInclLong a;

/*
SELECT TOP 1000 * FROM #LNWHCoInclWide;
SELECT COUNT(*) FROM #LNWHCoInclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #LNWHCoInclWide;
*/

DROP TABLE IF EXISTS #LNWHCoach;
SELECT A.LocationSID
	, A.LocationName
	, 'WH-Coach' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LNWHCoach
FROM #LNWHCoInclWide A
	LEFT JOIN #LNGenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #LNWHCoExclWide C	ON A.LocationSID = C.LocationSID; 
--SELECT * FROM #LNWHCoach;

/******************************************************************************/
/*********************     LN: combine into one dim table      ****************/
/******************************************************************************/

/* no location names for massage or WH clinical care */

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.LocationNames;
with intermed as (
	SELECT * FROM #LNAcupTrad
	union
	SELECT * FROM #LNAcupBFA
	union 
	SELECT * FROM #LNBiofeedback
	union
	SELECT * FROM #LNChiro
	union
	SELECT * FROM #LNGima
	union 
	SELECT * FROM #LNHyp
	union 
	SELECT * FROM #LNMed
	union 
	SELECT * FROM #LNTaiChi
	union 
	SELECT * FROM #LNYoga
	union 
	SELECT * FROM #LNWHActivities
	union 
	SELECT * FROM #LNWHCoach
	)
select * INTO ORD_Fix_202309007D.WH_CIH.LocationNames FROM INTERMED;

/********************************/
/****** Note Titles *************/
/********************************/

/******************************************************************************/
/**************   NT general exclusions table   *******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTGenExcl;
CREATE TABLE #NTGenExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTGenExcl (ExclString) 
VALUES ('%research%'),('%rsch%'),
   ('%refer%'),
   ('%follo%'),('%f/u%'),('%fup%'),('%fol%'),('%flwup%'),('%fl up%'),('%fll up%'),
   ('%cons%'),('%econs%'),('%e consult%'),('%e-con%'),('%cnslt%'),
   ('%com tx%'),('%comm care%'),('%com care%'),('%choice%'),('% cc %'),('%community%'),
   ('%non va%'),('%non-va%'),('%nonva%'),
   ('%vcp%'),('%outside%'),('%no show%'),('%no-show%'),('%messag%'),('%test%'),
   ('%vcl%'),('%fager%'),('%call attempt%'),('%patient letter%'),('%consent%'),
   ('%appointment request%'),('%instructions%'),('%outcome%'),('%reply%'),('%intake%'),
   ('%eval%'),('%reminder%'),('%discharge%');

/* get all unique TIUDocumentDefinitionSIDs for these exclusions */
/* each SID may show up more than once if it matches more than one exclusion */
DROP TABLE IF EXISTS #NTGenExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTGenExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTGenExcl B on A.TIUDocumentDefinition like B.ExclString;

/* collapse to one row per LocationSID */
/* collect all exclusion term matches into one column for future reference */

DROP TABLE IF EXISTS #NTGenExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTGenExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTGenExclWide
FROM #NTGenExclLong a;
--SELECT * FROM #NTGenExclWide ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     NT ACUPUNCTURE - TRADITIONAL    ******************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTAcupTExcl;
CREATE TABLE #NTAcupTExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTAcupTExcl (ExclString) 
VALUES ('%battlefield%'),('%bfa%'),('%BTL ACP%'),('%BF acup%'),('%/battlefield%'),('%battlefld%'),
	('%chiro%'),('%acupressure%'),('%phone%'),('%plan%');

DROP TABLE IF EXISTS #NTAcupTExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTAcupTExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTAcupTExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #NTAcupTExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTAcupTExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTAcupTExclWide
FROM #NTAcupTExclLong a;

/*
SELECT TOP 1000 * FROM #NTAcupTExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTAcupTExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTAcupTExclWide;
*/

DROP TABLE IF EXISTS #NTAcupTIncl;
CREATE TABLE #NTAcupTIncl (
	InclString varchar (50)
	);
INSERT INTO #NTAcupTIncl (InclString)
VALUES ('%acup%'),('%acpu%'); 

DROP TABLE IF EXISTS #NTAcupTInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTAcupTInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTAcupTIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTAcupTInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTAcupTInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTAcupTInclWide
FROM #NTAcupTInclLong a;

/*
SELECT TOP 1000 * FROM #NTAcupTInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTAcupTInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTAcupTInclWide;
*/

DROP TABLE IF EXISTS #NTAcupTrad;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Acup-Trad' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTAcupTrad
FROM #NTAcupTInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTAcupTExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTAcupTrad;

/******************************************************************************/
/**************************     NT ACUPUNCTURE - BFA      *********************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTAcupBExcl;
CREATE TABLE #NTAcupBExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTAcupBExcl (ExclString) 
VALUES ('%note%'),('%acupressure%'),('%plan%');

DROP TABLE IF EXISTS #NTAcupBExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTAcupBExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTAcupBExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #NTAcupBExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTAcupBExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTAcupBExclWide
FROM #NTAcupBExclLong a;

/*
SELECT TOP 1000 * FROM #NTAcupBExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTAcupBExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTAcupBExclWide;
*/

DROP TABLE IF EXISTS #NTAcupBIncl
CREATE TABLE #NTAcupBIncl (
	InclString varchar (50)
	);
INSERT INTO #NTAcupBIncl (InclString)
VALUES ('%battlefield%'),('%bfa%')
	, ('%BTL ACP%'),('%BF acup%')
	, ('%battlefld%'),('%/battlefield%')
	, ('%battle-acu%'),('%battle acu%'); 

DROP TABLE IF EXISTS #NTAcupBInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTAcupBInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTAcupBIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTAcupBInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTAcupBInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTAcupBInclWide
FROM #NTAcupBInclLong a;

/*
SELECT TOP 1000 * FROM #NTAcupBInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTAcupBInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTAcupBInclWide;
*/

DROP TABLE IF EXISTS #NTAcupBFA;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Acup-BFA' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTAcupBFA
FROM #NTAcupBInclWide A
	LEFT JOIN #NTGenExclWide B	 ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTAcupBExclWide C ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID; 
--SELECT * FROM #NTAcupBFA;

/******************************************************************************/
/**************************     NT BIOFEEDBACK      ***************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTBioExcl;
CREATE TABLE #NTBioExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTBioExcl (ExclString) 
VALUES ('%cancel%'),('%baseline%'),('%plan%');

DROP TABLE IF EXISTS #NTBioExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTBioExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTBioExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTBioExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTBioExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTBioExclWide
FROM #NTBioExclLong a;

/*
SELECT TOP 1000 * FROM #NTBioExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTBioExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTBioExclWide;
*/

DROP TABLE IF EXISTS #NTBioIncl
CREATE TABLE #NTBioIncl (
	InclString varchar (50)
	);
INSERT INTO #NTBioIncl (InclString)
VALUES ('%biofeed%'),('%bio feed%')
	, ('%neurofeed%'),('%neuro feed%'); 

DROP TABLE IF EXISTS #NTBioInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTBioInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTBioIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTBioInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTBioInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTBioInclWide
FROM #NTBioInclLong a;

/*
SELECT TOP 1000 * FROM #NTBioInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTBioInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTBioInclWide;
*/

DROP TABLE IF EXISTS #NTBiofeedback;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Biofeedback' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTBiofeedback
FROM #NTBioInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTBioExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID; 
--SELECT * FROM #NTBiofeedback;

/******************************************************************************/
/**************************     NT Chiro      *********************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTChiroExcl;
CREATE TABLE #NTChiroExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTChiroExcl (ExclString) 
VALUES /*added by LA team 7/30/19*/ ('%child%'),
	/*added by LA team 2/12/20*/ ('%apmt%'),('%fee%'),('%scanned%'),
	('%metrics%'),('%education%'),
	/*added 12/16/21*/('%chiron%'),('%letter%'),('%plan%');

DROP TABLE IF EXISTS #NTChiroExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTChiroExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTChiroExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTChiroExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTChiroExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTChiroExclWide
FROM #NTChiroExclLong a;

/*
SELECT TOP 1000 * FROM #NTChiroExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTChiroExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTChiroExclWide;
*/

DROP TABLE IF EXISTS #NTChiroIncl
CREATE TABLE #NTChiroIncl (
	InclString varchar (50)
	);
INSERT INTO #NTChiroIncl (InclString)
VALUES ('%chiro%'); 

DROP TABLE IF EXISTS #NTChiroInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTChiroInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTChiroIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTChiroInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTChiroInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTChiroInclWide
FROM #NTChiroInclLong a;

/*
SELECT TOP 1000 * FROM #NTChiroInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTChiroInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTChiroInclWide;
*/

DROP TABLE IF EXISTS #NTChiro;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Chiropractic' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTChiro
FROM #NTChiroInclWide A
	LEFT JOIN #NTGenExclWide B	 ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTChiroExclWide C ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTChiro;

/******************************************************************************/
/**************************     NT Guided Imagery      ************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTGimaExcl;
CREATE TABLE #NTGimaExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTGimaExcl (ExclString) 
VALUES ('%biopsy%'),('%fee%'),
	/*added by LA 4/21/21*/ ('%endoscopic%'),('%placement%'),('%procedure%'),
	('%oncology%'),('%lung%'),('%ultrasound%'),
	/*added 12/16/21*/('%radiology%'),('%meditation%'),('%plan%');

DROP TABLE IF EXISTS #NTGimaExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTGimaExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTGimaExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTGimaExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTGimaExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTGimaExclWide
FROM #NTGimaExclLong a;

/*
SELECT TOP 1000 * FROM #NTGimaExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTGimaExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTGimaExclWide;
*/

DROP TABLE IF EXISTS #NTGimaIncl
CREATE TABLE #NTGimaIncl (
	InclString varchar (50)
	);
INSERT INTO #NTGimaIncl (InclString)
VALUES ('%guided%'),('%guided image%')
	, ('%imagery%'),('%gima%'); 

DROP TABLE IF EXISTS #NTGimaInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTGimaInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTGimaIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTGimaInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTGimaInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTGimaInclWide
FROM #NTGimaInclLong a;

/*
SELECT TOP 1000 * FROM #NTGimaInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTGimaInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTGimaInclWide;
*/

DROP TABLE IF EXISTS #NTGima;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Guided Imagery' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTGima
FROM #NTGimaInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTGimaExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTGima;

/******************************************************************************/
/**************************     NT HYPNOSIS      ******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTHypExcl;
CREATE TABLE #NTHypExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTHypExcl (ExclString) 
VALUES /*added by LA 4/22/20*/ ('%opiate%'),
	/*added 12/16/21*/ ('%hypnotic%'),('%plan%');

DROP TABLE IF EXISTS #NTHypExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTHypExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTHypExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTHypExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTHypExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTHypExclWide
FROM #NTHypExclLong a;

/*
SELECT TOP 1000 * FROM #NTHypExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTHypExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTHypExclWide;
*/

DROP TABLE IF EXISTS #NTHypIncl
CREATE TABLE #NTHypIncl (
	InclString varchar (50)
	);
INSERT INTO #NTHypIncl (InclString)
VALUES ('%HYPN%'),('%hypno%')
	, ('%hypnosis%'),('%hypnotherapy%'); 

DROP TABLE IF EXISTS #NTHypInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTHypInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTHypIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTHypInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTHypInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTHypInclWide
FROM #NTHypInclLong a;

/*
SELECT TOP 1000 * FROM #NTHypInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTHypInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTHypInclWide;
*/

DROP TABLE IF EXISTS #NTHyp;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Hypnosis' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTHyp
FROM #NTHypInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTHypExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTHyp;

/******************************************************************************/
/**************************     NT MEDITATION      ****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTMedExcl;
CREATE TABLE #NTMedExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTMedExcl (ExclString) 
VALUES /*added by LA team 4/22/20*/ ('%mindful yoga%'),('%child%'),('%mindful living%'),
	('%parent%'),('%mindful action%'),('%movement%'),('%neuro%'),('%oncology%'),
	/*added 12/16/21*/('%guided imagery%'),('%biofeed%'),('%yoga%'),('%plan%');

DROP TABLE IF EXISTS #NTMedExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTMedExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTMedExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTMedExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTMedExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTMedExclWide
FROM #NTMedExclLong a;

/*
SELECT TOP 1000 * FROM #NTMedExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTMedExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTMedExclWide;
*/

DROP TABLE IF EXISTS #NTMedIncl
CREATE TABLE #NTMedIncl (
	InclString varchar (50)
	);
INSERT INTO #NTMedIncl (InclString)
VALUES ('%Mindful%'),('%Mantram%')
	, ('%meditation%'),('%iRest%'),('%MBSR%'); 

DROP TABLE IF EXISTS #NTMedInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTMedInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTMedIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTMedInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTMedInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTMedInclWide
FROM #NTMedInclLong a;

/*
SELECT TOP 1000 * FROM #NTMedInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTMedInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTMedInclWide;
*/

DROP TABLE IF EXISTS #NTMed;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Meditation' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTMed
FROM #NTMedInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTMedExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTMed;

/******************************************************************************/
/**************************     NT TAI CHI      *******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTTaicExcl;
CREATE TABLE #NTTaicExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTTaicExcl (ExclString) 
VALUES ('%iRest%'),
	/*added 12/15/21*/ ('%yoga%'),('%plan%');

DROP TABLE IF EXISTS #NTTaicExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTTaicExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTTaicExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTTaicExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTTaicExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTTaicExclWide
FROM #NTTaicExclLong a;

/*
SELECT TOP 1000 * FROM #NTTaicExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTTaicExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTTaicExclWide;
*/

DROP TABLE IF EXISTS #NTTaicIncl
CREATE TABLE #NTTaicIncl (
	InclString varchar (50)
	);
INSERT INTO #NTTaicIncl (InclString)
VALUES ('%TaiChi%'),('%TaiJi%')
	, ('%Tai Ji%'),('%TaiC%')
	, ('%Tai Chi%'),('%Qi Gong%'),('%QiGong%'); 

DROP TABLE IF EXISTS #NTTaicInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTTaicInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTTaicIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTTaicInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTTaicInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTTaicInclWide
FROM #NTTaicInclLong a;

/*
SELECT TOP 1000 * FROM #NTTaicInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTTaicInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTTaicInclWide;
*/

DROP TABLE IF EXISTS #NTTaiChi;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'TaiChi' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTTaiChi
FROM #NTTaicInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTTaicExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTTaiChi;

/******************************************************************************/
/**************************     NT YOGA      **********************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTYogaExcl;
CREATE TABLE #NTYogaExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTYogaExcl (ExclString) 
VALUES ('%iRest%'),
	/*added by LA*/('%letter%'),('%philosophy%'),('%nidra%'),('%dvd%'),('%plan%');

DROP TABLE IF EXISTS #NTYogaExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTYogaExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTYogaExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTYogaExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTYogaExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTYogaExclWide
FROM #NTYogaExclLong a;

/*
SELECT TOP 1000 * FROM #NTYogaExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTYogaExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTYogaExclWide;
*/

DROP TABLE IF EXISTS #NTYogaIncl
CREATE TABLE #NTYogaIncl (
	InclString varchar (50)
	);
INSERT INTO #NTYogaIncl (InclString)
VALUES ('%Yoga%'); 

DROP TABLE IF EXISTS #NTYogaInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTYogaInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTYogaIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTYogaInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTYogaInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTYogaInclWide
FROM #NTYogaInclLong a;

/*
SELECT TOP 1000 * FROM #NTYogaInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTYogaInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTYogaInclWide;
*/

DROP TABLE IF EXISTS #NTYoga;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Yoga' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTYoga
FROM #NTYogaInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTYogaExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTYoga;

/******************************************************************************/
/**************************     NT WH - ACTIVITIES      ***********************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTWHActExcl;
CREATE TABLE #NTWHActExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTWHActExcl (ExclString) 
VALUES ('%acup%'),('%bfa%'),('%yoga%'),('%qi g%'),('%qig%'),('%taic%'),('%tai c%'),
	('%MBSR%'),('%medita%'),('%mindfu%'),('%hypn%'),('%guided imag%'),('%biofeed%'),('%chiro%'),
	('%aroma%'),('%animal-assisted%'),('%animal assisted%'),('%creative art%'),('%expressive arts%'),
	('%eye movement%'),('%healing touch%'),('%therapeutic touch%'),('%reiki%'),('%pilates%'),
	('%native american heal%'),('%massage%'),('%movement therapy%'),('%progressive relax%'),
	('%reflexo%'),('%nutr%'),('% ntr %'),('%whole health cog behav%'),
	/*added by LA 12/14/20*/ ('%acpu%'),('%battlefield%'),('%btl acp%'),('%BF acup%'),
	('%battlefld%'),('%bio feed%'),('%neurofeed%'),('%neuro feed%'),('%guided%'),('%imagery%'),
	( '%gima%'),('%mantra%'),('%irest%'),('%Tai Ji%'),('%TaiJi%'),
	/*added by LA 3/15/21*/ ('%phillips%'),('%phic%'),('%phine%'),('%memphis%'),
	('%buprenorphine%'),('%rocephin%'),('%phil%'),('%graphic%'),('%emergency%'),
	/*added by LA 6/24/21*/ ('%demoted%'),('%non-visit%'),('%historical%'),('%revoked%'),
	('%ex-personal%'),('%rescinded%'),
	/*WH Coach exclusions*/ ('%Whole Health%Coach%'),('%Whole hlth%Coach%'),('%Whl Hlth%Coach%'),
	('%Whole-h%Coach%'),('%WHLHLTH%Coach%'),('%WH%Coach%');

DROP TABLE IF EXISTS #NTWHActExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTWHActExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTWHActExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTWHActExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTWHActExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTWHActExclWide
FROM #NTWHActExclLong a;

/*
SELECT TOP 1000 * FROM #NTWHActExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTWHActExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTWHActExclWide;
*/

DROP TABLE IF EXISTS #NTWHActIncl
CREATE TABLE #NTWHActIncl (
	InclString varchar (50)
	);
INSERT INTO #NTWHActIncl (InclString)
VALUES ('%Taking Charge%')
	, ('%TCMLH%')
	, ('%Introduction to Whole Health%')
	, ('%Introduction to WH%')
	, ('%Whole Health Orientation%')
	, ('%WH Orientation%')
	, ('%Whole Health Introduction%')
	, ('%WH Introduction%')
	, ('%WH%Pathway%')
	, ('%Whole Health%pathway%')
	, ('%Whole hlth%pathway%')
	, ('%Whl Hlth%pathway%')
	, ('%Whole-h%pathway%')
	, ('%WHLHLTH%pathway%')
	, ('%Whole Health Education%')
	, ('%WH Education%')
	, ('%Personal health inventory%')
	, ('%Personal health plan%')
	, ('%Whole Health PHI%')
	, ('%Whole Health PHP%')
	, ('%WH PHI%')
	, ('%WH PHP%')
	, ('%Whole hlth PHP%')
	, ('%Whole hlth PHI%'); 

DROP TABLE IF EXISTS #NTWHActInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTWHActInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTWHActIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTWHActInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTWHActInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTWHActInclWide
FROM #NTWHActInclLong a;

/*
SELECT TOP 1000 * FROM #NTWHActInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTWHActInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTWHActInclWide;
*/

DROP TABLE IF EXISTS #NTWHActivities;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'WH-Activities' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTWHActivities
FROM #NTWHActInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTWHActExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTWHActivities;

/******************************************************************************/
/**************************     NT WH - COACH      ****************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NTWHCoExcl;
CREATE TABLE #NTWHCoExcl (
	ExclString varchar(50)
	);
INSERT INTO #NTWHCoExcl (ExclString) 
VALUES ('%acup%'),('%bfa%'),('%yoga%'),('%qi g%'),('%qig%'),('%taic%'),('%tai c%'),
	('%MBSR%'),('%medita%'),('%mindfu%'),('%hypn%'),('%guided imag%'),('%biofeed%'),('%chiro%'),
	('%aroma%'),('%animal-assisted%'),('%animal assisted%'),('%creative art%'),('%expressive arts%'),
	('%eye movement%'),('%healing touch%'),('%therapeutic touch%'),('%reiki%'),('%pilates%'),
	('%native american heal%'),('%massage%'),('%movement therapy%'),('%progressive relax%'),
	('%reflexo%'),('%nutr%'),('% ntr %'),('%whole health cog behav%'),
	/*added by LA 12/14/20*/ ('%acpu%'),('%battlefield%'),('%btl acp%'),('%BF acup%'),
	('%battlefld%'),('%bio feed%'),('%neurofeed%'),('%neuro feed%'),('%guided%'),('%imagery%'),
	( '%gima%'),('%mantra%'),('%irest%'),('%Tai Ji%'),('%TaiJi%'),
	/*added by LA 3/15/21*/ ('%phillips%'),('%phic%'),('%phine%'),('%memphis%'),
	('%buprenorphine%'),('%rocephin%'),('%phil%'),('%graphic%'),('%emergency%'),
	/*added by LA 6/24/21*/ ('%demoted%'),('%non-visit%'),('%historical%'),('%revoked%'),
	('%ex-personal%'),('%rescinded%');

DROP TABLE IF EXISTS #NTWHCoExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #NTWHCoExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTWHCoExcl B on A.TIUDocumentDefinition like B.ExclString;
	
DROP TABLE IF EXISTS #NTWHCoExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #NTWHCoExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #NTWHCoExclWide
FROM #NTWHCoExclLong a;

/*
SELECT TOP 1000 * FROM #NTWHCoExclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTWHCoExclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTWHCoExclWide;
*/

DROP TABLE IF EXISTS #NTWHCoIncl
CREATE TABLE #NTWHCoIncl (
	InclString varchar (50)
	);
INSERT INTO #NTWHCoIncl (InclString)
VALUES ('%WH%Coach%')
	, ('%Whole Health%Coach%')
	, ('%Whole hlth%Coach%')
	, ('%Whl Hlth%Coach%')
	, ('%Whole-h%Coach%')
	, ('%WHLHLTH%Coach%'); 

DROP TABLE IF EXISTS #NTWHCoInclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.InclString
INTO #NTWHCoInclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #NTWHCoIncl B on A.TIUDocumentDefinition like B.InclString; 

DROP TABLE IF EXISTS #NTWHCoInclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + InclString
		FROM #NTWHCoInclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as InclStrings
INTO #NTWHCoInclWide
FROM #NTWHCoInclLong a;

/*
SELECT TOP 1000 * FROM #NTWHCoInclWide ORDER BY TIUDocumentDefinitionSID;
SELECT COUNT(*) FROM #NTWHCoInclWide;
SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #NTWHCoInclWide;
*/

DROP TABLE IF EXISTS #NTWHCoach;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'WH-Coach' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, A.InclStrings as Inclusions
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NTWHCoach
FROM #NTWHCoInclWide A
	LEFT JOIN #NTGenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #NTWHCoExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID;
--SELECT * FROM #NTWHCoach;

/******************************************************************************/
/*********************     NT: combine into one dim table      ****************/
/******************************************************************************/

/* no note titles for massage or WH clinical care */

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.NoteTitles;
with intermed as (
	SELECT * FROM #NTAcupTrad
	union
	SELECT * FROM #NTAcupBFA
	union 
	SELECT * FROM #NTBiofeedback
	union
	SELECT * FROM #NTChiro
	union
	SELECT * FROM #NTGima
	union 
	SELECT * FROM #NTHyp
	union 
	SELECT * FROM #NTMed
	union 
	SELECT * FROM #NTTaiChi
	union 
	SELECT * FROM #NTYoga
	union 
	SELECT * FROM #NTWHActivities
	union 
	SELECT * FROM #NTWHCoach
	)
select * INTO ORD_Fix_202309007D.WH_CIH.NoteTitles FROM INTERMED;

/********************************************************/
/****** Location Name Only Exclusions *******************/
/********************************************************/

/*
For visits found only by location name, apply exclusions based on string searches in the note titles
*/

/******************************************************************************/
/**************   LN Only Excl general exclusions table    ********************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_GenExcl;
CREATE TABLE #LN_only_GenExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_GenExcl (ExclString) 
VALUES ('%research%'),('%rsch%'),
   ('%refer%'),
   ('%follo%'),('%f/u%'),('%fup%'),('%fol%'),('%flwup%'),('%fl up%'),('%fll up%'),
   ('%cons%'),('%econs%'),('%e consult%'),('%e-con%'),('%cnslt%'),
   ('%com tx%'),('%comm care%'),('%com care%'),('%choice%'),('% cc %'),('%community%'),
   ('%non va%'),('%non-va%'),('%nonva%'),
   ('%vcp%'),('%outside%'),('%no show%'),('%no-show%'),('%messag%'),('%test%'),
   ('%vcl%'),('%call attempt%'),('%consent%'),('%letter%'),('%admin%'),('%cancel%'),
   ('%sched%'),('%nurs%'),('%contact%'),('%error%'),('%surg%'),
   ('%biopsy%'),('%adm%'),('%apmt%'),('%discharge%'),('%lab%');
   
/* get all unique TIUDocumentDefinitionSIDs for these exclusions */
/* each SID may show up more than once if it matches more than one exclusion */
DROP TABLE IF EXISTS #LN_only_GenExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_GenExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_GenExcl B on A.TIUDocumentDefinition like B.ExclString;

/* collapse to one row per LocationSID */
/* collect all exclusion term matches into one column for future reference */

DROP TABLE IF EXISTS #LN_only_GenExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_GenExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_GenExclWide
FROM #LN_only_GenExclLong a;
--SELECT * FROM #LN_only_GenExclWide ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     LN Only Excl ACUPUNCTURE     *********************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_AcupExcl;
CREATE TABLE #LN_only_AcupExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_AcupExcl (ExclString) 
VALUES ('%correspondence%'),('%dental%'),('%drug%'),('%mail%'),('%naloxone%'),
	('%ophth%'),('%optom%'),('%outreach%'),('%psychi%'),('%screening%'),('%mri%'),
	('%hybrid%'),('%travel%'),('%plan%'),('%rec%'),('%physical%'),
	('%clc%'),('%oss%'),('%rehab%'),('%primary care%'),('%interim%');

DROP TABLE IF EXISTS #LN_only_AcupExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_AcupExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_AcupExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_AcupExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_AcupExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_AcupExclWide
FROM #LN_only_AcupExclLong a;

DROP TABLE IF EXISTS #LN_only_Acup;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Acupuncture' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Acup
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_AcupExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #LN_only_Acup ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     LN Only Excl BIOFEEDBACK     *********************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_BioExcl;
CREATE TABLE #LN_only_BioExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_BioExcl (ExclString) 
VALUES ('%addendum%'),('%urology%'),('%suicide%'),('%advance%'),('%renal%'),
	('%inpat%'),('%addiction%'),('%after%'),('%central%'),('%erron%'),('%emergency%'),
	('%hypo%'),('%diag%'),('%reassign%'),('%plan%'),('%respiratory%'),
	('%chiro%'),('%anesthesia%'),('%ptsd%'),('%assessment%'),('%notification%'),
	('%risk%'),('%ymca%'),('%baseline%');

DROP TABLE IF EXISTS #LN_only_BioExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_BioExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_BioExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_BioExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_BioExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_BioExclWide
FROM #LN_only_BioExclLong a;

DROP TABLE IF EXISTS #LN_only_Biofeedback;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Biofeedback' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Biofeedback
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_BioExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_Biofeedback ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     LN Only Excl CHIRO     ***************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_ChiroExcl;
CREATE TABLE #LN_only_ChiroExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_ChiroExcl (ExclString) 
VALUES ('%app%'),('%addendum%'),('%test results%'),('%after visit%'),('%historic%'),
	('%event%'),('%dictation%'),('%tracking%'),('%information%'),('%child%'),('%fee%');

DROP TABLE IF EXISTS #LN_only_ChiroExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_ChiroExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_ChiroExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_ChiroExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_ChiroExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_ChiroExclWide
FROM #LN_only_ChiroExclLong a;

DROP TABLE IF EXISTS #LN_only_Chiro;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Chiropractic' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Chiro
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_ChiroExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_Chiro ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     LN Only Excl GUIDED IMAGERY     ******************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_GimaExcl;
CREATE TABLE #LN_only_GimaExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_GimaExcl (ExclString) 
VALUES ('%radiology%'),('%addendum%'),('%urology%'),('%endoscopic%'),('%placement%'),
	('%procedure%'),('%oncology%'),('%ultrasound%'),('%lung%'),('%fee%');

DROP TABLE IF EXISTS #LN_only_GimaExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_GimaExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_GimaExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_GimaExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_GimaExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_GimaExclWide
FROM #LN_only_GimaExclLong a;

DROP TABLE IF EXISTS #LN_only_Gima;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Guided Imagery' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Gima
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_GimaExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_Gima ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     LN Only Excl HYPNOSIS     ************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_HypExcl;
CREATE TABLE #LN_only_HypExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_HypExcl (ExclString) 
VALUES ('%addendum%'),('%erron%'),('%call%'),('%imag%'),
	('%update%'),('%istop%'),('%plan note%'),('%review%'),('%opiate%');

DROP TABLE IF EXISTS #LN_only_HypExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_HypExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_HypExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_HypExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_HypExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_HypExclWide
FROM #LN_only_HypExclLong a;

DROP TABLE IF EXISTS #LN_only_Hyp;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Hypnosis' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Hyp
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_HypExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_Hyp ORDER BY TIUDocumentDefinitionSID;
--SELECT COUNT(DISTINCT TIUDocumentDefinitionSID) FROM #LN_only_Hyp;

/******************************************************************************/
/***********************     LN Only Excl MEDITATION     **********************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_MedExcl;
CREATE TABLE #LN_only_MedExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_MedExcl (ExclString) 
VALUES ('%addendum%'),('%diabetes%'),('%chaplain%'),('%travel%'),('%nutrition%'),
	('%diagnostic%'),('%correspondence%'),('%suicide%'),('%missed%'),('%after%'),
	('%mindful yoga%'),('%child%'),('%mindful living%'),('%parent%'),
	('%mindful action%'),('%movement%'),('%neuro%'),('%oncology%');

DROP TABLE IF EXISTS #LN_only_MedExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_MedExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_MedExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_MedExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_MedExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_MedExclWide
FROM #LN_only_MedExclLong a;

DROP TABLE IF EXISTS #LN_only_Med;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Meditation' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Med
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_MedExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_Med ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***********************     LN Only Excl TAI CHI     *************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_TaicExcl;
CREATE TABLE #LN_only_TaicExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_TaicExcl (ExclString) 
VALUES ('%addendum%'),('%yoga%'),('%neuro%'),('%non-visit%'),('%erron%'),
	('%after%'),('%chaplain%'),('%audiology%'),('%occupation%'),('%erro%'),
	('%clerical%'),('%education%'),('%irest%');

DROP TABLE IF EXISTS #LN_only_TaicExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_TaicExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_TaicExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_TaicExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_TaicExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_TaicExclWide
FROM #LN_only_TaicExclLong a;

DROP TABLE IF EXISTS #LN_only_TaiChi;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'TaiChi' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_TaiChi
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_TaicExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_TaiChi ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/**************************     LN Only Excl YOGA      ************************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_YogaExcl;
CREATE TABLE #LN_only_YogaExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_YogaExcl (ExclString) 
VALUES ('%iRest%'),('%philosophy%'),('%nidra%'),('%dvd%');

DROP TABLE IF EXISTS #LN_only_YogaExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_YogaExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_YogaExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_YogaExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_YogaExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_YogaExclWide
FROM #LN_only_YogaExclLong a;

DROP TABLE IF EXISTS #LN_only_Yoga;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'Yoga' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_Yoga
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_YogaExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_Yoga --WHERE SpecExcl is not null 
--ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/**************************     LN Only Excl WH - ACTIVITIES      *************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_WHActExcl;
CREATE TABLE #LN_only_WHActExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_WHActExcl (ExclString) 
VALUES ('%call%'),('%addendum%'),('%attempt%'),('%non-visit%'),('%non visit%'),
	('%missed%'),('%covid-19%'),('%historic%'),('%mas contact%'),('%information only%'),
	('%demote%'),('%chart check%'),('%triage%'),('%msa return%'),('%erroneous%'),
	('%rescinded%'),('%abnormal%'),('%clopido%'),('%renewal%'),('%mas patient%'),
	('%immunization%'),('%dental%'),('%cp muse%'),('%tomah case%'),('%vaccination%'),
	('%dermatology%'),('%refill%'),('%drug request%'),('%vaccine%'),('%attempt%'),
	('%chaplain%'),('%suicide%'),('%cancer%'),('%drug monitoring%'),('%record review%'),
	('%patient letter%'),('%acup%'),('%bfa%'),('%yoga%'),('%qi g%'),
	('%qig%'),('%taic%'),('%tai c%'),('%MBSR%'),('%medita%'),('%mindfu%'),
	('%hypn%'),('%guided imag%'),('%biofeed%'),('%chiro%'),('%aroma%'),
	('%animal-assisted%'),('%animal assisted%'),('%creative art%'),('%expressive arts%'),
	('%eye movement%'),('%healing touch%'),('%therapeutic touch%'),('%reiki%'),
	('%pilates%'),('%native american heal%'),('%massage%'),('%movement therapy%'),
	('%progressive relax%'),('%reflexo%'),('%nutr%'),('% ntr %'),('%whole health cog behav%'),
	/*added by LA 12/14/20*/('%acpu%'),('%battlefield%'),('%bio feed%'),('%neurofeed%'),
	('%neuro feed%'),('%gima%'),('%guided%'),('%imagery%'),('%mantra%'),('%irest%'),
	('%Tai Ji%'),('%Taiji%'),
	/*added by LA 3/15/21*/('%phillips%'),('%phic%'),('%phine%'),('%memphis%'),
	('%buprenorphine%'),('%rocephin%'),('%phil%'),('%graphic%'),('%emergency%'),
	/*added by LA 6/24/21*/('%demoted%'),('%historical%'),('%revoked%'),('%ex-personal%');

DROP TABLE IF EXISTS #LN_only_WHActExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_WHActExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_WHActExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_WHActExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_WHActExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_WHActExclWide
FROM #LN_only_WHActExclLong a;

DROP TABLE IF EXISTS #LN_only_WHActivities;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'WH-Activities' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_WHActivities
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_WHActExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_WHActivities ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/**************************     LN Only Excl WH - COACH      ******************/
/******************************************************************************/

DROP TABLE IF EXISTS #LN_only_WHCoExcl;
CREATE TABLE #LN_only_WHCoExcl (
	ExclString varchar(50)
	);
INSERT INTO #LN_only_WHCoExcl (ExclString) 
VALUES ('%call%'),('%addendum%'),('%attempt%'),('%non-visit%'),('%non visit%'),
	('%missed%'),('%covid-19%'),('%historic%'),('%mas contact%'),('%information only%'),
	('%demote%'),('%chart check%'),('%triage%'),('%msa return%'),('%erroneous%'),
	('%rescinded%'),('%abnormal%'),('%clopido%'),('%renewal%'),('%mas patient%'),
	('%immunization%'),('%dental%'),('%cp muse%'),('%tomah case%'),('%vaccination%'),
	('%dermatology%'),('%refill%'),('%drug request%'),('%vaccine%'),('%attempt%'),
	('%chaplain%'),('%suicide%'),('%cancer%'),('%drug monitoring%'),('%record review%'),
	('%patient letter%'),('%acup%'),('%bfa%'),('%yoga%'),('%qi g%'),
	('%qig%'),('%taic%'),('%tai c%'),('%MBSR%'),('%medita%'),('%mindfu%'),
	('%hypn%'),('%guided imag%'),('%biofeed%'),('%chiro%'),('%aroma%'),
	('%animal-assisted%'),('%animal assisted%'),('%creative art%'),('%expressive arts%'),
	('%eye movement%'),('%healing touch%'),('%therapeutic touch%'),('%reiki%'),
	('%pilates%'),('%native american heal%'),('%massage%'),('%movement therapy%'),
	('%progressive relax%'),('%reflexo%'),('%nutr%'),('% ntr %'),('%whole health cog behav%'),
	/*added by LA 12/14/20*/('%acpu%'),('%battlefield%'),('%bio feed%'),('%neurofeed%'),
	('%neuro feed%'),('%gima%'),('%guided%'),('%imagery%'),('%mantra%'),('%irest%'),
	('%Tai Ji%'),('%Taiji%'),
	/*added by LA 3/15/21*/('%phillips%'),('%phic%'),('%phine%'),('%memphis%'),
	('%buprenorphine%'),('%rocephin%'),('%phil%'),('%graphic%'),('%emergency%'),
	/*added by LA 6/24/21*/('%demoted%'),('%historical%'),('%revoked%'),('%ex-personal%');

DROP TABLE IF EXISTS #LN_only_WHCoExclLong;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, B.ExclString
INTO #LN_only_WHCoExclLong
FROM CDWWork.Dim.TIUDocumentDefinition A
	INNER JOIN #LN_only_WHCoExcl B on A.TIUDocumentDefinition like B.ExclString;

DROP TABLE IF EXISTS #LN_only_WHCoExclWide;
SELECT DISTINCT a.TIUDocumentDefinitionSID
	, a.TIUDocumentDefinition
	, (SELECT ' ' + ExclString
		FROM #LN_only_WHCoExclLong b
		WHERE (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
			AND a.TIUDocumentDefinition = b.TIUDocumentDefinition)
		FOR XML PATH('')) as ExclStrings
INTO #LN_only_WHCoExclWide
FROM #LN_only_WHCoExclLong a;

DROP TABLE IF EXISTS #LN_only_WHCoach;
SELECT A.TIUDocumentDefinitionSID
	, A.TIUDocumentDefinition
	, 'WH-Coach' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #LN_only_WHCoach
FROM CDWWork.Dim.TIUDocumentDefinition A
	LEFT JOIN #LN_only_GenExclWide B	ON A.TIUDocumentDefinitionSID = B.TIUDocumentDefinitionSID
	LEFT JOIN #LN_only_WHCoExclWide C	ON A.TIUDocumentDefinitionSID = C.TIUDocumentDefinitionSID
where B.ExclStrings is not null or C.ExclStrings is not null;

--SELECT * FROM #LN_only_WHCoach ORDER BY TIUDocumentDefinitionSID;

/******************************************************************************/
/***************     LN Only Excl: combine into one dim table      ************/
/******************************************************************************/

/* no LN only exclusions for massage or WH clinical care */

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.CIHWHLocationOnlyExclusions;
with intermed as (
	SELECT * FROM #LN_only_Acup
	union 
	SELECT * FROM #LN_only_Biofeedback
	union
	SELECT * FROM #LN_only_Chiro
	union
	SELECT * FROM #LN_only_Gima
	union 
	SELECT * FROM #LN_only_Hyp
	union 
	SELECT * FROM #LN_only_Med
	union 
	SELECT * FROM #LN_only_TaiChi
	union 
	SELECT * FROM #LN_only_Yoga
	union 
	SELECT * FROM #LN_only_WHActivities
	union 
	SELECT * FROM #LN_only_WHCoach
	)
select * INTO ORD_Fix_202309007D.WH_CIH.CIHWHLocationOnlyExclusions FROM INTERMED;

/********************************************************/
/****** Note Title Only Exclusions **********************/
/********************************************************/

/*
For visits found only by note titles, apply exclusions based on string searches in the location names
*/

/******************************************************************************/
/**************   NT Only Excl general exclusions table    ********************/
/******************************************************************************/

DROP TABLE IF EXISTS #NT_only_GenExcl;
CREATE TABLE #NT_only_GenExcl (
	ExclString varchar(50)
	);
INSERT INTO #NT_only_GenExcl (ExclString) 
VALUES ('%research%'),('%rsch%'),
   ('%refer%'),
   ('%follo%'),('%f/u%'),('%fup%'),('%fol%'),('%flwup%'),('%fl up%'),('%fll up%'),
   ('%cons%'),('%econs%'),('%e consult%'),('%e-con%'),('%cnslt%'),
   ('%com tx%'),('%comm care%'),('%com care%'),('%choice%'),('% cc %'),('%community%'),
   ('%non va%'),('%non-va%'),('%nonva%'),
   ('%vcp%'),('%outside%'),('%no show%'),('%no-show%'),('%messag%'),('%test%'),
   ('%vcl%');

/* get all unique LocationSIDs for these exclusions */
/* each SID may show up more than once if it matches more than one exclusion */
DROP TABLE IF EXISTS #NT_only_GenExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_GenExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #NT_only_GenExcl B on A.LocationName like B.ExclString;

/* collapse to one row per LocationSID */
/* collect all exclusion term matches into one column for future reference */

DROP TABLE IF EXISTS #NT_only_GenExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_GenExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_GenExclWide
FROM #NT_only_GenExclLong a;
--SELECT * FROM #NT_only_GenExclWide ORDER BY LocationSID;

/******************************************************************************/
/***********************     NT Only Excl ACUPUNCTURE     *********************/
/******************************************************************************/

/* **** currently no specific exclusions for acupuncture ***** */
DROP TABLE IF EXISTS #NT_only_AcupExcl;
CREATE TABLE #NT_only_AcupExcl (
	ExclString varchar(50)
	);
--INSERT INTO #NT_only_AcupExcl (ExclString) 
--VALUES ();

DROP TABLE IF EXISTS #NT_only_AcupExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_AcupExclLong
FROM CDWWork.Dim.[Location] A
	INNER JOIN #NT_only_AcupExcl B on A.LocationName like B.ExclString;

DROP TABLE IF EXISTS #NT_only_AcupExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_AcupExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_AcupExclWide
FROM #NT_only_AcupExclLong a;

DROP TABLE IF EXISTS #NT_only_Acup;
SELECT A.LocationSID
	, A.LocationName
	, 'Acupuncture' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NT_only_Acup
FROM CDWWork.Dim.Location A
	LEFT JOIN #NT_only_GenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #NT_only_AcupExclWide C	ON A.LocationSID = C.LocationSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #NT_only_Acup

/******************************************************************************/
/*******************     NT Only Excl BIOFEEDBACK     *************************/
/******************************************************************************/

/* **** currently no specific exclusions for biofeedback ***** */
DROP TABLE IF EXISTS #NT_only_BioExcl;
CREATE TABLE #NT_only_BioExcl (
	ExclString varchar(50)
	);
--INSERT INTO #NT_only_BioExcl (ExclString) 
--VALUES ();

DROP TABLE IF EXISTS #NT_only_BioExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_BioExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #NT_only_BioExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #NT_only_BioExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_BioExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_BioExclWide
FROM #NT_only_BioExclLong a;

DROP TABLE IF EXISTS #NT_only_Biofeedback;
SELECT A.LocationSID
	, A.LocationName
	, 'Biofeedback' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NT_only_Biofeedback
FROM CDWWork.Dim.Location A
	LEFT JOIN #NT_only_GenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #NT_only_BioExclWide C	ON A.LocationSID = C.LocationSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #NT_only_Biofeedback;

/******************************************************************************/
/********************     NT Only Excl CHIRO     ******************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NT_only_ChiroExcl;
CREATE TABLE #NT_only_ChiroExcl (
	ExclString varchar(50)
	);
INSERT INTO #NT_only_ChiroExcl (ExclString) 
VALUES ('%scan%'),('%question%'),('%non count-x%'),('%acup%'),('%acu%'),
	('%care-x%'),('%CC-CHIROPRACTIC-X%'),('%zznonvacare%'),('%accu%'),
	('%ymca%'),('%fee%'),('%bfa%'),('%chiron%'),('%chiros%'),
	('%secmsg%'),('%secure%');

DROP TABLE IF EXISTS #NT_only_ChiroExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_ChiroExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #NT_only_ChiroExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #NT_only_ChiroExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_ChiroExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_ChiroExclWide
FROM #NT_only_ChiroExclLong a;

/*
SELECT TOP 1000 * FROM #NT_only_ChiroExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #NT_only_ChiroExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #NT_only_ChiroExclWide;
*/

DROP TABLE IF EXISTS #NT_only_Chiro;
SELECT A.LocationSID
	, A.LocationName
	, 'Chiropractic' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NT_only_Chiro
FROM CDWWork.Dim.Location A
	LEFT JOIN #NT_only_GenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #NT_only_ChiroExclWide C	ON A.LocationSID = C.LocationSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #NT_only_Chiro;

/******************************************************************************/
/****************     NT Only Excl GUIDED IMAGERY     *************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NT_only_GimaExcl;
CREATE TABLE #NT_only_GimaExcl (
	ExclString varchar(50)
	);
INSERT INTO #NT_only_GimaExcl (ExclString) 
VALUES ('%acu%');

DROP TABLE IF EXISTS #NT_only_GimaExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_GimaExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #NT_only_GimaExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #NT_only_GimaExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_GimaExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_GimaExclWide
FROM #NT_only_GimaExclLong a;

DROP TABLE IF EXISTS #NT_only_GIMA;
SELECT A.LocationSID
	, A.LocationName
	, 'Guided Imagery' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NT_only_GIMA
FROM CDWWork.Dim.Location A
	LEFT JOIN #NT_only_GenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #NT_only_GimaExclWide C	ON A.LocationSID = C.LocationSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #NT_only_GIMA;

/* no exclusions for Hypnosis */

/* no exclusions for Massage */

/******************************************************************************/
/********************     NT Only Excl MEDITATION     *************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NT_only_MedExcl;
CREATE TABLE #NT_only_MedExcl (
	ExclString varchar(50)
	);
INSERT INTO #NT_only_MedExcl (ExclString) 
VALUES ('%education%'),('%demonstrations%'),('%subsequent%'),
	('%firestone%'),('%eating%'),('%mindful yoga%');

DROP TABLE IF EXISTS #NT_only_MedExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_MedExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #NT_only_MedExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #NT_only_MedExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_MedExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_MedExclWide
FROM #NT_only_MedExclLong a;

/*
SELECT TOP 1000 * FROM #NT_only_MedExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #NT_only_MedExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #NT_only_MedExclWide;
*/

DROP TABLE IF EXISTS #NT_only_Med;
SELECT A.LocationSID
	, A.LocationName
	, 'Meditation' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NT_only_Med
FROM CDWWork.Dim.Location A
	LEFT JOIN #NT_only_GenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #NT_only_MedExclWide C	ON A.LocationSID = C.LocationSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #NT_only_Med WHERE SpecExcl is not null;

/* no exclusions for TaiChi */

/******************************************************************************/
/**************************    NT Only Excl YOGA      *************************/
/******************************************************************************/

DROP TABLE IF EXISTS #NT_only_YogaExcl;
CREATE TABLE #NT_only_YogaExcl (
	ExclString varchar(50)
	);
INSERT INTO #NT_only_YogaExcl (ExclString) 
VALUES ('%acup%'),('%bfa%'),('%meditation%'),('%tai chi%'),('%iRest%');

DROP TABLE IF EXISTS #NT_only_YogaExclLong;
SELECT A.LocationSID
	, A.LocationName
	, B.ExclString
INTO #NT_only_YogaExclLong
FROM CDWWork.Dim.Location A
	INNER JOIN #NT_only_YogaExcl B on A.LocationName like B.ExclString;
	
DROP TABLE IF EXISTS #NT_only_YogaExclWide;
SELECT DISTINCT a.LocationSID
	, a.LocationName
	, (SELECT ' ' + ExclString
		FROM #NT_only_YogaExclLong b
		WHERE (a.LocationSID = b.LocationSID
			AND a.LocationName = b.LocationName)
		FOR XML PATH('')) as ExclStrings
INTO #NT_only_YogaExclWide
FROM #NT_only_YogaExclLong a;

/*
SELECT TOP 1000 * FROM #NT_only_YogaExclWide ORDER BY LocationSID;
SELECT COUNT(*) FROM #NT_only_YogaExclWide;
SELECT COUNT(DISTINCT LocationSID) FROM #NT_only_YogaExclWide;
*/

DROP TABLE IF EXISTS #NT_only_Yoga;
SELECT A.LocationSID
	, A.LocationName
	, 'Yoga' as CIHType
	, StartDate = CONVERT(date, '2017-01-01')
	, EndDate   = CONVERT(date, '2050-01-01')
	, B.ExclStrings as GenExcl
	, C.ExclStrings as SpecExcl
INTO #NT_only_Yoga
FROM CDWWork.Dim.Location A
	LEFT JOIN #NT_only_GenExclWide B	ON A.LocationSID = B.LocationSID
	LEFT JOIN #NT_only_YogaExclWide C	ON A.LocationSID = C.LocationSID
where B.ExclStrings is not null or C.ExclStrings is not null;
--SELECT * FROM #NT_only_Yoga --WHERE SpecExcl is not null;

/******************************************************************************/
/******************     NT Only excl: combine into one dim table      *********/
/******************************************************************************/

/* no exclusions for massage, hypnosis or TaiChi */

DROP TABLE IF EXISTS ORD_Fix_202309007D.WH_CIH.CIHWHNoteTitleOnlyExclusions;
with intermed as (
	SELECT * FROM #NT_only_Acup
	union 
	SELECT * FROM #NT_only_Biofeedback
	union
	SELECT * FROM #NT_only_Chiro
	union
	SELECT * FROM #NT_only_GIMA
	union 
	SELECT * FROM #NT_only_Med
	union 
	SELECT * FROM #NT_only_Yoga
	)
select * INTO ORD_Fix_202309007D.WH_CIH.CIHWHNoteTitleOnlyExclusions FROM INTERMED;

/********************************/
/****** Telehealth **************/
/********************************/

/*
General approach: 
Whole Health/CIH utilization found as normal by a combination of stop codes, ctp codes, char 4, notes, hfs, etc. (NOTE: remove VVC, tele, remote, etc exclusions from standard searches) 
Consolidated list of tele clinics built from a combination of stop codes and clinic names: 

We cross reference the visit locations associated with utilization with the tele clinic lists to categorize utilization as “tele”. 
*/

drop table if exists ORD_Fix_202309007D.WH_CIH.Telehealth
Select c.LocationSID,
	--LocationIEN,
	c.sta3n, 
	locationname, 
	--locationabbreviation, 
	d.StopCode as PrimaryStopCode, 
	d.stopcodename as PrimaryStopCodeName, 
	e.stopcode as SecondaryStopCode, 
	e.StopCodeName as SecondaryStopCodeName
into ORD_Fix_202309007D.WH_CIH.Telehealth
from CDWWork.Dim.DSSLocationStopCode a
	inner join CDWWork.Dim.DSSlocation b on a.DSSLocationStopCodeSID=b.DSSLocationStopCodeSID
	inner join CDWWork.Dim.Location c on b.LocationSID=c.locationSID
	inner join cdwwork.dim.stopcode as d on c.PrimaryStopCodeSID = d.StopCodeSID
	left join cdwwork.dim.stopcode as e on c.SecondaryStopCodeSID = e.StopCodeSID
where d.stopcode in (147, 179, 221, 444, 445, 446, 447, 648, 679, 683, 684, 685, 686, 690, 692, 723, 724) 
or e.stopcode in (147, 179, 221, 444, 445, 446, 447, 648, 679, 683, 684, 685, 686, 690, 692, 723, 724)
union 
select LocationSID,
   -- LocationIEN,
    a.Sta3n,
    LocationName,
    --LocationAbbreviation ,
    b.StopCode as PrimaryStopCode,
    b.StopCodeName as PrimaryStopCodeName,
    c.StopCode as SecondaryStopCode,
    c.StopCodeName as SecondaryStopCodeName
from cdwwork.dim.location a
    inner join cdwwork.dim.stopcode as b on (a.PrimaryStopCodeSID = b.StopCodeSID)
    left join cdwwork.dim.stopcode as c on (a.SecondaryStopCodeSID = c.StopCodeSID) 
where (LocationName like '%tele%' and LocationName not like '%teleret%') 
    or LocationName like '%VVC%'
	or LocationName like '%CVT%' 
    or LocationName like '%CCHT%'
	or LocationName like 'HT %'
    or LocationName like '%VTC%'
	or LocationName like '% TH %'
	or LocationName like '%Phone%'


