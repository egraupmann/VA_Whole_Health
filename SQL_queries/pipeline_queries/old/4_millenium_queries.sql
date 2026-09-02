/********************************************
This table is the millennium diagnosis queries
********************************************/
drop table if exists opccct_cih.dflt.mill_acu_user_dianoses
SELECT patienticn
      ,[EncounterSID]
      ,[PersonSID]
      ,[OrganizationNameSID]
      ,[EncounterDiagnosisSID]
      ,[EncounterType]
      ,[EncounterTypeCD]
      ,[CodeID] as ICD10Code
      ,[CodeDescription]
      ,[DiagnosisDateTime]
      ,[DiagnosisPriority]
      ,[DiagnosisDisplay]
into opccct_cih.dflt.mill_acu_user_dianoses
  FROM [CDWWork2].[Mill].[PatientDiagnosisAll] as p
    	INNER JOIN (select distinct patientsid,visitsid,PatientICN
				from OPCCCT_CIH.dflt.acupuncture_VA_encounters
				where VisitDateTime >= '2021-10-01') AS ACU
		ON P.PersonSID = ACU.PatientSID 
            and CONCAT(FORMAT(p.diagnosisdatetime, 'yyMMdd'), CAST(p.encounterSID AS VARCHAR(20))) = CAST(acu.visitSID AS VARCHAR(20))
  where DiagnosisDateTime >= '2020-10-01';

  -- example visitSID in Irad's data      2104131800001157497
  -- example encounterSID in the diagnosis data 1800000217826
  -- he's adding the date in the form of YYMMDD to the front of the encounterSID. I think this is 
  -- because he's avoiding the possibility of a millenium and VISTA visitSID/encounterSID accidental overlap
/******************************************
this table has the patient demographics
*******************************************/
drop table if exists opccct_cih.dflt.mill_acu_user_patient_list
select acu.patienticn
      ,[PersonSID] as PatientSID
      ,[Age]
      ,BirthDateTime
      ,[DeceasedDateTime] as DeathDateTime
      ,[Sex] as gender
      ,[Race]
      ,[MaritalType] as MaritalStatus
into opccct_cih.dflt.mill_acu_user_patient_list
  FROM [CDWWork2].[SVeteranMill].[SPerson] as p
    INNER JOIN (select distinct patientsid, PatientICN
				from OPCCCT_CIH.dflt.acupuncture_VA_encounters
				where VisitDateTime >= '2021-10-01') AS ACU
		ON P.PersonSID = ACU.PatientSID 
where [CDWPossibleTestPatientFlag]='N'
