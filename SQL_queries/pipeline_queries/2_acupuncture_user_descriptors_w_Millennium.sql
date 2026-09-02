/**********************************************************************
[CDWWork2].[Mill].[PatientEncounterAll] seems like maybe the most promising lead
for getting mental health and vital signs. I think getting the community care info
figured out is more important right now though
******************************************************************************/


/***************************************************************
get patient demographic data
***************************************************************/
/**************1st VISTA**************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.VISTA_acupuncture_patient_list;
SELECT DISTINCT
	 P.PatientSID
	,P.PatientICN
	,P.Age
	,sp.birthdatetime
	,P.DeathDateTime
	,P.Gender
	,P.MaritalStatus
	,pr.race
INTO OPCCCT_CIH.dflt.VISTA_acupuncture_patient_list
FROM CDWWork.Patient.Patient AS P
	INNER JOIN cdwwork.spatient.spatient AS sp
		ON P.PatientSID = sp.PatientSID
	INNER JOIN (SELECT DISTINCT patienticn, patientsid
				FROM OPCCCT_CIH.dflt.ALL_ACUP_VA_encounters
				WHERE VisitDateTime >= '2021-10-01') AS ACU
		ON P.PatientSID = ACU.PatientSID AND p.PatientICN = ACU.PatientICN
	INNER JOIN CDWWork.Veteran.ADRPerson AS VET
		ON VET.ADRPersonICN = P.PatientICN
	LEFT JOIN CDWWork.PatSub.PatientRace AS PR
		ON P.PatientSID = PR.PatientSID
WHERE (P.TestPatientFlag IS NULL OR P.TestPatientFlag <> 'Y')
	AND P.VeteranFlag = 'Y' AND VET.VeteranFlag = 'Y';

CREATE INDEX IX_acu_patientsid ON OPCCCT_CIH.dflt.VISTA_acupuncture_patient_list (PatientSID);

/********************************Now Millennium*****************************/
drop table if exists opccct_cih.dflt.MILL_acupuncture_patient_list
select acu.patienticn
      ,[PersonSID] as PatientSID
      ,[Age]
      ,BirthDateTime
      ,[DeceasedDateTime] as DeathDateTime
      ,[Sex] as gender
      ,[Race]
      ,[MaritalType] as MaritalStatus
into opccct_cih.dflt.MILL_acupuncture_patient_list
  FROM [CDWWork2].[SVeteranMill].[SPerson] as p
    INNER JOIN (select distinct patientsid, PatientICN
				from OPCCCT_CIH.dflt.ALL_ACUP_VA_encounters
				where VisitDateTime >= '2021-10-01') AS ACU
		ON P.PersonSID = ACU.PatientSID 
where [CDWPossibleTestPatientFlag]='N'

CREATE INDEX IX_acu_patientsid ON OPCCCT_CIH.dflt.MILL_acupuncture_patient_list (PatientSID);


/***********************************Now Combine patient lists*****************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_acupuncture_patient_list;

SELECT
	 PatientICN
	,PatientSID
	,Age
	,birthdatetime AS BirthDateTime
	,DeathDateTime
	,Gender
	,MaritalStatus
	,race AS Race
	,'VISTA' AS SourceSystem
INTO OPCCCT_CIH.dflt.COMBINED_acupuncture_patient_list
FROM OPCCCT_CIH.dflt.acupuncture_patient_list

UNION ALL

SELECT
	 PatientICN
	,PatientSID
	,Age
	,BirthDateTime
	,DeathDateTime
	,gender AS Gender
	,MaritalStatus
	,Race
	,'Millennium' AS SourceSystem
FROM OPCCCT_CIH.dflt.MILL_acupuncture_patient_list;

CREATE INDEX IX_acu_patient_combined_patienticn
	ON OPCCCT_CIH.dflt.COMBINED_acupuncture_patient_list (PatientICN);


/******************************************************************************
STEP 1: Outpatient diagnoses (visit-only: join encounters via VisitSID)
******************************************************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.acupuncture_outpatient_diagnoses_acu_only;

SELECT
	 ACU.PatientICN
	,acu.Acupuncture_BFA
	,acu.Acupuncture_Traditional
	,OD.PatientSID
	,OD.VisitSID
	,OD.VDiagnosisDateTime
	,ICD.ICD10Code
	,ICD.DRGIdentifier AS ICD10_DRG
	,OD.PrimarySecondary
INTO OPCCCT_CIH.dflt.acupuncture_outpatient_diagnoses_acu_only
FROM CDWWork.Outpat.VDiagnosis AS OD
	INNER JOIN OPCCCT_CIH.dflt.ALL_ACUP_VA_encounters AS ACU
		ON OD.VisitSID = acu.VisitSID
	LEFT JOIN CDWWork.Dim.ICD10 AS ICD
		ON OD.ICD10SID = ICD.ICD10SID
WHERE ICD.ICD10Code IS NOT NULL
	AND ICD.ICD10Code <> '*Unknown at this time*'
	AND OD.VDiagnosisDateTime >= '2020-10-01';

CREATE INDEX IX_acu_patienticn_acu_only
	ON OPCCCT_CIH.dflt.acupuncture_outpatient_diagnoses_acu_only (PatientICN);

/********************************************
STEP 2: This table is the millennium diagnosis queries
********************************************/
drop table if exists opccct_cih.dflt.MILL_acu_user_dianoses
SELECT acu.PatientICN
      ,[EncounterSID]
      ,[PersonSID]
      ,[OrganizationNameSID]
      ,[EncounterDiagnosisSID]
      ,[CodeID] as ICD10Code
      ,[CodeDescription]
      ,[DiagnosisDateTime]
      ,[DiagnosisPriority]
      ,[DiagnosisDisplay]
into opccct_cih.dflt.MILL_acu_user_diagnoses
  FROM [CDWWork2].[Mill].[PatientDiagnosisAll] as p
    	INNER JOIN (select distinct patientsid,visitsid,PatientICN
				from OPCCCT_CIH.dflt.ALL_ACUP_VA_encounters
				where VisitDateTime >= '2021-10-01') AS ACU
		ON P.PersonSID = ACU.PatientSID 
            and CONCAT(FORMAT(p.diagnosisdatetime, 'yyMMdd'), CAST(p.encounterSID AS VARCHAR(20))) = CAST(acu.visitSID AS VARCHAR(20))
  where DiagnosisDateTime >= '2020-10-01' and SourceVocabulary in ('ICD-10-CM');

  CREATE INDEX IX_acu_patienticn_acu_only
	ON OPCCCT_CIH.dflt.MILL_acu_user_diagnoses (PatientICN)

  -- example visitSID in Irad's data      2104131800001157497
  -- example encounterSID in the diagnosis data 1800000217826
  -- he's adding the date in the form of YYMMDD to the front of the encounterSID. I think this is 
  -- because he's avoiding the possibility of a millenium and VISTA visitSID/encounterSID accidental overlap

/******************************************************************************
STEP 3: Combine into longitudinal diagnosis table.

VISTA outpatient diagnoses (from Step 1) UNION ALL Millennium diagnoses
(mill_acu_user_dianoses). A SourceSystem column is added so the two identifier
spaces / vocabularies can be told apart downstream.

Inpatient is still excluded on the VISTA side. See the CONFIRM notes below on
the Millennium side — Millennium diagnoses can be inpatient, so filter/label
accordingly.
******************************************************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.acupuncture_all_diagnoses_acu_only;

SELECT
	 PatientICN
	,PatientSID
	,VisitSID AS EncounterSID
	,VDiagnosisDateTime AS DiagnosisDateTime
	,ICD10Code
	,PrimarySecondary
	,'VISTA' AS SourceSystem
INTO OPCCCT_CIH.dflt.acupuncture_all_diagnoses_acu_only
FROM OPCCCT_CIH.dflt.acupuncture_outpatient_diagnoses_acu_only

UNION ALL

SELECT
	 patienticn
	,PersonSID AS PatientSID          -- Millennium person key; different ID space, reconciles via PatientICN
	,CAST(EncounterSID AS VARCHAR(20)) AS EncounterSID
	,DiagnosisDateTime
	,ICD10Code
	,CASE WHEN DiagnosisPriority = 0 THEN 'P' ELSE 'S' END AS PrimarySecondary
	,'Millennium' AS SourceSystem
FROM OPCCCT_CIH.dflt.MILL_acu_user_diagnoses;

CREATE INDEX IX_acu_all_diag_patienticn_acu_only
	ON OPCCCT_CIH.dflt.acupuncture_all_diagnoses_acu_only (PatientICN);

/******************************************************************************
STEP 4: Final summary — one row per PatientICN + PatientSID + ICD10Code
******************************************************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only;

WITH agg AS (
	SELECT
		 PatientICN
		,PatientSID
		,SourceSystem
		,ICD10Code
		,MIN(DiagnosisDateTime) AS FirstDiagnosedDate
		,MAX(DiagnosisDateTime) AS MostRecentDiagnosedDate
		,COUNT(*) AS TimesDiagnosedTotal
		,MAX(CASE WHEN PrimarySecondary = 'P' THEN 1 ELSE 0 END) AS EverPrimaryFlag
	FROM OPCCCT_CIH.dflt.acupuncture_all_diagnoses_acu_only
	GROUP BY PatientICN, PatientSID, SourceSystem, ICD10Code
),

ranked_overall AS (
	SELECT
		 PatientICN
		,PatientSID
		,SourceSystem
		,ICD10Code
		,PrimarySecondary
		,ROW_NUMBER() OVER (
			PARTITION BY PatientICN, PatientSID, ICD10Code
			ORDER BY DiagnosisDateTime DESC
		 ) AS rn
	FROM OPCCCT_CIH.dflt.acupuncture_all_diagnoses_acu_only
),

most_recent_diagnosis AS (
	SELECT
		 PatientICN
		,PatientSID
		,MAX(DiagnosisDateTime) AS PatientMostRecentDiagnosis
	FROM OPCCCT_CIH.dflt.acupuncture_all_diagnoses_acu_only
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
	,a.EverPrimaryFlag
	,ro.PrimarySecondary AS MostRecentPrimarySecondary
INTO OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only
FROM agg AS a
INNER JOIN most_recent_diagnosis AS m
	ON a.PatientICN = m.PatientICN
	AND a.PatientSID = m.PatientSID
INNER JOIN ranked_overall AS ro
	ON a.PatientICN = ro.PatientICN
	AND a.PatientSID = ro.PatientSID
	AND a.ICD10Code = ro.ICD10Code
	AND ro.rn = 1;

CREATE INDEX IX_acu_diag_summary_patienticn_acu_only
	ON OPCCCT_CIH.dflt.COMBINED_acupuncture_diagnoses_VA_acu_visits_only (PatientICN);

/***************************************************************
Vital signs / pain-score data (visit-only: same PatientSID + LocationSID +
same calendar date as the acupuncture encounter).
***************************************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.acupuncture_vital_signs_acu_only;

WITH acu_visit_location AS (
	SELECT
		 ACU.PatientICN
		,ACU.VisitSID
		,OV.LocationSID
		,OV.VisitDateTime
	FROM OPCCCT_CIH.dflt.ALL_ACUP_VA_encounters AS ACU
		INNER JOIN CDWWork.Outpat.Visit AS OV
			ON ACU.VisitSID = OV.VisitSID
)
SELECT DISTINCT
	 AVL.PatientICN
	,VS.PatientSID
	,VS.LocationSID
	,VS.VitalTypeSID
	,VS.VitalSignTakenDateTime
	,VS.VitalResult
	,VS.VitalResultNumeric
	,VT.VitalType
INTO OPCCCT_CIH.dflt.acupuncture_vital_signs_acu_only
FROM CDWWork.Vital.VitalSign AS VS
	INNER JOIN CDWWork.Dim.VitalType AS VT
		ON VS.VitalTypeSID = VT.VitalTypeSID
	INNER JOIN acu_visit_location AS AVL
		ON VS.LocationSID = AVL.LocationSID
		AND CAST(VS.VitalSignTakenDateTime AS DATE) = CAST(AVL.VisitDateTime AS DATE)
WHERE (VS.EnteredInErrorFlag IS NULL OR VS.EnteredInErrorFlag <> 'Y')
	AND VS.VitalSignTakenDateTime >= '2020-10-01'
	AND VT.VitalType NOT IN ('HEIGHT','CIRCUMFERENCE/GIRTH','WEIGHT','CENTRAL VENOUS PRESSURE'
							,'*Missing*','PULSE OXIMETRY','TEMPERATURE','BLOOD PRESSURE'
							,'PULSE','RESPIRATION')
	AND TRY_CAST(VS.VitalResult AS INT) BETWEEN 0 AND 10;

/***************************************************************
Mental Health Factors (visit-only: nearest survey per visit per
SurveyName + SurveyScale, using the B/F decision rule).

  B = days from nearest survey ON OR BEFORE the visit (backward)
  F = days to nearest survey AFTER the visit (forward)
  - no backward -> use forward (if any)
  - else forward wins if F <= MIN(B/2, 14)
  - else backward
***************************************************************/
DROP TABLE IF EXISTS OPCCCT_CIH.dflt.acupuncture_mental_health_scores_acu_only;

WITH visits AS (
	SELECT
		 ACU.PatientICN
		,ACU.VisitSID
		,OV.PatientSID
		,OV.VisitDateTime
	FROM OPCCCT_CIH.dflt.ALL_ACUP_VA_encounters AS ACU
		INNER JOIN CDWWork.Outpat.Visit AS OV
			ON ACU.VisitSID = OV.VisitSID
),

surveys AS (
	SELECT DISTINCT
		 m.PatientSID
		,acu.PatientICN
		,m.SurveySID
		,m.SurveyName
		,m.SurveyGivenDateTime
		,m.SurveyScale
		,CASE WHEN m.SurveyName = 'C-SSRS' THEN sq.SurveyQuestionText ELSE NULL END AS QuestionText
		,CASE WHEN m.SurveyName = 'C-SSRS' THEN sc.Designator ELSE NULL END AS QuestionDesignator
		,m.RawScore
	FROM CDWWork.MH.SurveyResult AS m
	INNER JOIN OPCCCT_CIH.dflt.VISTA_acupuncture_patient_list AS acu
		ON m.PatientSID = acu.PatientSID
	LEFT JOIN CDWWork.Dim.SurveyContent AS sc
		ON m.SurveySID = sc.SurveySID
		AND m.SurveyName = 'C-SSRS'
		AND TRY_CAST(REPLACE(LOWER(m.SurveyScale), 'ques', '') AS INT) = sc.QuestionSequence
	LEFT JOIN CDWWork.Dim.SurveyQuestion AS sq
		ON sc.SurveyQuestionSID = sq.SurveyQuestionSID
	WHERE m.SurveyGivenDateTime >= '2020-10-01'
		AND m.SurveyName IN ('C-SSRS','AUDC','PHQ-2','PC-PTSD-5','PHQ9'
							 ,'GAD-7','MORSE FALL SCALE','BRADEN SCALE')
),

candidates AS (
	SELECT
		 v.PatientICN
		,v.VisitSID
		,v.VisitDateTime
		,s.SurveyName
		,s.SurveyScale
		,s.QuestionText
		,s.QuestionDesignator
		,s.SurveyGivenDateTime
		,s.RawScore
		,DATEDIFF(DAY, s.SurveyGivenDateTime, v.VisitDateTime) AS DaysBackward
		,DATEDIFF(DAY, v.VisitDateTime, s.SurveyGivenDateTime) AS DaysForward
	FROM visits AS v
	INNER JOIN surveys AS s
		ON v.PatientSID = s.PatientSID
		AND s.SurveyGivenDateTime >= DATEADD(DAY, -365, v.VisitDateTime)
		AND s.SurveyGivenDateTime <= DATEADD(DAY,  365, v.VisitDateTime)
),

backward_ranked AS (
	SELECT *,
		ROW_NUMBER() OVER (
			PARTITION BY VisitSID, SurveyName, SurveyScale
			ORDER BY DaysBackward ASC
		) AS rn
	FROM candidates
	WHERE DaysBackward >= 0
),

forward_ranked AS (
	SELECT *,
		ROW_NUMBER() OVER (
			PARTITION BY VisitSID, SurveyName, SurveyScale
			ORDER BY DaysForward ASC
		) AS rn
	FROM candidates
	WHERE DaysForward > 0
),

backward_best AS (SELECT * FROM backward_ranked WHERE rn = 1),
forward_best  AS (SELECT * FROM forward_ranked  WHERE rn = 1),

paired AS (
	SELECT
		 COALESCE(b.PatientICN, f.PatientICN) AS PatientICN
		,COALESCE(b.VisitSID, f.VisitSID) AS VisitSID
		,COALESCE(b.VisitDateTime, f.VisitDateTime) AS VisitDateTime
		,COALESCE(b.SurveyName, f.SurveyName) AS SurveyName
		,COALESCE(b.SurveyScale, f.SurveyScale) AS SurveyScale
		,b.SurveyGivenDateTime AS BackwardSurveyDateTime
		,b.RawScore AS BackwardRawScore
		,b.QuestionText AS BackwardQuestionText
		,b.QuestionDesignator AS BackwardQuestionDesignator
		,b.DaysBackward
		,f.SurveyGivenDateTime AS ForwardSurveyDateTime
		,f.RawScore AS ForwardRawScore
		,f.QuestionText AS ForwardQuestionText
		,f.QuestionDesignator AS ForwardQuestionDesignator
		,f.DaysForward
	FROM backward_best AS b
	FULL OUTER JOIN forward_best AS f
		ON b.VisitSID = f.VisitSID
		AND b.SurveyName = f.SurveyName
		AND b.SurveyScale = f.SurveyScale
),

decision AS (
	SELECT
		 p.*
		,CASE WHEN p.DaysBackward IS NULL THEN 14.0
			  ELSE (CASE WHEN p.DaysBackward / 2.0 < 14 THEN p.DaysBackward / 2.0 ELSE 14 END)
		 END AS ForwardThreshold
	FROM paired AS p
)

SELECT
	 PatientICN
	,VisitSID
	,VisitDateTime
	,SurveyName
	,SurveyScale
	,CASE
		WHEN DaysBackward = 0 THEN BackwardSurveyDateTime
		WHEN DaysBackward IS NULL THEN ForwardSurveyDateTime
		WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN ForwardSurveyDateTime
		ELSE BackwardSurveyDateTime
	 END AS MatchedSurveyDateTime
	,CASE
		WHEN DaysBackward = 0 THEN BackwardRawScore
		WHEN DaysBackward IS NULL THEN ForwardRawScore
		WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN ForwardRawScore
		ELSE BackwardRawScore
	 END AS MatchedRawScore
	,CASE
		WHEN DaysBackward = 0 THEN BackwardQuestionText
		WHEN DaysBackward IS NULL THEN ForwardQuestionText
		WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN ForwardQuestionText
		ELSE BackwardQuestionText
	 END AS MatchedQuestionText
	,CASE
		WHEN DaysBackward = 0 THEN BackwardQuestionDesignator
		WHEN DaysBackward IS NULL THEN ForwardQuestionDesignator
		WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN ForwardQuestionDesignator
		ELSE BackwardQuestionDesignator
	 END AS MatchedQuestionDesignator
	,CASE
		WHEN DaysBackward = 0 THEN 0
		WHEN DaysBackward IS NULL THEN DaysForward
		WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN DaysForward
		ELSE -DaysBackward
	 END AS MatchedDayDistance
	,CASE
		WHEN DaysBackward = 0 THEN 'Same day'
		WHEN DaysBackward IS NULL THEN 'Forward (no backward available)'
		WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN 'Forward (ratio/cap rule)'
		ELSE 'Backward (default)'
	 END AS MatchDirection
INTO OPCCCT_CIH.dflt.acupuncture_mental_health_scores_acu_only
FROM decision
WHERE DaysBackward IS NOT NULL OR DaysForward IS NOT NULL;

CREATE INDEX IX_acu_mh_patienticn_acu_only
	ON OPCCCT_CIH.dflt.acupuncture_mental_health_scores_acu_only (PatientICN);