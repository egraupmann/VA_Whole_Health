/***************************************************************
To Do: OK, I think I initially want to set up the exact query
we want for the current users. To do that, I need to get some
extra transforms but primarily all of the filters that were 
provided in the compendium code. I may be able to achieve most 
of this using the code below. I want the records at a patient
level, ideally.
***************************************************************/

/***************************************************************
These 1st tables get the visits that were acupuncture. Based
on the compendium logic, we need to consider Stop Codes,
CHAR4, CPT codes, location name, health factors, 
and document names to get the complete representation
***************************************************************/

/***************************************************************
Location information - filtered to facilities that provide
acupuncture services
***************************************************************/
select distinct
	 inst.InstitutionSID
	,inst.LocationSID
	,inst.InstitutionName
	,inst.Sta3n
	,inst.Zip
	,inst.MedicalDistrict
	,inst.LocationName
	,inst.LocationAbbreviation
	,inst.LocationType
	,inst.MedicalService
	,dssl.DSSLocationStopCodeSID
	,dssl.PrimaryStopCode
	,dssl.SecondaryStopCode
	,dst.NationalChar4
	,dst.NationalChar4Description
	,psc.StopCode as PrimaryStopCode
	,psc.StopCodeName as PrimaryStopCodeName
	,ssc.StopCode as SecondaryStopCode
	,ssc.StopCodeName as SecondaryStopCodeName
	,case when dst.NationalChar4 in ('acup') then 1 
		  else 0 
		  end as acu_trad_CHAR4
	,case when dst.NationalChar4 in ('IACT') then 1 
		  else 0 
		  end as acu_btf_CHAR4
	,case when inst.LocationName like '%acup%' or inst.LocationName like '%acpu%' then 'trad'
		  when inst.LocationName LIKE '%battlefield%' or inst.LocationName LIKE '%bfa%' 
				or inst.LocationName like '%BTL ACP%' or inst.LocationName like '%BF acup%'
				or inst.LocationName like '%battlefld%' or inst.LocationName like '%/battlefield%' then 'bfa'
		  else 'unknown'
		  end as acu_loc_type

into #acu_facility_info
from CDWWork.Dim.Institution as inst
	inner join CDWWork.Dim.DSSLocation as dssl on inst.LocationSID = dssl.LocationSID
	inner join CDWWork.Dim.DSSLocationStopCode as dst on dssl.DSSLocationStopCodeSID = dst.DSSLocationStopCodeSID
	inner join CDWWork.Dim.StopCode as psc on dssl.PrimaryStopCodeSID = psc.StopCodeSID
	inner join CDWWORK.Outpat.Visit as v on inst.LocationSID = v.LocationSID
	left join CDWWork.Dim.StopCode as ssc on dssl.SecondaryStopCodeSID = ssc.StopCodeSID
where (v.VisitDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999'))
	and (psc.StopCode not in ('655','656','660','663','679') and ssc.StopCode not in ('655','656','660','663','679'))
	and ((dst.NationalChar4 in ('acup','IACT'))
	or	((inst.LocationName like '%acup%' or inst.LocationName like '%acpu%' or inst.LocationName LIKE '%battlefield%' or inst.LocationName LIKE '%bfa%' 
		or inst.LocationName like '%BTL ACP%' or inst.LocationName like '%BF acup%'
		or inst.LocationName like '%battlefld%' or inst.LocationName like '%/battlefield%')
		/* loc specific exclusion strings*/ 
		and (inst.LocationName not like '%study%' and inst.LocationName not like '%zznonvacare%' and inst.LocationName not like '%test%' 
		and inst.LocationName not like '%ref%' and inst.LocationName not like '%chiro%' 
		--and inst.LocationName not like '%phone%'
		/* apply generic exclusion strings*/ 
		and inst.LocationName not like '%non va care%' and inst.LocationName not like '%vcp%' and inst.LocationName not like '%outside%' 
		and inst.LocationName not like '%plan%' and inst.LocationName not like '%acupressure%' and inst.LocationName not like '%vcl%'
		and inst.LocationName not like '%follow%'  
		--inst.LocationName not like '%telephone%' 
		and inst.LocationName not like '%no show%'
		and inst.LocationName not like '%messaging%' and inst.LocationName not like '%econsult%' and inst.LocationName not like '%e consult%'
		and inst.LocationName not like '%e-consult%' and inst.LocationName NOT LIKE '%referral%' and inst.LocationName NOT LIKE '%consult%' 
		and inst.LocationName not like '%research%' and inst.LocationName not like '%rsch%' and inst.LocationName not like '%community%' 
		and inst.LocationName not like '%com tx%' and inst.LocationName not like '%comm care%' and inst.LocationName not like '%com care%'
		and inst.LocationName not like '%choice%'
		/*Added by LA Team*/
		and inst.LocationName not like '%labfasting%'
		and inst.LocationName not like '%secm%'
		and inst.LocationName not like '%tele%'
		and inst.LocationName not like '%bacup a%')));

/***************************************************************
Outpatient visit information - filtered to acupuncture visits
***************************************************************/
select distinct
	 v.PatientSID
	,v.VisitSID
	,v.VisitDateTime, convert(date, v.VisitDateTime) as VisitDate
	,v.InstitutionSID
	,v.LocationSID
	,v.PrimaryStopCodeSID
	,v.SecondaryStopCodeSID
	,v.ServiceCategory
	,v.EncounterType
	,v.PatientVeteranFlag
	,hft.HealthFactorType
	,hft.HealthFactorCategory
	,hf.LevelSeverity as HealthFactorLevelSeverity
	,hf.Magnitude as HealthFactorMagnitude
	,hf.HealthFactorTypeSID
	,hf.UCUMCodeSID
	,uccode.DescriptionOfTheUnit as HealthFactorDescriptionOfUnit
	,uccode.Comment as HealthFactorComment
	,psc.StopCode as PrimaryStopCode
	,psc.StopCodeName as PrimaryStopCodeName
	,ssc.StopCode as SecondaryStopCode
	,ssc.StopCodeName as SecondaryStopCodeName
	,case when hft.HealthFactorType like '%acup%' or hft.HealthFactorType like '%acpu%' then 'trad'
		  when hft.HealthFactorType '%bfa%'or hft.HealthFactorType like '%battlefield%' then 'bfa'
		  else 'unknown'
		  end as hf_acu_type
into #acu_outpatient_visits
from CDWWork.Outpat.Visit as v
	inner join CDWWork.Dim.StopCode as psc on v.PrimaryStopCodeSID = psc.StopCodeSID
	left join CDWWork.Dim.StopCode as ssc on v.SecondaryStopCodeSID = ssc.StopCodeSID
	left join CDWWork.HF.HealthFactor as hf on v.PatientSID = hf.PatientSID
										    and v.VisitSID = hf.VisitSID
	left join CDWWork.Dim.HealthFactorType as hft on hf.HealthFactorTypeSID = hft.HealthFactorTypeSID
	left join CDWWork.Dim.UCUMCode as uccode on hf.UCUMCodeSID = uccode.UCUMCodeSID
where 
	(hft.HealthFactorType is null or hft.HealthFactorType like '%acup%' or hft.HealthFactorType like '%acpu%' or  hft.HealthFactorType '%bfa%'or hft.HealthFactorType like '%battlefield%')
	/* apply generic exclusion strings to HealthFactors*/
	and hft.HealthFactorType not like '%research%' 
	and hft.HealthFactorType not like '%rsch%' and hft.HealthFactorType not like '%referral' and hft.HealthFactorType not like '%non va%' 
	and hft.HealthFactorType not like '%vcp%' and hft.HealthFactorType not like '%outside%' and hft.HealthFactorType not like '%plan%' 
	and hft.HealthFactorType not like '%acupressure%' and hft.HealthFactorType not like '%follow%' and hft.HealthFactorType not like '%consult%'
	and hft.HealthFactorType not like '%no show%' and hft.HealthFactorType not like '%messaging%'
	and hft.HealthFactorType not like '%econsult%' and hft.HealthFactorType not like '%e consult%' and hft.HealthFactorType not like '%e-consult%'
	and hft.HealthFactorType not like '%ref%' and hft.HealthFactorType not like '%test%' and hft.HealthFactorType not like '%TCMLH%' 
	and hft.HealthFactorType not like '%vcl%' and hft.HealthFactorType not like '%yoga%' and hft.HealthFactorType not like '%community%'
	and hft.HealthFactorType not like '%com tx%' and hft.HealthFactorType not like '%comm care%' and hft.HealthFactorType not like '%com care%'
	and hft.HealthFactorType not like '%choice%' and hft.HealthFactorType not like '%cc%'
	and hft.HealthFactorType not like '%fager%'
	and hft.HealthFactorType not like '%f/u%'
	and v.PatientVeteranFlag = 'Y'
	and (v.VisitDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999'))
	and (psc.StopCode is null or psc.StopCode not in ('655','656','660','663','679')) and (ssc.StopCode is null or ssc.StopCode not in ('655','656','660','663','679')) 
	);

/***************************************************************
Outpatient procedure information - with filters
***************************************************************/
select distinct
	 op.PatientSID
	,op.CPTSID
	,op.VisitSID
	,op.Quantity
	,op.VisitDateTime, convert(date, op.VisitDateTime) as VisitDate
	,op.EventDateTime
	,cpt.CPTCode
	,cpt.CPTName
	,cpt.CPTDescription
into #acu_outpatient_procedures
from CDWWork.Outpat.VProcedure as op
	inner join CDWWork.Dim.CPT as cpt on op.CPTSID = cpt.CPTSID
where (op.EventDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999')) 
	and cpt.cptcode in ('97810','97811','97813','97814');


/***************************************************************
Document info table - needed to help identify extra possible
						acupuncture visits
***************************************************************/
select distinct 
	 d.TIUDocumentDefinitionSID
	,d.PatientSID
	,d.VisitSID
	,dd.TIUDocumentDefinition
	,case when dd.TIUDocumentDefinition like '%acup%' or dd.TIUDocumentDefinition like '%acpu%' then 'trad'
		  when dd.TIUDocumentDefinition like '%battlefield%' or dd.TIUDocumentDefinition like '%bfa%' then 'bfa'
		  end as NoteType
into #acu_doc_name
from cdwwork.TIU.TIUDocument as d
	inner join cdwwork.dim.TIUDocumentDefinition as dd on d.TIUDocumentDefinitionSID = dd.TIUDocumentDefinitionSID
where
	(dd.TIUDocumentDefinition like '%acup%' or dd.TIUDocumentDefinition like '%acpu%' or dd.TIUDocumentDefinition like '%battlefield%' 
		or dd.TIUDocumentDefinition like '%bfa%')
	and dd.TIUDocumentDefinition not like '%acupressure%' and  dd.TIUDocumentDefinition not like '%phone%'  and dd.TIUDocumentDefinition not like '%chiro%' 
	and dd.TIUDocumentDefinition not like '%cc%'
	/* apply generic exclusion strings*/ 
	and dd.TIUDocumentDefinition not like '%non va%' and dd.TIUDocumentDefinition not like '%vcl%' and dd.TIUDocumentDefinition not like '%vcp%'
	and dd.TIUDocumentDefinition not like '%outside%' and dd.TIUDocumentDefinition not like '%plan%' and dd.TIUDocumentDefinition not like '%follow%'
	and dd.TIUDocumentDefinition not like '%no show%' and dd.TIUDocumentDefinition not like '%messaging%' and dd.TIUDocumentDefinition not like '%econsult%'
	and dd.TIUDocumentDefinition not like '%e consult%' and dd.TIUDocumentDefinition not like '%e-consult%' and dd.TIUDocumentDefinition not like '%referral%'  
	and dd.TIUDocumentDefinition not like '%research%' and dd.TIUDocumentDefinition not like '%rsch%' and dd.TIUDocumentDefinition not like '%consult%'
	and dd.TIUDocumentDefinition not like '%community%' 
	and dd.TIUDocumentDefinition not like '%com tx%' and dd.TIUDocumentDefinition not like '%comm care%' and dd.TIUDocumentDefinition not like '%com care%'
	and dd.TIUDocumentDefinition not like '%choice%'
	and dd.TIUDocumentDefinition not like '%appointment request%'
	and dd.TIUDocumentDefinition not like '%instructions%'
	and dd.TIUDocumentDefinition not like '%non-va%'
	and dd.TIUDocumentDefinition not like '%consent%'
	and dd.TIUDocumentDefinition not like '%reply%'
	and dd.TIUDocumentDefinition not like '%outcome%'
	and dd.TIUDocumentDefinition not like '%test%');

/***************************************************************
From the compendium code to get the notes table into an easier
to use format 
***************************************************************/
select distinct
	 a.PatientSID 
	,a.VisitSID
	,b.NoteType
	,c.VisitDateTime, convert(date, c.VisitDateTime) as VisitDate
	,b.TIUDocumentDefinition 
	,d.LocationSID
into #acu_docs
from cdwwork.TIU.TIUDocument as a
	inner join #acu_doc_name b on (a.TIUDocumentDefinitionSID = b.TIUDocumentDefinitionSID)
	inner join cdwwork.Outpat.visit as c on a.VisitSID=c.VisitSID 
	inner join cdwwork.dim.Location as d on c.LocationSID=d.LocationSID
	inner join cdwwork.dim.StopCode as e on c.PrimaryStopCodeSID=e.StopCodeSID
	left join cdwwork.dim.StopCode as f on c.SecondaryStopCodeSID=f.StopCodeSID
	inner join cdwwork.dim.Division as g on c.DivisionSID = g.DivisionSID 
	inner join cdwwork.SPatient.SPatient as h on a.PatientSID = h.PatientSID
where (c.VisitDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999'))
	and (e.StopCode is null or e.Stopcode not in ('655','656','660','663','679')) and (f.StopCode is null or f.StopCode not in ('655','656','660','663','679')) 
	and h.CDWPossibleTestPatientFlag != 'Y' and h.VeteranFlag = 'Y';

/***************************************************************
From the compendium code to get the location name table into 
an easier to use format 
***************************************************************/
select 
	 a.PatientSID 
	,a.sta3n 
	,a.locationsid
	,c.Sta6a
	,a.VisitSID
	,b.NationalChar4
	,b.acu_loc_type
	,b.acu_trad_CHAR4
	,b.acu_btf_CHAR4
	,a.VisitDateTime,convert(date, a.VisitDateTime) as VisitDate
	,case when b.acu_trad_CHAR4=1 or b.acu_btf_CHAR4=1 then 0
		  else 1 
		  end as loc_name_only

into #loc_details
from [cdwwork].[outpat].[Visit] as a 
	inner join #acu_facility_info as b on a.LocationSID=b.LocationSID 
	inner join [cdwwork].[dim].[division] as c on a.DivisionSID=c.DivisionSID
	left join [cdwwork].[SPatient].[SPatient] as d on a.PatientSID=d.PatientSID  
where (a.VisitDateTime between convert(datetime2(0),'2019-10-01 00:00:00.000') and convert(datetime2(0),'2020-09-30 23:59:59.999'))
	and (b.PrimaryStopCode is null or b.PrimaryStopcode not in ('655','656','660','663','679')) and (b.SecondaryStopCode is null or b.SecondaryStopCode not in ('655','656','660','663','679')) 
	and d.CDWPossibleTestPatientFlag != 'Y' and d.VeteranFlag = 'Y';

select *
into #name_only
from #loc_details
where loc_name_only=1;

select *
into #CHAR4
from #loc_details
where loc_name_only=0;

/***************************************************************
Compile acupuncture visit sources
***************************************************************/
with visit_list as (
	select distinct PatientSid, VisitSID, VisitDate from #acu_docs
	union
	select distinct PatientSid, VisitSID, VisitDate from #acu_outpatient_procedures
	union
	select distinct PatientSid, VisitSID, VisitDate from #acu_outpatient_visits
	union
	select distinct PatientSid, VisitSID, VisitDate  from #name_only
	union
	select distinct PatientSid, VisitSID, VisitDate  from #CHAR4
	)
/*determine which visits qualify as an acupuncture visit, remove the visits that are location name only*/
select distinct A.PatientSid
	, A.VisitSID
	, A.VisitDate
	, case when B.VisitSID is not null then 1 else 0 end as 'CPT'
	, case when C.VisitSID is not null then 1 else 0 end as 'NoteTitle'
	, case when D.VisitSID is not null then 1 else 0 end as 'HealthFactor'
	, case when E.VisitSID is not null then 1 else 0 end as 'LocationName'
	, case when F.VisitSID is not null then 1 else 0 end as 'CHAR4'
	, case when c.NoteType = 'bfa' or e.acu_loc_type = 'bfa' or f.acu_btf_CHAR4 = 'bfa' or d.hf_acu_type='bfa' Then 1 Else 0 end as 'BFA'
into #acu_visits
from visit_list A
	left join #acu_outpatient_procedures as B on A.VisitSID = B.VisitSID
	left join #acu_docs	as C on A.VisitSID = C.VisitSID
	left join #acu_outpatient_visits as D on A.VisitSID = D.VisitSID
	left join #name_only as E on A.VisitSID = E.VisitSID
	left join #CHAR4 as F on A.VisitSID = F.VisitSID;

/***************************************************************
This filter also comes from the compendium logic. It identifies
the visit records to exclude that are location name only
***************************************************************/
select distinct 
        a.ScrSSN,
		a.sta3n,
		a.VisitDate,
		a.VisitSID,
		b.TIUDocumentSID,
		c.TIUDocumentDefinition
into #loc_only_exclusions
from #acu_visits as  a
	inner join cdwwork.TIU.TIUDocument as b on b.visitsid = a.visitsid          
	inner join cdwwork.dim.TIUDocumentDefinition as c  on b.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
where CPT = 0 and NoteTitle = 0 and CHAR4 = 0 and HealthFactor = 0 and LocationName = 1 
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

/*get the final visit list table*/
select * 
into #acu_visits_consolidated 
from #acu_visits
where VisitSID not in (select distinct(VisitSID) from #loc_only_exclusions);

/******   reduce to patient-day table   ******/
select 
	 a.PatientSID
	,a.VisitDate
	,a.VisitSID
	, max(a.CPT) as any_CPT
	, max(a.NoteTitle) as any_note_title
	, max(a.LocationName) as any_loc_name
	, max(a.HealthFactor) as any_health_factor
	, max(a.CHAR4) as any_CHAR4
	, case when max(a.BFA) = 1 then 'BFA' else 'Traditional' end as acu_type
into #acu_visits_final
from #acu_visits_consolidated as a
group by a.PatientSID, a.VisitDate;

/*and a distinct patient list*/
select distinct
	PatientSid
into #acu_patient_list
from #acu_visits_final;
/***************************************************************
Patient information - filter to those who have had at least 
					  1 acupuncture visit
also get the associated veteran status
***************************************************************/
select distinct
	 p.PatientSID
	,p.PatientICN
	,p.TestPatientFlag
	,p.VeteranFlag
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
	 ,vet.VeteranFlag
	 ,eh.EnrollStartDate
	 ,eh.EnrollEndDate
	 ,eh.RecordCreateDate
	 ,eh.RecordModifiedDate
into #acu_patient_info
from CDWWork.Patient.Patient as p
	left join CDWWork.PatSub.PatientRace as pr on p.PatientSID = pr.PatientSID
	left join CDWWork.SPatient.SPatientAddress as addr on p.PatientSID = addr.PatientSID
	inner join DWWork.Veteran.ADRPerson as vet on vet.ADRPersonICN = p.PatientICN
	left join CDWWork.ADR.ADREnrollHistory as eh on vet.ADRPersonSID = eh.ADRPersonSID
	inner join #acu_patient_list as acu on p.PatientSID = acu.PatientSID
where (p.TestPatientFlag is null or p.TestPatientFlag != 'Y')
	and p.VeteranFlag = 'Y';

/***************************************************************
Outpatient diagnosis information for patients that have received
	acupuncture
***************************************************************/
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
from CDWWork.Outpat.VDiagnosis as od
	inner join CDWWork.Dim.ICD10 as icd on od.ICD10SID = icd.ICD10SID
	inner join CDWWork.Outpat.ProblemList as pl on od.PatientSID = pl.PatientSID
		and od.ProblemListSID = pl.ProblemListSID
		and od.ICD10SID = pl.ICD10SID
	inner join CDWWork.Dim.ClinicalTerm as ct on pl.ClinicalTermSID = ct.ClinicalTermSID
	inner join #acu_patient_list as acu on od.PatientSID=acu.PatientSID
where (od.EventDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999'));

/***************************************************************
Inpatient diagnosis information for patients who have received
	acupuncture
***************************************************************/
select distinct
	 id.PatientSID
	,id.ICD10SID
	,id.OrdinalNumber 
	,id.DischargeDateTime
	,icd.ICD10Code
	,icd.DRGIdentifier
into #acu_inpatient_diagnoses
from CDWWork.Inpat.InpatientDiagnosis as id
	inner join CDWWork.Dim.ICD10 as icd on id.ICD10SID = icd.ICD10SID
	inner join #acu_patient_list as acu on id.PatientSID=acu.PatientSID
where (id.DischargeDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999'));

/***************************************************************
Vital signs / pain-score data
***************************************************************/
select distinct
	 vs.PatientSID
	,vs.locationSID
	,vs.VitalTypeSID
	,vs.VitalSignTakenDateTime
	,vs.VitalResult
	,vs.VitalResultNumeric
	,vt.VitalType
into #acu_vital_signs
from CDWWork.Vital.VitalSign as vs
	inner join CDWWork.Dim.VitalType as vt on vs.VitalTypeSID = vt.VitalTypeSID
	inner join #acu_patient_list as acu on vs.PatientSID=acu.PatientSID
where vs.EnteredInErrorFlag is NULL OR vs.EnteredInErrorFlag != 'Y'
	and (vs.VitalSignTakenDateTime between convert(datetime2(0),'2022-10-01 00:00:00.000') and convert(datetime2(0),'2025-09-30 23:59:59.999'));
	