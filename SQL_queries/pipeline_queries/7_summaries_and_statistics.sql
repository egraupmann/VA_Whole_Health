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
    where EverPrimaryFlag=1 and PatientMostRecent_ACU_RelatedDiagnosis >= '2025-08-01'
)

SELECT
    ICD10Code,
    ICD10Description,
    c.[Group] as tier,
    c.Condition,
    sum(TimesDiagnosedTotal)          AS icd10_total,
    COUNT(DISTINCT PatientICN) AS icd10_patient_count
FROM primary_codes
    left join OPCCCT_CIH.dflt.ICD10_Tier_List as c on primary_codes.ICD10Code = c.Code
GROUP BY ICD10Code, ICD10Description, c.[Group], c.Condition
HAVING COUNT(DISTINCT PatientICN) > 100 
ORDER BY icd10_total DESC;

/***********************************/

/**********************************************
Summarize acupuncture Conditions for current users
*********************************************/
with primary_codes as (
    select *
    FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
    where EverPrimaryFlag=1 and PatientMostRecent_ACU_RelatedDiagnosis >= '2025-08-01'
)

SELECT
    a.tier,
    condition,
    sum(TimesDiagnosedTotal)          AS condition_diagnosis_total,
    COUNT(DISTINCT PatientICN) AS condition_distinct_patient_count
FROM primary_codes as a
GROUP BY a.tier, condition
HAVING COUNT(DISTINCT PatientICN) > 100 
ORDER BY condition_diagnosis_total DESC;

select count(distinct PatientICN)
from OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
where EverPrimaryFlag=1 and PatientMostRecent_ACU_RelatedDiagnosis >= '2025-08-01';

/*****************************************************/
/* Summarize the number of patients in each tier    */
with primary_codes as (
    select *
    FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
    where EverPrimaryFlag=1 and PatientMostRecent_ACU_RelatedDiagnosis >= '2025-08-01'
),
max_tier as (
    select PatientICN
           ,min(case when tier='Group A' then 1
                 else case when tier='Group B' then 2
                 else case when tier='Group C' then 3 
                 else 4 end end end) as highest_tier
    from primary_codes
    group by PatientICN
),
user_tier_counts as (
    select highest_tier, count(distinct PatientICN) as user_count
    from max_tier
    group by highest_tier
)

select case when highest_tier=1 then 'Group A'
            else case when highest_tier=2 then 'Group B'
            else case when highest_tier=3 then 'Group C'
            else 'No Tier' end end end as tier
        ,user_count
from user_tier_counts


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
from [OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
    left join (select *
               from opccct_cih.dflt.ALL_Enrolled_Vets 
               where [EnrolledFY25]=1 or [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
group by icd10code, tier;

/**********************************************
now summarize by the higher order condition
*********************************************/
select tier 
      ,a.[Condition] 
      ,count(distinct a.patientICN) as total_patients_w_Condition
      ,sum(a.ever_used_acupuncture) as total_patients_w_Condition_ever_used_acup
      ,sum(a.current_acupuncture_user) as total_patients_w_Condition_currently_using_acup --defined as using since 8/1/2025
from [OPCCCT_CIH].[Dflt].[ALL_tiered_Diagnoses] as a
    inner join [OPCCCT_CIH].[Dflt].icd10_tier_list as c on a.icd10code = c.code
group by a.[Condition], tier
order by total_patients_w_Condition desc;

--identify the highest level tier condition that a patient has been diagnosed with
with highet_patient_tier as 
        (select patientICN 
          ,ever_used_acupuncture
          ,current_acupuncture_user
          ,min(case when tier='Group A' then 1
                   else case when tier='Group B' then 2
                   else case when tier='Group C' then 3 end end end) as tier_rank

        from [OPCCCT_CIH].[Dflt].[ALL_tiered_Diagnoses] as a
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


/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/**************************************************************************************************************/
/* Get some current demographics. This logic is for the entire likely to benefit population, tiers 1 to 3
for those who are users and those who aren't*/
drop table if exists #test;

WITH mill_ICN AS (
    SELECT PersonSID
          ,CASE WHEN AliasName LIKE '%zz%' THEN NULL
                ELSE LEFT(CAST(AliasName AS varchar(50)), 10) END AS PatientICN
    FROM [CDWWork2].[VeteranMill].[PersonAlias]
    WHERE AliasPool = 'ICN'
),

vista_race as (
    select distinct a.patientsid
          ,case when a.race_count>1 THEN 'MULTI-RACIAL' else a.race end as race_mod
    from (
            select b.patientsid, b.race, c.race_count
            from cdwwork.patsub.patientrace as b
                inner join (select patientsid, count(distinct race) as race_count
                            from cdwwork.patsub.patientrace
                            where race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
                            group by patientsid) as c on b.patientsid = c.patientsid
            where b.race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
        ) as a
),
max_tier as (
    select patienticn, ever_used_acupuncture, current_acupuncture_user
          ,min(case when tier='Group A' then 1
                   else case when tier='Group B' then 2
                   else case when tier='Group C' then 3 end end end) as likely_to_benefit_tier
    from [OPCCCT_CIH].[Dflt].All_tiered_diagnoses
    group by patienticn, ever_used_acupuncture, current_acupuncture_user
)

select distinct a.patienticn
       ,a.likely_to_benefit_tier
       ,a.ever_used_acupuncture
       ,a.current_acupuncture_user
      ,case when b.BirthDateTime is null then f.BirthDateTime else b.BirthDateTime end as BirthDate
      ,case when b.gender is null then f.sex else b.gender end as gender
      ,case when d.race_mod is null then f.race else d.race_mod end as race
      ,case when c.ethnicity is null then f.ethnicGroup else c.ethnicity end as ethnicity
into #test
From max_tier as a
    left join cdwwork.spatient.spatient as b
        on a.patienticn = b.patienticn
    left join cdwwork.patsub.patientethnicity as c
        on b.patientsid = c.patientsid
    left join vista_race as d
        on b.patientsid = d.patientsid
    left JOIN mill_ICN AS e
        ON a.patientICN = e.PatientICN
    left join cdwwork2.sveteranmill.sperson as f
        on e.personSID = f.PersonSID;

drop table if exists opccct_cih.dflt.ALL_Tiered_Patient_Demographics;

with ages AS (
    SELECT distinct patienticn,
           DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01')
           - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01'), CAST(birthdate AS DATE)) > '2026-10-01'
                  THEN 1 ELSE 0 END AS age
    FROM #test
) 

select a.PatientICN
      ,case when a.gender='F' then 'Female'
            when a.gender='M' then 'Male'
            else a.gender end as gender
      ,a.ethnicity
      ,a.race
    ,case when race in ('*Implied NULL*','Prefer Not To Answer','UNKNOWN') and ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when race='WHITE NOT OF HISP ORIG' then 'WHITE'
          when race='zzOther Race' then 'UNKNOWN'
          when race='NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' then 'Native Hawaiian or Pacific Islander'
          when race in ('*Implied NULL*','Prefer Not To Answer','Unknown') or race is null then 'UNKNOWN'
          else race end as race_mod
    ,age
    ,CASE WHEN age < 35 THEN '<35'
           WHEN age BETWEEN 35 AND 44 THEN '35-44'
           WHEN age BETWEEN 45 AND 54 THEN '45-54'
           WHEN age BETWEEN 55 AND 64 THEN '55-64'
           WHEN age BETWEEN 65 AND 74 THEN '65-74'
           WHEN age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
into opccct_cih.dflt.ALL_Tiered_Patient_Demographics
from #test as a
    left join ages as b on a.patienticn = b.patienticn;

select age_bin, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
group by age_bin
order by age_bin

select race_mod, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
group by race_mod
order by count(distinct patienticn) desc

select gender, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
group by gender
order by gender

/***************************************************/
/* now get the same stats for the current users only */
/***************************************************/
drop table if exists #acup_users;

with vista_race as (
    select distinct a.patientsid
          ,case when a.race_count>1 THEN 'MULTI-RACIAL' else a.race end as race_mod
    from (
            select b.patientsid, b.race, c.race_count
            from cdwwork.patsub.patientrace as b
                inner join (select patientsid , count(distinct race) as race_count
                            from cdwwork.patsub.patientrace
                            where race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
                            group by patientsid) as c on try_cast(b.patientsid as bigint) = try_cast(c.patientsid as bigint) 
            where b.race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
           
        ) as a
)

select distinct a.patienticn
      ,case when b.BirthDateTime is null then f.BirthDateTime else b.BirthDateTime end as BirthDate
      ,case when b.gender is null then f.sex else b.gender end as gender
      ,case when d.race_mod is null then f.race else d.race_mod end as race
      ,case when c.ethnicity is null then f.ethnicGroup else c.ethnicity end as ethnicity
into #acup_users
From opccct_cih.dflt.ALL_ACUP_Referrals_and_Encounters as a
    left join cdwwork.spatient.spatient as b
        on cast(a.patienticn as varchar(50)) = b.patienticn
    left join cdwwork.patsub.patientethnicity as c
        on b.patientsid = c.patientsid
    left join vista_race as d
        on b.patientsid = d.patientsid
    left join cdwwork2.sveteranmill.sperson as f
        on a.patientsid = f.PersonSID
where eventDate >= '2025-08-01';

/***************************************************/
/*make a current user dmeographics table*/
drop table if exists opccct_cih.dflt.ALL_ACUP_User_Demographics;

with ages AS (
    SELECT distinct patienticn,
           DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01')
           - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01'), CAST(birthdate AS DATE)) > '2026-10-01'
                  THEN 1 ELSE 0 END AS age
    FROM #acup_users
) 
select a.PatientICN
      ,case when a.gender='F' then 'Female'
            when a.gender='M' then 'Male'
            else a.gender end as gender
      ,a.ethnicity
      ,a.race
    ,case when race in ('*Implied NULL*','Prefer Not To Answer','UNKNOWN') and ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when race='WHITE NOT OF HISP ORIG' then 'WHITE'
          when race='zzOther Race' then 'UNKNOWN'
          when race='NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' then 'Native Hawaiian or Pacific Islander'
          when race in ('*Implied NULL*','Prefer Not To Answer','Unknown') or race is null then 'UNKNOWN'
          else race end as race_mod
    ,age
    ,CASE WHEN age < 35 THEN '<35'
           WHEN age BETWEEN 35 AND 44 THEN '35-44'
           WHEN age BETWEEN 45 AND 54 THEN '45-54'
           WHEN age BETWEEN 55 AND 64 THEN '55-64'
           WHEN age BETWEEN 65 AND 74 THEN '65-74'
           WHEN age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
into opccct_cih.dflt.ALL_ACUP_User_Demographics
from #acup_users as a
    left join ages as b on a.patienticn = b.patienticn;

select age_bin, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_ACUP_User_Demographics
group by age_bin
order by age_bin

select race_mod, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_ACUP_User_Demographics
group by race_mod
order by count(distinct patienticn) desc

select gender, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_ACUP_User_Demographics
group by gender
order by gender

/***************************************************/
/* and finally, for all enrolled Vets */
/***************************************************/
drop table if exists #acup_users;

with vista_race as (
    select distinct a.patientsid
          ,case when a.race_count>1 THEN 'MULTI-RACIAL' else a.race end as race_mod
    from (
            select b.patientsid, b.race, c.race_count
            from cdwwork.patsub.patientrace as b
                inner join (select patientsid , count(distinct race) as race_count
                            from cdwwork.patsub.patientrace
                            where race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
                            group by patientsid) as c on try_cast(b.patientsid as bigint) = try_cast(c.patientsid as bigint) 
            where b.race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
           
        ) as a
)


select distinct a.adrpersonICN as PatientICN
      ,case when b.BirthDateTime is null then f.BirthDateTime else b.BirthDateTime end as BirthDate
      ,case when b.gender is null then f.sex else b.gender end as gender
      ,case when d.race_mod is null then f.race else d.race_mod end as race
      ,case when c.ethnicity is null then f.ethnicGroup else c.ethnicity end as ethnicity
into #acup_users
From opccct_cih.dflt.ALL_Enrolled_Vets as a
    left join cdwwork.spatient.spatient as b
        on cast(a.adrpersonICN as varchar(50)) = b.patienticn
    left join cdwwork.patsub.patientethnicity as c
        on b.patientsid = c.patientsid
    left join vista_race as d
        on b.patientsid = d.patientsid
    left join cdwwork2.sveteranmill.sperson as f
        on b.patientsid = f.PersonSID
where a.[EnrolledFY25]=1 or a.[EnrolledFY26]=1;

/***************************************************/
/*make a current user dmeographics table*/
drop table if exists opccct_cih.dflt.ALL_Enrolled_Vet_Demographics;

with ages AS (
    SELECT distinct patienticn,
           DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01')
           - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01'), CAST(birthdate AS DATE)) > '2026-10-01'
                  THEN 1 ELSE 0 END AS age
    FROM #acup_users
) 
select a.PatientICN
      ,case when a.gender='F' then 'Female'
            when a.gender='M' then 'Male'
            else a.gender end as gender
      ,a.ethnicity
      ,a.race
    ,case when race in ('*Implied NULL*','Prefer Not To Answer','UNKNOWN') and ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when race='WHITE NOT OF HISP ORIG' then 'WHITE'
          when race='zzOther Race' then 'UNKNOWN'
          when race='NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' then 'Native Hawaiian or Pacific Islander'
          when race in ('*Implied NULL*','Prefer Not To Answer','Unknown') or race is null then 'UNKNOWN'
          else race end as race_mod
    ,age
    ,CASE WHEN age < 35 THEN '<35'
           WHEN age BETWEEN 35 AND 44 THEN '35-44'
           WHEN age BETWEEN 45 AND 54 THEN '45-54'
           WHEN age BETWEEN 55 AND 64 THEN '55-64'
           WHEN age BETWEEN 65 AND 74 THEN '65-74'
           WHEN age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
into opccct_cih.dflt.ALL_Enrolled_Vet_Demographics
from #acup_users as a
    left join ages as b on a.patienticn = b.patienticn;

select age_bin, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Enrolled_Vet_Demographics
group by age_bin
order by age_bin

select race_mod, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Enrolled_Vet_Demographics
group by race_mod
order by count(distinct patienticn) desc

select gender, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Enrolled_Vet_Demographics
group by gender
order by gender

