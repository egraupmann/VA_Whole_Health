/****************************************************/
/*	This assembles the diagnosis code that are	*/
/*	observed in the VA encounters from both VISTA	*/
/*	and Millennium, as well as the referrals for	*/
/*	acupuncture that come from both sources as well	*/
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

/*	Aggregate the referral diagnoses in a similar way as the VA visit
diagnoses so that there's 1 record per patient/ICD10 */
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals;

WITH agg AS (
	SELECT
		 PatientICN
		,PatientSID
		,SourceSystem
		,ICD10Code
		,MIN(RequestDateTime) AS FirstDiagnosedDate
		,MAX(RequestDateTime) AS MostRecentDiagnosedDate
		,COUNT(*) AS TimesDiagnosedTotal
	FROM #with_ICN
	GROUP BY PatientICN, PatientSID, SourceSystem, ICD10Code
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
	,a.FirstDiagnosedDate
	,a.MostRecentDiagnosedDate
	,a.TimesDiagnosedTotal
INTO OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals
FROM agg AS a
INNER JOIN most_recent_diagnosis AS m
	ON a.PatientICN = m.PatientICN
	AND a.PatientSID = m.PatientSID;

CREATE INDEX IX_acu_diag_referral_summary_patienticn_acu_only
	ON OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals (PatientICN);

/****************************************************/
/*	Aggregate the Referrals with the VA Visits      */
/*	This gives the full list of all diagnoses for	*/
/*	acupuncture related visits/referrals			*/
/****************************************************/
drop table if exists #ALL_ACUP_Related_Diagnoses_temp;

--combined CC referral table with VA visits
select *
INTO #ALL_ACUP_Related_Diagnoses_temp
from OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only

UNION ALL

select *
	,1 as EverPrimaryFlag --all the diagnoses listed in the referral list at this point are primary
	,'P' as MostRecentPrimarySecondary
from OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_CC_acu_referrals;

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
	  ,min(FirstDiagnosedDate) as First_ICD10_DiagnosedDate
	  ,max(MostRecentDiagnosedDate) as MostRecent_ICD10_DiagnosedDate
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

drop table if exists OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses;

WITH icd10_desc AS (
	SELECT DISTINCT
		 [CodeID] as ICD10Code
        ,[CodeDescription] as ICD10Description
	FROM cdwwork2.mill.PatientDiagnosisAll
)

select a.PatientICN
	  ,a.ICD10Code
	  ,c.ICD10Description
	  ,d.[Group] as tier
	  ,d.Condition
	  ,d.[Code Description] as ICD10_detailed_description
	  ,b.PatientMostRecent_ACU_RelatedDiagnosis
	  ,a.First_ICD10_DiagnosedDate
	  ,a.MostRecent_ICD10_DiagnosedDate
	  ,a.TimesDiagnosedTotal
	  ,a.EverPrimaryFlag
	  ,a.MostRecentPrimarySecondary
into OPCCCT_CIH.dflt.ALL_ACUP_Related_Diagnoses
from #patient_summary as a
	inner join #patient_most_recent_visit as b
		on a.patientICN = b.patientICN
	left join icd10_desc as c
		on a.ICD10Code = c.ICD10Code
	left join OPCCCT_CIH.dflt.ICD10_Tier_List as d
		on a.ICD10Code = d.Code;


