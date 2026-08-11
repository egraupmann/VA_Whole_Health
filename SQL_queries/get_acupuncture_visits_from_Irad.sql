/******************************************************************************/
/* Health Factor inclusion/exclusion criteria (unchanged from original)      */
/******************************************************************************/
DROP TABLE IF EXISTS #HFGenExcl;
CREATE TABLE #HFGenExcl (ExclString varchar(50));
INSERT INTO #HFGenExcl (ExclString)
VALUES ('%research%'), ('%rsch%'), ('%refer%'),('%follo%'), ('%f/u%'), ('%fup%'), ('%fol%'),
        ('%flwup%'), ('%fl up%'), ('%fll up%'),('%cons%'), ('%econs%'), ('%e consult%'), ('%e-con%'), ('%cnslt%'),
        ('%com tx%'), ('%comm care%'), ('%com care%'), ('%choice%'),('% cc %'), ('%community%'), ('%discharge%'),
        ('%non va%'), ('%non-va%'), ('%nonva%'),('%vcp%'), ('%outside%'), ('%no show%'), ('%no-show%'),
        ('%messag%'), ('%test%'), ('%vcl%'), ('%fager%'),('%call attempt%'), ('%patient letter%'), ('%consent%'),
        ('%appointment request%'), ('%instructions%'), ('%outcome%'),('%reply%'), ('%intake%'), ('%eval%'), ('%reminder%');

DROP TABLE IF EXISTS #HFAcupBfaExcl;
CREATE TABLE #HFAcupBfaExcl (ExclString varchar(50));
INSERT INTO #HFAcupBfaExcl (ExclString)
VALUES('%acupressure%'),('%yoga%'),('%TCMLH%'),('%clubface%'),('%plan%'),('%labfasting%');

DROP TABLE IF EXISTS #HFAcupBfaIncl;
CREATE TABLE #HFAcupBfaIncl (InclString varchar(50));
INSERT INTO #HFAcupBfaIncl (InclString)
VALUES ('%bfa%'), ('%battlefield%'), ('%btl acp%'),('%bf acup%'), ('%battlefld%'),
        ('%acup%nada%'), ('%acup%ear%'), ('%auricular%');

DROP TABLE IF EXISTS #HFAcupTradExcl;
CREATE TABLE #HFAcupTradExcl (ExclString varchar(50));
INSERT INTO #HFAcupTradExcl (ExclString)
VALUES ('%battlefield%'),('%bfa%'),('%btl acp%'),('%bf acup%'),('%battlefld%'),('%biacuplasty%'),
    ('%nada%'),('%ear%'),('%auricular%'),('%acupressure%'),('%yoga%'),('%TCMLH%'),('%plan%');

DROP TABLE IF EXISTS #HFAcupTradIncl;
CREATE TABLE #HFAcupTradIncl (InclString varchar(50));
INSERT INTO #HFAcupTradIncl (InclString)
VALUES ('%acup%'),('%acpu%');

/******************************************************************************/
/* Location Names pipeline (as previously optimized)                         */
/******************************************************************************/
DROP TABLE IF EXISTS #DistinctVisitLocs;
SELECT DISTINCT sta6a, LocationName
INTO #DistinctVisitLocs
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_1_VISITS];

CREATE CLUSTERED INDEX IX_DistinctVisitLocs ON #DistinctVisitLocs (sta6a, LocationName);

DROP TABLE IF EXISTS #LNGenExcl;
CREATE TABLE #LNGenExcl (ExclString varchar(50));
INSERT INTO #LNGenExcl (ExclString)
VALUES ('%research%'),('%rsch%'),('%refer%'),
   ('%follo%'),('%f/u%'),('%fup%'),('%fol%'),('%flwup%'),('%fl up%'),('%fll up%'),
   ('%cons%'),('%econs%'),('%e consult%'),('%e-con%'),('%cnslt%'),
   ('%com tx%'),('%comm care%'),('%com care%'),('%choice%'),('% cc %'),('%community%'),
   ('%non va%'),('%non-va%'),('%nonva%'),
   ('%vcp%'),('%outside%'),('%no show%'),('%no-show%'),('%messag%'),('%test%'),
   ('%vcl%'),('%fager%'),('%call attempt%'),('%patient letter%'),('%consent%'),
   ('%appointment request%'),('%instructions%'),('%outcome%'),('%reply%'),('%intake%'),
   ('%eval%'),('%reminder%'),('%discharge%');

DROP TABLE IF EXISTS #LNGenExclWide;
SELECT A.sta6a, A.LocationName, STRING_AGG(' ' + B.ExclString, '') AS ExclStrings
INTO #LNGenExclWide
FROM #DistinctVisitLocs A
    INNER JOIN #LNGenExcl B ON A.LocationName LIKE B.ExclString
GROUP BY A.sta6a, A.LocationName;

DROP TABLE IF EXISTS #LNAcupTExcl;
CREATE TABLE #LNAcupTExcl (ExclString varchar(50));
INSERT INTO #LNAcupTExcl (ExclString)
VALUES ('%battlefield%'),('%bfa%'),('%BTL ACP%'),('%BF acup%'),('%/battlefield%'),('%battlefld%'),
    ('%study%'),('%acupressure%'),('%labfasting%'),('%secm%'),('%tele%'),('%bacup a%'),
    ('%battle-acu%'),('%battle acu%'),('%acupress%'),('%plan%');

DROP TABLE IF EXISTS #LNAcupTExclWide;
SELECT A.sta6a, A.LocationName, STRING_AGG(' ' + B.ExclString, '') AS ExclStrings
INTO #LNAcupTExclWide
FROM #DistinctVisitLocs A
    INNER JOIN #LNAcupTExcl B ON A.LocationName LIKE B.ExclString
GROUP BY A.sta6a, A.LocationName;

DROP TABLE IF EXISTS #LNAcupTIncl;
CREATE TABLE #LNAcupTIncl (InclString varchar(50));
INSERT INTO #LNAcupTIncl (InclString)
VALUES ('%acup%'),('%acpu%');

DROP TABLE IF EXISTS #LNAcupTInclWide;
SELECT A.sta6a, A.LocationName, STRING_AGG(' ' + B.InclString, '') AS InclStrings
INTO #LNAcupTInclWide
FROM #DistinctVisitLocs A
    INNER JOIN #LNAcupTIncl B ON A.LocationName LIKE B.InclString
GROUP BY A.sta6a, A.LocationName;

DROP TABLE IF EXISTS #LNAcupTrad;
SELECT A.sta6a, A.LocationName,
    CASE WHEN A.InclStrings IS NOT NULL AND B.ExclStrings IS NULL AND C.ExclStrings IS NULL
         THEN 1 ELSE 0 END AS TradQualifies
INTO #LNAcupTrad
FROM #LNAcupTInclWide A
    LEFT JOIN #LNGenExclWide B  ON A.sta6a = B.sta6a AND A.LocationName = B.LocationName
    LEFT JOIN #LNAcupTExclWide C ON A.sta6a = C.sta6a AND A.LocationName = C.LocationName;

-- Sanity check: should be roughly the same order of magnitude as
-- #LNAcupTInclWide (one row per distinct qualifying/non-qualifying
-- location, not fanned out by exclusion pattern count).
SELECT
    (SELECT COUNT(*) FROM #LNAcupTInclWide) AS InclWide_RowCount,
    (SELECT COUNT(*) FROM #LNAcupTrad) AS LNAcupTrad_RowCount;

DROP TABLE IF EXISTS #LNAcupBExcl;
CREATE TABLE #LNAcupBExcl (ExclString varchar(50));
INSERT INTO #LNAcupBExcl (ExclString)
VALUES ('%study%'),('%acupressure%'),('%labfasting%'),('%secm%'),('%tele%'),('%bacup a%'),
        ('%plan%');

DROP TABLE IF EXISTS #LNAcupBExclWide;
SELECT A.sta6a, A.LocationName, STRING_AGG(' ' + B.ExclString, '') AS ExclStrings
INTO #LNAcupBExclWide
FROM #DistinctVisitLocs A
    INNER JOIN #LNAcupBExcl B ON A.LocationName LIKE B.ExclString
GROUP BY A.sta6a, A.LocationName;

DROP TABLE IF EXISTS #LNAcupBIncl;
CREATE TABLE #LNAcupBIncl (InclString varchar(50));
INSERT INTO #LNAcupBIncl (InclString)
VALUES ('%battlefield%'),('%bfa%'), ('%BTL ACP%'),('%BF acup%')
    , ('%battlefld%'),('%/battlefield%'), ('%battle-acu%'),('%battle acu%');

DROP TABLE IF EXISTS #LNAcupBInclWide;
SELECT A.sta6a, A.LocationName, STRING_AGG(' ' + B.InclString, '') AS InclStrings
INTO #LNAcupBInclWide
FROM #DistinctVisitLocs A
    INNER JOIN #LNAcupBIncl B ON A.LocationName LIKE B.InclString
GROUP BY A.sta6a, A.LocationName;

DROP TABLE IF EXISTS #LNAcupBFA;
SELECT A.sta6a, A.LocationName,
    CASE WHEN A.InclStrings IS NOT NULL AND B.ExclStrings IS NULL AND C.ExclStrings IS NULL
         THEN 1 ELSE 0 END AS BfaQualifies
INTO #LNAcupBFA
FROM #LNAcupBInclWide A
    LEFT JOIN #LNGenExclWide B  ON A.sta6a = B.sta6a AND A.LocationName = B.LocationName
    LEFT JOIN #LNAcupBExclWide C ON A.sta6a = C.sta6a AND A.LocationName = C.LocationName;

-- Sanity check: should be roughly the same order of magnitude as
-- #LNAcupBInclWide, not fanned out.
SELECT
    (SELECT COUNT(*) FROM #LNAcupBInclWide) AS InclWide_RowCount,
    (SELECT COUNT(*) FROM #LNAcupBFA) AS LNAcupBFA_RowCount;

-- Now trivially safe: TradQualifies/BfaQualifies are single bits per
-- (sta6a, LocationName), so this FULL JOIN cannot fan out regardless
-- of how many patterns originally matched at a location.
DROP TABLE IF EXISTS OPCCCT_cih.dflt.LocationName_filter;
SELECT
    COALESCE(t.sta6a, b.sta6a) AS sta6a,
    COALESCE(t.LocationName, b.LocationName) AS LocationName,
    CONVERT(date, '2022-10-01') AS StartDate,
    CONVERT(date, '2050-01-01') AS EndDate,
    ISNULL(t.TradQualifies, 0) AS TradQualifies,
    ISNULL(b.BfaQualifies, 0) AS BfaQualifies
INTO OPCCCT_cih.dflt.LocationName_filter
FROM #LNAcupTrad t
    FULL JOIN #LNAcupBFA b
        ON t.sta6a = b.sta6a AND t.LocationName = b.LocationName;

-- Sanity check: this should be roughly the count of distinct
-- (sta6a, LocationName) pairs across both inputs combined - low
-- thousands expected. If this is in the millions, STOP before
-- proceeding to #temp_viz - something is still fanning out.
SELECT COUNT(*) AS LocationName_filter_RowCount
FROM OPCCCT_cih.dflt.LocationName_filter;

DROP TABLE IF EXISTS #LNGenExcl;
DROP TABLE IF EXISTS #LNAcupTExcl;
DROP TABLE IF EXISTS #LNAcupTIncl;
DROP TABLE IF EXISTS #LNAcupBExcl;
DROP TABLE IF EXISTS #LNAcupBIncl;
DROP TABLE IF EXISTS #DistinctVisitLocs;

/******************************************************************************/
/* STEP 1: Classify each HealthFactor row (not yet joined to visits)         */
/* This runs pattern matching ONCE per distinct HealthFactorType, using a    */
/* set-based join instead of 6 correlated EXISTS subqueries per output row.  */
/******************************************************************************/
DROP TABLE IF EXISTS #DistinctHFTypes;
SELECT DISTINCT HealthFactorType
INTO #DistinctHFTypes
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_3_HealthFactor]
WHERE HealthFactorType IS NOT NULL;

CREATE CLUSTERED INDEX IX_DistinctHFTypes ON #DistinctHFTypes (HealthFactorType);

DROP TABLE IF EXISTS #HFTypeFlags;
SELECT
    h.HealthFactorType,
    MAX(CASE WHEN bfa_i.InclString IS NOT NULL THEN 1 ELSE 0 END) AS BfaIncl,
    MAX(CASE WHEN bfa_ge.ExclString IS NOT NULL THEN 1 ELSE 0 END) AS BfaGenExcl,
    MAX(CASE WHEN bfa_e.ExclString IS NOT NULL THEN 1 ELSE 0 END) AS BfaSpecExcl,
    MAX(CASE WHEN trad_i.InclString IS NOT NULL THEN 1 ELSE 0 END) AS TradIncl,
    MAX(CASE WHEN trad_ge.ExclString IS NOT NULL THEN 1 ELSE 0 END) AS TradGenExcl,
    MAX(CASE WHEN trad_e.ExclString IS NOT NULL THEN 1 ELSE 0 END) AS TradSpecExcl
INTO #HFTypeFlags
FROM #DistinctHFTypes h
    LEFT JOIN #HFAcupBfaIncl  bfa_i  ON h.HealthFactorType LIKE bfa_i.InclString
    LEFT JOIN #HFGenExcl      bfa_ge ON h.HealthFactorType LIKE bfa_ge.ExclString
    LEFT JOIN #HFAcupBfaExcl  bfa_e  ON h.HealthFactorType LIKE bfa_e.ExclString
    LEFT JOIN #HFAcupTradIncl trad_i  ON h.HealthFactorType LIKE trad_i.InclString
    LEFT JOIN #HFGenExcl      trad_ge ON h.HealthFactorType LIKE trad_ge.ExclString
    LEFT JOIN #HFAcupTradExcl trad_e  ON h.HealthFactorType LIKE trad_e.ExclString
GROUP BY h.HealthFactorType;

DROP TABLE IF EXISTS #HFTypeClassified;
SELECT
    HealthFactorType,
    CASE
        WHEN BfaIncl = 1 AND BfaGenExcl = 0 AND BfaSpecExcl = 0
         AND TradIncl = 1 AND TradGenExcl = 0 AND TradSpecExcl = 0
            THEN 'Acup-Both'
        WHEN BfaIncl = 1 AND BfaGenExcl = 0 AND BfaSpecExcl = 0
            THEN 'Acup-BFA'
        WHEN TradIncl = 1 AND TradGenExcl = 0 AND TradSpecExcl = 0
            THEN 'Acup-Trad'
        ELSE 'Other'
    END AS HealthFactor_Acup
INTO #HFTypeClassified
FROM #HFTypeFlags;

CREATE CLUSTERED INDEX IX_HFTypeClassified ON #HFTypeClassified (HealthFactorType);

/******************************************************************************/
/* STEP 2: Aggregate to one row per (VisitSID, PatientSID) BEFORE joining to  */
/* visits - this is what prevents the health-factor side from fanning out.   */
/* A visit counts as Acup-Trad/BFA/Both if ANY of its health factor rows      */
/* classify that way.                                                        */
/******************************************************************************/
DROP TABLE IF EXISTS #HFPerVisit;
SELECT
    hf.VisitSID,
    hf.PatientSID,
    MAX(CASE WHEN c.HealthFactor_Acup IN ('Acup-Trad','Acup-Both') THEN 1 ELSE 0 END) AS HF_Trad,
    MAX(CASE WHEN c.HealthFactor_Acup IN ('Acup-BFA','Acup-Both') THEN 1 ELSE 0 END) AS HF_BFA
INTO #HFPerVisit
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_3_HealthFactor] hf
    INNER JOIN #HFTypeClassified c ON hf.HealthFactorType = c.HealthFactorType
GROUP BY hf.VisitSID, hf.PatientSID;

CREATE CLUSTERED INDEX IX_HFPerVisit ON #HFPerVisit (VisitSID, PatientSID);

/******************************************************************************/
/* STEP 3: Aggregate CPT to one row per (VisitSID, PatientSID) BEFORE joining.*/
/* Same principle - prevents the CPT side from fanning out against HF.       */
/******************************************************************************/
DROP TABLE IF EXISTS #CPTPerVisit;
SELECT
    c.VisitSID,
    c.PatientSID,
    MAX(CASE WHEN c.CPTCode IN ('97810','97811','97813','97814','WH001') THEN 1 ELSE 0 END) AS CPT_Trad,
    MAX(CASE WHEN c.CPTCode = 'WH009' THEN 1 ELSE 0 END) AS CPT_BFA
INTO #CPTPerVisit
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_4_CPT] c
GROUP BY c.VisitSID, c.PatientSID;

CREATE CLUSTERED INDEX IX_CPTPerVisit ON #CPTPerVisit (VisitSID, PatientSID);

/******************************************************************************/
/* STEP 4: Join visits to the pre-aggregated HF and CPT flags (both are now   */
/* unique per VisitSID/PatientSID, so this join cannot fan out), plus         */
/* location filter. One row per visit, as intended.                          */
/******************************************************************************/
DROP TABLE IF EXISTS #temp_viz;
SELECT
    a.*,
    CASE
        WHEN hfv.HF_Trad = 1 AND hfv.HF_BFA = 1 THEN 'Acup-Both'
        WHEN hfv.HF_Trad = 1 THEN 'Acup-Trad'
        WHEN hfv.HF_BFA = 1 THEN 'Acup-BFA'
        ELSE 'Other'
    END AS HealthFactor_Acup,
    CASE
        WHEN cpv.CPT_Trad = 1 AND cpv.CPT_BFA = 1 THEN 'Acup-Both'
        WHEN cpv.CPT_Trad = 1 THEN 'Acup-Trad'
        WHEN cpv.CPT_BFA = 1 THEN 'Acup-BFA'
        ELSE 'Other'
    END AS CPT_Acup,
    CASE
        WHEN a.nationalchar4 = 'ACUP' AND a.nationalchar4 = 'IACT' THEN 'Acup-Both'  -- preserved from original; see note below
        WHEN a.nationalchar4 = 'ACUP' THEN 'Acup-Trad'
        WHEN a.nationalchar4 = 'IACT' THEN 'Acup-BFA'
        ELSE 'Other'
    END AS Char4_Acup,
    CASE
        WHEN a.[PrimaryStopCode] IN (147, 179, 221, 444, 445, 446, 447, 648, 679, 683, 684, 685, 686, 690, 692, 723, 724)
          OR a.[SecondaryStopCode] IN (147, 179, 221, 444, 445, 446, 447, 648, 679, 683, 684, 685, 686, 690, 692, 723, 724)
            THEN 'Telehealth' ELSE 'In-person'
    END AS VisitType,
    -- Location qualifies for Trad/BFA based on the pre-computed bit flags
    -- from LocationName_filter. Treated as an independent signal, OR'd
    -- with CPT/HealthFactor/Char4 below - not a hard gate.
    CASE
        WHEN ln.TradQualifies = 1 AND ln.BfaQualifies = 1 THEN 'Acup-Both'
        WHEN ln.TradQualifies = 1 THEN 'Acup-Trad'
        WHEN ln.BfaQualifies = 1 THEN 'Acup-BFA'
        ELSE 'Other'
    END AS Location_Acup
INTO #temp_viz
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_1_VISITS] a
    LEFT JOIN #HFPerVisit hfv ON a.VisitSID = hfv.VisitSID AND a.PatientSID = hfv.PatientSID
    LEFT JOIN #CPTPerVisit cpv ON a.VisitSID = cpv.VisitSID AND a.PatientSID = cpv.PatientSID
    LEFT JOIN OPCCCT_cih.dflt.LocationName_filter ln ON a.sta6a = ln.sta6a AND a.LocationName = ln.LocationName
WHERE a.VisitDateTime >= '2020-10-01';

/******************************************************************************/
/* STEP 5: Final acupuncture visit flags - one row per visit, as intended     */
/******************************************************************************/
DROP TABLE IF EXISTS opccct_cih.dflt.acupuncture_vists_opccct_visit_info;
SELECT *,
    CASE WHEN CPT_Acup IN ('Acup-Trad','Acup-Both')
           OR Char4_Acup IN ('Acup-Trad','Acup-Both')
           OR HealthFactor_Acup IN ('Acup-Trad','Acup-Both')
           OR Location_Acup IN ('Acup-Trad','Acup-Both')
         THEN 1 ELSE 0 END AS Acupuncture_Traditional,
    CASE WHEN CPT_Acup IN ('Acup-BFA','Acup-Both')
           OR Char4_Acup IN ('Acup-BFA','Acup-Both')
           OR HealthFactor_Acup IN ('Acup-BFA','Acup-Both')
           OR Location_Acup IN ('Acup-BFA','Acup-Both')
         THEN 1 ELSE 0 END AS Acupuncture_BFA,
    -- Per-signal, per-type flags identifying WHICH source(s) qualified
    -- this visit as Trad and/or BFA acupuncture. Each is independent -
    -- a visit can have multiple flags set to 1 across different signals.
    CASE WHEN CPT_Acup IN ('Acup-Trad','Acup-Both') THEN 1 ELSE 0 END AS Source_CPT_Trad,
    CASE WHEN CPT_Acup IN ('Acup-BFA','Acup-Both') THEN 1 ELSE 0 END AS Source_CPT_BFA,
    CASE WHEN Char4_Acup IN ('Acup-Trad','Acup-Both') THEN 1 ELSE 0 END AS Source_Char4_Trad,
    CASE WHEN Char4_Acup IN ('Acup-BFA','Acup-Both') THEN 1 ELSE 0 END AS Source_Char4_BFA,
    CASE WHEN HealthFactor_Acup IN ('Acup-Trad','Acup-Both') THEN 1 ELSE 0 END AS Source_HF_Trad,
    CASE WHEN HealthFactor_Acup IN ('Acup-BFA','Acup-Both') THEN 1 ELSE 0 END AS Source_HF_BFA,
    CASE WHEN Location_Acup IN ('Acup-Trad','Acup-Both') THEN 1 ELSE 0 END AS Source_Location_Trad,
    CASE WHEN Location_Acup IN ('Acup-BFA','Acup-Both') THEN 1 ELSE 0 END AS Source_Location_BFA
INTO opccct_cih.dflt.acupuncture_vists_opccct_visit_info
FROM #temp_viz
WHERE CPT_Acup IN ('Acup-Both','Acup-Trad','Acup-BFA')
   OR Char4_Acup IN ('Acup-Both','Acup-Trad','Acup-BFA')
   OR HealthFactor_Acup IN ('Acup-Both','Acup-Trad','Acup-BFA')
   OR Location_Acup IN ('Acup-Both','Acup-Trad','Acup-BFA');

/******************************************************************************/
/* Cleanup */
/******************************************************************************/
DROP TABLE IF EXISTS #HFGenExcl;
DROP TABLE IF EXISTS #HFAcupBfaExcl;
DROP TABLE IF EXISTS #HFAcupBfaIncl;
DROP TABLE IF EXISTS #HFAcupTradExcl;
DROP TABLE IF EXISTS #HFAcupTradIncl;
DROP TABLE IF EXISTS #DistinctHFTypes;
DROP TABLE IF EXISTS #HFTypeFlags;
DROP TABLE IF EXISTS #HFTypeClassified;
DROP TABLE IF EXISTS #HFPerVisit;
DROP TABLE IF EXISTS #CPTPerVisit;