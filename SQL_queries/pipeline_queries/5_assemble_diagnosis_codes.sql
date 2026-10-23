/****************************************************/
/*	This assembles the diagnosis code that are	*/
/*	observed in the VA encounters from both VISTA	*/
/*	and Millennium, as well as the referrals for	*/
/*	acupuncture that come from both sources as well	*/
/*	It also attaches the ICD-10 Tier List to determine	*/
/*	whether a current users have a condition viewed as	*/
/*	benefiting from acupuncture treatment			*/
/****************************************************/

/****************************************************/
/* Bring in the various sources. I dedupe as well as
possible. People could be in both VISTA and Millennium
and referrals so trying to account for that */
/****************************************************/

--attach the patientICN so I can dedupe same people spanning VISTA
--and Millennium
drop table if exists #with_ICN;

WITH mill_ICN AS(
	SELECT	PersonSID as PatientSID
		,case when AliasName LIKE '%zz%' then null --This zz record was for 1 patient that appears to be fake and was causing issues
												   --so simply got rid of it
			  else left(cast(AliasName as varchar(50)), 10) end as PatientICN
	FROM [CDWWork2].[VeteranMill].[PersonAlias]
	where AliasPool = 'ICN'
)

select a.*
	  , case when b.PatientICN IS NULL THEN c.PatientICN
					ELSE b.PatientICN end as PatientICN
into #with_ICN
from opccct_cih.dflt.COMBINED_acupuncture_referrals as a
	left join mill_ICN as b 
		on a.PatientSID = b.PatientSID
	left join CDWWork.patient.patient as c
		on a.PatientSID = c.PatientSID;


/******************************************************************************
Helper tables to determine whether the patient has chronic neck pain in the referral data
******************************************************************************/
drop table if exists #chronic_pain_referrals;

with chronic_pain as (
	select distinct PatientSID
			,ReferralSID
			,1 as chronic_pain_indicator
	from OPCCCT_CIH.dflt.COMBINED_acupuncture_referrals
	where icd10code in ('G89.29','G89.4')
)

select a.PatientSID, case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
						else a.ICD10Code end as ICD10Code, chronic_pain_indicator
into #chronic_pain_referrals
from OPCCCT_CIH.dflt.COMBINED_acupuncture_referrals as a
	inner join chronic_pain as b
		on a.PatientSID = b.PatientSID
			and a.ReferralSID = b.ReferralSID
	inner join (select  case when len(ICD_10_Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from ICD_10_Code)) 
						else ICD_10_Code end as ICD_10_Code
				from OPCCCT_CIH.Dflt.ICD10_Tier_List
				where Chronic_Version=1
				) as c
		on  case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
						else a.ICD10Code end = c.ICD_10_Code
where RequestDateTime >= '2025-09-01'; 

/*	Aggregate the referral diagnoses in a similar way as the VA visit
diagnoses so that there's 1 record per patient/ICD10 */
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals;

WITH agg AS (
	SELECT
		 PatientICN
		,a.PatientSID
		,SourceSystem
		,case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
						else a.ICD10Code end as ICD10Code
		,max(case when chronic_pain_indicator is null then 0 else 1 end) as chronic_pain_indicator
		,MIN(RequestDateTime) AS FirstDiagnosedDate
		,MAX(RequestDateTime) AS MostRecentDiagnosedDate
		,COUNT(*) AS TimesDiagnosedTotal
		,sum(case when RequestDateTime >= '2025-09-01' then 1 else 0 end) as Num_Diagnoses_in_Last_Year
		,min(case when RequestDateTime >= '2025-09-01' then RequestDateTime end) as First_Diagnosis_in_Last_Year
		,max(case when RequestDateTime >= '2025-09-01' then RequestDateTime end) as Last_Diagnosis_in_Last_Year
	FROM #with_ICN as a
		left join #chronic_pain_referrals as b
			on a.PatientSID = b.PatientSID AND case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
													else a.ICD10Code end = b.ICD10Code
	GROUP BY PatientICN, a.PatientSID, SourceSystem, a.ICD10Code
),

most_recent_diagnosis AS (
	SELECT
		 PatientICN
		,PatientSID
		,MAX(RequestDateTime) AS PatientMostRecentDiagnosis
	FROM #with_ICN
	GROUP BY PatientICN, PatientSID
)

SELECT
	 a.PatientICN
	,a.PatientSID
	,a.SourceSystem
	,m.PatientMostRecentDiagnosis
	,a.ICD10Code
	,chronic_pain_indicator
	,a.FirstDiagnosedDate
	,a.MostRecentDiagnosedDate
	,a.Num_Diagnoses_in_Last_Year
	,a.First_Diagnosis_in_Last_Year
	,a.Last_Diagnosis_in_Last_Year
	,a.TimesDiagnosedTotal
INTO OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals
FROM agg AS a
INNER JOIN most_recent_diagnosis AS m
	ON a.PatientICN = m.PatientICN
	AND a.PatientSID = m.PatientSID

CREATE INDEX IX_acu_diag_referral_summary_patienticn_acu_only
	ON OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals (PatientICN);


/****************************************************/
/*	Aggregate the Referrals with the VA Visits      */
/*	This gives the full list of all diagnoses for	*/
/*	acupuncture related visits/referrals			*/
/****************************************************/
drop table if exists #ALL_ACUP_Related_Diagnoses_temp;
drop table if exists #chronic_pain_referrals2;

with chronic_pain as (
	select distinct PatientSID
		  ,1 as chronic_pain_indicator
	from OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only
	where icd10code in ('G89.29','G89.4')
)

select a.PatientSID, case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
													else a.ICD10Code end as ICD10Code
	, chronic_pain_indicator
into #chronic_pain_referrals2
from OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only as a
	inner join chronic_pain as b
		on a.PatientSID = b.PatientSID
	inner join (select ICD_10_Code
				from OPCCCT_CIH.Dflt.ICD10_Tier_List
				where Chronic_Version=1
				) as c
		on case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
				else a.ICD10Code end 
		 = case when len(c.ICD_10_Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from c.ICD_10_Code)) 
				else c.ICD_10_Code end
where MostRecentDiagnosedDate >= '2025-09-01'; 

--combined CC referral table with VA visits
select a.PatientICN
	,a.PatientSID
	,a.SourceSystem
	,a.PatientMostRecentDiagnosis
	,case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
				else a.ICD10Code end as ICD10Code
	,a.FirstDiagnosedDate
	,a.MostRecentDiagnosedDate
	,a.Num_Diagnoses_in_Last_Year
	,a.First_Diagnosis_in_Last_Year
	,a.Last_Diagnosis_in_Last_Year
	,a.TimesDiagnosedTotal
	,a.EverPrimaryFlag --all the diagnoses listed in the referral list at this point are primary
	,a.MostRecentPrimarySecondary
	,case when b.chronic_pain_indicator is null then 0 else b.chronic_pain_indicator end as chronic_pain_indicator
INTO #ALL_ACUP_Related_Diagnoses_temp
from OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only as a
	left join #chronic_pain_referrals2 as b
		on a.PatientSID = b.PatientSID
			and case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
				else a.ICD10Code end  = b.ICD10Code

UNION ALL

select  a.PatientICN
	,a.PatientSID
	,a.SourceSystem
	,a.PatientMostRecentDiagnosis
	,case when len(a.ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from a.ICD10Code)) 
				else a.ICD10Code end as ICD10Code
	,a.FirstDiagnosedDate
	,a.MostRecentDiagnosedDate
	,a.Num_Diagnoses_in_Last_Year
	,a.First_Diagnosis_in_Last_Year
	,a.Last_Diagnosis_in_Last_Year
	,a.TimesDiagnosedTotal
	,1 as EverPrimaryFlag --all the diagnoses listed in the referral list at this point are primary
	,'P' as MostRecentPrimarySecondary
	,case when chronic_pain_indicator is null then 0 else chronic_pain_indicator end as chronic_pain_indicator
from OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals as a;


---------now aggregate again at the ICN level
---this removes any distinction for a patient of whether the diagnosis
---was at a VA facility, VISTA or millennium, and also whether it was a referral
---to give a true diagnsosis count for each patient in a comprehensive VA care view
drop table if exists #patient_most_recent_visit;

select PatientICN
	  ,max(PatientMostRecentDiagnosis) AS PatientMostRecent_ACU_RelatedDiagnosis
into #patient_most_recent_visit
from #ALL_ACUP_Related_Diagnoses_temp
group by PatientICN;

drop table if exists #patient_summary;

select PatientICN
	  ,ICD10Code
	  ,max(chronic_pain_indicator) as chronic_pain_indicator
	  ,min(FirstDiagnosedDate) as First_ICD10_DiagnosedDate
	  ,max(MostRecentDiagnosedDate) as MostRecent_ICD10_DiagnosedDate
	  ,sum(Num_Diagnoses_in_Last_Year) as Num_Diagnoses_in_Last_Year
	  ,min(First_Diagnosis_in_Last_Year) as First_Diagnosis_in_Last_Year
	  ,max(Last_Diagnosis_in_Last_Year) as Last_Diagnosis_in_Last_Year
	  ,sum(TimesDiagnosedTotal) as TimesDiagnosedTotal
	  ,max(EverPrimaryFlag) as EverPrimaryFlag
	  ,max(case when MostRecentPrimarySecondary='P' THEN 1
				else 0 end) as MostRecentPrimarySecondary
into #patient_summary
from #ALL_ACUP_Related_Diagnoses_temp as a
group by PatientICN, ICD10Code;

/****************************************************/
/* Get the final list of acupuncture related diagnoses */
/* for the acupuncture users. Adds in the tier determined*/
/* by our medical SMEs */
/****************************************************/
drop table if exists #ALL_ACUP_Related_Diagnoses_temp_final;
drop table if exists OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses;
drop table if exists #full_icd_10_list;

with icd_10_names as (
	select distinct case when len([codeid])>=4 then trim(TRAILING '.' from trim(TRAILING '0' from [CodeID])) 
						else codeid end as ICD10Code
        ,[CodeDescription] as ICD10Description
    FROM cdwwork2.mill.PatientDiagnosisAll
),
ranked AS (
	SELECT DISTINCT
		 ICD10Code
        ,ICD10Description
		,ROW_NUMBER() OVER (
					PARTITION BY ICD10Code
					ORDER BY ICD10Code
				) AS rn
	FROM icd_10_names
),
icd10_desc as (
	select ICD10Code, ICD10Description
	from ranked
	where rn=1
),
unique_handling_st as (
	select distinct case when len(ICD_10_Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from ICD_10_Code)) 
						else ICD_10_Code end as ICD_10_Code, cast(Unique_Handling as int) as unique_handling
	from opccct_cih.dflt.ICD10_Tier_List
),
unique_handling as (
	select ICD_10_Code, max(Unique_Handling) as Unique_Handling
	from unique_handling_st
	group by ICD_10_Code
)
--full_icd_10_list as (
	select a.PatientICN
		  ,e.age as age_on_10_1_2026
		  ,a.ICD10Code
		  ,c.ICD10Description
		  ,f.Unique_Handling
		  ,case when f.Unique_Handling = 1 and a.ICD10Code not in ('F51.01','F51.04','G47','G47.','G47.0','G47.00','G47.01','G47.09')
				then case when a.Num_Diagnoses_in_Last_Year>=2 AND (DATEDIFF(day, First_Diagnosis_in_Last_Year, Last_Diagnosis_in_Last_Year))>=90 then 1
							when a.chronic_pain_indicator=1 then 1
							else 0 end 
				else 0 end as chronic_version
		,b.PatientMostRecent_ACU_RelatedDiagnosis
		,a.First_ICD10_DiagnosedDate
		,a.MostRecent_ICD10_DiagnosedDate
		,a.TimesDiagnosedTotal
		,a.EverPrimaryFlag
		,a.MostRecentPrimarySecondary
	into #full_icd_10_list
	from #patient_summary as a
		inner join #patient_most_recent_visit as b
			on a.patientICN = b.patientICN
		left join icd10_desc as c
			on a.ICD10Code = c.ICD10Code
		left join OPCCCT_CIH.dflt.[ALL_ACUP_User_Demographics] as e
			on a.patientICN = e.patientICN
		left join unique_handling as f
			on a.icd10code = f.icd_10_code


select a.*
	  ,b.[group]
	  ,case when a.ICD10Code in ('F51.01','F51.04','G47','G47.','G47.0','G47.00','G47.01','G47.09') then
				case when a.age_on_10_1_2026>=60 then 'Moderate' else 'Low/Very Low' end
			else b.Group_A_Evidence_Certainty_Rating end as Group_A_Evidence_Certainty_Rating
	  ,case when a.ICD10Code in ('F51.01','F51.04','G47','G47.','G47.0','G47.00','G47.01','G47.09') then
				case when a.age_on_10_1_2026>=60 then 'Insomnia in elderly adults' else 'Primary Insomnia' end
			else b.Condition end as Condition
--into #ALL_ACUP_Related_Diagnoses_temp_final
into OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
from #full_icd_10_list as a
	left join (select distinct case when len([ICD_10_Code])>=4 then trim(TRAILING '.' from trim(TRAILING '0' from [ICD_10_Code])) else [ICD_10_Code] end as ICD_10_Code
					, [group], Group_A_Evidence_Certainty_Rating, Condition, Chronic_Version, Unique_Handling
			   from opccct_cih.dflt.ICD10_Tier_List) as b
		on case when len(ICD10Code)>=4 then trim(TRAILING '.' from trim(TRAILING '0' from ICD10Code)) else ICD10Code end
			= b.ICD_10_Code
		AND a.chronic_version = b.Chronic_Version
		AND a.Unique_Handling = b.Unique_Handling;

select icd10code, ICD10Description, [group], Group_A_Evidence_Certainty_Rating, Condition
	,count(*) as diagnosis_count
from OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
group by icd10code, ICD10Description, [group], Group_A_Evidence_Certainty_Rating, Condition
order by count(*) desc;