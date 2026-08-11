/***************************************************************
EXTRACT TABLES: The following is a list of the extracts that we 
want from the CDW. Some of the tables are intermediate tables
used for determining acupuncture usage so those are unneeded

Needed extract tables:
1) acu_facility_info
2) acu_visits_final - y
3) acu_outpatient_visits
4) acu_outpatient_diagnoses -y
5) acu_patient_info - y
6) acu_inpatient_diagnoses - y
7) acu_vital_signs - y
8) mh_factors - y
***************************************************************/

SET NOCOUNT ON;

DECLARE @StartDateTime datetime2(0) = CONVERT(datetime2(0), '2022-10-01 00:00:00');
DECLARE @EndDateTime   datetime2(0) = CONVERT(datetime2(0), '2026-06-30 23:59:59');

/***************************************************************
Clean up temp tables
***************************************************************/

DROP TABLE IF EXISTS #acu_pattern_terms;
DROP TABLE IF EXISTS #acu_char4_lookup;
DROP TABLE IF EXISTS #acu_cpt_lookup;
DROP TABLE IF EXISTS #acu_health_factor_lookup;
DROP TABLE IF EXISTS #acu_location_lookup;
DROP TABLE IF EXISTS #acu_note_title_lookup;
DROP TABLE IF EXISTS #acu_location_only_exclusion_lookup;
DROP TABLE IF EXISTS #acu_note_title_only_exclusion_lookup;
DROP TABLE IF EXISTS #acu_telehealth_lookup;
DROP TABLE IF EXISTS #acu_outpat_visit;
DROP TABLE IF EXISTS #acu_cpt;
DROP TABLE IF EXISTS #acu_cpt_wide;
DROP TABLE IF EXISTS #acu_char4;
DROP TABLE IF EXISTS #acu_loc_name;
DROP TABLE IF EXISTS #acu_nt;
DROP TABLE IF EXISTS #acu_nt_wide;
DROP TABLE IF EXISTS #acu_hf;
DROP TABLE IF EXISTS #acu_hf_wide;
DROP TABLE IF EXISTS #acu_consolidated_methods;
DROP TABLE IF EXISTS #acu_consolidated_methods2;
DROP TABLE IF EXISTS #acu_consolidated_methods3;
DROP TABLE IF EXISTS #acu_location_name_only_exclusions;
DROP TABLE IF EXISTS #acu_consolidated_methods_excl1;
DROP TABLE IF EXISTS #acu_note_title_only_exclusions;
DROP TABLE IF EXISTS #acu_visits_consolidated;
DROP TABLE IF EXISTS #acu_visits_final;
DROP TABLE IF EXISTS #acu_patient_list;
DROP TABLE IF EXISTS #acu_patient_info;
DROP TABLE IF EXISTS #acu_outpatient_diagnoses;
DROP TABLE IF EXISTS #acu_inpatient_diagnoses;
DROP TABLE IF EXISTS #acu_vital_signs;

/***************************************************************
Newer acupuncture-only include/exclude terms

These terms are taken from the 2024 dim_tables script, reduced to
the acupuncture-relevant term sets only.
***************************************************************/

CREATE TABLE #acu_pattern_terms (
	TermSet varchar(50) NOT NULL,
	Pattern varchar(100) NOT NULL
);

INSERT INTO #acu_pattern_terms (TermSet, Pattern)
VALUES
	-- Health-factor general exclusions
	('HF_GEN_EXCL', '%research%'), ('HF_GEN_EXCL', '%rsch%'),
	('HF_GEN_EXCL', '%refer%'),
	('HF_GEN_EXCL', '%follo%'), ('HF_GEN_EXCL', '%f/u%'), ('HF_GEN_EXCL', '%fup%'),
	('HF_GEN_EXCL', '%fol%'), ('HF_GEN_EXCL', '%flwup%'), ('HF_GEN_EXCL', '%fl up%'),
	('HF_GEN_EXCL', '%fll up%'),
	('HF_GEN_EXCL', '%cons%'), ('HF_GEN_EXCL', '%econs%'), ('HF_GEN_EXCL', '%e consult%'),
	('HF_GEN_EXCL', '%e-con%'), ('HF_GEN_EXCL', '%cnslt%'),
	('HF_GEN_EXCL', '%com tx%'), ('HF_GEN_EXCL', '%comm care%'), ('HF_GEN_EXCL', '%com care%'),
	('HF_GEN_EXCL', '%choice%'), ('HF_GEN_EXCL', '% cc %'), ('HF_GEN_EXCL', '%community%'),
	('HF_GEN_EXCL', '%non va%'), ('HF_GEN_EXCL', '%non-va%'), ('HF_GEN_EXCL', '%nonva%'),
	('HF_GEN_EXCL', '%vcp%'), ('HF_GEN_EXCL', '%outside%'), ('HF_GEN_EXCL', '%no show%'),
	('HF_GEN_EXCL', '%no-show%'), ('HF_GEN_EXCL', '%messag%'), ('HF_GEN_EXCL', '%test%'),
	('HF_GEN_EXCL', '%vcl%'), ('HF_GEN_EXCL', '%fager%'), ('HF_GEN_EXCL', '%call attempt%'),
	('HF_GEN_EXCL', '%patient letter%'), ('HF_GEN_EXCL', '%consent%'),
	('HF_GEN_EXCL', '%appointment request%'), ('HF_GEN_EXCL', '%instructions%'),
	('HF_GEN_EXCL', '%outcome%'), ('HF_GEN_EXCL', '%reply%'), ('HF_GEN_EXCL', '%intake%'),
	('HF_GEN_EXCL', '%eval%'), ('HF_GEN_EXCL', '%reminder%'), ('HF_GEN_EXCL', '%discharge%'),

	-- Health-factor acupuncture terms
	('HF_TRAD_INCL', '%acup%'), ('HF_TRAD_INCL', '%acpu%'),
	('HF_TRAD_EXCL', '%battlefield%'), ('HF_TRAD_EXCL', '%bfa%'),
	('HF_TRAD_EXCL', '%acupressure%'), ('HF_TRAD_EXCL', '%yoga%'),
	('HF_TRAD_EXCL', '%TCMLH%'), ('HF_TRAD_EXCL', '%biacuplasty%'),
	('HF_TRAD_EXCL', '%plan%'), ('HF_TRAD_EXCL', '%btl acp%'),
	('HF_TRAD_EXCL', '%bf acup%'), ('HF_TRAD_EXCL', '%battlefld%'),
	('HF_TRAD_EXCL', '%nada%'), ('HF_TRAD_EXCL', '%ear%'), ('HF_TRAD_EXCL', '%auricular%'),
	('HF_BFA_INCL', '%bfa%'), ('HF_BFA_INCL', '%battlefield%'),
	('HF_BFA_INCL', '%btl acp%'), ('HF_BFA_INCL', '%bf acup%'),
	('HF_BFA_INCL', '%battlefld%'), ('HF_BFA_INCL', '%acup%nada%'),
	('HF_BFA_INCL', '%acup%ear%'), ('HF_BFA_INCL', '%auricular%'),
	('HF_BFA_EXCL', '%acupressure%'), ('HF_BFA_EXCL', '%yoga%'),
	('HF_BFA_EXCL', '%TCMLH%'), ('HF_BFA_EXCL', '%clubface%'),
	('HF_BFA_EXCL', '%plan%'), ('HF_BFA_EXCL', '%labfasting%'),

	-- Location-name general exclusions
	('LN_GEN_EXCL', '%research%'), ('LN_GEN_EXCL', '%rsch%'),
	('LN_GEN_EXCL', '%refer%'),
	('LN_GEN_EXCL', '%follo%'), ('LN_GEN_EXCL', '%f/u%'), ('LN_GEN_EXCL', '%fup%'),
	('LN_GEN_EXCL', '%fol%'), ('LN_GEN_EXCL', '%flwup%'), ('LN_GEN_EXCL', '%fl up%'),
	('LN_GEN_EXCL', '%fll up%'),
	('LN_GEN_EXCL', '%cons%'), ('LN_GEN_EXCL', '%econs%'), ('LN_GEN_EXCL', '%e consult%'),
	('LN_GEN_EXCL', '%e-con%'), ('LN_GEN_EXCL', '%cnslt%'),
	('LN_GEN_EXCL', '%com tx%'), ('LN_GEN_EXCL', '%comm care%'), ('LN_GEN_EXCL', '%com care%'),
	('LN_GEN_EXCL', '%choice%'), ('LN_GEN_EXCL', '% cc %'), ('LN_GEN_EXCL', '%community%'),
	('LN_GEN_EXCL', '%non va%'), ('LN_GEN_EXCL', '%non-va%'), ('LN_GEN_EXCL', '%nonva%'),
	('LN_GEN_EXCL', '%vcp%'), ('LN_GEN_EXCL', '%outside%'), ('LN_GEN_EXCL', '%no show%'),
	('LN_GEN_EXCL', '%no-show%'), ('LN_GEN_EXCL', '%messag%'), ('LN_GEN_EXCL', '%test%'),
	('LN_GEN_EXCL', '%vcl%'), ('LN_GEN_EXCL', '%fager%'), ('LN_GEN_EXCL', '%call attempt%'),
	('LN_GEN_EXCL', '%patient letter%'), ('LN_GEN_EXCL', '%consent%'),
	('LN_GEN_EXCL', '%appointment request%'), ('LN_GEN_EXCL', '%instructions%'),
	('LN_GEN_EXCL', '%outcome%'), ('LN_GEN_EXCL', '%reply%'), ('LN_GEN_EXCL', '%intake%'),
	('LN_GEN_EXCL', '%eval%'), ('LN_GEN_EXCL', '%reminder%'), ('LN_GEN_EXCL', '%discharge%'),

	-- Location-name acupuncture terms
	('LN_TRAD_INCL', '%acup%'), ('LN_TRAD_INCL', '%acpu%'),
	('LN_TRAD_EXCL', '%battlefield%'), ('LN_TRAD_EXCL', '%bfa%'),
	('LN_TRAD_EXCL', '%BTL ACP%'), ('LN_TRAD_EXCL', '%BF acup%'),
	('LN_TRAD_EXCL', '%/battlefield%'), ('LN_TRAD_EXCL', '%battlefld%'),
	('LN_TRAD_EXCL', '%study%'), ('LN_TRAD_EXCL', '%acupressure%'),
	('LN_TRAD_EXCL', '%labfasting%'), ('LN_TRAD_EXCL', '%secm%'),
	('LN_TRAD_EXCL', '%tele%'), ('LN_TRAD_EXCL', '%bacup a%'),
	('LN_TRAD_EXCL', '%battle-acu%'), ('LN_TRAD_EXCL', '%battle acu%'),
	('LN_TRAD_EXCL', '%acupress%'), ('LN_TRAD_EXCL', '%plan%'),
	('LN_BFA_INCL', '%battlefield%'), ('LN_BFA_INCL', '%bfa%'),
	('LN_BFA_INCL', '%BTL ACP%'), ('LN_BFA_INCL', '%BF acup%'),
	('LN_BFA_INCL', '%battlefld%'), ('LN_BFA_INCL', '%/battlefield%'),
	('LN_BFA_INCL', '%battle-acu%'), ('LN_BFA_INCL', '%battle acu%'),
	('LN_BFA_EXCL', '%study%'), ('LN_BFA_EXCL', '%acupressure%'),
	('LN_BFA_EXCL', '%labfasting%'), ('LN_BFA_EXCL', '%secm%'),
	('LN_BFA_EXCL', '%tele%'), ('LN_BFA_EXCL', '%bacup a%'),
	('LN_BFA_EXCL', '%plan%'),

	-- Note-title general exclusions
	('NT_GEN_EXCL', '%research%'), ('NT_GEN_EXCL', '%rsch%'),
	('NT_GEN_EXCL', '%refer%'),
	('NT_GEN_EXCL', '%follo%'), ('NT_GEN_EXCL', '%f/u%'), ('NT_GEN_EXCL', '%fup%'),
	('NT_GEN_EXCL', '%fol%'), ('NT_GEN_EXCL', '%flwup%'), ('NT_GEN_EXCL', '%fl up%'),
	('NT_GEN_EXCL', '%fll up%'),
	('NT_GEN_EXCL', '%cons%'), ('NT_GEN_EXCL', '%econs%'), ('NT_GEN_EXCL', '%e consult%'),
	('NT_GEN_EXCL', '%e-con%'), ('NT_GEN_EXCL', '%cnslt%'),
	('NT_GEN_EXCL', '%com tx%'), ('NT_GEN_EXCL', '%comm care%'), ('NT_GEN_EXCL', '%com care%'),
	('NT_GEN_EXCL', '%choice%'), ('NT_GEN_EXCL', '% cc %'), ('NT_GEN_EXCL', '%community%'),
	('NT_GEN_EXCL', '%non va%'), ('NT_GEN_EXCL', '%non-va%'), ('NT_GEN_EXCL', '%nonva%'),
	('NT_GEN_EXCL', '%vcp%'), ('NT_GEN_EXCL', '%outside%'), ('NT_GEN_EXCL', '%no show%'),
	('NT_GEN_EXCL', '%no-show%'), ('NT_GEN_EXCL', '%messag%'), ('NT_GEN_EXCL', '%test%'),
	('NT_GEN_EXCL', '%vcl%'), ('NT_GEN_EXCL', '%fager%'), ('NT_GEN_EXCL', '%call attempt%'),
	('NT_GEN_EXCL', '%patient letter%'), ('NT_GEN_EXCL', '%consent%'),
	('NT_GEN_EXCL', '%appointment request%'), ('NT_GEN_EXCL', '%instructions%'),
	('NT_GEN_EXCL', '%outcome%'), ('NT_GEN_EXCL', '%reply%'), ('NT_GEN_EXCL', '%intake%'),
	('NT_GEN_EXCL', '%eval%'), ('NT_GEN_EXCL', '%reminder%'), ('NT_GEN_EXCL', '%discharge%'),

	-- Note-title acupuncture terms
	('NT_TRAD_INCL', '%acup%'), ('NT_TRAD_INCL', '%acpu%'),
	('NT_TRAD_EXCL', '%battlefield%'), ('NT_TRAD_EXCL', '%bfa%'),
	('NT_TRAD_EXCL', '%BTL ACP%'), ('NT_TRAD_EXCL', '%BF acup%'),
	('NT_TRAD_EXCL', '%/battlefield%'), ('NT_TRAD_EXCL', '%battlefld%'),
	('NT_TRAD_EXCL', '%chiro%'), ('NT_TRAD_EXCL', '%acupressure%'),
	('NT_TRAD_EXCL', '%phone%'), ('NT_TRAD_EXCL', '%plan%'),
	('NT_BFA_INCL', '%battlefield%'), ('NT_BFA_INCL', '%bfa%'),
	('NT_BFA_INCL', '%BTL ACP%'), ('NT_BFA_INCL', '%BF acup%'),
	('NT_BFA_INCL', '%battlefld%'), ('NT_BFA_INCL', '%/battlefield%'),
	('NT_BFA_INCL', '%battle-acu%'), ('NT_BFA_INCL', '%battle acu%'),
	('NT_BFA_EXCL', '%note%'), ('NT_BFA_EXCL', '%acupressure%'),
	('NT_BFA_EXCL', '%plan%'),

	-- Location-name-only exclusion terms, applied to TIU document names
	('LN_ONLY_GEN_EXCL', '%research%'), ('LN_ONLY_GEN_EXCL', '%rsch%'),
	('LN_ONLY_GEN_EXCL', '%refer%'),
	('LN_ONLY_GEN_EXCL', '%follo%'), ('LN_ONLY_GEN_EXCL', '%f/u%'),
	('LN_ONLY_GEN_EXCL', '%fup%'), ('LN_ONLY_GEN_EXCL', '%fol%'),
	('LN_ONLY_GEN_EXCL', '%flwup%'), ('LN_ONLY_GEN_EXCL', '%fl up%'),
	('LN_ONLY_GEN_EXCL', '%fll up%'),
	('LN_ONLY_GEN_EXCL', '%cons%'), ('LN_ONLY_GEN_EXCL', '%econs%'),
	('LN_ONLY_GEN_EXCL', '%e consult%'), ('LN_ONLY_GEN_EXCL', '%e-con%'),
	('LN_ONLY_GEN_EXCL', '%cnslt%'),
	('LN_ONLY_GEN_EXCL', '%com tx%'), ('LN_ONLY_GEN_EXCL', '%comm care%'),
	('LN_ONLY_GEN_EXCL', '%com care%'), ('LN_ONLY_GEN_EXCL', '%choice%'),
	('LN_ONLY_GEN_EXCL', '% cc %'), ('LN_ONLY_GEN_EXCL', '%community%'),
	('LN_ONLY_GEN_EXCL', '%non va%'), ('LN_ONLY_GEN_EXCL', '%non-va%'),
	('LN_ONLY_GEN_EXCL', '%nonva%'), ('LN_ONLY_GEN_EXCL', '%vcp%'),
	('LN_ONLY_GEN_EXCL', '%outside%'), ('LN_ONLY_GEN_EXCL', '%no show%'),
	('LN_ONLY_GEN_EXCL', '%no-show%'), ('LN_ONLY_GEN_EXCL', '%messag%'),
	('LN_ONLY_GEN_EXCL', '%test%'), ('LN_ONLY_GEN_EXCL', '%vcl%'),
	('LN_ONLY_GEN_EXCL', '%call attempt%'), ('LN_ONLY_GEN_EXCL', '%consent%'),
	('LN_ONLY_GEN_EXCL', '%letter%'), ('LN_ONLY_GEN_EXCL', '%admin%'),
	('LN_ONLY_GEN_EXCL', '%cancel%'), ('LN_ONLY_GEN_EXCL', '%sched%'),
	('LN_ONLY_GEN_EXCL', '%nurs%'), ('LN_ONLY_GEN_EXCL', '%contact%'),
	('LN_ONLY_GEN_EXCL', '%error%'), ('LN_ONLY_GEN_EXCL', '%surg%'),
	('LN_ONLY_GEN_EXCL', '%biopsy%'), ('LN_ONLY_GEN_EXCL', '%adm%'),
	('LN_ONLY_GEN_EXCL', '%apmt%'), ('LN_ONLY_GEN_EXCL', '%discharge%'),
	('LN_ONLY_GEN_EXCL', '%lab%'),
	('LN_ONLY_ACUP_EXCL', '%correspondence%'), ('LN_ONLY_ACUP_EXCL', '%dental%'),
	('LN_ONLY_ACUP_EXCL', '%drug%'), ('LN_ONLY_ACUP_EXCL', '%mail%'),
	('LN_ONLY_ACUP_EXCL', '%naloxone%'), ('LN_ONLY_ACUP_EXCL', '%ophth%'),
	('LN_ONLY_ACUP_EXCL', '%optom%'), ('LN_ONLY_ACUP_EXCL', '%outreach%'),
	('LN_ONLY_ACUP_EXCL', '%psychi%'), ('LN_ONLY_ACUP_EXCL', '%screening%'),
	('LN_ONLY_ACUP_EXCL', '%mri%'), ('LN_ONLY_ACUP_EXCL', '%hybrid%'),
	('LN_ONLY_ACUP_EXCL', '%travel%'), ('LN_ONLY_ACUP_EXCL', '%plan%'),
	('LN_ONLY_ACUP_EXCL', '%rec%'), ('LN_ONLY_ACUP_EXCL', '%physical%'),
	('LN_ONLY_ACUP_EXCL', '%clc%'), ('LN_ONLY_ACUP_EXCL', '%oss%'),
	('LN_ONLY_ACUP_EXCL', '%rehab%'), ('LN_ONLY_ACUP_EXCL', '%primary care%'),
	('LN_ONLY_ACUP_EXCL', '%interim%'),

	-- Note-title-only exclusion terms, applied to clinic/location names
	('NT_ONLY_GEN_EXCL', '%research%'), ('NT_ONLY_GEN_EXCL', '%rsch%'),
	('NT_ONLY_GEN_EXCL', '%refer%'),
	('NT_ONLY_GEN_EXCL', '%follo%'), ('NT_ONLY_GEN_EXCL', '%f/u%'),
	('NT_ONLY_GEN_EXCL', '%fup%'), ('NT_ONLY_GEN_EXCL', '%fol%'),
	('NT_ONLY_GEN_EXCL', '%flwup%'), ('NT_ONLY_GEN_EXCL', '%fl up%'),
	('NT_ONLY_GEN_EXCL', '%fll up%'),
	('NT_ONLY_GEN_EXCL', '%cons%'), ('NT_ONLY_GEN_EXCL', '%econs%'),
	('NT_ONLY_GEN_EXCL', '%e consult%'), ('NT_ONLY_GEN_EXCL', '%e-con%'),
	('NT_ONLY_GEN_EXCL', '%cnslt%'),
	('NT_ONLY_GEN_EXCL', '%com tx%'), ('NT_ONLY_GEN_EXCL', '%comm care%'),
	('NT_ONLY_GEN_EXCL', '%com care%'), ('NT_ONLY_GEN_EXCL', '%choice%'),
	('NT_ONLY_GEN_EXCL', '% cc %'), ('NT_ONLY_GEN_EXCL', '%community%'),
	('NT_ONLY_GEN_EXCL', '%non va%'), ('NT_ONLY_GEN_EXCL', '%non-va%'),
	('NT_ONLY_GEN_EXCL', '%nonva%'), ('NT_ONLY_GEN_EXCL', '%vcp%'),
	('NT_ONLY_GEN_EXCL', '%outside%'), ('NT_ONLY_GEN_EXCL', '%no show%'),
	('NT_ONLY_GEN_EXCL', '%no-show%'), ('NT_ONLY_GEN_EXCL', '%messag%'),
	('NT_ONLY_GEN_EXCL', '%test%'), ('NT_ONLY_GEN_EXCL', '%vcl%');

/***************************************************************
Acupuncture lookup tables
***************************************************************/

SELECT DISTINCT
	 C.LocationSID
	,B.DSSLocationSID
	,A.DSSLocationStopCodeSID
	,A.Sta3n
	,D.Sta6a
	,A.NationalChar4
	,A.NationalChar4Description
	,CASE
		WHEN UPPER(A.NationalChar4) = 'ACUP' THEN 'Acup-Trad'
		WHEN UPPER(A.NationalChar4) = 'IACT' THEN 'Acup-BFA'
	 END AS CIHType
INTO #acu_char4_lookup
FROM CDWWork.Dim.DSSLocationStopCode AS A
	INNER JOIN CDWWork.Dim.DSSLocation AS B
		ON A.DSSLocationStopCodeSID = B.DSSLocationStopCodeSID
	INNER JOIN CDWWork.Dim.[Location] AS C
		ON B.LocationSID = C.LocationSID
	LEFT JOIN CDWWork.Dim.Division AS D
		ON C.DivisionSID = D.DivisionSID
WHERE UPPER(A.NationalChar4) IN ('ACUP', 'IACT');

SELECT DISTINCT
	 CPTSID
	,Sta3n
	,CPTCode
	,CPTName
	,CPTDescription
	,'Acup-Trad' AS CIHType
INTO #acu_cpt_lookup
FROM CDWWork.Dim.CPT
WHERE CPTCode IN ('97810', '97811', '97813', '97814');

SELECT DISTINCT
	 H.HealthFactorTypeSID
	,H.HealthFactorType
	,H.HealthFactorCategory
	,H.Sta3n
	,'Acup-Trad' AS CIHType
INTO #acu_health_factor_lookup
FROM CDWWork.Dim.HealthFactorType AS H
WHERE EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet = 'HF_TRAD_INCL'
			AND H.HealthFactorType LIKE T.Pattern
	)
	AND NOT EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet IN ('HF_GEN_EXCL', 'HF_TRAD_EXCL')
			AND H.HealthFactorType LIKE T.Pattern
	)
UNION
SELECT DISTINCT
	 H.HealthFactorTypeSID
	,H.HealthFactorType
	,H.HealthFactorCategory
	,H.Sta3n
	,'Acup-BFA' AS CIHType
FROM CDWWork.Dim.HealthFactorType AS H
WHERE EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet = 'HF_BFA_INCL'
			AND H.HealthFactorType LIKE T.Pattern
	)
	AND NOT EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet IN ('HF_GEN_EXCL', 'HF_BFA_EXCL')
			AND H.HealthFactorType LIKE T.Pattern
	);

SELECT DISTINCT
	 L.LocationSID
	,L.LocationName
	,L.Sta3n
	,'Acup-Trad' AS CIHType
INTO #acu_location_lookup
FROM CDWWork.Dim.[Location] AS L
WHERE EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet = 'LN_TRAD_INCL'
			AND L.LocationName LIKE T.Pattern
	)
	AND NOT EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet IN ('LN_GEN_EXCL', 'LN_TRAD_EXCL')
			AND L.LocationName LIKE T.Pattern
	)
UNION
SELECT DISTINCT
	 L.LocationSID
	,L.LocationName
	,L.Sta3n
	,'Acup-BFA' AS CIHType
FROM CDWWork.Dim.[Location] AS L
WHERE EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet = 'LN_BFA_INCL'
			AND L.LocationName LIKE T.Pattern
	)
	AND NOT EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet IN ('LN_GEN_EXCL', 'LN_BFA_EXCL')
			AND L.LocationName LIKE T.Pattern
	);

SELECT DISTINCT
	 D.TIUDocumentDefinitionSID
	,D.TIUDocumentDefinition
	,D.Sta3n
	,'Acup-Trad' AS CIHType
INTO #acu_note_title_lookup
FROM CDWWork.Dim.TIUDocumentDefinition AS D
WHERE EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet = 'NT_TRAD_INCL'
			AND D.TIUDocumentDefinition LIKE T.Pattern
	)
	AND NOT EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet IN ('NT_GEN_EXCL', 'NT_TRAD_EXCL')
			AND D.TIUDocumentDefinition LIKE T.Pattern
	)
UNION
SELECT DISTINCT
	 D.TIUDocumentDefinitionSID
	,D.TIUDocumentDefinition
	,D.Sta3n
	,'Acup-BFA' AS CIHType
FROM CDWWork.Dim.TIUDocumentDefinition AS D
WHERE EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet = 'NT_BFA_INCL'
			AND D.TIUDocumentDefinition LIKE T.Pattern
	)
	AND NOT EXISTS (
		SELECT 1 FROM #acu_pattern_terms AS T
		WHERE T.TermSet IN ('NT_GEN_EXCL', 'NT_BFA_EXCL')
			AND D.TIUDocumentDefinition LIKE T.Pattern
	);

SELECT DISTINCT
	 D.TIUDocumentDefinitionSID
	,D.TIUDocumentDefinition
INTO #acu_location_only_exclusion_lookup
FROM CDWWork.Dim.TIUDocumentDefinition AS D
WHERE EXISTS (
	SELECT 1 FROM #acu_pattern_terms AS T
	WHERE T.TermSet IN ('LN_ONLY_GEN_EXCL', 'LN_ONLY_ACUP_EXCL')
		AND D.TIUDocumentDefinition LIKE T.Pattern
);

SELECT DISTINCT
	 L.LocationSID
	,L.LocationName
INTO #acu_note_title_only_exclusion_lookup
FROM CDWWork.Dim.[Location] AS L
WHERE EXISTS (
	SELECT 1 FROM #acu_pattern_terms AS T
	WHERE T.TermSet = 'NT_ONLY_GEN_EXCL'
		AND L.LocationName LIKE T.Pattern
);

SELECT DISTINCT LocationSID
INTO #acu_telehealth_lookup
FROM (
	SELECT C.LocationSID
	FROM CDWWork.Dim.DSSLocationStopCode AS A
		INNER JOIN CDWWork.Dim.DSSLocation AS B
			ON A.DSSLocationStopCodeSID = B.DSSLocationStopCodeSID
		INNER JOIN CDWWork.Dim.[Location] AS C
			ON B.LocationSID = C.LocationSID
		INNER JOIN CDWWork.Dim.StopCode AS D
			ON C.PrimaryStopCodeSID = D.StopCodeSID
		LEFT JOIN CDWWork.Dim.StopCode AS E
			ON C.SecondaryStopCodeSID = E.StopCodeSID
	WHERE D.StopCode IN ('147', '179', '221', '444', '445', '446', '447', '648', '679', '683', '684', '685', '686', '690', '692', '723', '724')
		OR E.StopCode IN ('147', '179', '221', '444', '445', '446', '447', '648', '679', '683', '684', '685', '686', '690', '692', '723', '724')
	UNION
	SELECT L.LocationSID
	FROM CDWWork.Dim.[Location] AS L
	WHERE (L.LocationName LIKE '%tele%' AND L.LocationName NOT LIKE '%teleret%')
		OR L.LocationName LIKE '%VVC%'
		OR L.LocationName LIKE '%CVT%'
		OR L.LocationName LIKE '%CCHT%'
		OR L.LocationName LIKE 'HT %'
		OR L.LocationName LIKE '%VTC%'
		OR L.LocationName LIKE '% TH %'
		OR L.LocationName LIKE '%Phone%'
) AS TH;

/***************************************************************
Limit outpatient visits to the request date range and eligible
Veterans, then collect acupuncture evidence by method.
***************************************************************/

SELECT DISTINCT
	 V.VisitSID
	,V.PatientSID
	,SP.ScrSSN
	,SP.PatientICN
	,V.Sta3n
	,D.Sta6a
	,V.InstitutionSID
	,V.LocationSID
	,V.PrimaryStopCodeSID
	,V.SecondaryStopCodeSID
	,V.ServiceCategory
	,V.EncounterType
	,V.PatientVeteranFlag
	,V.VisitDateTime
	,CONVERT(date, V.VisitDateTime) AS VisitDate
INTO #acu_outpat_visit
FROM CDWWork.Outpat.Visit AS V
	INNER JOIN CDWWork.SPatient.SPatient AS SP
		ON V.PatientSID = SP.PatientSID
	LEFT JOIN CDWWork.Dim.Division AS D
		ON V.DivisionSID = D.DivisionSID
WHERE V.VisitDateTime >= @StartDateTime
	AND V.VisitDateTime <= @EndDateTime
	AND (SP.CDWPossibleTestPatientFlag IS NULL OR SP.CDWPossibleTestPatientFlag <> 'Y')
	AND SP.VeteranFlag = 'Y';

SELECT DISTINCT
	 V.VisitSID
	,C.CPTCode
	,C.CPTSID
	,C.CIHType
INTO #acu_cpt
FROM #acu_outpat_visit AS V
	INNER JOIN CDWWork.Outpat.VProcedure AS P
		ON V.VisitSID = P.VisitSID
	INNER JOIN #acu_cpt_lookup AS C
		ON P.CPTSID = C.CPTSID;

WITH all_visits AS (
	SELECT VisitSID
		,CIHType
		,COUNT(DISTINCT CPTSID) AS CPT_num_terms
	FROM #acu_cpt
	GROUP BY VisitSID, CIHType
),
cpt_terms_wide AS (
	SELECT DISTINCT A.VisitSID
		,A.CIHType
		,STUFF((
			SELECT '; ' + B.CPTCode
			FROM #acu_cpt AS B
			WHERE A.VisitSID = B.VisitSID
				AND A.CIHType = B.CIHType
			FOR XML PATH('')
		), 1, 2, '') AS CPT_codes
	FROM #acu_cpt AS A
)
SELECT DISTINCT
	 A.VisitSID
	,A.CIHType
	,A.CPT_num_terms
	,T.CPT_codes
INTO #acu_cpt_wide
FROM all_visits AS A
	LEFT JOIN cpt_terms_wide AS T
		ON A.VisitSID = T.VisitSID
		AND A.CIHType = T.CIHType;

WITH intermed AS (
	SELECT DISTINCT
		 V.VisitSID
		,C.NationalChar4 AS CHAR4_code
		,C.CIHType
		,MIN(C.CIHType) OVER (PARTITION BY V.VisitSID) AS min_CIHType
	FROM #acu_outpat_visit AS V
		INNER JOIN #acu_char4_lookup AS C
			ON V.LocationSID = C.LocationSID
)
SELECT
	 VisitSID
	,CHAR4_code
	,CIHType
INTO #acu_char4
FROM intermed
WHERE CIHType = min_CIHType;

WITH intermed AS (
	SELECT DISTINCT
		 V.VisitSID
		,L.CIHType
		,L.LocationName
		,MIN(L.CIHType) OVER (PARTITION BY V.VisitSID) AS min_CIHType
	FROM #acu_outpat_visit AS V
		INNER JOIN #acu_location_lookup AS L
			ON V.LocationSID = L.LocationSID
)
SELECT
	 VisitSID
	,CIHType
	,LocationName
INTO #acu_loc_name
FROM intermed
WHERE CIHType = min_CIHType;

WITH intermed AS (
	SELECT DISTINCT
		 V.VisitSID
		,L.TIUDocumentDefinition
		,L.TIUDocumentDefinitionSID
		,L.CIHType
		,MIN(L.CIHType) OVER (PARTITION BY V.VisitSID) AS min_CIHType
	FROM #acu_outpat_visit AS V
		INNER JOIN CDWWork.TIU.TIUDocument AS T
			ON V.VisitSID = T.VisitSID
		INNER JOIN #acu_note_title_lookup AS L
			ON T.TIUDocumentDefinitionSID = L.TIUDocumentDefinitionSID
)
SELECT
	 VisitSID
	,TIUDocumentDefinition
	,TIUDocumentDefinitionSID
	,CIHType
INTO #acu_nt
FROM intermed
WHERE CIHType = min_CIHType;

WITH all_visits AS (
	SELECT VisitSID
		,CIHType
		,COUNT(DISTINCT TIUDocumentDefinitionSID) AS NT_num_terms
	FROM #acu_nt
	GROUP BY VisitSID, CIHType
),
nt_terms_wide AS (
	SELECT DISTINCT A.VisitSID
		,A.CIHType
		,STUFF((
			SELECT '; ' + B.TIUDocumentDefinition
			FROM #acu_nt AS B
			WHERE A.VisitSID = B.VisitSID
				AND A.CIHType = B.CIHType
			FOR XML PATH(''), TYPE
		).value('.', 'varchar(max)'), 1, 2, '') AS NT_terms
	FROM #acu_nt AS A
)
SELECT DISTINCT
	 A.VisitSID
	,A.CIHType
	,A.NT_num_terms
	,T.NT_terms
INTO #acu_nt_wide
FROM all_visits AS A
	LEFT JOIN nt_terms_wide AS T
		ON A.VisitSID = T.VisitSID
		AND A.CIHType = T.CIHType;

WITH intermed AS (
	SELECT DISTINCT
		 V.VisitSID
		,L.HealthFactorType
		,L.HealthFactorTypeSID
		,L.CIHType
		,MIN(L.CIHType) OVER (PARTITION BY V.VisitSID) AS min_CIHType
	FROM #acu_outpat_visit AS V
		INNER JOIN CDWWork.HF.HealthFactor AS H
			ON V.VisitSID = H.VisitSID
		INNER JOIN #acu_health_factor_lookup AS L
			ON H.HealthFactorTypeSID = L.HealthFactorTypeSID
)
SELECT
	 VisitSID
	,HealthFactorType
	,HealthFactorTypeSID
	,CIHType
INTO #acu_hf
FROM intermed
WHERE CIHType = min_CIHType;

WITH all_visits AS (
	SELECT VisitSID
		,CIHType
		,COUNT(DISTINCT HealthFactorTypeSID) AS HF_num_terms
	FROM #acu_hf
	GROUP BY VisitSID, CIHType
),
hf_terms_wide AS (
	SELECT DISTINCT A.VisitSID
		,A.CIHType
		,STUFF((
			SELECT '; ' + B.HealthFactorType
			FROM #acu_hf AS B
			WHERE A.VisitSID = B.VisitSID
				AND A.CIHType = B.CIHType
			FOR XML PATH(''), TYPE
		).value('.', 'varchar(max)'), 1, 2, '') AS HF_terms
	FROM #acu_hf AS A
)
SELECT DISTINCT
	 A.VisitSID
	,A.CIHType
	,A.HF_num_terms
	,T.HF_terms
INTO #acu_hf_wide
FROM all_visits AS A
	LEFT JOIN hf_terms_wide AS T
		ON A.VisitSID = T.VisitSID
		AND A.CIHType = T.CIHType;

/***************************************************************
Consolidate evidence sources, apply newer exclusions, and reduce
to the same patient-day/patient-list temp tables used downstream.
***************************************************************/

WITH visit_list AS (
	SELECT VisitSID FROM #acu_cpt
	UNION
	SELECT VisitSID FROM #acu_char4
	UNION
	SELECT VisitSID FROM #acu_loc_name
	UNION
	SELECT VisitSID FROM #acu_nt_wide
	UNION
	SELECT VisitSID FROM #acu_hf_wide
)
SELECT DISTINCT
	 A.VisitSID
	,CASE WHEN C.CIHType = 'Acup-BFA'
			OR N.CIHType = 'Acup-BFA'
			OR L.CIHType = 'Acup-BFA'
			OR H.CIHType = 'Acup-BFA'
			OR CH.CIHType = 'Acup-BFA'
		THEN 'Acup-BFA' ELSE 'Acup-Trad' END AS CIHType
	,CASE WHEN C.VisitSID IS NOT NULL THEN 1 ELSE 0 END AS CPT
	,C.CPT_num_terms
	,C.CPT_codes
	,CASE WHEN N.VisitSID IS NOT NULL THEN 1 ELSE 0 END AS NoteTitle
	,N.NT_num_terms
	,N.NT_terms
	,CASE WHEN L.VisitSID IS NOT NULL THEN 1 ELSE 0 END AS LocationName
	,L.LocationName AS LocationNameText
	,CASE WHEN H.VisitSID IS NOT NULL THEN 1 ELSE 0 END AS HealthFactor
	,H.HF_num_terms
	,H.HF_terms
	,CASE WHEN CH.VisitSID IS NOT NULL THEN 1 ELSE 0 END AS CHAR4
	,CH.CHAR4_code
	,CAST(0 AS int) AS StopCode
INTO #acu_consolidated_methods
FROM visit_list AS A
	LEFT JOIN #acu_cpt_wide AS C
		ON A.VisitSID = C.VisitSID
	LEFT JOIN #acu_nt_wide AS N
		ON A.VisitSID = N.VisitSID
	LEFT JOIN #acu_loc_name AS L
		ON A.VisitSID = L.VisitSID
	LEFT JOIN #acu_hf_wide AS H
		ON A.VisitSID = H.VisitSID
	LEFT JOIN #acu_char4 AS CH
		ON A.VisitSID = CH.VisitSID;

SELECT DISTINCT
	 V.PatientSID
	,V.ScrSSN
	,V.PatientICN
	,A.VisitSID
	,V.VisitDate
	,A.CIHType
	,V.Sta3n
	,V.Sta6a
	,CASE WHEN TH.LocationSID IS NOT NULL THEN 1 ELSE 0 END AS Tele
	,SC1.StopCode AS PrimaryStopCode
	,SC2.StopCode AS SecondaryStopCode
	,A.CPT
	,A.CPT_num_terms
	,A.CPT_codes
	,A.NoteTitle
	,A.NT_num_terms
	,A.NT_terms
	,A.LocationName
	,A.LocationNameText
	,A.HealthFactor
	,A.HF_num_terms
	,A.HF_terms
	,A.CHAR4
	,A.CHAR4_code
	,A.StopCode
	,CASE WHEN A.CPT = 1 OR A.NoteTitle = 1 OR A.HealthFactor = 1 OR A.CHAR4 = 1 THEN 1 ELSE 0 END AS strong_evid
	,CASE WHEN A.LocationName = 1 OR A.StopCode = 1 THEN 1 ELSE 0 END AS weak_evid
INTO #acu_consolidated_methods2
FROM #acu_consolidated_methods AS A
	INNER JOIN #acu_outpat_visit AS V
		ON A.VisitSID = V.VisitSID
	LEFT JOIN #acu_telehealth_lookup AS TH
		ON V.LocationSID = TH.LocationSID
	LEFT JOIN CDWWork.Dim.StopCode AS SC1
		ON V.PrimaryStopCodeSID = SC1.StopCodeSID
	LEFT JOIN CDWWork.Dim.StopCode AS SC2
		ON V.SecondaryStopCodeSID = SC2.StopCodeSID;

SELECT *
INTO #acu_consolidated_methods3
FROM #acu_consolidated_methods2
WHERE (PrimaryStopCode IS NULL OR PrimaryStopCode NOT IN ('459', '655', '656', '660', '669', '679'))
	AND (SecondaryStopCode IS NULL OR SecondaryStopCode NOT IN ('459', '655', '656', '660', '669', '679'));

SELECT DISTINCT
	 A.VisitSID
INTO #acu_location_name_only_exclusions
FROM #acu_consolidated_methods3 AS A
	INNER JOIN CDWWork.TIU.TIUDocument AS T
		ON A.VisitSID = T.VisitSID
	INNER JOIN #acu_location_only_exclusion_lookup AS X
		ON T.TIUDocumentDefinitionSID = X.TIUDocumentDefinitionSID
WHERE A.CPT = 0
	AND A.NoteTitle = 0
	AND A.LocationName = 1
	AND A.HealthFactor = 0
	AND A.CHAR4 = 0
	AND A.StopCode = 0;

SELECT A.*
INTO #acu_consolidated_methods_excl1
FROM #acu_consolidated_methods3 AS A
WHERE NOT EXISTS (
	SELECT 1
	FROM #acu_location_name_only_exclusions AS X
	WHERE A.VisitSID = X.VisitSID
);

SELECT DISTINCT
	 A.VisitSID
INTO #acu_note_title_only_exclusions
FROM #acu_consolidated_methods_excl1 AS A
	INNER JOIN #acu_outpat_visit AS V
		ON A.VisitSID = V.VisitSID
	INNER JOIN #acu_note_title_only_exclusion_lookup AS X
		ON V.LocationSID = X.LocationSID
WHERE A.CPT = 0
	AND A.NoteTitle = 1
	AND A.LocationName = 0
	AND A.HealthFactor = 0
	AND A.CHAR4 = 0
	AND A.StopCode = 0;

SELECT
	 A.PatientSID
	,A.VisitSID
	,A.VisitDate
	,A.CPT
	,A.NoteTitle
	,A.HealthFactor
	,A.LocationName
	,A.CHAR4
	,CASE WHEN A.CIHType = 'Acup-BFA' THEN 1 ELSE 0 END AS BFA
	,A.CIHType
	,A.Tele
	,A.PrimaryStopCode
	,A.SecondaryStopCode
	,A.CPT_num_terms
	,A.CPT_codes
	,A.NT_num_terms
	,A.NT_terms
	,A.LocationNameText
	,A.HF_num_terms
	,A.HF_terms
	,A.CHAR4_code
	,A.StopCode
	,A.strong_evid
	,A.weak_evid
INTO #acu_visits_consolidated
FROM #acu_consolidated_methods_excl1 AS A
WHERE NOT EXISTS (
	SELECT 1
	FROM #acu_note_title_only_exclusions AS X
	WHERE A.VisitSID = X.VisitSID
);

SELECT
	 A.PatientSID
	,A.VisitDate
	,MIN(A.VisitSID) AS VisitSID
	,MAX(A.CPT) AS any_CPT
	,MAX(A.NoteTitle) AS any_note_title
	,MAX(A.LocationName) AS any_loc_name
	,MAX(A.HealthFactor) AS any_health_factor
	,MAX(A.CHAR4) AS any_CHAR4
	,CASE WHEN MAX(A.BFA) = 1 THEN 'BFA' ELSE 'Traditional' END AS acu_type
INTO #acu_visits_final
FROM #acu_visits_consolidated AS A
GROUP BY A.PatientSID, A.VisitDate;

SELECT DISTINCT
	 PatientSID
INTO #acu_patient_list
FROM #acu_visits_final;

/***************************************************************
Patient information - filter to those who have had at least
1 acupuncture visit and get associated Veteran status.
***************************************************************/

SELECT DISTINCT
	 P.PatientSID
	,P.PatientICN
	,P.TestPatientFlag
	,P.VeteranFlag
	,P.Age
	,P.DeathDateTime
	,P.Gender
	,P.IneligibleReason
	,P.PreferredInstitutionSID
	,P.InsuranceCoverageFlag
	,P.MedicaidEligibleFlag
	,P.MaritalStatus
	,PR.Race
	,ADDR.Zip AS PatientZip
	,ADDR.County AS PatientCounty
	,ADDR.State AS PatientState
	,ADDR.GISFIPSCode AS PatientGISFIPSCode
	,ADDR.GISMarket AS PatientGISMarket
	,ADDR.GISSubmarket AS PatientGISSubmarket
	,ADDR.GISSector AS PatientGISSector
	,ADDR.GISURH AS PatientGISURH
	,ADDR.AddressStartDateTime AS PatientAddressStartDateTime
	,ADDR.AddressEndDateTime AS PatientAddressEndDateTime
	,VET.VeteranFlag AS ADRVeteranFlag
	,EH.EnrollStartDate
	,EH.EnrollEndDate
	,EH.RecordCreateDate
	,EH.RecordModifiedDate
INTO #acu_patient_info
FROM CDWWork.Patient.Patient AS P
	LEFT JOIN CDWWork.PatSub.PatientRace AS PR
		ON P.PatientSID = PR.PatientSID
	LEFT JOIN CDWWork.SPatient.SPatientAddress AS ADDR
		ON P.PatientSID = ADDR.PatientSID
	INNER JOIN CDWWork.Veteran.ADRPerson AS VET
		ON VET.ADRPersonICN = P.PatientICN
	LEFT JOIN CDWWork.ADR.ADREnrollHistory AS EH
		ON VET.ADRPersonSID = EH.ADRPersonSID
	INNER JOIN #acu_patient_list AS ACU
		ON P.PatientSID = ACU.PatientSID
WHERE (P.TestPatientFlag IS NULL OR P.TestPatientFlag <> 'Y')
	AND P.VeteranFlag = 'Y';

/***************************************************************
Outpatient diagnosis information for patients that have received
acupuncture.
***************************************************************/

SELECT DISTINCT
	 OD.PatientSID
	,OD.VisitSID
	,OD.ProblemListSID
	,OD.EventDateTime
	,OD.Sta3n
	,OD.ICD10SID
	,ICD.ICD10Code
	,OD.PrimarySecondary
	,ICD.DRGIdentifier
	,PL.ClinicalTermSID
	,PL.OnsetDateTime
	,PL.ResolvedDateTime
	,PL.ServiceConnectedFlag
	,PL.ProblemListClass
	,PL.ActiveFlag
	,CT.ClinicalTerm
	,CT.ClinicalTermScope
INTO #acu_outpatient_diagnoses
FROM CDWWork.Outpat.VDiagnosis AS OD
	INNER JOIN CDWWork.Dim.ICD10 AS ICD
		ON OD.ICD10SID = ICD.ICD10SID
	INNER JOIN CDWWork.Outpat.ProblemList AS PL
		ON OD.PatientSID = PL.PatientSID
		AND OD.ProblemListSID = PL.ProblemListSID
		AND OD.ICD10SID = PL.ICD10SID
	INNER JOIN CDWWork.Dim.ClinicalTerm AS CT
		ON PL.ClinicalTermSID = CT.ClinicalTermSID
	INNER JOIN #acu_patient_list AS ACU
		ON OD.PatientSID = ACU.PatientSID
WHERE OD.EventDateTime >= @StartDateTime
	AND OD.EventDateTime <= @EndDateTime;

/***************************************************************
Inpatient diagnosis information for patients who have received
acupuncture.
***************************************************************/

SELECT DISTINCT
	 ID.PatientSID
	,ID.ICD10SID
	,ID.OrdinalNumber
	,ID.DischargeDateTime
	,ICD.ICD10Code
	,ICD.DRGIdentifier
INTO #acu_inpatient_diagnoses
FROM CDWWork.Inpat.InpatientDiagnosis AS ID
	INNER JOIN CDWWork.Dim.ICD10 AS ICD
		ON ID.ICD10SID = ICD.ICD10SID
	INNER JOIN #acu_patient_list AS ACU
		ON ID.PatientSID = ACU.PatientSID
WHERE ID.DischargeDateTime >= @StartDateTime
	AND ID.DischargeDateTime <= @EndDateTime;

/***************************************************************
Vital signs / pain-score data.
***************************************************************/

SELECT DISTINCT
	 VS.PatientSID
	,VS.LocationSID
	,VS.VitalTypeSID
	,VS.VitalSignTakenDateTime
	,VS.VitalResult
	,VS.VitalResultNumeric
	,VT.VitalType
INTO #acu_vital_signs
FROM CDWWork.Vital.VitalSign AS VS
	INNER JOIN CDWWork.Dim.VitalType AS VT
		ON VS.VitalTypeSID = VT.VitalTypeSID
	INNER JOIN #acu_patient_list AS ACU
		ON VS.PatientSID = ACU.PatientSID
WHERE (VS.EnteredInErrorFlag IS NULL OR VS.EnteredInErrorFlag <> 'Y')
	AND VS.VitalSignTakenDateTime >= @StartDateTime
	AND VS.VitalSignTakenDateTime <= @EndDateTime;

/***************************************************************
Mental Health Factors
***************************************************************/
select distinct
	 m.PatientSID
	,acu.PatientICN
	,m.SurveyName
	,m.SurveyScale
	,m.RawScore
	,m.TransformedScore1
into #mh_factors
from CDWWork.MH.SurveyResult as m
	INNER JOIN #acu_patient_list AS ACU
		ON VS.PatientSID = ACU.PatientSID
where m.VitalSignTakenDateTime >= @StartDateTime
	AND m.VitalSignTakenDateTime <= @EndDateTime;
