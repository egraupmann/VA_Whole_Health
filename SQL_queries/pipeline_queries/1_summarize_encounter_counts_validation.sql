/*******************************************
This is used to compare the outputs of the 0_acupuncture... script to the numbers that are reported by the 
OPCCCT_Analytics dashboard
*******************************************/


/* summarize the data by fiscal year, acupuncture type, visit type, and source system */
DROP TABLE IF EXISTS #count_table;
select CASE WHEN MONTH(VisitDateTime) >= 10 THEN YEAR(VisitDateTime) + 1
			ELSE YEAR(VisitDateTime) END AS FiscalYear
	   ,case when acupuncture_traditional>0 and [Source_CPT_Trad]+[Source_Char4_Trad]+[Source_HF_Trad]>0
				then 1 else 0 end as traditional_acupuncture
	   ,case when Acupuncture_BFA>0 then 1 else 0 end as bfa_acupuncture
	   ,case when (acupuncture_traditional>0 and [Source_CPT_Trad]+[Source_Char4_Trad]+[Source_HF_Trad]>0)
				and (Acupuncture_BFA>0) then 1 else 0 end as both_acupuncture
		, PatientICN, VisitSID
into #count_table
from opccct_cih.dflt.ALL_ACUP_VA_encounters;

select fiscalyear
	,sum(traditional_acupuncture) as traditional_acupuncture_count
	,sum(bfa_acupuncture) as bfa_acupuncture_count
	,sum(both_acupuncture) as both_acupuncture_count
	,count(distinct patienticn) as unique_patient_count
	,count(distinct case when traditional_acupuncture=1 then patienticn else null end) as unique_traditional_acupuncture_patient_count
	,count(distinct case when bfa_acupuncture=1 then patienticn else null end) as unique_BFA_acupuncture_patient_count
from #count_table
group by fiscalyear
order by fiscalyear

/****************Do the same as above but for VISN****************/
select fiscalyear, VISN
	,sum(traditional_acupuncture) as traditional_acupuncture_count
	,sum(bfa_acupuncture) as bfa_acupuncture_count
	,sum(both_acupuncture) as both_acupuncture_count
	,count(distinct c.patienticn) as unique_patient_count
	,count(distinct case when traditional_acupuncture=1 then c.patienticn else null end) as unique_traditional_acupuncture_patient_count
	,count(distinct case when bfa_acupuncture=1 then c.patienticn else null end) as unique_BFA_acupuncture_patient_count
from #count_table as c
	left join OPCCCT_Analytics.DOEx.WholeHealth_1_VISITS as v
		on c.VisitSID = v.VisitSID
group by fiscalyear, VISN
order by fiscalyear, VISN

/****************************************************
for the tables created from the code provided by Jamie 

select  CASE WHEN MONTH(VisitDate) >= 10 THEN YEAR(VisitDate) + 1
			ELSE YEAR(VisitDate) END AS FiscalYear
	,CIHType
	,count(distinct patientSID) as unique_patient_count
	,count(distinct visitsid) as unique_visit_count
from opccct_cih.dflt.Acupuncture_Visits_FY23_FY26
where strong_evid + weak_evid>0
group by CASE WHEN MONTH(VisitDate) >= 10 THEN YEAR(VisitDate) + 1
				ELSE YEAR(VisitDate) END
		,CIHTYPE
order by fiscalyear

select  top 1000 *
from opccct_cih.dflt.Acupuncture_Visits_FY17_FY20
***********************************************************/

