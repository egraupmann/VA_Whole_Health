/**************************************************************/
/* get all diagnoses that fall into the list of tiers for all*/
/* patients, those who are or aren't getting care			*/
/**************************************************************/

DECLARE @StepStart DATETIME;
DECLARE @PipelineStart DATETIME = GETDATE();
DECLARE @WindowStart DATETIME = DATEADD(YEAR, -1, '2026-08-01');  -- date cutoff for person to be considered as having the condition

--this gets SQL to print out each step's time as it's running instead of only for all at the end
DECLARE @msg VARCHAR(200);

/******************************************************************************
STEP 1: VISTA Outpatient diagnoses
******************************************************************************/
SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #VISTA_tiered_outpatient_diagnoses;

-- Drive from the small tier list first; LEFT JOIN to ICD10 changed to INNER
-- (the tier-list join already requires a matching ICD10Code, so the LEFT was
--  effectively an INNER anyway).
SELECT
     OD.PatientSID
    ,OD.VisitSID
    ,OD.Sta3n
    ,OD.VDiagnosisDateTime
    ,ICD.ICD10Code
    ,c.[group] AS tier
    ,OD.PrimarySecondary
INTO #VISTA_tiered_outpatient_diagnoses
FROM opccct_cih.dflt.ICD10_Tier_List AS c
    INNER JOIN CDWWork.Dim.ICD10 AS ICD
        ON ICD.ICD10Code = c.code
    INNER JOIN CDWWork.Outpat.VDiagnosis AS OD
        ON OD.ICD10SID = ICD.ICD10SID
       AND OD.VDiagnosisDateTime >= @WindowStart;

CREATE INDEX IX_vista_outpat_diagnoses
    ON #VISTA_tiered_outpatient_diagnoses (PatientSID);

SET @msg = 'Step 1: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 2: VISTA Inpatient diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #VISTA_tiered_inpatient_diagnoses;

-- NOTE: DISTINCT kept for now, but verify it's needed (see notes below).
SELECT DISTINCT
     ID.PatientSID
    ,ID.Sta3n
    ,ID.InpatientSID
    ,INP.AdmitDateTime
    ,ICD.ICD10Code
    ,c.[group] AS tier
    ,CASE WHEN ID.OrdinalNumber = 0 THEN 'P' ELSE 'S' END AS PrimarySecondary
INTO #VISTA_tiered_inpatient_diagnoses
FROM opccct_cih.dflt.ICD10_Tier_List AS c
    INNER JOIN CDWWork.Dim.ICD10 AS ICD
        ON ICD.ICD10Code = c.code
    INNER JOIN CDWWork.Inpat.InpatientDiagnosis AS ID
        ON ID.ICD10SID = ICD.ICD10SID
    INNER JOIN CDWWork.Inpat.Inpatient AS INP
        ON ID.InpatientSID = INP.InpatientSID
       AND INP.AdmitDateTime >= @WindowStart;

CREATE INDEX IX_vista_inpat_diagnoses
    ON #VISTA_tiered_inpatient_diagnoses (PatientSID);

SET @msg = 'Step 2: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 3: Unified VISTA diagnoses -> final VISTA table
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS opccct_cih.dflt.VISTA_tiered_diagnoses;

WITH vista_combined AS (
    SELECT PatientSID, ICD10Code, VDiagnosisDateTime AS diagnosisDate, tier, Sta3n
    FROM #VISTA_tiered_outpatient_diagnoses
    WHERE PrimarySecondary = 'P'
    UNION ALL
    SELECT PatientSID, ICD10Code, AdmitDateTime AS diagnosisDate, tier, Sta3n
    FROM #VISTA_tiered_inpatient_diagnoses
    WHERE PrimarySecondary = 'P'
)
SELECT b.PatientICN
      ,a.ICD10Code
      ,a.tier
      ,a.Sta3n
      ,MAX(a.diagnosisDate) AS most_recent_diagnosis_date
INTO opccct_cih.dflt.VISTA_tiered_diagnoses
FROM vista_combined AS a
    INNER JOIN cdwwork.patient.patient AS b
        ON a.PatientSID = b.PatientSID
GROUP BY b.PatientICN, a.ICD10Code, a.tier, a.Sta3n;

SET @msg = 'Step 3: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 4: Millennium diagnoses (inpatient + outpatient)
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS opccct_cih.dflt.MILL_tiered_diagnoses;

WITH mill_ICN AS (
    SELECT PersonSID
          ,CASE WHEN AliasName LIKE '%zz%' THEN NULL
                ELSE LEFT(CAST(AliasName AS varchar(50)), 10) END AS PatientICN
    FROM [CDWWork2].[VeteranMill].[PersonAlias]
    WHERE AliasPool = 'ICN'
)
SELECT p.[EncounterSID]
      ,p.[PersonSID]
      ,b.PatientICN
      ,p.[OrganizationNameSID]
      ,p.[EncounterDiagnosisSID]
      ,p.[CodeID] AS ICD10Code
      ,c.[group] AS tier
      ,p.[CodeDescription]
      ,p.[DiagnosisDateTime]
      ,p.[DiagnosisPriority]
      ,p.[DiagnosisDisplay]
INTO opccct_cih.dflt.MILL_tiered_diagnoses
FROM opccct_cih.dflt.ICD10_Tier_List AS c
    INNER JOIN [CDWWork2].[Mill].[PatientDiagnosisAll] AS p
        ON p.CodeID = c.code
       AND p.DiagnosisDateTime >= @WindowStart
       AND p.SourceVocabulary = 'ICD-10-CM'
    INNER JOIN mill_ICN AS b
        ON p.PersonSID = b.PersonSID;

CREATE INDEX IX_patienticn_diagnoses_tier_one
    ON opccct_cih.dflt.MILL_tiered_diagnoses (PatientICN);

SET @msg = 'Step 4: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 5: Combine VISTA + MILL diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS opccct_cih.dflt.COMBINED_tiered_Diagnoses;

SELECT a.PatientICN
      ,a.ICD10Code
      ,a.tier
      ,a.most_recent_diagnosis_date
      ,b.VISN
      ,'VISTA' AS SrcSystem
INTO opccct_cih.dflt.COMBINED_tiered_Diagnoses
FROM opccct_cih.dflt.VISTA_tiered_diagnoses AS a
    INNER JOIN cdwwork.dim.vistasite AS b
        ON a.Sta3n = b.Sta3n

UNION ALL

SELECT a.PatientICN
      ,a.ICD10Code
      ,a.tier
      ,MAX(a.[DiagnosisDateTime]) AS most_recent_diagnosis_date
      ,b.VISN
      ,'MILL' AS SrcSystem
FROM opccct_cih.dflt.MILL_tiered_diagnoses AS a
    INNER JOIN cdwwork2.mill.valocations AS b
        ON a.[OrganizationNameSID] = b.[OrganizationNameSID]
GROUP BY a.PatientICN, a.ICD10Code, a.tier, b.VISN;

SET @msg = 'Step 5: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 6: VISTA referral diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #VISTA_referrals;

SELECT CASE WHEN MONTH(c.RequestDateTime) >= 10 THEN YEAR(c.RequestDateTime) + 1
            ELSE YEAR(c.RequestDateTime) END AS FiscalYear
      ,c.RequestDateTime
      ,c.[PatientSID]
      ,os.OrderStatus
      ,rs.servicename
      ,c.[ProvisionalDiagnosis] AS ICD10Code
      ,c.[ProvisionalDiagnosisCode] AS ICD10_Description
      ,'VISTA' AS SourceSystem
      ,d.[group] AS tier
      ,c.ConsultSID
      ,b.VISN
INTO #VISTA_referrals
FROM opccct_cih.dflt.ICD10_Tier_List AS d
    INNER JOIN CDWWork.Con.Consult AS c
        ON c.[ProvisionalDiagnosis] = d.code
       AND c.RequestDateTime >= @WindowStart
    INNER JOIN CDWWork.Dim.RequestService AS rs
        ON c.ToRequestServiceSID = rs.RequestServiceSID
    INNER JOIN cdwwork.dim.vistasite AS b
        ON c.Sta3n = b.Sta3n
    LEFT JOIN CDWWork.Dim.OrderStatus AS os
        ON c.OrderStatusSID = os.OrderStatusSID
WHERE (os.OrderStatus IS NULL OR os.OrderStatus NOT IN ('CANCELLED','DISCONTINUED'));

SET @msg = 'Step 6: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 7: MILL referral diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #MILL_referrals;

SELECT DISTINCT
       CASE WHEN MONTH(a.ReferralWrittenDateTime) >= 10 THEN YEAR(a.ReferralWrittenDateTime) + 1
            ELSE YEAR(a.ReferralWrittenDateTime) END AS FiscalYear
      ,a.ReferralWrittenDateTime AS RequestDateTime
      ,a.ServiceTypeRequested AS ServiceName
      ,a.MedicalService AS acup_type
      ,a.[PersonSID] AS PatientSID
      ,a.ReferralStatus AS OrderStatus
      ,a.ReferralSID
      ,'MILLENNIUM' AS SourceSystem
      ,c.[CodeID] AS ICD10Code
      ,c.[CodeDescription]
      ,c.[DiagnosisDateTime]
      ,c.[DiagnosisPriority]
      ,c.[DiagnosisDisplay] AS diag_disp_all
      ,e.VISN
      ,d.[group] AS tier
INTO #MILL_referrals
FROM opccct_cih.dflt.ICD10_Tier_List AS d
    INNER JOIN cdwwork2.mill.PatientDiagnosisAll AS c
        ON c.[CodeID] = d.code
       AND (c.SourceVocabulary = 'ICD-10-CM' OR c.SourceVocabulary IS NULL)
    INNER JOIN [CDWWork2].[StaffMill].[Referral] AS a
        ON a.OutboundEncounterSID = c.encountersid
       AND a.CreateDateTime >= @WindowStart
       AND a.ReferralStatus NOT IN ('Cancelled','Rejected','On Hold','SEND_FAILURE')
    INNER JOIN cdwwork2.mill.valocations AS e
        ON a.[ReferFromOrganizationNameSID] = e.[OrganizationNameSID]
    LEFT JOIN [CDWWork2].[StaffMill].[ReferralAction] AS b
        ON a.[ReferralSID] = b.[ReferralSID]
WHERE (b.ReferralActionType IS NULL OR b.ReferralActionType <> 'Cancel');

SET @msg = 'Step 7: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 8: Combine referral diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_tiered_referrals;

SELECT ConsultSID AS ReferralSID
      ,RequestDateTime
      ,[PatientSID]
      ,OrderStatus
      ,servicename
      ,ICD10Code
      ,ICD10_Description
      ,SourceSystem
      ,tier
      ,VISN
INTO OPCCCT_CIH.dflt.COMBINED_tiered_referrals
FROM #VISTA_referrals

UNION ALL

SELECT ReferralSID
      ,RequestDateTime
      ,[PatientSID]
      ,OrderStatus
      ,servicename
      ,ICD10Code
      ,CodeDescription AS ICD10_Description
      ,SourceSystem
      ,tier
      ,VISN
FROM #MILL_referrals;

SET @msg = 'Step 8: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 9: Attach PatientICN + aggregate referrals to 1 row per patient/ICD10
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #with_ICN;

SELECT a.*
      ,COALESCE(b.PatientICN, c.PatientICN) AS PatientICN
INTO #with_ICN
FROM OPCCCT_CIH.dflt.COMBINED_tiered_referrals AS a
    INNER JOIN (
        SELECT PersonSID AS PatientSID
              ,CASE WHEN AliasName LIKE '%zz%' THEN NULL
                    ELSE LEFT(CAST(AliasName AS varchar(50)), 10) END AS PatientICN
        FROM [CDWWork2].[VeteranMill].[PersonAlias]
        WHERE AliasPool = 'ICN'
    ) AS b ON a.PatientSID = b.PatientSID
    LEFT JOIN CDWWork.patient.patient AS c
        ON a.PatientSID = c.PatientSID;

DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_tiered_referrals;

WITH most_recent_diagnosis AS (
    SELECT PatientICN
          ,PatientSID
          ,MAX(RequestDateTime) AS PatientMostRecentDiagnosis
    FROM #with_ICN
    GROUP BY PatientICN, PatientSID
)
SELECT a.PatientICN
      ,a.PatientSID
      ,a.SourceSystem
      ,m.PatientMostRecentDiagnosis
      ,a.ICD10Code
      ,a.tier
      ,a.VISN
INTO OPCCCT_CIH.dflt.COMBINED_tiered_referrals
FROM #with_ICN AS a
    INNER JOIN most_recent_diagnosis AS m
        ON a.PatientICN = m.PatientICN
       AND a.PatientSID = m.PatientSID;

CREATE INDEX IX_diag_referral_summary_patienticn
    ON OPCCCT_CIH.dflt.COMBINED_tiered_referrals (PatientICN);

SET @msg = 'Step 9: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 10: Combine visit + referral diagnoses, aggregate at ICN level
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #ALL_tiered_Diagnoses_temp;

SELECT [PatientICN]
      ,[ICD10Code]
      ,[tier]
      ,[most_recent_diagnosis_date]
      ,[VISN]
INTO #ALL_tiered_Diagnoses_temp
FROM OPCCCT_CIH.dflt.COMBINED_tiered_Diagnoses

UNION ALL

SELECT [PatientICN]
      ,[ICD10Code]
      ,[tier]
      ,PatientMostRecentDiagnosis AS [most_recent_diagnosis_date]
      ,[VISN]
FROM OPCCCT_CIH.dflt.COMBINED_tiered_referrals;

DROP TABLE IF EXISTS OPCCCT_CIH.dflt.ALL_tiered_Diagnoses;

-- Pre-aggregate acupuncture usage once (avoids re-scanning inside the main query)
WITH acup AS (
    SELECT PatientICN
          ,MAX(eventDate) AS most_recent_acup_usage
    FROM [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters]
    GROUP BY PatientICN
)
SELECT a.[PatientICN]
      ,a.[ICD10Code]
      ,desc_lookup.ICD10Description
      ,e.Condition
      ,MAX(a.[most_recent_diagnosis_date]) AS most_recent_diagnosis_date
      ,a.[tier]
      ,a.VISN
      ,c.most_recent_acup_usage
      ,CASE WHEN c.most_recent_acup_usage IS NOT NULL THEN 1 ELSE 0 END AS ever_used_acupuncture
      ,CASE WHEN c.most_recent_acup_usage >= @WindowStart THEN 1 ELSE 0 END AS current_acupuncture_user
INTO OPCCCT_CIH.dflt.ALL_tiered_Diagnoses
FROM #ALL_tiered_Diagnoses_temp AS a
    OUTER APPLY (
        SELECT TOP (1) d.CodeDescription AS ICD10Description
        FROM cdwwork2.mill.PatientDiagnosisAll AS d
        WHERE d.CodeID = a.ICD10Code
        ORDER BY d.CodeDescription
    ) AS desc_lookup
    LEFT JOIN acup AS c
        ON a.PatientICN = c.PatientICN
    left join opccct_cih.dflt.ICD10_Tier_List as e
        on a.ICD10Code = e.code
GROUP BY a.[PatientICN], a.[ICD10Code], desc_lookup.ICD10Description
        ,a.[tier], a.VISN, c.most_recent_acup_usage, e.condition;

SET @msg = 'Step 10: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;
PRINT 'TOTAL PIPELINE: ' + CAST(DATEDIFF(SECOND, @PipelineStart, GETDATE()) AS VARCHAR) + ' seconds';