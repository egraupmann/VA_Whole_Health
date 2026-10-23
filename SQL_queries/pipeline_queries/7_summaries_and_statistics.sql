/**********************************************/
/* This script contains a variety of summary  */
/* queries used for the report and/or         */
/* understanding various table outputs        */
/**********************************************/

--get a count of distinct acupuncture users since FY21
declare @distinctUsers int;
set @distinctUsers = (select count(distinct patienticn)
                      FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses);
print 'Distinct Acupuncture user count since FY21 ' + cast(@distinctUsers as varchar)

--also a distinct count of current users
declare @distinctCurrentUsers int;
set @distinctCurrentUsers = (select count(distinct patienticn)
                             FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
                             where patientmostrecent_ACU_RelatedDiagnosis >='2025-09-01');
print 'Distinct current acupuncture user count ' + cast(@distinctUsers as varchar)

/**********************************************
Summarize acupuncture ICD10s
*********************************************/
drop table if exists #current_acup_icd10s;
drop table if exists #primary_codes;

select *
into #primary_codes
FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
where (EverPrimaryFlag=1 OR Condition='Chronic Neck Pain' OR condition='Other chronic musculoskelatal pain') 
        --and [group] <> 'Exclude'

SELECT
    ICD10Code,
    ICD10Description,
    [group],
    Group_A_Evidence_Certainty_Rating,
    Condition,
    sum(TimesDiagnosedTotal)          AS icd10_total,
    COUNT(DISTINCT PatientICN) AS icd10_patient_count,
    COUNT(DISTINCT PatientICN) * 1.0/@distinctUsers as per_of_acu_users_w_ICD10_as_primary_since_FY21
into #current_acup_icd10s
FROM #primary_codes
where [group] is not null and [group]<>'Exclude'
GROUP BY ICD10Code, ICD10Description, [group], Condition, Group_A_Evidence_Certainty_Rating
HAVING COUNT(DISTINCT PatientICN) >= 100  OR [group] is not null
ORDER BY icd10_total DESC;

PRINT 'Current user ICD 10 count';

select *
from #current_acup_icd10s
order by icd10_total desc;

/***********************************/

/**********************************************
Summarize acupuncture Conditions for current users
*********************************************/
PRINT 'Current user Condition counts';

SELECT
    a.[group],
    Group_A_Evidence_Certainty_Rating,
    condition,
    sum(TimesDiagnosedTotal)          AS condition_diagnosis_total,
    COUNT(DISTINCT PatientICN) AS condition_distinct_patient_count,
    COUNT(DISTINCT PatientICN) * 1.0/@distinctUsers as per_of_acu_users_w_condition_as_primary_since_FY21
FROM #primary_codes as a
GROUP BY a.[group], condition,Group_A_Evidence_Certainty_Rating
ORDER BY condition_diagnosis_total DESC;

/*****************************************************/
/* Summarize the number of patients in each tier    */
PRINT 'Current user Group/evidence counts';

with max_tier as (
    select PatientICN
           ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from #primary_codes
    group by PatientICN
),
max_evidence as (
    select PatientICN
          ,min(case when Group_A_Evidence_Certainty_Rating='High/Strong' then 1
                    when Group_A_Evidence_Certainty_Rating='Moderate' then 2
                    when Group_A_Evidence_Certainty_Rating='Low/Very Low' then 3
                    else 4 end) as highest_evidence
    from #primary_codes
    group by PatientICN
),
user_tier_counts as (
    select highest_tier, highest_evidence, count(distinct a.PatientICN) as user_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    group by highest_tier, highest_evidence
)

select case when highest_tier=1 then 'Group A'
            when highest_tier=2 then 'Group B'
            when highest_tier=3 then 'Group C'
            when highest_tier=4 then 'Group D'
            else 'No Group' end as [Group],
       case when highest_evidence=1 then 'High/Strong'
            when highest_evidence=2 then 'Moderate'
            when highest_evidence=3 then 'Low/Very Low'
            else 'N/A' end as Group_A_Evidence_Certainty_Rating
        ,user_count
        ,user_count * 1.0 /(select count(distinct patienticn)
                    from #primary_codes)
from user_tier_counts
    
order by highest_tier, highest_evidence;

/*********************************************
identify the codes in the MTIRE list that do not appear
in the met demand codes
*********************************************/
PRINT 'ICD10s in MITRE list but not used as primary codes for acupuncture encounters/referrals';

select distinct case when len(a.ICD_10_Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD_10_Code))
                     else a.ICD_10_Code end as ICD_10_Code
     , a.Code_Description as icd10_description
     , a.[Group], a.Group_A_Evidence_Certainty_Rating
     ,a.Condition
from OPCCCT_CIH.Dflt.ICD10_Tier_List as a
    left join #current_acup_icd10s as b
        on case when len(a.ICD_10_Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD_10_Code)) 
                else a.ICD_10_Code end
         = case when len(b.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from b.ICD10Code)) 
                else b.ICD10Code end
where b.icd10_patient_count is null and a.[group] <> 'Exclude' and a.ICD_10_Code is not null;

--now do at the condition level
select distinct a.condition, a.[group], a.Group_A_Evidence_Certainty_Rating
                ,b.condition as in_users
from OPCCCT_CIH.Dflt.ICD10_Tier_List as a
    left join #current_acup_icd10s as b
        ON a.condition = b.Condition
--where b.icd10_patient_count is null and a.[group] <> 'Exclude' and a.ICD_10_Code is not null;

/**********************************************
**********************************************
**********************************************
Summarize patients with ICD10 codes that are likely to benefit or use
--This includes the patients that are active acupuncture users
**********************************************
**********************************************
*********************************************/
PRINT 'Total potential demand at the ICD10 level';
declare @total_acu_events int;
set @total_acu_events = (select sum(icd10_total)
                         from #current_acup_icd10s);

drop table if exists #total_icd_counts;

with summarize as (
    select icd10_code
          ,[group]
          ,group_a_evidence_certainty_rating
          ,a.condition
          ,sum(a.current_acupuncture_user) as total_patients_w_ICD10_currently_using_acup --defined as using since 9/1/2025
          ,count(distinct b.ADRPersonICN) as total_enrolled_patients --count the population of patients as those who are enrolled in FY26
    from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
        left join (select *
                   from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                   where [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
    group by icd10_code, [group],group_a_evidence_certainty_rating, a.condition
)

select   a.icd10_code
        ,b.ICD10Description
        ,a.[group]
        ,a.group_a_evidence_certainty_rating
        ,a.condition
        ,a.total_patients_w_ICD10_currently_using_acup --defined as using since 9/1/2025
        ,a.total_patients_w_ICD10_currently_using_acup * 1.0/@distinctCurrentUsers as per_of_curr_users_w_ICD10
        ,b.icd10_total as total_icd10_count_attached_to_acup_event
        ,b.icd10_total * 1.0/@total_acu_events as per_acupuncture_events
        ,b.icd10_patient_count as total_patient_count_attached_to_acup_event
        ,b.icd10_patient_count * 1.0/@distinctUsers as per_acup_patient_users
        ,a.total_enrolled_patients --count the population of patients as those who are enrolled in FY26
from summarize as a
    left join #current_acup_icd10s as b
        on a.icd10_code = b.icd10code
        AND a.condition = b.condition
where a.[group] <>'Exclude' and a.[group] is not null
order by a.total_enrolled_patients desc, ICD10_Code;

/**********************************************
now summarize by the higher order condition
*********************************************/
drop table if exists #curr_acup_conditions;
drop table if exists [OPCCCT_CIH].[Dflt].unmet_condition_level_table;

with summarize as (
    select [group]
          ,group_a_evidence_certainty_rating
          ,a.condition
          ,count(distinct case when a.current_acupuncture_user=1 then a.PatientICN end) as total_patients_w_condition_currently_using_acup --defined as using since 9/1/2025
          ,count(distinct b.ADRPersonICN) as total_enrolled_patients --count the population of patients as those who are enrolled in FY26
    from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
        left join (select *
                   from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                   where [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
    group by [group],group_a_evidence_certainty_rating, a.condition
), acup_related_diagnoses as (
    SELECT 
        [group],
        Group_A_Evidence_Certainty_Rating,
        Condition,
        sum(TimesDiagnosedTotal)          AS condition_total,
        COUNT(DISTINCT PatientICN) AS distinct_patient_count,
        COUNT(DISTINCT PatientICN) * 1.0/@distinctUsers as per_of_acu_users_w_condition_as_primary_since_FY21
    FROM #primary_codes
    GROUP BY [group], Condition, Group_A_Evidence_Certainty_Rating
    HAVING COUNT(DISTINCT PatientICN) >= 100  OR [group] is not null
)
select  a.[group]
        ,a.group_a_evidence_certainty_rating
        ,a.condition
        ,a.total_patients_w_condition_currently_using_acup --defined as using since 9/1/2025
        ,a.total_patients_w_condition_currently_using_acup * 1.0/@distinctCurrentUsers as per_of_curr_users_w_condition
        ,b.condition_total as condition_total_count_attached_to_acup_event
        ,b.condition_total * 1.0/@total_acu_events as per_acupuncture_conditions
        ,b.distinct_patient_count as total_patient_count_attached_to_acup_event
        ,b.distinct_patient_count * 1.0/@distinctUsers as per_acup_patient_users
        ,a.total_enrolled_patients --count the population of patients as those who are enrolled in FY26
into [OPCCCT_CIH].[Dflt].unmet_condition_level_table
from summarize as a
    left join acup_related_diagnoses as b
        ON a.condition = b.condition
        AND a.[group] = b.[group]
        AND b.group_a_evidence_certainty_rating = b.group_a_evidence_certainty_rating
where a.[group] <>'Exclude'
order by a.total_enrolled_patients desc;

select *
from [OPCCCT_CIH].[Dflt].unmet_condition_level_table;

/*****************************************************************************
--identify the highest level tier condition that a patient has been diagnosed with
**************************************************************/
drop table if exists #fy26_user_groups;
drop table if exists #fy_26_users;

/***********start with current users ****************/
select *
into #fy_26_users
FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
where (EverPrimaryFlag=1 OR Condition='Chronic Neck Pain' OR condition='Other chronic musculoskelatal pain') 
        and PatientMostRecent_ACU_RelatedDiagnosis>='2025-09-01';

with max_tier as (
    select PatientICN
           ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from #fy_26_users
    group by PatientICN
),
max_evidence as (
    select PatientICN
          ,min(case when Group_A_Evidence_Certainty_Rating='High/Strong' then 1
                    when Group_A_Evidence_Certainty_Rating='Moderate' then 2
                    when Group_A_Evidence_Certainty_Rating='Low/Very Low' then 3
                    else 4 end) as highest_evidence
    from #fy_26_users
    group by PatientICN
),
user_tier_counts as (
    select highest_tier, highest_evidence, count(distinct a.PatientICN) as user_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    group by highest_tier, highest_evidence
)

select case when highest_tier=1 then 'Group A'
            when highest_tier=2 then 'Group B'
            when highest_tier=3 then 'Group C'
            when highest_tier=4 then 'Group D'
            else 'No Group' end as [Group],
       case when highest_evidence=1 then 'High/Strong'
            when highest_evidence=2 then 'Moderate'
            when highest_evidence=3 then 'Low/Very Low'
            else 'N/A' end as Group_A_Evidence_Certainty_Rating
        ,user_count as fy26_user_count
into #fy26_user_groups
from user_tier_counts
order by highest_tier, highest_evidence;

/****************************************************************************
now the enrolled population
*****************************************************************************/

with pat_group as (
    select [group]
          ,group_a_evidence_certainty_rating
          ,PatientICN
          ,current_acupuncture_user
    from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
        inner join (select *
                   from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                   where [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
),
max_tier as (
    select PatientICN,current_acupuncture_user
           ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from pat_group
    group by PatientICN,current_acupuncture_user
),
max_evidence as (
    select PatientICN
          ,min(case when Group_A_Evidence_Certainty_Rating='High/Strong' then 1
                    when Group_A_Evidence_Certainty_Rating='Moderate' then 2
                    when Group_A_Evidence_Certainty_Rating='Low/Very Low' then 3
                    else 4 end) as highest_evidence
    from pat_group
    group by PatientICN
),
user_tier_counts as (
    select highest_tier, highest_evidence, count(distinct a.PatientICN) as enrolled_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    group by highest_tier, highest_evidence
),
fy_26_enrollees as (
select case when highest_tier=1 then 'Group A'
            when highest_tier=2 then 'Group B'
            when highest_tier=3 then 'Group C'
            when highest_tier=4 then 'Group D'
            else 'No Group' end as [Group],
       case when highest_evidence=1 then 'High/Strong'
            when highest_evidence=2 then 'Moderate'
            when highest_evidence=3 then 'Low/Very Low'
            else 'N/A' end as Group_A_Evidence_Certainty_Rating
        ,enrolled_count
        ,highest_tier
        ,highest_evidence
from user_tier_counts
),
-- for fy26 users
user_tier_counts_user as (
    select highest_tier, highest_evidence, count(distinct a.PatientICN) as fy26_user_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    where current_acupuncture_user=1
    group by highest_tier, highest_evidence
),
fy_26_enrollees_user as (
select case when highest_tier=1 then 'Group A'
            when highest_tier=2 then 'Group B'
            when highest_tier=3 then 'Group C'
            when highest_tier=4 then 'Group D'
            else 'No Group' end as [Group],
       case when highest_evidence=1 then 'High/Strong'
            when highest_evidence=2 then 'Moderate'
            when highest_evidence=3 then 'Low/Very Low'
            else 'N/A' end as Group_A_Evidence_Certainty_Rating
        ,fy26_user_count
        ,highest_tier
        ,highest_evidence
from user_tier_counts_user
)

select a.[group]
      ,a.Group_A_Evidence_Certainty_Rating
      ,b.fy26_user_count
      ,b.fy26_user_count * 1.0/(select sum(fy26_user_count)
                                from user_tier_counts_user
                                ) as per_fy26_users
      ,a.enrolled_count as fy_26_enrollee_count
      ,a.enrolled_count * 1.0/(select count(distinct ADRPersonICN)
                                from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                                where [EnrolledFY26]=1) as per_fy26_enrollees
from fy_26_enrollees as a
    left join fy_26_enrollees_user as b
        ON a.[group] = b.[group]
        AND a.Group_A_Evidence_Certainty_Rating = b.Group_A_Evidence_Certainty_Rating
where a.[group] <> 'No Group' and a.[group] <> 'Exclude'
order by a.highest_tier, a.highest_evidence;

select count(distinct ADRPersonICN)
from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
where [EnrolledFY26]=1

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
drop table if exists #patient_demos;

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
          ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from [OPCCCT_CIH].[Dflt].All_tiered_diagnoses
    group by patienticn, ever_used_acupuncture, current_acupuncture_user
),
max_evidence as (
    select PatientICN, ever_used_acupuncture, current_acupuncture_user
          ,min(case when Group_A_Evidence_Certainty_Rating='High/Strong' then 1
                    when Group_A_Evidence_Certainty_Rating='Moderate' then 2
                    when Group_A_Evidence_Certainty_Rating='Low/Very Low' then 3
                    else 4 end) as highest_evidence
    from [OPCCCT_CIH].[Dflt].All_tiered_diagnoses
    group by patienticn, ever_used_acupuncture, current_acupuncture_user
)

select distinct a.patienticn
       ,case when highest_tier=1 then 'Group A'
            when highest_tier=2 then 'Group B'
            when highest_tier=3 then 'Group C'
            when highest_tier=4 then 'Group D'
            else 'No Group' end as [Group]
       ,case when highest_evidence=1 then 'High/Strong'
            when highest_evidence=2 then 'Moderate'
            when highest_evidence=3 then 'Low/Very Low'
            else 'N/A' end as Group_A_Evidence_Certainty_Rating
       ,a.ever_used_acupuncture
       ,a.current_acupuncture_user
      ,case when b.BirthDateTime is null then f.BirthDateTime else b.BirthDateTime end as BirthDate
      ,case when b.gender is null then f.sex else b.gender end as gender
      ,case when d.race_mod is null then f.race else d.race_mod end as race
      ,case when c.ethnicity is null then f.ethnicGroup else c.ethnicity end as ethnicity
into #patient_demos
From max_tier as a
    inner join max_evidence as g
        on a.PatientICN = g.PatientICN
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

/**********************************************************************
Make the likely to benefit demographic table
******************************************************************/

drop table if exists opccct_cih.dflt.ALL_Tiered_Patient_Demographics;

with ages AS (
    SELECT distinct patienticn,
           DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01')
           - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01'), CAST(birthdate AS DATE)) > '2026-10-01'
                  THEN 1 ELSE 0 END AS age
    FROM #patient_demos
) 

select DISTINCT 
       a.PatientICN
      ,[group]
      ,Group_A_Evidence_Certainty_Rating
      ,ever_used_acupuncture
      ,current_acupuncture_user
      ,case when a.gender='F' then 'Female'
            when a.gender='M' then 'Male'
            else a.gender end as gender
      --,a.ethnicity
      --,a.race
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
    ,EnrolledFY26
into opccct_cih.dflt.ALL_Tiered_Patient_Demographics
from #patient_demos as a
    left join ages as b on a.patienticn = b.patienticn
    inner join vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets as c
        on a.PatientICN = c.adrpersonicn
where [group] not in ('No Group','Exclude');

select age_bin, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
where EnrolledFY26=1
group by age_bin
order by age_bin

select race_mod, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
where EnrolledFY26=1
group by race_mod
order by count(distinct patienticn) desc

select gender, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
where EnrolledFY26=1
group by gender
order by gender

select [group], Group_A_Evidence_Certainty_Rating, count(distinct patienticn) as n
from opccct_cih.dflt.ALL_Tiered_Patient_Demographics
where EnrolledFY26=1
group by [group], Group_A_Evidence_Certainty_Rating
order by [group], Group_A_Evidence_Certainty_Rating


/***************************************************/
/* now get the same stats for the acupuncture users only */
/***************************************************/
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
drop table if exists #all_VA_enrollees;

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
into #all_VA_enrollees
From opccct_cih.dflt.ALL_Enrolled_Vets as a
    left join cdwwork.spatient.spatient as b
        on cast(a.adrpersonICN as varchar(50)) = b.patienticn
    left join cdwwork.patsub.patientethnicity as c
        on b.patientsid = c.patientsid
    left join vista_race as d
        on b.patientsid = d.patientsid
    left join cdwwork2.sveteranmill.sperson as f
        on b.patientsid = f.PersonSID
where a.[EnrolledFY26]=1;

/***************************************************/
/*make a currently enrolled VA (user and non-user) dmeographics table*/
drop table if exists ALL_Enrolled_Vet_Demographics_temp;

with ages AS (
    SELECT distinct patienticn,
           DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01')
           - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01'), CAST(birthdate AS DATE)) > '2026-10-01'
                  THEN 1 ELSE 0 END AS age
    FROM #all_VA_enrollees
) 
select DISTINCT a.PatientICN
      ,case when a.gender='F' then 'Female'
            when a.gender='M' then 'Male'
            else a.gender end as gender
      --,a.ethnicity
      --,a.race
    ,case when race in ('*Implied NULL*','Prefer Not To Answer','UNKNOWN') and ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when race='WHITE NOT OF HISP ORIG' then 'WHITE'
          when race='zzOther Race' then 'UNKNOWN'
          when race='NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' then 'Native Hawaiian or Pacific Islander'
          when race in ('*Implied NULL*','Prefer Not To Answer','Unknown') or race is null then 'UNKNOWN'
          else race end as race_mod
    ,b.age
    ,CASE WHEN b.age < 35 THEN '<35'
           WHEN b.age BETWEEN 35 AND 44 THEN '35-44'
           WHEN b.age BETWEEN 45 AND 54 THEN '45-54'
           WHEN b.age BETWEEN 55 AND 64 THEN '55-64'
           WHEN b.age BETWEEN 65 AND 74 THEN '65-74'
           WHEN b.age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
    ,[group] as highest_acupuncture_evidence_group
    ,Group_A_Evidence_Certainty_Rating
    ,ever_used_acupuncture
    ,current_acupuncture_user
    ,EnrolledFY26
into ALL_Enrolled_Vet_Demographics_temp
from #all_VA_enrollees as a
    left join ages as b on a.patienticn = b.patienticn
    left join opccct_cih.dflt.ALL_Tiered_Patient_Demographics as c
        on a.PatientICN = c.PatientICN;

/********************************************************
all enrolled patients locations
*******************************************************/
drop table if exists opccct_cih.dflt.all_enrolled_vet_demographics;

with get_zips as (
    select DISTINCT
           a.PatientICN
          ,a.gender
          ,a.race_mod
          ,a.age
          ,a.age_bin
          ,b.Zip
          ,b.FIPSCode
    from ALL_Enrolled_Vet_Demographics_temp  as a
        left join [CDWWork].[SPatient].[SPatientGISAddress] as b
            on cast(a.PatientICN as varchar(10)) = cast(b.PatientICN as varchar(10))
    where a.PatientICN is not null
),
counts as (
    select patienticn
          ,count(patienticn) as pat_count
          ,sum(case when FIPSCODe is null then 1 else 0 end) as null_fips_count
          ,sum(case when Zip is null then 1 else 0 end) as null_zip_count
          ,sum(case when race_mod='UNKNOWN' then 1 else 0 end) as unknown_race
          ,sum(case when race_mod<>'UNKNOWN' then 1 else 0 end) as not_unknown_race
    from get_zips
    group by PatientICN
),
remove_records as (
    select a.*
            ,b.pat_count
            ,b.null_fips_count
            ,b.null_zip_count
            ,b.unknown_race
            ,not_unknown_race
            ,case when pat_count>1 then 
                case when null_fips_count>0 and FIPSCode is null then 1
                     when null_zip_count>0 and zip is null then 1
                     when unknown_race>0 and race_mod='UNKNOWN' and not_unknown_race>0 then 1 
                     else 0 end
                else 0 end as remove_record
    from get_zips  as a
        inner join counts as b
            on a.patienticn = b.patienticn
),
new_dupe_count as (
    select patienticn
          ,count(patienticn) as pat_count_update
    from remove_records
    where remove_record = 0
    group by PatientICN
), remaining_dupes as (
    select a.*
          , b.pat_count_update
    from remove_records as a
        inner join new_dupe_count as b        
            on a.patienticn = b.patienticn
    where remove_record=0
), ranked_rows as (
    select *,
        ROW_NUMBER() over (partition by patientICN order by age desc) as rn
    from remaining_dupes
), final as (
    select *
    from ranked_rows
    where rn=1 
)
select a.*, b.Zip, b.FIPSCode
into opccct_cih.dflt.all_enrolled_vet_demographics
from ALL_Enrolled_Vet_Demographics_temp  as a
    left join final as b
        on a.PatientICN = b.PatientICN;





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


/***************************************************
This is the intial, simple, attempt to give a more 
realistic attempt at getting a possible upper threshold
of the people that may use acupuncture if outreach 
were perfect and everyone with high likely to use
conditions were to actually use. This could use 
tons of refinements but is a starting point
***************************************************/
drop table if exists #likely_to_use;

with top_conditions as (
    select a.*, c.per_acup_patient_users
        from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
            inner join (select *
                       from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                       where [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
            inner join vhacdwa01.[OPCCCT_CIH].[Dflt].unmet_condition_level_table as c
                ON a.Condition = c.condition
                AND a.[group] = c.[group]
                AND a.Group_A_Evidence_Certainty_Rating = c.Group_A_Evidence_Certainty_Rating
        where a.[group] <>'Exclude'
),
pat_top_condition as (
    select patientICN
           ,max(per_acup_patient_users) as max_user_condition
    from top_conditions
    group by PatientICN
)
select distinct
    a.PatientICN
    ,a.Condition
    ,b.max_user_condition
into #likely_to_use
from top_conditions as a
    inner join pat_top_condition as b
        ON a.PatientICN = b.PatientICN
where a.per_acup_patient_users = b.max_user_condition ;

declare @likely_to_use int;
set @likely_to_use = (select sum(max_user_condition)
                      FROM #likely_to_use);
print 'Distinct Acupuncture user count since FY21 ' + cast(@likely_to_use as varchar)

select a.condition
      ,b.[Group]
      ,b.Group_A_Evidence_Certainty_Rating
      ,sum(max_user_condition) as number_of_possible_users
from #likely_to_use as a
    inner join (select distinct 
                    condition
                    ,[group]
                    ,Group_A_Evidence_Certainty_Rating
                from OPCCCT_CIH.Dflt.ICD10_Tier_List 
               ) as b
        on a.Condition = b.Condition
group by a.condition,b.[Group]
      ,b.Group_A_Evidence_Certainty_Rating
order by sum(max_user_condition) desc;

select top 1000 *
from #likely_to_use