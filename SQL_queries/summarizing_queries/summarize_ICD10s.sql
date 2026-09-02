/**********************************************/
/* This script contains a variety of summary  */
/* queries used for the report and/or         */
/* understanding various table outputs        */
/**********************************************/

/**********************************************
Summarize acupuncture ICD10s
*********************************************/
with primary_codes as (
    select *
    FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
    where EverPrimaryFlag=1
)

SELECT
    ICD10Code,
    ICD10Description,
    sum(TimesDiagnosedTotal)          AS icd10_total,
    COUNT(DISTINCT PatientICN) AS icd10_patient_count
FROM primary_codes
GROUP BY ICD10Code, ICD10Description
HAVING COUNT(DISTINCT PatientICN) > 100 
ORDER BY icd10_total DESC;

/***********************************/

/**********************************************
Summarize acupuncture Conditions for current users
*********************************************/
with primary_codes as (
    select *
    FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
    where EverPrimaryFlag=1
)

SELECT
    tier,
    condition,
    sum(TimesDiagnosedTotal)          AS condition_diagnosis_total,
    COUNT(DISTINCT PatientICN) AS condition_distinct_patient_count
FROM primary_codes
GROUP BY tier, condition
HAVING COUNT(DISTINCT PatientICN) > 100 
ORDER BY condition_diagnosis_total DESC;

select count(distinct PatientICN)
from OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses;

/**********************************************
Summarize patients with ICD10 codes that are likely to benefit
--This includes the patients that are active acupuncture users
*********************************************/
select tier 
      ,icd10code 
      ,count(distinct a.patientICN) as total_patients_w_ICD10
      ,sum(a.ever_used_acupuncture) as total_patients_w_ICD10_ever_used_acup
      ,sum(a.current_acupuncture_user) as total_patients_w_ICD10_currently_using_acup --defined as using since 8/1/2025
      ,count(distinct b.ADRPersonICN) as total_enrolled_patients
from [OPCCCT_CIH].[Dflt].[ALL_Tier1_Diagnoses] as a
    left join (select *
               from opccct_cih.dflt.ALL_Enrolled_Vets 
               where [EnrolledFY25]=1 or [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
group by icd10code, tier;

/**********************************************
now summarize by the higher order condition
*********************************************/
select tier 
      ,[Condition] 
      ,count(distinct a.patientICN) as total_patients_w_Condition
      ,sum(a.ever_used_acupuncture) as total_patients_w_Condition_ever_used_acup
      ,sum(a.current_acupuncture_user) as total_patients_w_Condition_currently_using_acup --defined as using since 8/1/2025
from [OPCCCT_CIH].[Dflt].[ALL_Tier1_Diagnoses] as a
    inner join [OPCCCT_CIH].[Dflt].icd10_tier_list as c on a.icd10code = c.code
group by [Condition], tier;

--identify the highest level tier condition that a patient has been diagnosed with
with highet_patient_tier as 
        (select patientICN 
          ,ever_used_acupuncture
          ,current_acupuncture_user
          ,min(case when tier='Group A' then 1
                   else case when tier='Group B' then 2
                   else case when tier='Group C' then 3 end end end) as tier_rank

        from [OPCCCT_CIH].[Dflt].[ALL_Tier1_Diagnoses] as a
            inner join [OPCCCT_CIH].[Dflt].icd10_tier_list as c on a.icd10code = c.code
        group by patientICN, current_acupuncture_user, ever_used_acupuncture)

select tier_rank
      ,count(distinct patientICN) as total_patients
      ,sum(ever_used_acupuncture) as total_patients_ever_used_acup
      ,sum(current_acupuncture_user) as total_patients_currently_using_acup --defined as using since 8/1/2025
from highet_patient_tier
group by tier_rank;

/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/* count and slice up current user numbers */
/**********************************************/
/* Summarize total 'current users' by year    */
/**********************************************/
select 
    FiscalYear
    ,count(distinct patientICN) as unique_user_count
    ,count(distinct (case when eventType='Encounter' then PatientICN end)) as unique_VA_user_count
    ,count(distinct (case when eventType='Referral' then PatientICN end)) as unique_CC_user_count
    ,count(distinct (case when eventType='Encounter' and SrcSystem='VISTA'
        then PatientICN end)) as unique_VA_VISTA_user_count
    ,count(distinct (case when eventType='Encounter' and SrcSystem='CERNER'
        then PatientICN end)) as unique_VA_MILL_user_count
    ,count(distinct (case when eventType='Referral' and SrcSystem='VISTA'
        then PatientICN end)) as unique_CC_VISTA_user_count
    ,count(distinct (case when eventType='Referral' and SrcSystem='MILLENNIUM'
        then PatientICN end)) as unique_CC_MILL_user_count
From [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters]
group by FiscalYear
order by FiscalYear

/**********************************************/
/*  Track how long each current user patient has been using*/
/**********************************************/
drop table if exists #track_users_by_year;

select PatientICN
      ,case when sum(case when FiscalYear=2021 then 1 else 0 end)>0 then 1 else 0 end as FY21_user
      ,case when sum(case when FiscalYear=2022 then 1 else 0 end)>0 then 1 else 0 end as FY22_user
      ,case when sum(case when FiscalYear=2023 then 1 else 0 end)>0 then 1 else 0 end as FY23_user
      ,case when sum(case when FiscalYear=2024 then 1 else 0 end)>0 then 1 else 0 end as FY24_user
      ,case when sum(case when FiscalYear=2025 then 1 else 0 end)>0 then 1 else 0 end as FY25_user
      ,case when sum(case when FiscalYear=2026 then 1 else 0 end)>0 then 1 else 0 end as FY26_user
into #track_users_by_year
From [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters]
group by PatientICN;

/*identify new users*/
drop table if exists #new_users;

select PatientICN
      ,case when FY22_user=1 and FY21_user=0 
                then 1 else 0 end as new_user_in_FY22
      ,case when FY23_user=1 and FY21_user+FY22_user=0 
                then 1 else 0 end as new_user_in_FY23
      ,case when FY24_user=1 and FY21_user+FY22_user+FY23_user=0 
                then 1 else 0 end as new_user_in_FY24
      ,case when FY25_user=1 and FY21_user+FY22_user+FY23_user+FY24_user=0 
                then 1 else 0 end as new_user_in_FY25
      ,case when FY26_user=1 and FY21_user+FY22_user+FY23_user+FY24_user+FY25_user=0 
                then 1 else 0 end as new_user_in_FY26

      ,case when FY25_user=1 and FY24_user=1 and FY23_user=1
                then 1 else 0 end as FY25_user_using_since_at_least_FY23
      ,case when FY26_user=1 and FY25_user=1 and FY24_user=1
                then 1 else 0 end as FY26_user_using_since_at_least_FY24
into #new_users
from #track_users_by_year;

/*sum new users at the FY level*/
select sum(new_user_in_FY22) as FY22_new_users
      ,sum(new_user_in_FY23) as FY23_new_users
      ,sum(new_user_in_FY24) as FY24_new_users
      ,sum(new_user_in_FY25) as FY25_new_users
      ,sum(new_user_in_FY26) as FY26_new_users

      ,sum(FY25_user_using_since_at_least_FY23) as FY25_user_using_since_at_least_FY23
      ,sum(FY26_user_using_since_at_least_FY24) as FY26_user_using_since_at_least_FY24
from #new_users;



/*QA below*/
select a.*
      ,b.*
      ,case when b.patientICN is not null then 1 else 0 end as enrolled
from [OPCCCT_CIH].[Dflt].[ALL_Tier1_Diagnoses] as a
    left join  opccct_cih.dflt.ALL_Enrolled_Vets as b on a.patienticn = b.ADRPersonICN
where icd10code = 'M25.519';

SELECT TOP (1000) [PatientICN]
      ,[ICD10Code]
      ,[ICD10Description]
      ,[most_recent_diagnosis_date]
      ,[tier]
      ,[VISN]
      ,[most_recent_acup_usage]
      ,[ever_used_acupuncture]
      ,[current_acupuncture_user]
  FROM [OPCCCT_CIH].[Dflt].[ALL_Tier1_Diagnoses]
  order by patientICN

  select *
  from cdwwork.patient.patient
  where patienticn = '1043542914'

  select *
  from cdwwork.patient.enrollment
  where patientsid in ('1602350845','1604022250','806686406','1603554800')

  select *
  from opccct_cih.dflt.ALL_Enrolled_Vets 
  where patienticn = '1043542914'
