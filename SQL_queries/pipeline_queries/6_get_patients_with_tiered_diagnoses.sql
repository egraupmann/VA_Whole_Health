/**************************************************************/
/* get all diagnoses that fall into the list of tiers for all*/
/* patients, those who are or aren't getting care			*/
/**************************************************************/

DECLARE @StepStart DATETIME;
DECLARE @PipelineStart DATETIME = GETDATE();
DECLARE @WindowStart DATETIME = '2020-10-01';  -- date cutoff for person to be considered as having the condition
DECLARE @WindowEnd DATETIME = dateadd(year, 1, @windowStart)

--this gets SQL to print out each step's time as it's running instead of only for all at the end
DECLARE @msg VARCHAR(200);

/*******************************************************************************
STEP 0: Delete any of the permenantely persisted tables and created an aggregated
list that is derived from the ICD10_Tier_List and the ICD10s that are commonly
associated with acupuncture usage but not in the list. THis will form the basis
of all the people that may be our user base
*******************************************************************************/
DROP TABLE IF EXISTS opccct_cih.dflt.COMBINED_tiered_Diagnoses;
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_tiered_referrals;
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.ALL_tiered_Diagnoses_FY21;
drop table if exists #icd_10_user_list;
drop table if exists #user_icd10s;


with primary_codes as (
    select *
    FROM vhacdwa01.OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
    where (EverPrimaryFlag=1 OR Condition='Chronic Neck Pain' OR condition='Other chronic musculoskelatal pain') 
        and PatientMostRecent_ACU_RelatedDiagnosis >= '2025-09-01' 
        and [group] <> 'Exclude'
)
SELECT
    case when len(ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from ICD10Code)) 
         else ICD10Code end as ICD10Code,
    ICD10Description,
    [group],
    Group_A_Evidence_Certainty_Rating,
    Condition,
    sum(TimesDiagnosedTotal)          AS icd10_total,
    COUNT(DISTINCT PatientICN) AS icd10_patient_count
into #user_icd10s
FROM primary_codes
GROUP BY ICD10Code, ICD10Description, [group], Condition, Group_A_Evidence_Certainty_Rating
HAVING COUNT(DISTINCT PatientICN) >= 100  OR [group] is not null
ORDER BY icd10_total DESC;

with all_icds as (
        select
        [Group]
        ,group_a_evidence_certainty_rating
        ,condition
        ,case when len(icd_10_code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from icd_10_code)) 
             else icd_10_code end as icd_10_code
        ,unique_handling
        ,Chronic_Version
    from vhacdwa01.opccct_cih.dflt.ICD10_Tier_List

    union all

    select
        'Group D' as [Group]
        ,'N/A' as group_a_evidence_certainty_rating
        ,Icd10description as condition
        ,icd10code as icd_10_code
        ,0 as unique_handling
        ,0 as chronic_version
    from #user_icd10s
    where [group] is null
)
/******************************************************************************
The icd 10 user list will have some dupes. That happens due to the chronic neck
pain codes having ICD-10s listed twice. Once for being chronic and the other
just due to pain. I need to dedupe and then add back in the group info at the 
end to avoid getting duplication errors and expanding out the list of people
in the likely to use list
******************************************************************************/
select distinct *
into #icd_10_user_list
from all_icds;

/******************************************************************************
STEP 1: VISTA Outpatient diagnoses
******************************************************************************/
SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #VISTA_tiered_outpatient_diagnoses;

-- Drive from the small tier list first; LEFT JOIN to ICD10 changed to INNER
-- (the tier-list join already requires a matching ICD10Code, so the LEFT was
--  effectively an INNER anyway).
SELECT distinct
     OD.PatientSID
    ,OD.VisitSID
    ,OD.Sta3n
    ,OD.VDiagnosisDateTime
    ,c.icd_10_code as ICD10_Code
    ,OD.PrimarySecondary
INTO #VISTA_tiered_outpatient_diagnoses
FROM (select distinct icd_10_code
      from #icd_10_user_list) AS c
    inner JOIN CDWWork.Dim.ICD10 AS ICD
        ON c.icd_10_code = 
            case when len(ICD.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from ICD.ICD10Code)) 
                 else ICD.ICD10Code end
    INNER JOIN CDWWork.Outpat.VDiagnosis AS OD
        ON OD.ICD10SID = ICD.ICD10SID
       AND OD.VDiagnosisDateTime >= @WindowStart AND OD.VDiagnosisDateTime < @WindowEnd

CREATE INDEX IX_vista_outpat_diagnoses
    ON #VISTA_tiered_outpatient_diagnoses (PatientSID);


/** for chronic neck pain, require special handling **/
drop table if exists #VISTA_tiered_outpatient_diagnoses_final;

with chronic_pain as (
    select distinct PatientSID
        ,VisitSID
        ,1 as chronic_indicator_found
    from #VISTA_tiered_outpatient_diagnoses
    where ICD10_Code in ('G89.29','G89.4')
)

select a.*, case when b.chronic_indicator_found is null then 0 else 1 end as chronic_indicator_found
INTO #VISTA_tiered_outpatient_diagnoses_final
from #VISTA_tiered_outpatient_diagnoses as a
    left join chronic_pain as b
        on a.patientSID = b.patientSID
        AND a.visitSID = b.visitSID;

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
    ,c.icd_10_code as ICD10_Code
    ,CASE WHEN ID.OrdinalNumber = 0 THEN 'P' ELSE 'S' END AS PrimarySecondary
INTO #VISTA_tiered_inpatient_diagnoses
FROM (select distinct icd_10_code
      from #icd_10_user_list) AS c
    INNER JOIN CDWWork.Dim.ICD10 AS ICD
        ON case when len(ICD.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from ICD.ICD10Code)) 
                 else ICD.ICD10Code end
              = c.icd_10_code
    INNER JOIN CDWWork.Inpat.InpatientDiagnosis AS ID
        ON ID.ICD10SID = ICD.ICD10SID
    INNER JOIN CDWWork.Inpat.Inpatient AS INP
        ON ID.InpatientSID = INP.InpatientSID
       AND INP.AdmitDateTime >= @WindowStart AND INP.AdmitDateTime < @WindowEnd;

CREATE INDEX IX_vista_inpat_diagnoses
    ON #VISTA_tiered_inpatient_diagnoses (PatientSID);

/** for chronic neck pain, require special handling **/
drop table if exists #VISTA_tiered_inpatient_diagnoses_final;

with chronic_pain as (
    select distinct PatientSID
        ,InpatientSID
        ,1 as chronic_indicator_found
    from #VISTA_tiered_inpatient_diagnoses
    where ICD10_Code in ('G89.29','G89.4')
)

select a.*, case when b.chronic_indicator_found is null then 0 else 1 end as chronic_indicator_found
INTO #VISTA_tiered_inpatient_diagnoses_final
from #VISTA_tiered_inpatient_diagnoses as a
    left join chronic_pain as b
        on a.patientSID = b.patientSID
        AND a.InpatientSID = b.InpatientSID

SET @msg = 'Step 2: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 3: Unified VISTA diagnoses -> final VISTA Encounter table
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #VISTA_tiered_diagnoses_final;

WITH vista_combined AS (
    SELECT PatientSID, ICD10_Code, VDiagnosisDateTime AS diagnosisDate
        , chronic_indicator_found, Sta3n
    FROM #VISTA_tiered_outpatient_diagnoses_final
    WHERE PrimarySecondary = 'P' or chronic_indicator_found=1

    UNION ALL

    SELECT PatientSID, ICD10_Code, AdmitDateTime AS diagnosisDate
         , chronic_indicator_found, Sta3n
    FROM #VISTA_tiered_inpatient_diagnoses_final
    WHERE PrimarySecondary = 'P' or chronic_indicator_found=1
)
SELECT b.PatientICN
      ,b.age
      ,a.ICD10_Code
      ,max(a.chronic_indicator_found) as chronic_indicator_found
      ,a.Sta3n
      ,count(a.icd10_code) as diagnosis_count
      ,MIN(a.diagnosisDate) AS first_diagnosis_date
      ,MAX(a.diagnosisDate) AS most_recent_diagnosis_date
INTO #VISTA_tiered_diagnoses_final
FROM vista_combined AS a
    INNER JOIN cdwwork.patient.patient AS b
        ON a.PatientSID = b.PatientSID
GROUP BY b.PatientICN, b.age, a.ICD10_Code
         , a.Sta3n;

SET @msg = 'Step 3: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 4: Millennium diagnoses (inpatient + outpatient) -stopped here
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #MILL_tiered_diagnoses_temp;

WITH mill_ICN AS (
    SELECT PersonSID
          ,CASE WHEN AliasName LIKE '%zz%' THEN NULL
                ELSE LEFT(CAST(AliasName AS varchar(50)), 10) END AS PatientICN
    FROM [CDWWork2].[VeteranMill].[PersonAlias]
    WHERE AliasPool = 'ICN'
)
SELECT distinct p.[EncounterSID]
      ,p.[PersonSID]
      ,b.PatientICN
      ,p.[OrganizationNameSID]
      ,p.[EncounterDiagnosisSID]
      ,c.icd_10_code AS ICD10_Code
      ,p.[CodeDescription]
      ,p.[DiagnosisDateTime]
      ,p.[DiagnosisPriority]
      ,p.[DiagnosisDisplay]
INTO #MILL_tiered_diagnoses_temp
FROM (select distinct icd_10_code
      from #icd_10_user_list) AS c
    INNER JOIN [CDWWork2].[Mill].[PatientDiagnosisAll] AS p
        ON case when len(p.CodeID)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from p.CodeID)) 
                 else p.CodeID end
         = c.icd_10_code
       AND p.DiagnosisDateTime >= @WindowStart AND p.DiagnosisDateTime < @WindowEnd
       AND p.SourceVocabulary = 'ICD-10-CM'
    INNER JOIN mill_ICN AS b
        ON p.PersonSID = b.PersonSID;

CREATE INDEX IX_patienticn_diagnoses_tier_one
    ON #MILL_tiered_diagnoses_temp (PatientICN);

/** for chronic neck pain, require special handling **/
drop table if exists #MILL_tiered_diagnoses_final;

with chronic_pain as (
    select distinct [PersonSID]
        ,[EncounterSID]
        ,1 as chronic_indicator_found
    from #MILL_tiered_diagnoses_temp
    where ICD10_Code in ('G89.29','G89.4')
)

select a.*, case when b.chronic_indicator_found is null then 0 else 1 end as chronic_indicator_found, c.Age
INTO #MILL_tiered_diagnoses_final
from #MILL_tiered_diagnoses_temp as a
    left join chronic_pain as b
        on a.[PersonSID] = b.[PersonSID]
        AND a.[EncounterSID] = b.[EncounterSID]
    inner join cdwwork2.VeteranMill.Person as c
        on a.PersonSID = c.Personsid
where DiagnosisPriority=0 or chronic_indicator_found=1;

SET @msg = 'Step 4: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 5: Combine VISTA + MILL diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS opccct_cih.dflt.COMBINED_tiered_Diagnoses;
with combined as (
    SELECT a.PatientICN
          ,a.age
          ,a.chronic_indicator_found
          ,a.ICD10_Code
          ,a.diagnosis_count
          ,a.first_diagnosis_date
          ,a.most_recent_diagnosis_date
          ,b.VISN
          ,'VISTA' AS SrcSystem
    FROM #VISTA_tiered_diagnoses_final AS a
        INNER JOIN cdwwork.dim.vistasite AS b
            ON a.Sta3n = b.Sta3n

    UNION ALL

    SELECT a.PatientICN
          ,a.age
          ,a.chronic_indicator_found
          ,a.ICD10_Code
          ,count(a.ICD10_Code) as diagnosis_count
          ,MIN(a.[DiagnosisDateTime]) AS first_diagnosis_date
          ,MAX(a.[DiagnosisDateTime]) AS most_recent_diagnosis_date
          ,b.VISN
          ,'MILL' AS SrcSystem
    FROM #MILL_tiered_diagnoses_final AS a
        INNER JOIN cdwwork2.mill.valocations AS b
            ON a.[OrganizationNameSID] = b.[OrganizationNameSID]
    GROUP BY a.PatientICN,a.age,a.chronic_indicator_found
               ,a.ICD10_Code, b.VISN
)
select PatientICN
      ,age
      ,ICD10_Code
      ,VISN
      ,SrcSystem
      ,max(chronic_indicator_found) as chronic_indicator_found
      ,sum(diagnosis_count) as diagnosis_count
      ,MIN(first_diagnosis_date) AS first_diagnosis_date
      ,MAX(most_recent_diagnosis_date) AS most_recent_diagnosis_date
INTO opccct_cih.dflt.COMBINED_tiered_Diagnoses
from combined
group by PatientICN, age, ICD10_Code, VISN, SrcSystem;

SET @msg = 'Step 5: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 6: VISTA referral diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #VISTA_referrals;

SELECT DISTINCT
       CASE WHEN MONTH(c.RequestDateTime) >= 10 THEN YEAR(c.RequestDateTime) + 1
            ELSE YEAR(c.RequestDateTime) END AS FiscalYear
      ,c.RequestDateTime
      ,c.[PatientSID]
      ,os.OrderStatus
      ,rs.servicename
      ,case when len(c.[ProvisionalDiagnosis])>=4 then trim(TRAILING '.' from trim(TRAILING '0' from c.[ProvisionalDiagnosis])) 
                 else c.[ProvisionalDiagnosis] end AS ICD10_Code
      ,c.[ProvisionalDiagnosisCode] AS ICD10_Description
      ,'VISTA' AS SourceSystem
      ,c.ConsultSID
      ,b.VISN
INTO #VISTA_referrals
FROM (select distinct icd_10_code
      from #icd_10_user_list) AS d
    INNER JOIN CDWWork.Con.Consult AS c
        ON case when len(c.[ProvisionalDiagnosis])>=4 then trim(TRAILING '.' from trim(TRAILING '0' from c.[ProvisionalDiagnosis])) 
                 else c.[ProvisionalDiagnosis] end = d.icd_10_code
       AND c.RequestDateTime >= @WindowStart AND c.RequestDateTime < @WindowEnd
    INNER JOIN CDWWork.Dim.RequestService AS rs
        ON c.ToRequestServiceSID = rs.RequestServiceSID
    INNER JOIN cdwwork.dim.vistasite AS b
        ON c.Sta3n = b.Sta3n
    LEFT JOIN CDWWork.Dim.OrderStatus AS os
        ON c.OrderStatusSID = os.OrderStatusSID
WHERE (os.OrderStatus IS NULL OR os.OrderStatus NOT IN ('CANCELLED','DISCONTINUED'));

/** for chronic neck pain, require special handling **/
DROP TABLE IF EXISTS #VISTA_referrals_final;

with chronic_pain as (
    select distinct [PatientSID]
        ,ConsultSID
        ,1 as chronic_indicator_found
    from #VISTA_referrals
    where ICD10_Code in ('G89.29','G89.4')
)

select a.*, case when b.chronic_indicator_found is null then 0 else 1 end as chronic_indicator_found, c.Age
INTO #VISTA_referrals_final
from #VISTA_referrals as a
    left join chronic_pain as b
        on a.[PatientSID] = b.[PatientSID]
        AND a.ConsultSID = b.ConsultSID
    inner join cdwwork.patient.patient as c
        on a.[PatientSID] = c.[PatientSID]

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
      ,d.icd_10_code AS ICD10_Code
      ,c.[CodeDescription]
      ,c.[DiagnosisDateTime]
      ,c.[DiagnosisPriority]
      ,c.[DiagnosisDisplay] AS diag_disp_all
      ,e.VISN
INTO #MILL_referrals
FROM (select distinct icd_10_code
      from #icd_10_user_list) AS d
    INNER JOIN cdwwork2.mill.PatientDiagnosisAll AS c
        ON case when len(c.[CodeID])>=4 then trim(TRAILING '.' from trim(TRAILING '0' from c.[CodeID])) 
                 else c.[CodeID] end = d.icd_10_code
       AND (c.SourceVocabulary = 'ICD-10-CM' OR c.SourceVocabulary IS NULL)
    INNER JOIN [CDWWork2].[StaffMill].[Referral] AS a
        ON a.OutboundEncounterSID = c.encountersid
       AND a.CreateDateTime >= @WindowStart and a.CreateDateTime < @WindowEnd
       AND a.ReferralStatus NOT IN ('Cancelled','Rejected','On Hold','SEND_FAILURE')
    INNER JOIN cdwwork2.mill.valocations AS e
        ON a.[ReferFromOrganizationNameSID] = e.[OrganizationNameSID]
    LEFT JOIN [CDWWork2].[StaffMill].[ReferralAction] AS b
        ON a.[ReferralSID] = b.[ReferralSID]
WHERE (b.ReferralActionType IS NULL OR b.ReferralActionType <> 'Cancel');

/** for chronic neck pain, require special handling **/
DROP TABLE IF EXISTS #MILL_referrals_final;

with chronic_pain as (
    select distinct [PatientSID]
        ,ReferralSID
        ,1 as chronic_indicator_found
    from #MILL_referrals
    where ICD10_Code in ('G89.29','G89.4')
)

select a.*, case when b.chronic_indicator_found is null then 0 else 1 end as chronic_indicator_found, c.Age
INTO #MILL_referrals_final
from #MILL_referrals as a
    left join chronic_pain as b
        on a.[PatientSID] = b.[PatientSID]
        AND a.ReferralSID = b.ReferralSID
    inner join cdwwork2.VeteranMill.Person as c
        on a.PatientSID = c.Personsid

SET @msg = 'Step 7: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 8: Combine referral diagnoses
******************************************************************************/

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #COMBINED_tiered_referrals_temp;

SELECT ConsultSID AS ReferralSID
      ,RequestDateTime
      ,[PatientSID]
      ,age
      ,OrderStatus
      ,servicename
      ,ICD10_Code
      ,ICD10_Description
      ,SourceSystem
      ,chronic_indicator_found
      ,VISN
INTO #COMBINED_tiered_referrals_temp
FROM #VISTA_referrals_final

UNION ALL

SELECT ReferralSID
      ,RequestDateTime
      ,[PatientSID]
      ,age
      ,OrderStatus
      ,servicename
      ,ICD10_Code
      ,CodeDescription AS ICD10_Description
      ,SourceSystem
      ,chronic_indicator_found
      ,VISN
FROM #MILL_referrals_final;

SET @msg = 'Step 8: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;

/******************************************************************************
STEP 9: Attach PatientICN + aggregate referrals to 1 row per patient/ICD10
******************************************************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_tiered_referrals;

SET @StepStart = GETDATE();
DROP TABLE IF EXISTS #with_ICN;

SELECT a.*
      ,COALESCE(b.PatientICN, c.PatientICN) AS PatientICN
INTO #with_ICN
FROM #COMBINED_tiered_referrals_temp AS a
    INNER JOIN (
        SELECT PersonSID AS PatientSID
              ,CASE WHEN AliasName LIKE '%zz%' THEN NULL
                    ELSE LEFT(CAST(AliasName AS varchar(50)), 10) END AS PatientICN
        FROM [CDWWork2].[VeteranMill].[PersonAlias]
        WHERE AliasPool = 'ICN'
    ) AS b ON a.PatientSID = b.PatientSID
    LEFT JOIN CDWWork.patient.patient AS c
        ON a.PatientSID = c.PatientSID;

WITH diagnoses_summary AS (
    SELECT PatientICN
          ,ICD10_Code
          ,max(chronic_indicator_found) as chronic_indicator_found
          ,count(PatientSID) as diagnosis_count
          ,min(RequestDateTime) as PatientFirstDiagnosis
          ,MAX(RequestDateTime) AS PatientMostRecentDiagnosis
    FROM #with_ICN
    GROUP BY PatientICN, ICD10_Code
)
SELECT a.PatientICN
      ,a.PatientSID
      ,a.age
      ,a.SourceSystem
      ,m.diagnosis_count
      ,m.PatientFirstDiagnosis
      ,m.PatientMostRecentDiagnosis
      ,a.ICD10_Code
      ,m.chronic_indicator_found
      ,a.VISN
INTO OPCCCT_CIH.dflt.COMBINED_tiered_referrals
FROM #with_ICN AS a
    INNER JOIN diagnoses_summary AS m
        ON a.PatientICN = m.PatientICN
       AND a.ICD10_Code = m.ICD10_Code;

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
      ,age
      ,[ICD10_Code]
      ,diagnosis_count
      ,first_diagnosis_date
      ,[most_recent_diagnosis_date]
      ,chronic_indicator_found
      ,[VISN]
INTO #ALL_tiered_Diagnoses_temp
FROM OPCCCT_CIH.dflt.COMBINED_tiered_Diagnoses

UNION ALL

SELECT [PatientICN]
      ,age
      ,[ICD10_Code]
      ,diagnosis_count
      ,PatientFirstDiagnosis as first_diagnosis_date
      ,PatientMostRecentDiagnosis AS [most_recent_diagnosis_date]
      ,chronic_indicator_found
      ,[VISN]
FROM OPCCCT_CIH.dflt.COMBINED_tiered_referrals;

/*******************************************
make the final compiled table, need several steps 
to handle all of the special exceptions
**********************************************/
DROP TABLE IF EXISTS #ALL_tiered_Diagnoses;

-- Pre-aggregate acupuncture usage once (avoids re-scanning inside the main query)
WITH acup AS (
    SELECT cast(PatientICN as varchar(50)) as PatientICN
          ,MAX(eventDate) AS most_recent_acup_usage
    FROM [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters]
    GROUP BY PatientICN
)
SELECT a.[PatientICN]
      ,a.age
      ,a.[ICD10_Code]
      ,sum(a.diagnosis_count) as diagnosis_count
      ,min(a.first_diagnosis_date) as first_diagnosis_date
      ,MAX(a.[most_recent_diagnosis_date]) AS most_recent_diagnosis_date
      ,max(a.chronic_indicator_found) as chronic_indicator_found
      ,c.most_recent_acup_usage
      ,CASE WHEN c.most_recent_acup_usage IS NOT NULL THEN 1 ELSE 0 END AS ever_used_acupuncture
      ,CASE WHEN c.most_recent_acup_usage >= @WindowStart AND c.most_recent_acup_usage < @windowend THEN 1 ELSE 0 END AS current_acupuncture_user
INTO #ALL_tiered_Diagnoses
FROM #ALL_tiered_Diagnoses_temp AS a
    LEFT JOIN acup AS c
        ON a.PatientICN = c.PatientICN
GROUP BY a.[PatientICN], a.age, a.[ICD10_Code]
        , c.most_recent_acup_usage;

/**************************************************************************
Now need to account for the distinctions in the ICD10 codes. For example,
M54.2 can be considered chronic neck pain if it meets the chronic criteria but, if not
it's still a likely user, just a lower group and not considered 'chronic'
***************************************************************************/
DROP TABLE IF EXISTS #special_conditions;

--determine, at the ICD10 level, whether the code has multiple instances and needs special logic
with icd10_unique_list as (
    select ICD_10_Code, max(unique_handling) as unique_handling
    from #icd_10_user_list
    group by ICD_10_Code
),
unique_icd10 as (
    select a.*, b.unique_handling
    from #ALL_tiered_Diagnoses as a
        inner join icd10_unique_list as b
            ON a.ICD10_Code = b.ICD_10_Code
)
select *
    /* the logic to deal with the conditions with more complicated logic */
    ,case when Unique_Handling = 1 and ICD10_Code not in ('F51.01','F51.04','G47','G47.','G47.0','G47.00','G47.01','G47.09')
				then case when diagnosis_count>=2 AND (DATEDIFF(day, first_diagnosis_date, most_recent_diagnosis_date))>=90 then 1
						  when chronic_indicator_found=1 then 1
						  else 0 end 
				else 0 end as chronic_version
into #special_conditions
from unique_icd10;

/* make the final table, which accounts for the duplicated ICD10s in the list by identifying whether
they are the special, higher level evidence group or not
also, only keep 1 VISN per patient, if there are multiple to avoid duplicate records. This is rare so handling crudely
right now but just taking the VISN associated with their most recent visit which seems justifiable.*/
with visn_distinct as (
    select patienticn, visn, max([most_recent_diagnosis_date]) as recent_diagnoses
    from #ALL_tiered_Diagnoses_temp
    group by PatientICN, visn
),
ranked AS (
	SELECT DISTINCT
		 patienticn
        ,visn
		,ROW_NUMBER() OVER (
					PARTITION BY patienticn
					ORDER BY recent_diagnoses desc
				) AS rn
	FROM visn_distinct
),
visn_recent as (
	select patienticn, visn
	from ranked
	where rn=1
)

select a.PatientICN
      ,age
      ,ICD10_Code
      ,[group]
      ,case when ICD10_Code in ('F51.01','F51.04','G47','G47.','G47.0','G47.00','G47.01','G47.09') then
				case when age >=60 then 'Moderate' else 'Low/Very Low' end
			else b.Group_A_Evidence_Certainty_Rating end as Group_A_Evidence_Certainty_Rating
	  ,case when ICD10_Code in ('F51.01','F51.04','G47','G47.','G47.0','G47.00','G47.01','G47.09') then
				case when age >=60 then 'Insomnia in elderly adults' else 'Primary Insomnia' end
			else b.Condition end as Condition
      ,diagnosis_count
      ,first_diagnosis_date
      ,most_recent_diagnosis_date
      ,a.unique_handling
      ,a.chronic_version
      ,VISN
      ,most_recent_acup_usage
      ,ever_used_acupuncture
      ,current_acupuncture_user
into OPCCCT_CIH.dflt.ALL_tiered_Diagnoses_FY21
from #special_conditions as a 
    inner join #icd_10_user_list as b
        ON a.ICD10_Code = b.ICD_10_Code
        AND a.unique_handling = b.Unique_Handling
        and a.chronic_version = b.Chronic_Version
    inner join visn_recent as c
        on a.PatientICN = c.patienticn;

SET @msg = 'Step 10: ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
RAISERROR(@msg, 0, 1) WITH NOWAIT;
PRINT 'TOTAL PIPELINE: ' + CAST(DATEDIFF(SECOND, @PipelineStart, GETDATE()) AS VARCHAR) + ' seconds';

