select top 1000 *
from [OPCCCT_Analytics].[DOEx].[WholeHealth_1_VISITS]


select a.visitsid,NoncountClinicFlag,EncounterType
	,LocationName,LocationType,PrimaryStopCode,Primary_Name,SecondaryStopCode,SecondaryName
	,NationalChar4,NationalChar4Description,PatientICN,SrcSystem
	,hf.HealthFactorCategory
	,hf.HealthFactorType
	,c.CPTCode
	,c.CPTName
	,CASE WHEN MONTH(a.VisitDateTime) >= 10 THEN YEAR(a.VisitDateTime) + 1
			ELSE YEAR(a.VisitDateTime) END AS FiscalYear
	,MONTH(a.VisitDateTime) as month
into #investigate
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_1_VISITS] as a
    left join [OPCCCT_Analytics].[DOEx].[WholeHealth_3_HealthFactor] as hf on a.VisitSID = hf.VisitSID 
                and a.PatientSID = hf.PatientSID
    left join [OPCCCT_Analytics].[DOEx].[WholeHealth_4_CPT] as c on a.PatientSID = c.PatientSID
               and a.VisitSID = c.VisitSID

where CASE WHEN MONTH(a.VisitDateTime) >= 10 THEN YEAR(a.VisitDateTime) + 1
			ELSE YEAR(a.VisitDateTime) END = 2026 and MONTH(a.VisitDateTime) = 1

select distinct LocationName, LocationType
from #investigate
where LocationName is not null