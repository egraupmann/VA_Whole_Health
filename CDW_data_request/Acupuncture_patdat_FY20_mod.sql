-- Pulling acupuncture utilization for FY20
-- Adam Resnick | 6/30/2021

/*** CPT ***/
drop table if exists #cpt
select distinct 
       h.scrssn
	  ,h.patienticn
	  ,b.[PatientSID]
      ,b.[Sta3n]
	  ,g.Sta6a
	  ,b.[VisitSID]
      ,b.[VisitDateTime], convert(date, a.VisitDateTime) as VisitDate 
	  ,c.[CPTCode] 
	  ,d.stopcode as PrimaryStopCode
	  ,e.stopcode as SecondaryStopCode
	  ,f.LocationName
	  ,g.DivisionName
	  ,case when i.locationSID is not NULL then 1 
		when i.locationSID is NULL then 0 
		end as tele
	  ,'Trad' as cptType 
  INTO  #cpt
  FROM [CDWWork].[Outpat].[Visit] as b
  inner join cdwwork.outpat.vprocedure as a on a.visitsid=b.visitsid
  inner join cdwwork.dim.cpt as c on a.cptsid=c.cptsid
  inner join cdwwork.dim.stopcode as d on d.stopcodesid=b.PrimaryStopCodeSID
  left join cdwwork.dim.stopcode as e on e.stopcodesid=b.SecondaryStopCodeSID
  inner join cdwwork.dim.location as f on f.locationsid=b.locationsid
  inner join cdwwork.dim.division as g on g.divisionsid=b.divisionsid
  left join cdwwork.SPatient.SPatient as h on a.PatientSID=h.PatientSID
  left join OPCCCT_CIHEC.COMP_FY20.Dim_Telehealth i on f.LocationSID = i.locationsid
  where (a.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999')) 
        and c.cptcode in ('97810','97811','97813','97814') 
        and h.CDWPossibleTestPatientFlag != 'Y' and h.VeteranFlag = 'Y'


/*** Char4 ***/
Drop table if exists #CHAR4;
select distinct
	S.ScrSSN
	, V.Sta3n
	, D.Sta6a
	, V.VisitSID
	,convert(date, V.VisitDateTime) as VisitDate
	, V.LocationSID
	, DSSL.DSSLocationSID
	, DL.LocationName
	, DSSL.DSSLocationStopCodeSID
	, DST.NationalChar4
	, DST.NationalChar4Description
	, V.PrimaryStopCodeSID
	, V.SecondaryStopCodeSID
	, SC.StopCode as PrimaryStopCode
	, SC.StopCodeName as PrimaryStopCodeName
	, SC2.StopCode as SecondaryStopCode
	, SC2.StopCodeName as SecondaryStopCodeName
	,case when e.locationSID is not NULL then 1 
		when e.locationSID is NULL then 0 
		end as tele,
	'Trad' as Char4Type 
into #CHAR4 
from CDWWORK.Outpat.Visit V
	inner join CDWWORK.SPatient.SPatient S on V.PatientSID = S.PatientSID
	inner join CDWWORK.Dim.Division D on V.DivisionSID = D.DivisionSID
	inner join CDWWORK.Dim.[Location] DL on V.LocationSID = DL.LocationSID
	inner join CDWWORK.Dim.DSSLocation DSSL on V.LocationSID = DSSL.LocationSID
	inner join CDWWORK.Dim.DSSLocationStopCode DST on DSSL.DSSLocationStopCodeSID = DST.DSSLocationStopCodeSID
	left join CDWWORK.Dim.StopCode SC on V.PrimaryStopCodeSID = SC.StopCodeSID
	left join CDWWORK.Dim.StopCode SC2 on V.SecondaryStopCodeSID = SC2.StopCodeSID
	left join OPCCCT_CIHEC.COMP_FY20.Dim_Telehealth e on v.LocationSID = e.locationsid
where DST.NationalChar4 in ('acup')
	and (V.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999'))
	and (SC.StopCode not in ('655','656','660','663','679') and SC2.StopCode not in ('655','656','660','663','679'))
	and S.CDWPossibleTestPatientFlag != 'Y' and S.VeteranFlag = 'Y'
union
select distinct
	S.ScrSSN
	, V.Sta3n
	, D.Sta6a
	, V.VisitSID
	,convert(date, V.VisitDateTime) as VisitDate
	, V.LocationSID
	, DSSL.DSSLocationSID
	, DL.LocationName
	, DSSL.DSSLocationStopCodeSID
	, DST.NationalChar4
	, DST.NationalChar4Description
	, V.PrimaryStopCodeSID
	, V.SecondaryStopCodeSID
	, SC.StopCode as PrimaryStopCode
	, SC.StopCodeName as PrimaryStopCodeName
	, SC2.StopCode as SecondaryStopCode
	, SC2.StopCodeName as SecondaryStopCodeName
	,case when e.locationSID is not NULL then 1 
		when e.locationSID is NULL then 0 
		end as tele,
	'BFA' as Char4Type 
from CDWWORK.Outpat.Visit V
	inner join CDWWORK.SPatient.SPatient S on V.PatientSID = S.PatientSID
	inner join CDWWORK.Dim.Division D on V.DivisionSID = D.DivisionSID
	inner join CDWWORK.Dim.[Location] DL on V.LocationSID = DL.LocationSID
	inner join CDWWORK.Dim.DSSLocation DSSL on V.LocationSID = DSSL.LocationSID
	inner join CDWWORK.Dim.DSSLocationStopCode DST on DSSL.DSSLocationStopCodeSID = DST.DSSLocationStopCodeSID
	left join CDWWORK.Dim.StopCode SC on V.PrimaryStopCodeSID = SC.StopCodeSID
	left join CDWWORK.Dim.StopCode SC2 on V.SecondaryStopCodeSID = SC2.StopCodeSID
	left join OPCCCT_CIHEC.COMP_FY20.Dim_Telehealth e on v.LocationSID = e.locationsid
where DST.NationalChar4 in ('IACT')
	and (V.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999'))
	and (SC.StopCode not in ('655','656','660','663','679') and SC2.StopCode not in ('655','656','660','663','679'))
	and S.CDWPossibleTestPatientFlag != 'Y' and S.VeteranFlag = 'Y';

/*** Health Factors ***/
drop table if exists OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_healthfactors
select* 
into OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_healthfactors
from (
select 
	a.HealthFactorType,
	a.HealthFactorTypeIEN, 
	a.HealthFactorTypeSID, 
	a.HealthFactorCategory,
	a.sta3n,
	'Trad' as HFType 
from cdwwork.Dim.HealthFactorType as a
where 
	(HealthFactorType like '%acup%' or HealthFactorType like '%acpu%')
	/* apply generic exclusion strings to HealthFactors*/
	and (HealthFactorType not like '%battlefield%' and HealthFactorType not like '%bfa%' and HealthFactorType not like '%research%' 
	and HealthFactorType not like '%rsch%' and HealthFactorType not like '%referral' and HealthFactorType not like '%non va%' 
	and HealthFactorType not like '%vcp%' and HealthFactorType not like '%outside%' and HealthFactorType not like '%plan%' 
	and HealthFactorType not like '%acupressure%' and HealthFactorType not like '%follow%' and HealthFactorType not like '%consult%'
	--and HealthFactorType not like '%telephone%' 
	and HealthFactorType not like '%no show%' and HealthFactorType not like '%messaging%'
	and HealthFactorType not like '%econsult%' and HealthFactorType not like '%e consult%' and HealthFactorType not like '%e-consult%'
	and HealthFactorType not like '%ref%' and HealthFactorType not like '%test%' and healthfactortype not like '%TCMLH%' 
	and HealthFactorType not like '%vcl%' and HealthFactorType not like '%yoga%' and HealthFactorType not like '%community%'
	and HealthFactorType not like '%com tx%' and HealthFactorType not like '%comm care%' and HealthFactorType not like '%com care%'
	and HealthFactorType not like '%choice%' and HealthFactorType not like '%cc%'
	/*Added by LA team*/
	and HealthFactorType not like '%fager%'
	and HealthFactorType not like '%f/u%'
	) 
union
select 
	b.HealthFactorType,
	b.HealthFactorTypeIEN, 
	b.HealthFactorTypeSID, 
	b.HealthFactorCategory,
	b.sta3n,
	'BFA' as HFType 
from cdwwork.Dim.HealthFactorType as b
where 
	   (HealthFactorType like '%bfa%'or HealthFactorType like '%battlefield%')
	   /* apply generic exclusion strings to HealthFactors*/
	  and (HealthFactorType not like '%research%' 
	  and HealthFactorType not like '%rsch%' and HealthFactorType not like '%referral' and HealthFactorType not like '%non va%' 
	  and HealthFactorType not like '%vcp%' and HealthFactorType not like '%outside%' and HealthFactorType not like '%plan%' 
	  and HealthFactorType not like '%acupressure%' and HealthFactorType not like '%follow%' and HealthFactorType not like '%consult%'
	  --and HealthFactorType not like '%telephone%' 
	  and HealthFactorType not like '%no show%' and HealthFactorType not like '%messaging%'
	  and HealthFactorType not like '%econsult%' and HealthFactorType not like '%e consult%' and HealthFactorType not like '%e-consult%'
	  and HealthFactorType not like '%ref%' and HealthFactorType not like '%test%' and healthfactortype not like '%TCMLH%' 
	  and HealthFactorType not like '%vcl%' and HealthFactorType not like '%yoga%' and HealthFactorType not like '%community%'
	  and HealthFactorType not like '%com tx%' and HealthFactorType not like '%comm care%' and HealthFactorType not like '%com care%'
      and HealthFactorType not like '%choice%' and HealthFactorType not like '%cc%' )
	  	  /*Added by LA team*/
	   and HealthFactorType not like '%fager%'
	   and HealthFactorType not like '%f/u%')c

drop table if exists #hf
select 
	h.PatientICN, 
	h.ScrSSN,
	a.PatientSID, 
	a.sta3n, 
	g.sta6a,
	a.VisitSID,
	a.VisitDateTime, convert(date, a.VisitDateTime) as VisitDate, 
	a.HealthFactorSID, 
	a.HealthFactorTypeSID, 
	b.HFType,
	b.HealthFactorType, 
	b.HealthFactorCategory, 
	g.DivisionName, 
	d.LocationName,
	d.LocationSID,
	e.StopCode as PrimaryStopCode, 
	f.StopCode as SecondaryStopCode
	,case when i.locationSID is not NULL then 1 
		when i.locationSID is NULL then 0 
		end as tele
into #hf
from [cdwwork].[HF].[HealthFactor] as a 
	inner join OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_healthfactors as b on (a.HealthFactorTypeSID = b.HealthFactorTypeSID)
	inner join [cdwwork].[Outpat].[visit] as c on (a.VisitSID = c.VisitSID) 
	inner join [cdwwork].[dim].[Location] as d on (c.LocationSID = d.LocationSID) 
	inner join [cdwwork].[dim].[StopCode] as e on (c.PrimaryStopCodeSID = e.StopCodeSID) 
	left join [cdwwork].[dim].[StopCode] as f on (c.SecondaryStopCodeSID = f.StopCodeSID)
	inner join [cdwwork].[dim].[Division] as g on (c.DivisionSID = g.DivisionSID)  
	left join [cdwwork].[SPatient].[SPatient] as h on (a.PatientSID = h.PatientSID)
	left join OPCCCT_CIHEC.COMP_FY20.Dim_Telehealth i on d.LocationSID = i.locationsid
where (a.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999'))
	and (e.StopCode is null or e.StopCode not in ('655','656','660','663','679')) and (f.StopCode is null or f.StopCode not in ('655','656','660','663','679')) 
	and h.CDWPossibleTestPatientFlag != 'Y' and h.VeteranFlag = 'Y'

/*** Location ***/
drop table if exists OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_Loc
select *
into OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_Loc
from (
select distinct 
	a.[Sta3n]
	,a.locationsid
	,a.[LocationName]
	,c.StopCode as PrimaryStopCode
	,c.StopCodeName as PrimaryStopCodeName
	,b.StopCode as SecondaryStopCode
	,b.StopCodeName as SecondaryStopCodeName
	,'Trad' as LOCType 
FROM [CDWWork].[Dim].[Location] as a 
	inner join cdwwork.dim.stopcode as c on a.PrimaryStopCodeSID=c.StopCodeSID
	left join cdwwork.dim.stopcode as b on a.SecondaryStopCodeSID=b.StopCodeSID
where 
	(locationname like '%acup%' or locationname like '%acpu%')
	/* loc specific exclusion strings*/ 
	and (locationname not like '%study%' and locationname not like '%zznonvacare%' and locationname not like '%test%' 
	and locationname not like '%ref%' and locationname not like'%BFA%' and locationname not like '%battlefield%' 
	and locationname not like '%BTL ACP%' and locationname not like '%BF acup%' and locationname not like '%chiro%' 
	and locationname not like '%/battlefield%' and locationname not like '%battlefld%'
	--and locationname not like '%phone%'
	/* apply generic exclusion strings*/ 
	and locationname not like '%non va care%' and locationname not like '%vcp%' and locationname not like '%outside%' 
	and locationname not like '%plan%' and locationname not like '%acupressure%' and locationname not like '%vcl%'
	and locationname not like '%follow%'  
	--locationname not like '%telephone%' 
	and locationname not like '%no show%'
	and locationname not like '%messaging%' and locationname not like '%econsult%' and locationname not like '%e consult%'
	and locationname not like '%e-consult%' and locationname NOT LIKE '%referral%' and locationname NOT LIKE '%consult%' 
	and locationname not like '%research%' and locationname not like '%rsch%' and locationname not like '%community%' 
	and locationname not like '%com tx%' and locationname not like '%comm care%' and locationname not like '%com care%'
	and locationname not like '%choice%'
	/*Added by LA Team*/
	and locationname not like '%labfasting%'
	and locationname not like '%secm%'
	and locationname not like '%tele%'
	and locationname not like '%bacup a%')
union
select distinct 
	a.[Sta3n]
	,a.locationsid
	,a.[LocationName]
	,c.StopCode as PrimaryStopCode
	,c.StopCodeName as PrimaryStopCodeName
	,b.StopCode as SecondaryStopCode
	,b.StopCodeName as SecondaryStopCodeName
	,'BFA' as LOCType 
FROM [CDWWork].[Dim].[Location] as a 
	inner join cdwwork.dim.stopcode as b on a.PrimaryStopCodeSID=b.StopCodeSID
	left join cdwwork.dim.stopcode as c on a.SecondaryStopCodeSID=c.StopCodeSID
where 
	(locationname LIKE '%battlefield%' or locationname LIKE '%bfa%' or locationname like '%BTL ACP%' or locationname like '%BF acup%'
	or locationname like '%battlefld%' or locationname like '%/battlefield%')
	/* loc specific exclusion strings*/ 
	and (locationname not like '%study%' and locationname not like '%zznonvacare%' and locationname NOT LIKE '%test%' 
	and locationname not like '%ref%'  
	--locationname not like '%phone%'
	/* apply generic exclusion strings*/ 
	and locationname not like '%non va care%' and locationname not like '%vcp%' and locationname not like '%outside%' 
	and locationname not like '%plan%' and locationname not like '%acupressure%' and locationname not like '%vcl%'
	and locationname not like '%follow%'  
	--locationname not like '%telephone%' 
	and locationname not like '%no show%'
	and locationname not like '%messaging%' and locationname not like '%econsult%' and locationname not like '%e consult%'
	and locationname not like '%e-consult%' and locationname NOT LIKE '%referral%' and locationname NOT LIKE '%consult%' 
	and locationname not like '%research%' and locationname not like '%rsch%' and locationname not like '%community%' 
	and locationname not like '%com tx%' and locationname not like '%comm care%' and locationname not like '%com care%'
	and locationname not like '%choice%'
	/*Added by LA Team*/
	and locationname not like '%labfasting%'
	and locationname not like '%secm%'
	and locationname not like '%tele%'
	and locationname not like '%bacup a%'))d
--(1589 rows affected)

 drop table if exists #Loc_Name
select 
    d.PatientICN
	,d.ScrSSN
	,a.PatientSID 
	,a.sta3n 
	,c.Sta6a
	,a.VisitSID
	,a.VisitDateTime,convert(date, a.VisitDateTime) as VisitDate
	,b.LOCType
	,c.DivisionName 
	,b.LocationName
	,b.LocationSID
	,b.PrimaryStopCode
	,b.SecondaryStopCode
    ,case when i.locationSID is not NULL then 1 
		when i.locationSID is NULL then 0 
		end as tele
into #Loc_Name
from [cdwwork].[outpat].[Visit] as a 
	inner join OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_Loc  as b on a.LocationSID=b.LocationSID 
	inner join [cdwwork].[dim].[division] as c on a.DivisionSID=c.DivisionSID
	left join [cdwwork].[SPatient].[SPatient] as d on a.PatientSID=d.PatientSID  
	left join OPCCCT_CIHEC.COMP_FY20.Dim_Telehealth i on b.LocationSID = i.locationsid
where (a.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999'))
	and (b.PrimaryStopCode is null or b.PrimaryStopcode not in ('655','656','660','663','679')) and (b.SecondaryStopCode is null or b.SecondaryStopCode not in ('655','656','660','663','679')) 
	and d.CDWPossibleTestPatientFlag != 'Y' and d.VeteranFlag = 'Y'
	--(4648 rows affected) 5.12.21

/*** Note titles ***/
drop table if exists OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_notetitle
select *
into OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_notetitle
from (
	select TIUDocumentDefinitionSID, 
	sta3n, 
	TIUDocumentDefinition,
	'Trad' as NoteType 
from cdwwork.dim.TIUDocumentDefinition
where
	(TIUDocumentDefinition like '%acup%' or TIUDocumentDefinition like '%acpu%')
	/* note specific exclusion strings*/  --removed the "note" restriction that was previously imposed on the flagship sites; 
	and (TIUDocumentDefinition not like '%battlefield%' and TIUDocumentDefinition not like '%BFA%' 
	--and (TIUDocumentDefinition not like '%battlefield%' and TIUDocumentDefinition not like '%BFA%' and TIUDocumentDefinition not like '%note%'
	and TIUDocumentDefinition not like '%acupressure%' and  TIUDocumentDefinition not like '%phone%'  and TIUDocumentDefinition not like '%chiro%' 
	and TIUDocumentDefinition not like '%cc%'
	/* apply generic exclusion strings*/ 
	and TIUDocumentDefinition not like '%non va%' and TIUDocumentDefinition not like '%vcl%' and TIUDocumentDefinition not like '%vcp%'
	and TIUDocumentDefinition not like '%outside%' and TIUDocumentDefinition not like '%plan%' and TIUDocumentDefinition not like '%follow%'
	and TIUDocumentDefinition not like '%no show%' and TIUDocumentDefinition not like '%messaging%' and TIUDocumentDefinition not like '%econsult%'
	and TIUDocumentDefinition not like '%e consult%' and TIUDocumentDefinition not like '%e-consult%' and TIUDocumentDefinition not like '%referral%'  
	and TIUDocumentDefinition not like '%research%' and TIUDocumentDefinition not like '%rsch%' and TIUDocumentDefinition not like '%consult%'
	--and TIUDocumentDefinition not like '%telephone%' 
	and TIUDocumentDefinition not like '%community%' 
	and TIUDocumentDefinition not like '%com tx%' and TIUDocumentDefinition not like '%comm care%' and TIUDocumentDefinition not like '%com care%'
	and TIUDocumentDefinition not like '%choice%'
	/*Added by LA team*/
	and TIUDocumentDefinition not like '%appointment request%'
	and TIUDocumentDefinition not like '%instructions%'
	and TIUDocumentDefinition not like '%non-va%'
	and TIUDocumentDefinition not like '%consent%'
	and TIUDocumentDefinition not like '%reply%'
	and TIUDocumentDefinition not like '%outcome%'
	and TIUDocumentDefinition not like '%test%')
UNION
select TIUDocumentDefinitionSID, 
		sta3n, 
		TIUDocumentDefinition,
		'BFA' as NoteType 
from cdwwork.dim.TIUDocumentDefinition
where 
	(TIUDocumentDefinition like '%battlefield%' or TIUDocumentDefinition like '%bfa%')
	/* note specific exclusion strings*/ 
	and (TIUDocumentDefinition not like '%note%' and TIUDocumentDefinition not like '%acupressure%' 
	--and TIUDocumentDefinition not like '%phone%'
	and TIUDocumentDefinition not like '%cc%'
	/* apply generic exclusion strings*/ 
	and TIUDocumentDefinition not like '%non va%' and TIUDocumentDefinition not like '%vcl%' and TIUDocumentDefinition not like '%vcp%'
	and TIUDocumentDefinition not like '%outside%' and TIUDocumentDefinition not like '%plan%' and TIUDocumentDefinition not like '%follow%'
	and TIUDocumentDefinition not like '%no show%' and TIUDocumentDefinition not like '%messaging%' and TIUDocumentDefinition not like '%econsult%'
	and TIUDocumentDefinition not like '%e consult%' and TIUDocumentDefinition not like '%e-consult%' and TIUDocumentDefinition not like '%referral%'  
	and TIUDocumentDefinition not like '%research%' and TIUDocumentDefinition not like '%rsch%' and TIUDocumentDefinition not like '%consult%'
	--and TIUDocumentDefinition not like '%telephone%' 
	and  TIUDocumentDefinition not like '%community%' 
	and TIUDocumentDefinition not like '%com tx%' and TIUDocumentDefinition not like '%comm care%' and TIUDocumentDefinition not like '%com care%'
	and TIUDocumentDefinition not like '%choice%' and TIUDocumentDefinition not like '%cc%'
			/*Added by LA team*/
	and TIUDocumentDefinition not like '%appointment request%'
	and TIUDocumentDefinition not like '%instructions%'
	and TIUDocumentDefinition not like '%non-va%'
	and TIUDocumentDefinition not like '%consent%'
	and TIUDocumentDefinition not like '%outcome%'
	and TIUDocumentDefinition not like '%reply%'
	and TIUDocumentDefinition not like '%test%')) c
	--(331 rows affected) 5.12.21


drop table if exists #nt
select 
	 h.PatientICN 
	,h.ScrSSN
	,a.PatientSID 
	,c.Sta3n 
	,g.Sta6a
	,a.VisitSID 
	,c.VisitDateTime, convert(date, c.VisitDateTime) as VisitDate
	,b.TIUDocumentDefinition 
	,b.NoteType
	,g.DivisionName 
	,d.LocationName
	,d.LocationSID
	,e.StopCode as PrimaryStopCode
	,f.StopCode as SecondaryStopCode
    ,case when i.locationSID is not NULL then 1 
		when i.locationSID is NULL then 0 
		end as tele
into #nt
from [cdwwork].[TIU].[TIUDocument] as a
	inner join OPCCCT_CIHEC.COMP_FY20.dim_acupuncture_notetitle b on (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID)
	inner join [cdwwork].[Outpat].[visit] as c on a.VisitSID=c.VisitSID 
	inner join [cdwwork].[dim].[Location] as d on c.LocationSID=d.LocationSID
	inner join [cdwwork].[dim].[StopCode] as e on c.PrimaryStopCodeSID=e.StopCodeSID
	left join [cdwwork].[dim].[StopCode] as f on c.SecondaryStopCodeSID=f.StopCodeSID
	inner join [cdwwork].[dim].[Division] as g on c.DivisionSID = g.DivisionSID 
	left join [cdwwork].[SPatient].[SPatient] as h on a.PatientSID = h.PatientSID
	left join OPCCCT_CIHEC.COMP_FY20.Dim_Telehealth i on d.LocationSID = i.locationsid
where (c.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999'))
	and (e.StopCode is null or e.Stopcode not in ('655','656','660','663','679')) and (f.StopCode is null or f.StopCode not in ('655','656','660','663','679')) 
	and h.CDWPossibleTestPatientFlag != 'Y' and h.VeteranFlag = 'Y'

	/*** compile a consolidated list of all biofeedback visits and by which methods they were found ***/
drop table if exists #acupuncture_consolidated_methods;
with visit_list as (
	select distinct ScrSSN, Sta3n, VisitSID, VisitDate, tele from #cpt
	union
	select distinct ScrSSN, Sta3n, VisitSID, VisitDate,  tele from #nt
	union
	select distinct ScrSSN, Sta3n, VisitSID, VisitDate,  tele from #loc_name
	union
	select distinct ScrSSN, Sta3n, VisitSID, VisitDate,  tele from #hf
	union
	select distinct ScrSSN, Sta3n, VisitSID, VisitDate,  tele from #CHAR4
	)
select distinct A.ScrSSN
	, A.Sta3n
	, A.VisitSID
	, A.VisitDate
	, A.tele
	, case when B.VisitSID is not null then 1 else 0 end as 'CPT'
	, case when C.VisitSID is not null then 1 else 0 end as 'NoteTitle'
	, case when D.VisitSID is not null then 1 else 0 end as 'Clinic_Name'
	, case when E.VisitSID is not null then 1 else 0 end as 'HealthFactor'
	, case when F.VisitSID is not null then 1 else 0 end as 'CHAR4'
	, case when c.NoteType = 'BFA' or b.cptType = 'BFA' or d.LOCType = 'BFA' or e.HFType = 'BFA'or f.Char4Type = 'BFA' Then 1 Else 0 end as 'BFA'
into #acupuncture_consolidated_methods
from visit_list A
	left join #cpt		B	on A.VisitSID = B.VisitSID
	left join #nt		C	on A.VisitSID = C.VisitSID
	left join #loc_name D	on A.VisitSID = D.VisitSID
	left join #hf	E	on A.VisitSID = E.VisitSID
	left join #CHAR4	F	on A.VisitSID = F.VisitSID;

select Top(100) * from  #acupuncture_consolidated_methods
order by ScrSSN, VisitDate

select Top(100) * from  #nt
order by ScrSSN, VisitDate

/*** for visits identified only by [Clinic_Name]
-- 1. identify which ones should be excluded based on notetitles for those visits
-- 2. exclude these visits from the main list of visits 
select count(*) from #acupuncture_consolidated_methods where CPT = 0 and NoteTitle = 0 and Clinic_Name = 1 and healthfactor = 0 and CHAR4 = 0	
-- 20,863 visits identified by [Clinic_Name] alone
***/

-- identify location only visits to exclude
drop table if exists #loc_only_exclusions;
select distinct 
        a.ScrSSN,
		a.sta3n,
		a.VisitDate,
		a.VisitSID,
		b.TIUDocumentSID,
		c.TIUDocumentDefinition
into #loc_only_exclusions
from #acupuncture_consolidated_methods a
	inner join [cdwwork].[TIU].[TIUDocument] as b on b.visitsid = a.visitsid          
	inner join [cdwwork].[dim].[TIUDocumentDefinition] as c  on b.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
where CPT = 0 and NoteTitle = 0 and CHAR4 = 0 and HealthFactor = 0 and Clinic_Name = 1 
	/*excluded items for visits found by [Clinic_Name] only*/
	and (TIUDocumentDefinition  like '%failed%'
	or TIUDocumentDefinition  like '%missed appointment%'
	or TIUDocumentDefinition  like '%non-va%'
	or TIUDocumentDefinition  like '%beneficiary travel%'
	or TIUDocumentDefinition  like '%communication%'
	or TIUDocumentDefinition  like '%discharge%'
	or TIUDocumentDefinition  like '%education%'
	or TIUDocumentDefinition  like '%error/erroneous%'
	or TIUDocumentDefinition  like '%historical%'
	or TIUDocumentDefinition  like '%notification%'
	or TIUDocumentDefinition  like '%recall%'
	or TIUDocumentDefinition  like '%refill%'
	or TIUDocumentDefinition  like '%renewal%'
	or TIUDocumentDefinition  like '%result%'
	or TIUDocumentDefinition  like '%rxnote%'
	or TIUDocumentDefinition  like '%scheduler%'
	or TIUDocumentDefinition  like '%valuables%'
	or TIUDocumentDefinition  like '%cancel/cancellation%'
	or TIUDocumentDefinition  like '%no-show%'
	or TIUDocumentDefinition  like '%admin%'
	or  TIUDocumentDefinition  like '%appt%'
	or TIUDocumentDefinition  like '%clerical%'
	or TIUDocumentDefinition  like '%contact%'
	or TIUDocumentDefinition  like '%letter%'
	or TIUDocumentDefinition  like '%prescription drug%'
	or TIUDocumentDefinition  like '%reconciliation%'
	or TIUDocumentDefinition  like '%scheduling%'
	or TIUDocumentDefinition  like '%travel request%'
	or TIUDocumentDefinition  like '%yoga%'
	or TIUDocumentDefinition  like '%call%'
	or TIUDocumentDefinition  like '%chart review%'
	or TIUDocumentDefinition  like '%unknown%'
	or TIUDocumentDefinition  like '%addendum%'  
	or TIUDocumentDefinition  like '%Nursing%'
	or TIUDocumentDefinition  like '%QI GONG%'
	or TIUDocumentDefinition  like '%Neurology%'
	or TIUDocumentDefinition  like '%Rehab%'
	or TIUDocumentDefinition  like '%Specialty%'
	or TIUDocumentDefinition  like '%Physiatry%'
	or TIUDocumentDefinition  like '%Primary care%'
	or TIUDocumentDefinition  like '%Mental health%'
	or TIUDocumentDefinition  like '%Promotion%'
	or TIUDocumentDefinition  like '%Clerk%'
	or TIUDocumentDefinition  like '%External%'
	or TIUDocumentDefinition  like '%Admission%'
	or TIUDocumentDefinition  like '%psychology%'
	or TIUDocumentDefinition  like '%Surgery%'
	or TIUDocumentDefinition  like '%Medication%'
	or TIUDocumentDefinition  like '%non-visit%'
	or TIUDocumentDefinition  like '%Physician assistant%'
	or TIUDocumentDefinition  like '%opioid%'
	or TIUDocumentDefinition  like '%anticoagulation%'
	or TIUDocumentDefinition  like '%rheuma%'
	or TIUDocumentDefinition  like '%coaching%'
	or TIUDocumentDefinition  like '%suicide%'
	or TIUDocumentDefinition  like '%orthopedics%'
	or TIUDocumentDefinition  like '%cardiology%'
	or TIUDocumentDefinition  like '%social work%'
	or TIUDocumentDefinition  like '%urology%'
	or TIUDocumentDefinition  like '%oncology%'
	or TIUDocumentDefinition  like '%immunization%'
	or TIUDocumentDefinition  like '%Reminder%'
	or TIUDocumentDefinition  like '%anesthisiology%'
	or TIUDocumentDefinition  like '%advance directive%'
	/*previously excluded items, these are the exclusions from the original TIU search,
	still want to exclude these*/
	or TIUDocumentDefinition  like '%study%'
	or TIUDocumentDefinition  like '%zznonvacare%'
	or TIUDocumentDefinition  like '%ref%'
	or TIUDocumentDefinition  like '%test%'
	or TIUDocumentDefinition  like '%phone%'
	or TIUDocumentDefinition  like '%non va care%'
	or TIUDocumentDefinition  like '%chior%'
	or TIUDocumentDefinition  like'%vcp%'
	or TIUDocumentDefinition  like '%outside%'
	or TIUDocumentDefinition  like '%plan%'
	or TIUDocumentDefinition  like '%acupressure%'
	or TIUDocumentDefinition  like '%vcl%'
	or TIUDocumentDefinition  like '%follow%'
	or TIUDocumentDefinition  like '%no-show%'
	or TIUDocumentDefinition  like '%messaging%'
	or TIUDocumentDefinition  like '%e-consult%'
	or TIUDocumentDefinition  like '%econsult%'
	or TIUDocumentDefinition  like '%consult%'
	or TIUDocumentDefinition  like '%e consult%'
	or TIUDocumentDefinition  like '%referral %'
	or TIUDocumentDefinition  like '%research%'
	or TIUDocumentDefinition  like '%e-consult%'
	or TIUDocumentDefinition  like '%rsch%'
	or TIUDocumentDefinition  like '%community%'
	or TIUDocumentDefinition  like '%com tx%'
	or TIUDocumentDefinition  like '%comm care %'
	or TIUDocumentDefinition  like '%rsch%'
	or TIUDocumentDefinition  like '%com care%'
	or TIUDocumentDefinition  like '%choice%'
	);


-- remove exclusion visits from overall list of visits 
drop table if exists #acupuncture_consolidated_methods_excl;
select * into #acupuncture_consolidated_methods_excl from #acupuncture_consolidated_methods
where VisitSID not in (select distinct(VisitSID) from #loc_only_exclusions);
--(12,238visits after exclusions removed) 6.16.2021

/******   reduce to patient-day table   ******/
drop table if exists OPCCCT_CIHEC.COMP_FY20.acupuncture_patday;
select a.ScrSSN
	,a.Sta3n
	,a.VisitDate
	, case when min(a.tele) = 0 then 1 else 0 end as in_person
	, case when max(a.tele) = 1 then 1 else 0 end as any_tele
	, max(CPT) as any_CPT
	, max(NoteTitle) as any_note_title
	, max(Clinic_Name) as any_loc_name
	, max(HealthFactor) as any_health_factor
	, max(CHAR4) as any_CHAR4
	, case when max(bfa) = 1 then 'BFA' else 'Traditional' end as acu_type
into OPCCCT_CIHEC.COMP_FY20.acupuncture_patday
from #acupuncture_consolidated_methods_excl a
group by a.ScrSSN, a.Sta3n, a.VisitDate;


select * from OPCCCT_CIHEC.COMP_FY20.acupuncture_patday
order by ScrSSN, VisitDate

/***********************************************/
select  count(distinct concat(scrssn, sta3n))            as uniquepatients, 
         count(distinct concat(scrssn, sta3n, visitdate)) as uniquevisits
 from OPCCCT_CIHEC.COMP_FY20.acupuncture_patday;
 /* counts as of 7.6.21
        uniquepatients	uniquevisits
               60271	      200064

7.15.21
uniquepatients	uniquevisits
         60206	199857
*/

 --data to bring into sas to do freq table before entering into R to make the venn diagram
 select any_char4, any_CPT, any_note_title, any_loc_name, any_health_factor  , in_person, any_tele, acu_type                   
 from  OPCCCT_CIHEC.COMP_FY20.acupuncture_patday;