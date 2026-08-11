/***************************************************************
Whole Health CDW pull with acupuncture-identification logic
aligned to References\CDW Resources\Acupuncture_patdat_FY20.sql.

Key adaptation:
- The official FY20 logic is preserved, but the date window below uses
  FY2023-FY2025 from the modified request script.
- Official permanent staging tables were converted to temp tables so this
  script can run without writing to OPCCCT_CIHEC.COMP_FY20.
- #acu_visits_final is kept at the same patient-day grain as the official
  final acupuncture_patday table: ScrSSN + Sta3n + VisitDate.
***************************************************************/

/***************************************************************
Parameters
***************************************************************/
declare @StartDate datetime2(0) = convert(datetime2(0),'2022-10-01 00:00:00.000');
declare @EndDate datetime2(0) = convert(datetime2(0),'2025-09-30 23:59:59.999');


/***************************************************************
Step 1: CPT acupuncture visits

Official inclusion:
- Outpatient VProcedure CPT code in 97810, 97811, 97813, 97814
- Veteran, non-test patient by CDWWork.SPatient.SPatient flags
***************************************************************/
drop table if exists #cpt;
select distinct
	 h.ScrSSN
	,h.PatientICN
	,b.PatientSID
	,b.Sta3n
	,g.Sta6a
	,b.VisitSID
	,b.VisitDateTime
	,convert(date, a.VisitDateTime) as VisitDate
	,c.CPTCode
	,d.StopCode as PrimaryStopCode
	,e.StopCode as SecondaryStopCode
	,f.LocationName
	,g.DivisionName
	,case when i.LocationSID is not null then 1
		  when i.LocationSID is null then 0
		  end as tele
	,'Trad' as CPTType
into #cpt
from [CDWWork].[Outpat].[Visit] as b
	inner join [CDWWork].[Outpat].[VProcedure] as a on a.VisitSID = b.VisitSID
	inner join [CDWWork].[Dim].[CPT] as c on a.CPTSID = c.CPTSID
	inner join [CDWWork].[Dim].[StopCode] as d on d.StopCodeSID = b.PrimaryStopCodeSID
	left join [CDWWork].[Dim].[StopCode] as e on e.StopCodeSID = b.SecondaryStopCodeSID
	inner join [CDWWork].[Dim].[Location] as f on f.LocationSID = b.LocationSID
	inner join [CDWWork].[Dim].[Division] as g on g.DivisionSID = b.DivisionSID
	left join [CDWWork].[SPatient].[SPatient] as h on a.PatientSID = h.PatientSID
	left join [OPCCCT_CIHEC].[COMP_FY20].[Dim_Telehealth] as i on f.LocationSID = i.LocationSID
where a.VisitDateTime between @StartDate and @EndDate
	and c.CPTCode in ('97810','97811','97813','97814')
	and h.CDWPossibleTestPatientFlag != 'Y'
	and h.VeteranFlag = 'Y';


/***************************************************************
Step 2: CHAR4 acupuncture visits

Official inclusion:
- DSSLocationStopCode.NationalChar4 = 'acup' => Traditional
- DSSLocationStopCode.NationalChar4 = 'IACT' => BFA
- Excludes stop codes 655, 656, 660, 663, 679 using the same
  non-null-safe predicate used in the official script.
***************************************************************/
drop table if exists #CHAR4;
select distinct
	 S.ScrSSN
	,S.PatientICN
	,V.PatientSID
	,V.Sta3n
	,D.Sta6a
	,V.VisitSID
	,convert(date, V.VisitDateTime) as VisitDate
	,V.LocationSID
	,DSSL.DSSLocationSID
	,DL.LocationName
	,DSSL.DSSLocationStopCodeSID
	,DST.NationalChar4
	,DST.NationalChar4Description
	,V.PrimaryStopCodeSID
	,V.SecondaryStopCodeSID
	,SC.StopCode as PrimaryStopCode
	,SC.StopCodeName as PrimaryStopCodeName
	,SC2.StopCode as SecondaryStopCode
	,SC2.StopCodeName as SecondaryStopCodeName
	,case when e.LocationSID is not null then 1
		  when e.LocationSID is null then 0
		  end as tele
	,'Trad' as Char4Type
into #CHAR4
from [CDWWork].[Outpat].[Visit] as V
	inner join [CDWWork].[SPatient].[SPatient] as S on V.PatientSID = S.PatientSID
	inner join [CDWWork].[Dim].[Division] as D on V.DivisionSID = D.DivisionSID
	inner join [CDWWork].[Dim].[Location] as DL on V.LocationSID = DL.LocationSID
	inner join [CDWWork].[Dim].[DSSLocation] as DSSL on V.LocationSID = DSSL.LocationSID
	inner join [CDWWork].[Dim].[DSSLocationStopCode] as DST on DSSL.DSSLocationStopCodeSID = DST.DSSLocationStopCodeSID
	left join [CDWWork].[Dim].[StopCode] as SC on V.PrimaryStopCodeSID = SC.StopCodeSID
	left join [CDWWork].[Dim].[StopCode] as SC2 on V.SecondaryStopCodeSID = SC2.StopCodeSID
	left join [OPCCCT_CIHEC].[COMP_FY20].[Dim_Telehealth] as e on V.LocationSID = e.LocationSID
where DST.NationalChar4 in ('acup')
	and V.VisitDateTime between @StartDate and @EndDate
	and (SC.StopCode not in ('655','656','660','663','679') and SC2.StopCode not in ('655','656','660','663','679'))
	and S.CDWPossibleTestPatientFlag != 'Y'
	and S.VeteranFlag = 'Y'
union
select distinct
	 S.ScrSSN
	,S.PatientICN
	,V.PatientSID
	,V.Sta3n
	,D.Sta6a
	,V.VisitSID
	,convert(date, V.VisitDateTime) as VisitDate
	,V.LocationSID
	,DSSL.DSSLocationSID
	,DL.LocationName
	,DSSL.DSSLocationStopCodeSID
	,DST.NationalChar4
	,DST.NationalChar4Description
	,V.PrimaryStopCodeSID
	,V.SecondaryStopCodeSID
	,SC.StopCode as PrimaryStopCode
	,SC.StopCodeName as PrimaryStopCodeName
	,SC2.StopCode as SecondaryStopCode
	,SC2.StopCodeName as SecondaryStopCodeName
	,case when e.LocationSID is not null then 1
		  when e.LocationSID is null then 0
		  end as tele
	,'BFA' as Char4Type
from [CDWWork].[Outpat].[Visit] as V
	inner join [CDWWork].[SPatient].[SPatient] as S on V.PatientSID = S.PatientSID
	inner join [CDWWork].[Dim].[Division] as D on V.DivisionSID = D.DivisionSID
	inner join [CDWWork].[Dim].[Location] as DL on V.LocationSID = DL.LocationSID
	inner join [CDWWork].[Dim].[DSSLocation] as DSSL on V.LocationSID = DSSL.LocationSID
	inner join [CDWWork].[Dim].[DSSLocationStopCode] as DST on DSSL.DSSLocationStopCodeSID = DST.DSSLocationStopCodeSID
	left join [CDWWork].[Dim].[StopCode] as SC on V.PrimaryStopCodeSID = SC.StopCodeSID
	left join [CDWWork].[Dim].[StopCode] as SC2 on V.SecondaryStopCodeSID = SC2.StopCodeSID
	left join [OPCCCT_CIHEC].[COMP_FY20].[Dim_Telehealth] as e on V.LocationSID = e.LocationSID
where DST.NationalChar4 in ('IACT')
	and V.VisitDateTime between @StartDate and @EndDate
	and (SC.StopCode not in ('655','656','660','663','679') and SC2.StopCode not in ('655','656','660','663','679'))
	and S.CDWPossibleTestPatientFlag != 'Y'
	and S.VeteranFlag = 'Y';


/***************************************************************
Step 3: Health-factor acupuncture visits
***************************************************************/
drop table if exists #dim_acupuncture_healthfactors;
select *
into #dim_acupuncture_healthfactors
from (
	select
		 a.HealthFactorType
		,a.HealthFactorTypeIEN
		,a.HealthFactorTypeSID
		,a.HealthFactorCategory
		,a.Sta3n
		,'Trad' as HFType
	from [CDWWork].[Dim].[HealthFactorType] as a
	where (a.HealthFactorType like '%acup%' or a.HealthFactorType like '%acpu%')
		and (a.HealthFactorType not like '%battlefield%' and a.HealthFactorType not like '%bfa%' and a.HealthFactorType not like '%research%'
		and a.HealthFactorType not like '%rsch%' and a.HealthFactorType not like '%referral' and a.HealthFactorType not like '%non va%'
		and a.HealthFactorType not like '%vcp%' and a.HealthFactorType not like '%outside%' and a.HealthFactorType not like '%plan%'
		and a.HealthFactorType not like '%acupressure%' and a.HealthFactorType not like '%follow%' and a.HealthFactorType not like '%consult%'
		and a.HealthFactorType not like '%no show%' and a.HealthFactorType not like '%messaging%'
		and a.HealthFactorType not like '%econsult%' and a.HealthFactorType not like '%e consult%' and a.HealthFactorType not like '%e-consult%'
		and a.HealthFactorType not like '%ref%' and a.HealthFactorType not like '%test%' and a.HealthFactorType not like '%TCMLH%'
		and a.HealthFactorType not like '%vcl%' and a.HealthFactorType not like '%yoga%' and a.HealthFactorType not like '%community%'
		and a.HealthFactorType not like '%com tx%' and a.HealthFactorType not like '%comm care%' and a.HealthFactorType not like '%com care%'
		and a.HealthFactorType not like '%choice%' and a.HealthFactorType not like '%cc%'
		and a.HealthFactorType not like '%fager%'
		and a.HealthFactorType not like '%f/u%')
	union
	select
		 b.HealthFactorType
		,b.HealthFactorTypeIEN
		,b.HealthFactorTypeSID
		,b.HealthFactorCategory
		,b.Sta3n
		,'BFA' as HFType
	from [CDWWork].[Dim].[HealthFactorType] as b
	where (b.HealthFactorType like '%bfa%' or b.HealthFactorType like '%battlefield%')
		and (b.HealthFactorType not like '%research%'
		and b.HealthFactorType not like '%rsch%' and b.HealthFactorType not like '%referral' and b.HealthFactorType not like '%non va%'
		and b.HealthFactorType not like '%vcp%' and b.HealthFactorType not like '%outside%' and b.HealthFactorType not like '%plan%'
		and b.HealthFactorType not like '%acupressure%' and b.HealthFactorType not like '%follow%' and b.HealthFactorType not like '%consult%'
		and b.HealthFactorType not like '%no show%' and b.HealthFactorType not like '%messaging%'
		and b.HealthFactorType not like '%econsult%' and b.HealthFactorType not like '%e consult%' and b.HealthFactorType not like '%e-consult%'
		and b.HealthFactorType not like '%ref%' and b.HealthFactorType not like '%test%' and b.HealthFactorType not like '%TCMLH%'
		and b.HealthFactorType not like '%vcl%' and b.HealthFactorType not like '%yoga%' and b.HealthFactorType not like '%community%'
		and b.HealthFactorType not like '%com tx%' and b.HealthFactorType not like '%comm care%' and b.HealthFactorType not like '%com care%'
		and b.HealthFactorType not like '%choice%' and b.HealthFactorType not like '%cc%'
		and b.HealthFactorType not like '%fager%'
		and b.HealthFactorType not like '%f/u%')
) as c;

drop table if exists #hf;
select
	 h.PatientICN
	,h.ScrSSN
	,a.PatientSID
	,a.Sta3n
	,g.Sta6a
	,a.VisitSID
	,a.VisitDateTime
	,convert(date, a.VisitDateTime) as VisitDate
	,a.HealthFactorSID
	,a.HealthFactorTypeSID
	,b.HFType
	,b.HealthFactorType
	,b.HealthFactorCategory
	,g.DivisionName
	,d.LocationName
	,d.LocationSID
	,e.StopCode as PrimaryStopCode
	,f.StopCode as SecondaryStopCode
	,case when i.LocationSID is not null then 1
		  when i.LocationSID is null then 0
		  end as tele
into #hf
from [CDWWork].[HF].[HealthFactor] as a
	inner join #dim_acupuncture_healthfactors as b on a.HealthFactorTypeSID = b.HealthFactorTypeSID
	inner join [CDWWork].[Outpat].[Visit] as c on a.VisitSID = c.VisitSID
	inner join [CDWWork].[Dim].[Location] as d on c.LocationSID = d.LocationSID
	inner join [CDWWork].[Dim].[StopCode] as e on c.PrimaryStopCodeSID = e.StopCodeSID
	left join [CDWWork].[Dim].[StopCode] as f on c.SecondaryStopCodeSID = f.StopCodeSID
	inner join [CDWWork].[Dim].[Division] as g on c.DivisionSID = g.DivisionSID
	left join [CDWWork].[SPatient].[SPatient] as h on a.PatientSID = h.PatientSID
	left join [OPCCCT_CIHEC].[COMP_FY20].[Dim_Telehealth] as i on d.LocationSID = i.LocationSID
where a.VisitDateTime between @StartDate and @EndDate
	and (e.StopCode is null or e.StopCode not in ('655','656','660','663','679'))
	and (f.StopCode is null or f.StopCode not in ('655','656','660','663','679'))
	and h.CDWPossibleTestPatientFlag != 'Y'
	and h.VeteranFlag = 'Y';


/***************************************************************
Step 4: Location-name acupuncture visits
***************************************************************/
drop table if exists #dim_acupuncture_Loc;
select *
into #dim_acupuncture_Loc
from (
	select distinct
		 a.Sta3n
		,a.LocationSID
		,a.LocationName
		,c.StopCode as PrimaryStopCode
		,c.StopCodeName as PrimaryStopCodeName
		,b.StopCode as SecondaryStopCode
		,b.StopCodeName as SecondaryStopCodeName
		,'Trad' as LOCType
	from [CDWWork].[Dim].[Location] as a
		inner join [CDWWork].[Dim].[StopCode] as c on a.PrimaryStopCodeSID = c.StopCodeSID
		left join [CDWWork].[Dim].[StopCode] as b on a.SecondaryStopCodeSID = b.StopCodeSID
	where (a.LocationName like '%acup%' or a.LocationName like '%acpu%')
		and (a.LocationName not like '%study%' and a.LocationName not like '%zznonvacare%' and a.LocationName not like '%test%'
		and a.LocationName not like '%ref%' and a.LocationName not like '%BFA%' and a.LocationName not like '%battlefield%'
		and a.LocationName not like '%BTL ACP%' and a.LocationName not like '%BF acup%' and a.LocationName not like '%chiro%'
		and a.LocationName not like '%/battlefield%' and a.LocationName not like '%battlefld%'
		and a.LocationName not like '%non va care%' and a.LocationName not like '%vcp%' and a.LocationName not like '%outside%'
		and a.LocationName not like '%plan%' and a.LocationName not like '%acupressure%' and a.LocationName not like '%vcl%'
		and a.LocationName not like '%follow%'
		and a.LocationName not like '%no show%'
		and a.LocationName not like '%messaging%' and a.LocationName not like '%econsult%' and a.LocationName not like '%e consult%'
		and a.LocationName not like '%e-consult%' and a.LocationName not like '%referral%' and a.LocationName not like '%consult%'
		and a.LocationName not like '%research%' and a.LocationName not like '%rsch%' and a.LocationName not like '%community%'
		and a.LocationName not like '%com tx%' and a.LocationName not like '%comm care%' and a.LocationName not like '%com care%'
		and a.LocationName not like '%choice%'
		and a.LocationName not like '%labfasting%'
		and a.LocationName not like '%secm%'
		and a.LocationName not like '%tele%'
		and a.LocationName not like '%bacup a%')
	union
	select distinct
		 a.Sta3n
		,a.LocationSID
		,a.LocationName
		,c.StopCode as PrimaryStopCode
		,c.StopCodeName as PrimaryStopCodeName
		,b.StopCode as SecondaryStopCode
		,b.StopCodeName as SecondaryStopCodeName
		,'BFA' as LOCType
	from [CDWWork].[Dim].[Location] as a
		inner join [CDWWork].[Dim].[StopCode] as b on a.PrimaryStopCodeSID = b.StopCodeSID
		left join [CDWWork].[Dim].[StopCode] as c on a.SecondaryStopCodeSID = c.StopCodeSID
	where (a.LocationName like '%battlefield%' or a.LocationName like '%bfa%' or a.LocationName like '%BTL ACP%' or a.LocationName like '%BF acup%'
		or a.LocationName like '%battlefld%' or a.LocationName like '%/battlefield%')
		and (a.LocationName not like '%study%' and a.LocationName not like '%zznonvacare%' and a.LocationName not like '%test%'
		and a.LocationName not like '%ref%'
		and a.LocationName not like '%non va care%' and a.LocationName not like '%vcp%' and a.LocationName not like '%outside%'
		and a.LocationName not like '%plan%' and a.LocationName not like '%acupressure%' and a.LocationName not like '%vcl%'
		and a.LocationName not like '%follow%'
		and a.LocationName not like '%no show%'
		and a.LocationName not like '%messaging%' and a.LocationName not like '%econsult%' and a.LocationName not like '%e consult%'
		and a.LocationName not like '%e-consult%' and a.LocationName not like '%referral%' and a.LocationName not like '%consult%'
		and a.LocationName not like '%research%' and a.LocationName not like '%rsch%' and a.LocationName not like '%community%'
		and a.LocationName not like '%com tx%' and a.LocationName not like '%comm care%' and a.LocationName not like '%com care%'
		and a.LocationName not like '%choice%'
		and a.LocationName not like '%labfasting%'
		and a.LocationName not like '%secm%'
		and a.LocationName not like '%tele%'
		and a.LocationName not like '%bacup a%')
) as d;

drop table if exists #Loc_Name;
select
	 d.PatientICN
	,d.ScrSSN
	,a.PatientSID
	,a.Sta3n
	,c.Sta6a
	,a.VisitSID
	,a.VisitDateTime
	,convert(date, a.VisitDateTime) as VisitDate
	,b.LOCType
	,c.DivisionName
	,b.LocationName
	,b.LocationSID
	,b.PrimaryStopCode
	,b.SecondaryStopCode
	,case when i.LocationSID is not null then 1
		  when i.LocationSID is null then 0
		  end as tele
into #Loc_Name
from [CDWWork].[Outpat].[Visit] as a
	inner join #dim_acupuncture_Loc as b on a.LocationSID = b.LocationSID
	inner join [CDWWork].[Dim].[Division] as c on a.DivisionSID = c.DivisionSID
	left join [CDWWork].[SPatient].[SPatient] as d on a.PatientSID = d.PatientSID
	left join [OPCCCT_CIHEC].[COMP_FY20].[Dim_Telehealth] as i on b.LocationSID = i.LocationSID
where a.VisitDateTime between @StartDate and @EndDate
	and (b.PrimaryStopCode is null or b.PrimaryStopCode not in ('655','656','660','663','679'))
	and (b.SecondaryStopCode is null or b.SecondaryStopCode not in ('655','656','660','663','679'))
	and d.CDWPossibleTestPatientFlag != 'Y'
	and d.VeteranFlag = 'Y';


/***************************************************************
Step 5: Note-title acupuncture visits
***************************************************************/
drop table if exists #dim_acupuncture_notetitle;
select *
into #dim_acupuncture_notetitle
from (
	select
		 TIUDocumentDefinitionSID
		,Sta3n
		,TIUDocumentDefinition
		,'Trad' as NoteType
	from [CDWWork].[Dim].[TIUDocumentDefinition]
	where (TIUDocumentDefinition like '%acup%' or TIUDocumentDefinition like '%acpu%')
		and (TIUDocumentDefinition not like '%battlefield%' and TIUDocumentDefinition not like '%BFA%'
		and TIUDocumentDefinition not like '%acupressure%' and TIUDocumentDefinition not like '%phone%' and TIUDocumentDefinition not like '%chiro%'
		and TIUDocumentDefinition not like '%cc%'
		and TIUDocumentDefinition not like '%non va%' and TIUDocumentDefinition not like '%vcl%' and TIUDocumentDefinition not like '%vcp%'
		and TIUDocumentDefinition not like '%outside%' and TIUDocumentDefinition not like '%plan%' and TIUDocumentDefinition not like '%follow%'
		and TIUDocumentDefinition not like '%no show%' and TIUDocumentDefinition not like '%messaging%' and TIUDocumentDefinition not like '%econsult%'
		and TIUDocumentDefinition not like '%e consult%' and TIUDocumentDefinition not like '%e-consult%' and TIUDocumentDefinition not like '%referral%'
		and TIUDocumentDefinition not like '%research%' and TIUDocumentDefinition not like '%rsch%' and TIUDocumentDefinition not like '%consult%'
		and TIUDocumentDefinition not like '%community%'
		and TIUDocumentDefinition not like '%com tx%' and TIUDocumentDefinition not like '%comm care%' and TIUDocumentDefinition not like '%com care%'
		and TIUDocumentDefinition not like '%choice%'
		and TIUDocumentDefinition not like '%appointment request%'
		and TIUDocumentDefinition not like '%instructions%'
		and TIUDocumentDefinition not like '%non-va%'
		and TIUDocumentDefinition not like '%consent%'
		and TIUDocumentDefinition not like '%reply%'
		and TIUDocumentDefinition not like '%outcome%'
		and TIUDocumentDefinition not like '%test%')
	union
	select
		 TIUDocumentDefinitionSID
		,Sta3n
		,TIUDocumentDefinition
		,'BFA' as NoteType
	from [CDWWork].[Dim].[TIUDocumentDefinition]
	where (TIUDocumentDefinition like '%battlefield%' or TIUDocumentDefinition like '%bfa%')
		and (TIUDocumentDefinition not like '%note%' and TIUDocumentDefinition not like '%acupressure%'
		and TIUDocumentDefinition not like '%cc%'
		and TIUDocumentDefinition not like '%non va%' and TIUDocumentDefinition not like '%vcl%' and TIUDocumentDefinition not like '%vcp%'
		and TIUDocumentDefinition not like '%outside%' and TIUDocumentDefinition not like '%plan%' and TIUDocumentDefinition not like '%follow%'
		and TIUDocumentDefinition not like '%no show%' and TIUDocumentDefinition not like '%messaging%' and TIUDocumentDefinition not like '%econsult%'
		and TIUDocumentDefinition not like '%e consult%' and TIUDocumentDefinition not like '%e-consult%' and TIUDocumentDefinition not like '%referral%'
		and TIUDocumentDefinition not like '%research%' and TIUDocumentDefinition not like '%rsch%' and TIUDocumentDefinition not like '%consult%'
		and TIUDocumentDefinition not like '%community%'
		and TIUDocumentDefinition not like '%com tx%' and TIUDocumentDefinition not like '%comm care%' and TIUDocumentDefinition not like '%com care%'
		and TIUDocumentDefinition not like '%choice%' and TIUDocumentDefinition not like '%cc%'
		and TIUDocumentDefinition not like '%appointment request%'
		and TIUDocumentDefinition not like '%instructions%'
		and TIUDocumentDefinition not like '%non-va%'
		and TIUDocumentDefinition not like '%consent%'
		and TIUDocumentDefinition not like '%outcome%'
		and TIUDocumentDefinition not like '%reply%'
		and TIUDocumentDefinition not like '%test%')
) as c;

drop table if exists #nt;
select
	 h.PatientICN
	,h.ScrSSN
	,a.PatientSID
	,c.Sta3n
	,g.Sta6a
	,a.VisitSID
	,c.VisitDateTime
	,convert(date, c.VisitDateTime) as VisitDate
	,b.TIUDocumentDefinition
	,b.NoteType
	,g.DivisionName
	,d.LocationName
	,d.LocationSID
	,e.StopCode as PrimaryStopCode
	,f.StopCode as SecondaryStopCode
	,case when i.LocationSID is not null then 1
		  when i.LocationSID is null then 0
		  end as tele
into #nt
from [CDWWork].[TIU].[TIUDocument] as a
	inner join #dim_acupuncture_notetitle as b on a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID
	inner join [CDWWork].[Outpat].[Visit] as c on a.VisitSID = c.VisitSID
	inner join [CDWWork].[Dim].[Location] as d on c.LocationSID = d.LocationSID
	inner join [CDWWork].[Dim].[StopCode] as e on c.PrimaryStopCodeSID = e.StopCodeSID
	left join [CDWWork].[Dim].[StopCode] as f on c.SecondaryStopCodeSID = f.StopCodeSID
	inner join [CDWWork].[Dim].[Division] as g on c.DivisionSID = g.DivisionSID
	left join [CDWWork].[SPatient].[SPatient] as h on a.PatientSID = h.PatientSID
	left join [OPCCCT_CIHEC].[COMP_FY20].[Dim_Telehealth] as i on d.LocationSID = i.LocationSID
where c.VisitDateTime between @StartDate and @EndDate
	and (e.StopCode is null or e.StopCode not in ('655','656','660','663','679'))
	and (f.StopCode is null or f.StopCode not in ('655','656','660','663','679'))
	and h.CDWPossibleTestPatientFlag != 'Y'
	and h.VeteranFlag = 'Y';


/***************************************************************
Step 6: Consolidate acupuncture visit-identification methods
***************************************************************/
drop table if exists #acu_visits;
with visit_list as (
	select distinct PatientSID, PatientICN, ScrSSN, Sta3n, VisitSID, VisitDate, tele from #cpt
	union
	select distinct PatientSID, PatientICN, ScrSSN, Sta3n, VisitSID, VisitDate, tele from #nt
	union
	select distinct PatientSID, PatientICN, ScrSSN, Sta3n, VisitSID, VisitDate, tele from #Loc_Name
	union
	select distinct PatientSID, PatientICN, ScrSSN, Sta3n, VisitSID, VisitDate, tele from #hf
	union
	select distinct PatientSID, PatientICN, ScrSSN, Sta3n, VisitSID, VisitDate, tele from #CHAR4
)
select distinct
	 A.PatientSID
	,A.PatientICN
	,A.ScrSSN
	,A.Sta3n
	,A.VisitSID
	,A.VisitDate
	,A.tele
	,case when B.VisitSID is not null then 1 else 0 end as CPT
	,case when C.VisitSID is not null then 1 else 0 end as NoteTitle
	,case when D.VisitSID is not null then 1 else 0 end as Clinic_Name
	,case when E.VisitSID is not null then 1 else 0 end as HealthFactor
	,case when F.VisitSID is not null then 1 else 0 end as CHAR4
	,case when C.NoteType = 'BFA' or B.CPTType = 'BFA' or D.LOCType = 'BFA' or E.HFType = 'BFA' or F.Char4Type = 'BFA' then 1 else 0 end as BFA
into #acu_visits
from visit_list as A
	left join #cpt as B on A.VisitSID = B.VisitSID
	left join #nt as C on A.VisitSID = C.VisitSID
	left join #Loc_Name as D on A.VisitSID = D.VisitSID
	left join #hf as E on A.VisitSID = E.VisitSID
	left join #CHAR4 as F on A.VisitSID = F.VisitSID;


/***************************************************************
Step 7: Official location-name-only exclusions
***************************************************************/
drop table if exists #loc_only_exclusions;
select distinct
	 a.ScrSSN
	,a.Sta3n
	,a.VisitDate
	,a.VisitSID
	,b.TIUDocumentSID
	,c.TIUDocumentDefinition
into #loc_only_exclusions
from #acu_visits as a
	inner join [CDWWork].[TIU].[TIUDocument] as b on b.VisitSID = a.VisitSID
	inner join [CDWWork].[Dim].[TIUDocumentDefinition] as c on b.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
where a.CPT = 0
	and a.NoteTitle = 0
	and a.CHAR4 = 0
	and a.HealthFactor = 0
	and a.Clinic_Name = 1
	and (c.TIUDocumentDefinition like '%failed%'
	or c.TIUDocumentDefinition like '%missed appointment%'
	or c.TIUDocumentDefinition like '%non-va%'
	or c.TIUDocumentDefinition like '%beneficiary travel%'
	or c.TIUDocumentDefinition like '%communication%'
	or c.TIUDocumentDefinition like '%discharge%'
	or c.TIUDocumentDefinition like '%education%'
	or c.TIUDocumentDefinition like '%error/erroneous%'
	or c.TIUDocumentDefinition like '%historical%'
	or c.TIUDocumentDefinition like '%notification%'
	or c.TIUDocumentDefinition like '%recall%'
	or c.TIUDocumentDefinition like '%refill%'
	or c.TIUDocumentDefinition like '%renewal%'
	or c.TIUDocumentDefinition like '%result%'
	or c.TIUDocumentDefinition like '%rxnote%'
	or c.TIUDocumentDefinition like '%scheduler%'
	or c.TIUDocumentDefinition like '%valuables%'
	or c.TIUDocumentDefinition like '%cancel/cancellation%'
	or c.TIUDocumentDefinition like '%no-show%'
	or c.TIUDocumentDefinition like '%admin%'
	or c.TIUDocumentDefinition like '%appt%'
	or c.TIUDocumentDefinition like '%clerical%'
	or c.TIUDocumentDefinition like '%contact%'
	or c.TIUDocumentDefinition like '%letter%'
	or c.TIUDocumentDefinition like '%prescription drug%'
	or c.TIUDocumentDefinition like '%reconciliation%'
	or c.TIUDocumentDefinition like '%scheduling%'
	or c.TIUDocumentDefinition like '%travel request%'
	or c.TIUDocumentDefinition like '%yoga%'
	or c.TIUDocumentDefinition like '%call%'
	or c.TIUDocumentDefinition like '%chart review%'
	or c.TIUDocumentDefinition like '%unknown%'
	or c.TIUDocumentDefinition like '%addendum%'
	or c.TIUDocumentDefinition like '%Nursing%'
	or c.TIUDocumentDefinition like '%QI GONG%'
	or c.TIUDocumentDefinition like '%Neurology%'
	or c.TIUDocumentDefinition like '%Rehab%'
	or c.TIUDocumentDefinition like '%Specialty%'
	or c.TIUDocumentDefinition like '%Physiatry%'
	or c.TIUDocumentDefinition like '%Primary care%'
	or c.TIUDocumentDefinition like '%Mental health%'
	or c.TIUDocumentDefinition like '%Promotion%'
	or c.TIUDocumentDefinition like '%Clerk%'
	or c.TIUDocumentDefinition like '%External%'
	or c.TIUDocumentDefinition like '%Admission%'
	or c.TIUDocumentDefinition like '%psychology%'
	or c.TIUDocumentDefinition like '%Surgery%'
	or c.TIUDocumentDefinition like '%Medication%'
	or c.TIUDocumentDefinition like '%non-visit%'
	or c.TIUDocumentDefinition like '%Physician assistant%'
	or c.TIUDocumentDefinition like '%opioid%'
	or c.TIUDocumentDefinition like '%anticoagulation%'
	or c.TIUDocumentDefinition like '%rheuma%'
	or c.TIUDocumentDefinition like '%coaching%'
	or c.TIUDocumentDefinition like '%suicide%'
	or c.TIUDocumentDefinition like '%orthopedics%'
	or c.TIUDocumentDefinition like '%cardiology%'
	or c.TIUDocumentDefinition like '%social work%'
	or c.TIUDocumentDefinition like '%urology%'
	or c.TIUDocumentDefinition like '%oncology%'
	or c.TIUDocumentDefinition like '%immunization%'
	or c.TIUDocumentDefinition like '%Reminder%'
	or c.TIUDocumentDefinition like '%anesthisiology%'
	or c.TIUDocumentDefinition like '%advance directive%'
	or c.TIUDocumentDefinition like '%study%'
	or c.TIUDocumentDefinition like '%zznonvacare%'
	or c.TIUDocumentDefinition like '%ref%'
	or c.TIUDocumentDefinition like '%test%'
	or c.TIUDocumentDefinition like '%phone%'
	or c.TIUDocumentDefinition like '%non va care%'
	or c.TIUDocumentDefinition like '%chior%'
	or c.TIUDocumentDefinition like '%vcp%'
	or c.TIUDocumentDefinition like '%outside%'
	or c.TIUDocumentDefinition like '%plan%'
	or c.TIUDocumentDefinition like '%acupressure%'
	or c.TIUDocumentDefinition like '%vcl%'
	or c.TIUDocumentDefinition like '%follow%'
	or c.TIUDocumentDefinition like '%no-show%'
	or c.TIUDocumentDefinition like '%messaging%'
	or c.TIUDocumentDefinition like '%e-consult%'
	or c.TIUDocumentDefinition like '%econsult%'
	or c.TIUDocumentDefinition like '%consult%'
	or c.TIUDocumentDefinition like '%e consult%'
	or c.TIUDocumentDefinition like '%referral %'
	or c.TIUDocumentDefinition like '%research%'
	or c.TIUDocumentDefinition like '%rsch%'
	or c.TIUDocumentDefinition like '%community%'
	or c.TIUDocumentDefinition like '%com tx%'
	or c.TIUDocumentDefinition like '%comm care %'
	or c.TIUDocumentDefinition like '%com care%'
	or c.TIUDocumentDefinition like '%choice%');


/***************************************************************
Step 8: Final acupuncture visit and patient-day tables
***************************************************************/
drop table if exists #acu_visits_consolidated;
select *
into #acu_visits_consolidated
from #acu_visits
where VisitSID not in (select distinct VisitSID from #loc_only_exclusions);

drop table if exists #acu_visits_final;
select
	 a.ScrSSN
	,a.Sta3n
	,a.VisitDate
	,case when min(a.tele) = 0 then 1 else 0 end as in_person
	,case when max(a.tele) = 1 then 1 else 0 end as any_tele
	,max(a.CPT) as any_CPT
	,max(a.NoteTitle) as any_note_title
	,max(a.Clinic_Name) as any_loc_name
	,max(a.HealthFactor) as any_health_factor
	,max(a.CHAR4) as any_CHAR4
	,case when max(a.BFA) = 1 then 'BFA' else 'Traditional' end as acu_type
into #acu_visits_final
from #acu_visits_consolidated as a
group by a.ScrSSN, a.Sta3n, a.VisitDate;

drop table if exists #acu_patient_list;
select distinct
	 PatientSID
into #acu_patient_list
from #acu_visits_consolidated;


/***************************************************************
Patient information - filter to those who have had at least
1 acupuncture visit; also get the associated Veteran status.
***************************************************************/
drop table if exists #acu_patient_info;
select distinct
	 p.PatientSID
	,p.PatientICN
	,p.TestPatientFlag
	,p.VeteranFlag as PatientVeteranFlag
	,p.Age
	,p.DeathDateTime
	,p.Gender
	,p.IneligibleReason
	,p.PreferredInstitutionSID
	,p.InsuranceCoverageFlag
	,p.MedicaidEligibleFlag
	,p.MaritalStatus
	,pr.Race
	,addr.Zip as PatientZip
	,addr.County as PatientCounty
	,addr.State as PatientState
	,addr.GISFIPSCode as PatientGISFIPSCode
	,addr.GISMarket as PatientGISMarket
	,addr.GISSubmarket as PatientGISSubmarket
	,addr.GISSector as PatientGISSector
	,addr.GISURH as PatientGISURH
	,addr.AddressStartDateTime as PatientAddressStartDateTime
	,addr.AddressEndDateTime as PatientAddressEndDateTime
	,vet.VeteranFlag as ADRVeteranFlag
	,eh.EnrollStartDate
	,eh.EnrollEndDate
	--,eh.RecordCreateDate as EnrollmentRecordCreateDate -- Uncomment only if present in the local CDW view.
	,eh.RecordModifiedDate as EnrollmentRecordModifiedDate
into #acu_patient_info
from [CDWWork].[Patient].[Patient] as p
	left join [CDWWork].[PatSub].[PatientRace] as pr on p.PatientSID = pr.PatientSID
	left join [CDWWork].[SPatient].[SPatientAddress] as addr on p.PatientSID = addr.PatientSID
	left join [CDWWork].[Veteran].[ADRPerson] as vet on vet.ADRPersonICN = p.PatientICN
	left join [CDWWork].[ADR].[ADREnrollHistory] as eh on vet.ADRPersonSID = eh.ADRPersonSID
	inner join #acu_patient_list as acu on p.PatientSID = acu.PatientSID
where (p.TestPatientFlag is null or p.TestPatientFlag != 'Y')
	and p.VeteranFlag = 'Y';


/***************************************************************
Outpatient diagnosis information for patients that have received
acupuncture.
***************************************************************/
drop table if exists #acu_outpatient_diagnoses;
select distinct
	 od.PatientSID
	,od.VisitSID
	,od.ProblemListSID
	,od.EventDateTime
	,od.Sta3n
	,od.ICD10SID
	,icd.ICD10Code
	,od.PrimarySecondary
	,icd.DRGIdentifier
	,pl.ClinicalTermSID
	,pl.OnsetDateTime
	,pl.ResolvedDateTime
	,pl.ServiceConnectedFlag
	,pl.ProblemListClass
	,pl.ActiveFlag
	,ct.ClinicalTerm
	,ct.ClinicalTermScope
into #acu_outpatient_diagnoses
from [CDWWork].[Outpat].[VDiagnosis] as od
	left join [CDWWork].[Dim].[ICD10] as icd on od.ICD10SID = icd.ICD10SID
	left join [CDWWork].[Outpat].[ProblemList] as pl on od.PatientSID = pl.PatientSID
		and od.ProblemListSID = pl.ProblemListSID
		and od.ICD10SID = pl.ICD10SID
	left join [CDWWork].[Dim].[ClinicalTerm] as ct on pl.ClinicalTermSID = ct.ClinicalTermSID
	inner join #acu_patient_list as acu on od.PatientSID = acu.PatientSID
where od.EventDateTime between @StartDate and @EndDate;


/***************************************************************
Inpatient diagnosis information for patients who have received
acupuncture.
***************************************************************/
drop table if exists #acu_inpatient_diagnoses;
select distinct
	 id.PatientSID
	,id.ICD10SID
	,id.OrdinalNumber
	,id.DischargeDateTime
	,icd.ICD10Code
	,icd.DRGIdentifier
into #acu_inpatient_diagnoses
from [CDWWork].[Inpat].[InpatientDiagnosis] as id
	left join [CDWWork].[Dim].[ICD10] as icd on id.ICD10SID = icd.ICD10SID
	inner join #acu_patient_list as acu on id.PatientSID = acu.PatientSID
where id.DischargeDateTime between @StartDate and @EndDate;


/***************************************************************
Vital signs / pain-score data.
***************************************************************/
drop table if exists #acu_vital_signs;
select distinct
	 vs.PatientSID
	,vs.LocationSID
	,vs.VitalTypeSID
	,vs.VitalSignTakenDateTime
	,vs.VitalResult
	,vs.VitalResultNumeric
	,vt.VitalType
into #acu_vital_signs
from [CDWWork].[Vital].[VitalSign] as vs
	left join [CDWWork].[Dim].[VitalType] as vt on vs.VitalTypeSID = vt.VitalTypeSID
	inner join #acu_patient_list as acu on vs.PatientSID = acu.PatientSID
where (vs.EnteredInErrorFlag is null or vs.EnteredInErrorFlag != 'Y')
	and vs.VitalSignTakenDateTime between @StartDate and @EndDate;


/***************************************************************
Validation previews
***************************************************************/
select Top(100) *
from #acu_visits_final
order by ScrSSN, Sta3n, VisitDate;

select Top(100) *
from #acu_patient_info
order by PatientSID;

select 'acu_visits_final' as TableName, count(*) as RecordCount from #acu_visits_final
union all
select 'acu_patient_list' as TableName, count(*) as RecordCount from #acu_patient_list
union all
select 'acu_patient_info' as TableName, count(*) as RecordCount from #acu_patient_info
union all
select 'acu_outpatient_diagnoses' as TableName, count(*) as RecordCount from #acu_outpatient_diagnoses
union all
select 'acu_inpatient_diagnoses' as TableName, count(*) as RecordCount from #acu_inpatient_diagnoses
union all
select 'acu_vital_signs' as TableName, count(*) as RecordCount from #acu_vital_signs;
