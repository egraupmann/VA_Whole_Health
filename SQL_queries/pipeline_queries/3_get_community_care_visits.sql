
/******************************************************************************/
/* Community Care encounter: one row per Consult                */
/* this 1st section is just counts and comparison for QA and such */
/* the lower section gets the patient IDs to get all of the current users    */
/******************************************************************************/
drop table if exists OPCCCT_CIH.dflt.VISTA_comm_care_orders

SELECT CASE WHEN MONTH(c.RequestDateTime) >= 10 THEN YEAR(c.RequestDateTime) + 1
			ELSE YEAR(c.RequestDateTime) END AS FiscalYear,
        c.RequestDateTime,
        [PatientSID],
        os.OrderStatus,
        rs.servicename
       ,[ProvisionalDiagnosis]
       ,[ProvisionalDiagnosisCode],
        CASE WHEN rs.ServiceName LIKE '%BFA%' OR rs.ServiceName LIKE '%AURICULAR%'
            THEN 'BFA' ELSE 'Trad' END as acup_type
        ,'VISTA' as SourceSystem
        ,c.ConsultSID
into OPCCCT_CIH.dflt.VISTA_comm_care_orders
FROM CDWWork.Con.Consult AS c
    inner JOIN CDWWork.Dim.RequestService AS rs
      ON c.ToRequestServiceSID = rs.RequestServiceSID
    LEFT JOIN CDWWork.Dim.OrderStatus AS os
      ON c.OrderStatusSID = os.OrderStatusSID
WHERE
    (rs.ServiceName LIKE '%ACUPUN%'
    OR rs.ServiceName LIKE '%BFA%'
    OR rs.ServiceName LIKE '%ACCUP%'
    OR rs.ServiceName LIKE '%ACUPTRE%'
    OR rs.ServiceName LIKE '%ACPUNCTURE%'
    OR rs.ServiceName LIKE '%AURICULAR%')
  AND (rs.ServiceName LIKE '%COMMUNITY CARE%'
    OR rs.ServiceName LIKE '%NON VA%'
    OR rs.ServiceName LIKE '%NON-VA%'
    OR rs.ServiceName LIKE '%NVCC%'
    OR rs.ServiceName LIKE '%CHOICE%')
  AND c.RequestDateTime >= '2020-10-01'
  and os.OrderStatus <> 'CANCELLED' and os.OrderStatus<>'DISCONTINUED';

/*the logic below was testing whether certain discontinued consults
should be included in the counts. After checking, I don't really think they 
should be without clear guidance from someone else so removing them */
/*
drop table if exists #keep_discont_recs
select DISTINCT ca.*, 'keep' as keep_discont 
into #keep_discont_recs
from CDWWork.Con.ConsultActivity AS ca
    inner join(
            select distinct ConsultSID
            from #VISTA_comm_care_orders
            where orderstatus='DISCONTINUED') as c
        on c.ConsultSID = ca.ConsultSID
where ca.Activity='SCHEDULED';

select a.FiscalYear, a.OrderStatus, b.keep_discont, count(*) as n
from #VISTA_comm_care_orders as a
    left join #keep_discont_recs as b on a.ConsultSID=b.ConsultSID
where a.OrderStatus<>'DISCONTINUED' or b.keep_discont='keep'
group by a.FiscalYear, a.OrderStatus, b.keep_discont;*/

drop table if exists #VISTA_CC_ReferralCounts

select FiscalYear, count(*) as VISTA_CC_Referrals
into #VISTA_CC_ReferralCounts
from OPCCCT_CIH.dflt.VISTA_comm_care_orders 
group by fiscalYear;

/********************************************************************
************Millennium**********************************************
*******************************************************************/
drop table if exists OPCCCT_CIH.dflt.#mill_ref_diag;

SELECT DISTINCT CASE WHEN MONTH(a.ReferralWrittenDateTime) >= 10 THEN YEAR(a.ReferralWrittenDateTime) + 1
			ELSE YEAR(a.ReferralWrittenDateTime) END AS FiscalYear
        ,a.ReferralWrittenDateTime as RequestDateTime
        ,a.ServiceTypeRequested as ServiceName
        ,a.MedicalService as acup_type
        ,a.[PersonSID] as PatientSID
        ,a.ReferralStatus as OrderStatus
        ,a.ReferralSID
        ,'MILLENNIUM' as SourceSystem
        ,c.[CodeID] as ICD10Code
        ,c.[CodeDescription]
        ,c.[DiagnosisDateTime]
        ,c.[DiagnosisPriority]
        ,c.[DiagnosisDisplay] as diag_disp_all
into #mill_ref_diag
FROM [CDWWork2].[StaffMill].[Referral] as a 
    left join [CDWWork2].[StaffMill].[ReferralAction] as b
        on a.[ReferralSID] = b.[ReferralSID]
    left join cdwwork2.mill.PatientDiagnosisAll as c
        on a.OutboundEncounterSID = c.encountersid
WHERE a.CreateDateTime >= '2020-10-01' and a.ServiceTypeRequested = 'Community Care (VA)'
    and a.MedicalService='Acupuncture' and b.ReferralActionType<>'Cancel'
    and (c.SourceVocabulary in ('ICD-10-CM') or c.SourceVocabulary is Null)
order by a.ReferralSID;

/******Refine to keep only the diagnoses with the earliest dat
These seem to be the priamr ydiagnoses************************/
drop table if exists OPCCCT_CIH.dflt.MILL_comm_care_orders;

WITH ranked AS (
    SELECT pd.*,
        MIN(pd.DiagnosisDateTime) OVER (PARTITION BY pd.ReferralSID) AS earliest_dx
    FROM #mill_ref_diag AS pd)

select *
into OPCCCT_CIH.dflt.MILL_comm_care_orders
from ranked
where DiagnosisDateTime = earliest_dx;

/*summary counts*/
drop table if exists #MILL_CC_ReferralCounts
 
select DISTINCT FiscalYear, count(distinct ReferralSID) as MILL_CC_Referrals
into #MILL_CC_ReferralCounts
from OPCCCT_CIH.dflt.MILL_comm_care_orders 
group by fiscalYear;

/*********************Join the tables together***************/
/*    Note: a referral may have multiple records if there are */
/*    multiple primary diagnoses associated with the reason */
/*    for the acupuncture referral                           */
/************************************************************/
drop table if exists OPCCCT_CIH.dflt.COMBINED_acupuncture_referrals

--combined referral table
select FiscalYear,
       ConsultSID as ReferralSID,
       RequestDateTime,
       [PatientSID],
       OrderStatus,
       servicename,
       acup_type,
       provisionalDiagnosisCode as ICD10Code,
       provisionalDiagnosis as ICD10Description,
       SourceSystem
INTO OPCCCT_CIH.dflt.COMBINED_acupuncture_referrals
from OPCCCT_CIH.dflt.VISTA_comm_care_orders

UNION ALL

SELECT FiscalYear,
       ReferralSID,
       RequestDateTime,
       [PatientSID],
       OrderStatus,
       servicename,
       acup_type,
       ICD10Code,
       CodeDescription as ICD10Description,
       SourceSystem
FROM OPCCCT_CIH.dflt.MILL_comm_care_orders;

CREATE INDEX IX_acu_combined_referrals
	ON OPCCCT_CIH.dflt.COMBINED_acupuncture_referrals (PatientSID);

--counts
select a.fiscalyear, VISTA_CC_Referrals, MILL_CC_Referrals
    ,VISTA_CC_Referrals + MILL_CC_Referrals as total_ACU_CC_referrals
from #VISTA_CC_ReferralCounts a
    left join #MILL_CC_ReferralCounts b on a.FiscalYear = b.FiscalYear
order by FiscalYear;






