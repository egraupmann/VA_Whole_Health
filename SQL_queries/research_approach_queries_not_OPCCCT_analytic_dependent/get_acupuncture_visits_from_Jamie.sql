select year(visitdate) as visit_year
    ,sum(strong_evid) as strong_evid_count
    ,count(*) - sum(strong_evid) as weak_evid_count
    ,count(*) as record_count
from opccct_cih.dflt.temp_consolidated_methods
group by year(visitdate)
order by year(visitdate)




SELECT TOP (1000) [ScrSSN]
      ,[PatientSID]
      ,[VisitSID]
      ,[VisitDate]
      ,[CIHType]
      ,[Sta6a]
      ,[Tele]
      ,[PrimaryStopCode]
      ,[SecondaryStopCode]
      ,[CPT]
      ,[CPT_num_terms]
      ,[CPT_codes]
      ,[NT]
      ,[NT_num_terms]
      ,[NT_terms]
      ,[NT_inclusions]
      ,[LocName]
      ,[LocationName]
      ,[LN_inclusions]
      ,[HF]
      ,[HF_num_terms]
      ,[HF_terms]
      ,[HF_inclusions]
      ,[StopCode]
      ,[strong_evid]
      ,[weak_evid]
  FROM [OPCCCT_CIH].[Dflt].[temp_consolidated_methods]
