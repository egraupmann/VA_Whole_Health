/*******************************************
for the visits created from Irad's data
*******************************************/


/* summarize the data by fiscal year, acupuncture type, visit type, and source system */
select CASE WHEN MONTH(VisitDateTime) >= 10 THEN YEAR(VisitDateTime) + 1
			ELSE YEAR(VisitDateTime) END AS FiscalYear
	    ,sum(acupuncture_traditional) as traditional_count
from opccct_cih.dflt.acupuncture_vists_opccct_visit_info
where [Source_CPT_Trad]+[Source_Char4_Trad]+[Source_HF_Trad]>0
group by CASE WHEN MONTH(VisitDateTime) >= 10 THEN YEAR(VisitDateTime) + 1
				ELSE YEAR(VisitDateTime) END
order by fiscalyear

select CASE WHEN MONTH(VisitDateTime) >= 10 THEN YEAR(VisitDateTime) + 1
			ELSE YEAR(VisitDateTime) END AS FiscalYear
	    ,sum(Acupuncture_BFA) as bfa_count
from opccct_cih.dflt.acupuncture_vists_opccct_visit_info
/*where [Source_CPT_BFA]+[Source_Char4_BFA]+[Source_HF_BFA]>0*/
group by CASE WHEN MONTH(VisitDateTime) >= 10 THEN YEAR(VisitDateTime) + 1
				ELSE YEAR(VisitDateTime) END
order by fiscalyear

/****************************************************
for the tables created from the code provided by Jamie 
***********************************************************/
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


