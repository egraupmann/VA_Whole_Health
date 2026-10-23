/**************************************************************
Get the number of patients with multiple conditions/co-morbidities
1) count patients w/ multiple group A conditions diagnosed in last year
2) A Strong and Moderate also seems good
3) Any A through C
*************************************************************/
drop table if exists #patients_w_multiple_conditions;

with group_a_high_med_evid as (
	select patientICN
		  ,count(distinct Condition) as group_A_high_med_evidence
	from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses]
	where [group] = 'Group A' AND Group_A_Evidence_Certainty_Rating in ('High/Strong','Moderate')
	group by patientICN
), 
group_a as (
	select patientICN
		  ,count(distinct Condition) as group_A
	from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses]
	where [group] = 'Group A'
	group by patientICN
), 
group_a_to_c as (
	select patientICN
		  ,count(distinct Condition) as group_A_to_C
	from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses]
	where [group] in ('Group A','Group B','Group C')
	group by patientICN
),
group_a_high_med_evid_users as (
	select patientICN
		  ,count(distinct Condition) as group_A_high_med_evidence_acup_users
	from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses]
	where [group] = 'Group A' AND Group_A_Evidence_Certainty_Rating in ('High/Strong','Moderate')
		AND current_acupuncture_user=1
	group by patientICN
), 
group_a_users as (
	select patientICN
		  ,count(distinct Condition) as group_A_acup_users
	from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses]
	where [group] = 'Group A' AND current_acupuncture_user=1
	group by patientICN
), 
group_a_to_c_users as (
	select patientICN
		  ,count(distinct Condition) as group_A_to_c_acup_users
	from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses]
	where [group] in ('Group A','Group B','Group C')
		AND current_acupuncture_user=1
	group by patientICN
)
select distinct a.PatientICN
	  ,b.group_A_high_med_evidence
	  ,c.group_A
	  ,d.group_A_to_C
	  ,e.group_A_high_med_evidence_acup_users
	  ,f.group_A_acup_users
	  ,g.group_A_to_c_acup_users
into #patients_w_multiple_conditions
from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
	left join group_a_high_med_evid as b
		on a.PatientICN = b.PatientICN
	left join group_a as c
		on a.PatientICN = c.PatientICN
	left join group_a_to_c as d
		on a.PatientICN = d.PatientICN
	left join group_a_high_med_evid_users as e
		on a.PatientICN = e.PatientICN
	left join group_a_users as f
		on a.PatientICN = f.PatientICN
	left join group_a_to_c_users as g
		on a.PatientICN = g.PatientICN
	inner join (select *
                from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                where [EnrolledFY26]=1) as h on a.patienticn = h.ADRPersonICN;
/**************************************************************************
summarize by the categories
****************************************************************************/
select distinct
	   'Group A High/Med' as Group_Lvl 
	  ,sum(case when group_A_high_med_evidence > 0 then 1 else 0 end) as comorbidity_1
	  ,sum(case when group_A_high_med_evidence > 1 then 1 else 0 end) as comorbidity_2
	  ,sum(case when group_A_high_med_evidence > 2 then 1 else 0 end) as comorbidity_3
	  ,sum(case when group_A_high_med_evidence > 3 then 1 else 0 end) as comorbidity_4
	  ,sum(case when group_A_high_med_evidence > 4 then 1 else 0 end) as comorbidity_5

	  ,sum(case when group_A_high_med_evidence_acup_users > 0 then 1 else 0 end) as comorbidity_1_acup_user
	  ,sum(case when group_A_high_med_evidence_acup_users > 1 then 1 else 0 end) as comorbidity_2_acup_user
	  ,sum(case when group_A_high_med_evidence_acup_users > 2 then 1 else 0 end) as comorbidity_3_acup_user
	  ,sum(case when group_A_high_med_evidence_acup_users > 3 then 1 else 0 end) as comorbidity_4_acup_user
	  ,sum(case when group_A_high_med_evidence_acup_users > 4 then 1 else 0 end) as comorbidity_5_acup_user
from #patients_w_multiple_conditions

UNION ALL

SELECT DISTINCT
	   'Group A' as Group_Lvl
	  ,sum(case when group_A > 0 then 1 else 0 end) as comorbidity_1
	  ,sum(case when group_A > 1 then 1 else 0 end) as comorbidity_2
	  ,sum(case when group_A > 2 then 1 else 0 end) as comorbidity_3
	  ,sum(case when group_A > 3 then 1 else 0 end) as comorbidity_4
	  ,sum(case when group_A > 4 then 1 else 0 end) as comorbidity_5

	  ,sum(case when group_A_acup_users > 0 then 1 else 0 end) as comorbidity_1_acup_user
	  ,sum(case when group_A_acup_users > 1 then 1 else 0 end) as comorbidity_2_acup_user
	  ,sum(case when group_A_acup_users > 2 then 1 else 0 end) as comorbidity_3_acup_user
	  ,sum(case when group_A_acup_users > 3 then 1 else 0 end) as comorbidity_4_acup_user
	  ,sum(case when group_A_acup_users > 4 then 1 else 0 end) as comorbidity_5_acup_user
from #patients_w_multiple_conditions

UNION ALL

SELECT DISTINCT
	   'Group A to C' as Group_Lvl
	  ,sum(case when group_A_to_C > 0 then 1 else 0 end) as comorbidity_1
	  ,sum(case when group_A_to_C > 1 then 1 else 0 end) as comorbidity_2
	  ,sum(case when group_A_to_C > 2 then 1 else 0 end) as comorbidity_3
	  ,sum(case when group_A_to_C > 3 then 1 else 0 end) as comorbidity_4
	  ,sum(case when group_A_to_C > 4 then 1 else 0 end) as comorbidity_5

	  ,sum(case when group_A_to_c_acup_users > 0 then 1 else 0 end) as comorbidity_1_acup_user
	  ,sum(case when group_A_to_c_acup_users > 1 then 1 else 0 end) as comorbidity_2_acup_user
	  ,sum(case when group_A_to_c_acup_users > 2 then 1 else 0 end) as comorbidity_3_acup_user
	  ,sum(case when group_A_to_c_acup_users > 3 then 1 else 0 end) as comorbidity_4_acup_user
	  ,sum(case when group_A_to_c_acup_users > 4 then 1 else 0 end) as comorbidity_5_acup_user
from #patients_w_multiple_conditions

/**************************************************************
Get the conditions that are most commonly seen together
*************************************************************/
-- for the full veteran diagnosis list
select a.condition as condition_1
	  ,a.[group]
	  ,a.Group_A_Evidence_Certainty_Rating
	  ,b.condition as condition_2
	  ,b.[group]
	  ,b.Group_A_Evidence_Certainty_Rating
	  ,count(distinct a.patientICN) as veteran_count
	  ,count(distinct case when a.current_acupuncture_user =1 then a.PatientICN end) as curr_acup_user
from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
	inner join vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as b
		on a.patienticn = b.patientICN
		AND a.condition <b.condition
	inner join (select *
                from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                where [EnrolledFY26]=1) as c on a.patienticn = c.ADRPersonICN
where a.condition <> 'N/A' and b.condition <> 'N/A'
group by a.condition, b.condition
having count(distinct a.patientICN) >100 and count(distinct b.patientICN) >100
order by veteran_count desc;



-- for the acupuncture users since FY21
select a.condition as condition_1
	  ,a.[group]
	  ,a.Group_A_Evidence_Certainty_Rating
	  ,b.condition as condition_2
	  ,b.[group]
	  ,b.Group_A_Evidence_Certainty_Rating
	  ,count(distinct a.patientICN) as acup_user_count
from OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses as a
	inner join OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses as b
		on a.patienticn = b.patientICN
		AND a.condition < b.condition
	inner join (select *
                from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                where [EnrolledFY26]=1) as c on a.patienticn = c.ADRPersonICN
where a.condition is not null and a.EverPrimaryFlag=1 and a.condition <>'N/A'
	 and b.condition is not null and b.EverPrimaryFlag=1 and b.condition <>'N/A'
group by a.condition, b.condition
having count(distinct a.patientICN) >100
order by acup_user_count desc;

select top 1000 *
from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses];

/**************************************************************
Get the groups split by demographics
1) Age
2) Gender
3) race/ethnicity
*************************************************************/
/*************************************************************
1) Age
*************************************************************/

with pat_group as (
    select [group]
	      ,group_a_evidence_certainty_rating
          ,PatientICN
          ,current_acupuncture_user
		  ,CASE WHEN age < 35 THEN '<35'
           WHEN age BETWEEN 35 AND 44 THEN '35-44'
           WHEN age BETWEEN 45 AND 54 THEN '45-54'
           WHEN age BETWEEN 55 AND 64 THEN '55-64'
           WHEN age BETWEEN 65 AND 74 THEN '65-74'
           WHEN age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
    from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
        inner join (select *
                   from vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets 
                   where [EnrolledFY26]=1) as b on a.patienticn = b.ADRPersonICN
),
max_tier as (
    select PatientICN
		  ,current_acupuncture_user
		  ,age_bin
           ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from pat_group
    group by PatientICN,current_acupuncture_user,age_bin
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
    select highest_tier
		  ,highest_evidence
		  ,age_bin 
		  ,current_acupuncture_user
		  ,count(distinct a.PatientICN) as enrolled_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    group by highest_tier, highest_evidence, age_bin, current_acupuncture_user
),
summed_vals as (
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
		,current_acupuncture_user
		,age_bin
from user_tier_counts
)
select
    age_bin,
    current_acupuncture_user,
    -- Group A
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='High/Strong'  then enrolled_count else 0 end) as 'Group A - High/Strong',
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='Moderate'     then enrolled_count else 0 end) as 'Group A - Moderate',
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='Low/Very Low' then enrolled_count else 0 end) as 'Group A - Low/Very Low',
    -- Other Groups
    sum(case when [Group]='Group B' then enrolled_count else 0 end) as 'Group B',
	sum(case when [Group]='Group C' then enrolled_count else 0 end) as 'Group C',
	sum(case when [Group]='Group D' then enrolled_count else 0 end) as 'Group D',
    sum(case when [Group] not in ('Group A','Group B','Group C','Group D') then enrolled_count else 0 end) as 'Remove'
from summed_vals
group by age_bin, current_acupuncture_user
order by current_acupuncture_user, age_bin;

/*************************************************************
2) Gender
*************************************************************/

with pat_group as (
    select a.[group]
	      ,a.group_a_evidence_certainty_rating
          ,a.PatientICN
          ,a.current_acupuncture_user
		  ,b.gender
    from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
        inner join (select *
                   from vhacdwa01.opccct_cih.dflt.all_enrolled_vet_demographics 
                   where [EnrolledFY26]=1) as b on a.patienticn = b.patienticn
),
max_tier as (
    select PatientICN
		  ,current_acupuncture_user
		  ,gender
           ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from pat_group
    group by PatientICN, current_acupuncture_user, gender
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
    select highest_tier
		  ,highest_evidence
		  ,gender 
		  ,current_acupuncture_user
		  ,count(distinct a.PatientICN) as enrolled_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    group by highest_tier, highest_evidence, gender, current_acupuncture_user
),
summed_vals as (
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
		,current_acupuncture_user
		,gender
from user_tier_counts
)
select
    gender,
    current_acupuncture_user,
    -- Group A
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='High/Strong'  then enrolled_count else 0 end) as 'Group A - High/Strong',
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='Moderate'     then enrolled_count else 0 end) as 'Group A - Moderate',
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='Low/Very Low' then enrolled_count else 0 end) as 'Group A - Low/Very Low',
    -- Other Groups
    sum(case when [Group]='Group B' then enrolled_count else 0 end) as 'Group B',
	sum(case when [Group]='Group C' then enrolled_count else 0 end) as 'Group C',
	sum(case when [Group]='Group D' then enrolled_count else 0 end) as 'Group D',
    sum(case when [Group] not in ('Group A','Group B','Group C','Group D') then enrolled_count else 0 end) as 'Remove'
from summed_vals
where gender is not null
group by gender, current_acupuncture_user
order by current_acupuncture_user, gender;

/*************************************************************
3) Gender
*************************************************************/

with pat_group as (
    select a.[group]
	      ,a.group_a_evidence_certainty_rating
          ,a.PatientICN
          ,a.current_acupuncture_user
		  ,race_mod
    from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
        inner join (select *
                   from vhacdwa01.opccct_cih.dflt.all_enrolled_vet_demographics 
                   where [EnrolledFY26]=1) as b on a.patienticn = b.patienticn
),
max_tier as (
    select PatientICN
		  ,current_acupuncture_user
		  ,race_mod
           ,min(case when [group]='Group A' then 1
                     when [group]='Group B' then 2
                     when [group]='Group C' then 3 
                     when [group]='Group D' then 4
                     else 5 end) as highest_tier
    from pat_group
    group by PatientICN, current_acupuncture_user, race_mod
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
    select highest_tier
		  ,highest_evidence
		  ,race_mod 
		  ,current_acupuncture_user
		  ,count(distinct a.PatientICN) as enrolled_count
    from max_tier as a
        left join max_evidence as b 
            on a.patienticn = b.PatientICN
    group by highest_tier, highest_evidence, race_mod, current_acupuncture_user
),
summed_vals as (
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
		,current_acupuncture_user
		,race_mod
from user_tier_counts
)
select
    race_mod,
    current_acupuncture_user,
    -- Group A
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='High/Strong'  then enrolled_count else 0 end) as 'Group A - High/Strong',
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='Moderate'     then enrolled_count else 0 end) as 'Group A - Moderate',
    sum(case when [Group]='Group A' and Group_A_Evidence_Certainty_Rating='Low/Very Low' then enrolled_count else 0 end) as 'Group A - Low/Very Low',
    -- Other Groups
    sum(case when [Group]='Group B' then enrolled_count else 0 end) as 'Group B',
	sum(case when [Group]='Group C' then enrolled_count else 0 end) as 'Group C',
	sum(case when [Group]='Group D' then enrolled_count else 0 end) as 'Group D',
    sum(case when [Group] not in ('Group A','Group B','Group C','Group D') then enrolled_count else 0 end) as 'Remove'
from summed_vals
where race_mod is not null
group by race_mod, current_acupuncture_user
order by current_acupuncture_user, race_mod;

/*************************************************************
Want to get a full breakout at the condition level as well
This is primarily just if we need to explain the reason why certain 
group levels show substantial differences by age, gender, race
*************************************************************/
drop table if exists #age_bins;

select a.*,
    CASE WHEN a.age < 35 THEN '<35'
            WHEN a.age BETWEEN 35 AND 44 THEN '35-44'
            WHEN a.age BETWEEN 45 AND 54 THEN '45-54'
            WHEN a.age BETWEEN 55 AND 64 THEN '55-64'
            WHEN a.age BETWEEN 65 AND 74 THEN '65-74'
            WHEN a.age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
        ,b.gender
into #age_bins
from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses] as a
    inner join (select *
                from vhacdwa01.opccct_cih.dflt.all_enrolled_vet_demographics 
                where [EnrolledFY26]=1) as b on a.patienticn = b.patienticn;

/************get the various demographic total counts*/
declare @women int;
set @women = (select count(distinct patienticn)
              FROM #age_bins
              where gender='Female');
print 'number of women: ' + cast(@women as varchar);

declare @men int;
set @men = (select count(distinct patienticn)
              FROM #age_bins
              where gender='Male');
print 'number of men: ' + cast(@men as varchar);

declare @under_35 int;
set @under_35 = (select count(distinct patienticn)
                  FROM #age_bins
                  where age_bin='<35');
print 'number of under 35: ' + cast(@under_35 as varchar);

declare @35_44 int;
set @35_44 = (select count(distinct patienticn)
                  FROM #age_bins
                  where age_bin='35-44');
print 'number of 35 to 44: ' + cast(@35_44 as varchar);

declare @45_54 int;
set @45_54 = (select count(distinct patienticn)
                  FROM #age_bins
                  where age_bin='45-54');
print 'number of 45 to 54: ' + cast(@45_54 as varchar);

declare @55_64 int;
set @55_64 = (select count(distinct patienticn)
                  FROM #age_bins
                  where age_bin='55-64');
print 'number of 55 to 64: ' + cast(@55_64 as varchar);

declare @65_74 int;
set @65_74 = (select count(distinct patienticn)
                  FROM #age_bins
                  where age_bin='65-74');
print 'number of 65 to 74: ' + cast(@65_74 as varchar);

declare @75_over int;
set @75_over = (select count(distinct patienticn)
                  FROM #age_bins
                  where age_bin='75+');
print 'number of 75+: ' + cast(@75_over as varchar);

/*************************************************************
Now get the summary by condition to breakout by the demographcis of interest
*************************************************************/
select  a.Condition
        ,a.[group]
	    ,a.group_a_evidence_certainty_rating
		,count(distinct case when gender='Female' then a.patientICN end) * 1.0/@women as female_count
        ,count(distinct case when gender='Male' then a.patientICN end) * 1.0/@men as male_count
        ,count(distinct case when age_bin='<35' then a.patientICN end) * 1.0/@under_35 as under_35_count
        ,count(distinct case when age_bin='35-44' then a.patientICN end) * 1.0/@35_44 as [35_44_count]
        ,count(distinct case when age_bin='45-54' then a.patientICN end) * 1.0/@45_54 as [45_54_count]
        ,count(distinct case when age_bin='55-64' then a.patientICN end) * 1.0/@55_64 as [55_64_count]
        ,count(distinct case when age_bin='65-74' then a.patientICN end) * 1.0/@65_74 as [65_74_count]
        ,count(distinct case when age_bin='75+' then a.patientICN end) * 1.0/@75_over as [75_plus_count]
from #age_bins as a
where [group]<>'Exclude'
group by a.Condition, a.[group]
	    ,a.group_a_evidence_certainty_rating;

/*************************************************************
see the distributions of ages vs. genders
*************************************************************/
select DISTINCT
         gender
         ,PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY Age)
            OVER (PARTITION BY gender) AS percentile_10
        ,PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Age)
            OVER (PARTITION BY gender) AS percentile_25
        ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Age)
            OVER (PARTITION BY gender) AS percentile_50
        ,PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Age)
            OVER (PARTITION BY gender) AS percentile_75
        ,PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY Age)
            OVER (PARTITION BY gender) AS percentile_90
FROM #age_bins
where gender is not null;

/*************************************************************
lets do a control comparison of young men and women and old
men and women
*************************************************************/
declare @young_women int;
set @young_women = (select count(distinct patienticn)
                      FROM #age_bins
                      where age_bin='<35' and gender='Female');
print 'number of young women: ' + cast(@young_women as varchar);

declare @young_men int;
set @young_men = (select count(distinct patienticn)
                      FROM #age_bins
                      where age_bin='<35' and gender='Male');
print 'number of young men: ' + cast(@young_men as varchar);

declare @old_women int;
set @old_women = (select count(distinct patienticn)
                      FROM #age_bins
                      where age_bin='75+' and gender='Female');
print 'number of old women: ' + cast(@old_women as varchar);

declare @old_men int;
set @old_men = (select count(distinct patienticn)
                      FROM #age_bins
                      where age_bin='75+' and gender='Male');
print 'number of old men: ' + cast(@old_men as varchar);;

with young_people as (
    select  a.Condition
            ,a.[group]
	        ,a.group_a_evidence_certainty_rating
		    ,count(distinct case when gender='Female' then a.patientICN end) * 1.0/@young_women as young_female_count
            ,count(distinct case when gender='Male' then a.patientICN end) * 1.0/@young_men as young_male_count
    from #age_bins as a
    where [group]<>'Exclude' and age_bin='<35'
    group by a.Condition, a.[group]
	        ,a.group_a_evidence_certainty_rating
),
old_people as (
    select  a.Condition
            ,a.[group]
	        ,a.group_a_evidence_certainty_rating
		    ,count(distinct case when gender='Female' then a.patientICN end) * 1.0/@old_women as old_female_count
            ,count(distinct case when gender='Male' then a.patientICN end) * 1.0/@old_men as old_male_count
    from #age_bins as a
    where [group]<>'Exclude' and age_bin='75+'
    group by a.Condition, a.[group]
	        ,a.group_a_evidence_certainty_rating
)
select 
     COALESCE(a.condition, b.condition) AS condition
    ,COALESCE(a.[group], b.[group]) AS [group]
    ,COALESCE(a.group_a_evidence_certainty_rating, b.group_a_evidence_certainty_rating) AS group_a_evidence_certainty_rating
    ,young_female_count * 1.0/@young_women as young_female_per
    ,young_male_count * 1.0/@young_men as young_male_per
    ,old_female_count * 1.0/@old_women as old_female_per
    ,old_male_count * 1.0/@old_men as old_male_per
from young_people as a
    full outer join old_people as b
        on a.condition = b.condition
        AND a.[group] = b.[group]
        AND a.group_a_evidence_certainty_rating = b.group_a_evidence_certainty_rating


select top 1000 * 
FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses

/*************************************************************
Found that PTSD, migraines, depression, and anxiety are diagnosed
more commonly in women, let's see how much of the total acupuncture
treatments are for them
*************************************************************/
drop table if exists #primary_codes;

select a.*, b.gender
into #primary_codes
FROM OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses as a
    inner join (select *
                from vhacdwa01.opccct_cih.dflt.all_enrolled_vet_demographics
                ) as b on a.patienticn = b.patienticn
where (EverPrimaryFlag=1 OR Condition='Chronic Neck Pain' OR condition='Other chronic musculoskelatal pain') 
        and [group] <> 'Exclude';

declare @distinctMaleUsers int;
set @distinctMaleUsers = (select count(distinct case when gender='Male' then patienticn end)
                          FROM #primary_codes);

declare @distinctFemaleUsers int;
set @distinctFemaleUsers = (select count(distinct case when gender='Female' then patienticn end)
                            FROM #primary_codes);

drop table if exists #temp;

SELECT
    a.[group],
    Group_A_Evidence_Certainty_Rating,
    condition,
    sum(TimesDiagnosedTotal)          AS condition_diagnosis_total,
    sum(case when gender = 'male' then TimesDiagnosedTotal end) as male_diagnoses,
    sum(case when gender = 'female' then TimesDiagnosedTotal end) as female_diagnoses,
    COUNT(DISTINCT PatientICN) AS condition_distinct_patient_count,
    count(distinct case when gender ='male' then patientICN end) as condition_distinct_patient_male_count,
    count(distinct case when gender ='female' then patientICN end) as condition_distinct_patient_female_count,
    @distinctMaleUsers as total_male_users,
    @distinctFemaleUsers as total_female_users
into #temp
FROM #primary_codes as a
GROUP BY a.[group], condition,Group_A_Evidence_Certainty_Rating;

declare @total_male_diagnoses int;
set @total_male_diagnoses = (select sum(male_diagnoses)
                        from #temp);
print @total_male_diagnoses;

declare @total_diagnoses int;
set @total_diagnoses = (select sum(condition_diagnosis_total)
                        from #temp);
print @total_diagnoses;

SELECT
    [group],
    Group_A_Evidence_Certainty_Rating,
    condition,
    condition_diagnosis_total,
    @total_male_diagnoses*1.0/@total_diagnoses as per_of_all_diagnoses_male,
    male_diagnoses * 1.0/condition_diagnosis_total as per_of_diagnoses_male,
    --female_diagnoses * 1.0/condition_diagnosis_total as per_of_diagnoses_female,
    @distinctMaleUsers * 1.0/(@distinctMaleUsers+@distinctfeMaleUsers) as per_of_users_that_are_male,
    condition_distinct_patient_male_count * 1.0/condition_distinct_patient_count as per_of_users_treated_for_condition_male
    --condition_distinct_patient_female_count * 1.0/condition_distinct_patient_count as per_of_users_treated_for_condition_female,
   -- @distinctMaleUsers as total_male_users,
    --@distinctFemaleUsers as total_female_users
FROM #temp as a
order by condition_diagnosis_total desc;
