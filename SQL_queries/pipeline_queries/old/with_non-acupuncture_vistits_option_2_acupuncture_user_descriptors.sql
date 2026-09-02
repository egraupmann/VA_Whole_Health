
/**********************************************************************
CONFIG FLAG
@AcuVisitOnly = 0 -> "any diagnosis for a patient who ever received acupuncture"
                     (outpatient joins on acupuncture_patient_list)
@AcuVisitOnly = 1 -> "diagnoses tied specifically to an acupuncture visit"
                     (outpatient joins on acupuncture_VA_encounters via VisitSID)

TABLE NAMING: all output table names get a suffix based on the flag, so both
modes can coexist without overwriting each other:
  @AcuVisitOnly = 0 -> ..._allpatients
  @AcuVisitOnly = 1 -> ..._visitonly

NOTE ON INPATIENT: Inpatient diagnoses have no VisitSID linkage to acupuncture
encounters at all (acupuncture is not an inpatient-coded procedure here), so
there is no way to scope inpatient rows to "acupuncture visits" specifically.
When @AcuVisitOnly = 1, inpatient diagnoses are EXCLUDED from the final table
******************************************************************************/
DECLARE @AcuVisitOnly BIT = 1;  -- set to 0 or 1

DECLARE @Suffix VARCHAR(20) = CASE WHEN @AcuVisitOnly = 1 THEN '_acu_only' ELSE '_all' END;

/***************************************************************
Patient information - filter to those who have had at least
1 acupuncture visit and get associated Veteran status.
NOTE: this will not necessarily be 1 record per patient, as a patient may have 
multiple race records

NOTE: Dropped address information for now, as it is not needed for the current 
analysis. Many patients also have lots of location recrods and there aren't clear
dates to indicate which is most recent. If address information is needed,
need to evaluate whether there is a better way to assess where patients live
***************************************************************/

/***************************************************************
get the latest enrollment status for each patient
********************************************************/
DROP TABLE IF EXISTS #enrollstatus;
SELECT t.ADRPersonSID, EnrollStartDate, EnrollEndDate
INTO #enrollstatus
FROM CDWWork.ADR.ADREnrollHistory t
INNER JOIN (
    SELECT ADRPersonSID, MAX(recordmodifieddate) AS max_date
    FROM CDWWork.ADR.ADREnrollHistory
    GROUP BY ADRPersonSID
) latest
    ON t.ADRPersonSID = latest.ADRPersonSID
    AND t.recordmodifieddate = latest.max_date;

/***************************************************************
get patient demographic data
***************************************************************/
drop table if exists OPCCCT_CIH.dflt.acupuncture_patient_list;
SELECT DISTINCT
	 P.PatientSID
	,P.PatientICN
	,P.Age
	,sp.birthdatetime
	,P.DeathDateTime
	,P.Gender
	,P.IneligibleReason
	,P.PreferredInstitutionSID
	,P.InsuranceCoverageFlag
	,P.MedicaidEligibleFlag
	,P.MaritalStatus
	,pr.race
	,EH.EnrollStartDate
	,EH.EnrollEndDate
	/*
	,ADDR.Zip AS PatientZip
	,ADDR.County AS PatientCounty
	,ADDR.State AS PatientState
	,ADDR.GISFIPSCode AS PatientGISFIPSCode
	,ADDR.GISMarket AS PatientGISMarket
	,ADDR.GISSubmarket AS PatientGISSubmarket
	,ADDR.GISSector AS PatientGISSector
	,ADDR.GISURH AS PatientGISURH
	,ADDR.AddressStartDateTime AS PatientAddressStartDateTime
	,ADDR.AddressEndDateTime AS PatientAddressEndDateTime*/
into OPCCCT_CIH.dflt.acupuncture_patient_list
FROM CDWWork.Patient.Patient AS P
	inner join cdwwork.spatient.spatient as sp
		on P.PatientSID = sp.PatientSID
	/*inner join CDWWork.SPatient.SPatientAddress AS ADDR
		ON P.PatientSID = ADDR.PatientSID*/
	INNER JOIN (select distinct patienticn, patientsid
				from OPCCCT_CIH.dflt.acupuncture_VA_encounters
				where VisitDateTime >= '2021-10-01') AS ACU
		ON P.PatientSID = ACU.PatientSID and p.PatientICN = ACU.PatientICN
	INNER JOIN CDWWork.Veteran.ADRPerson AS VET
		ON VET.ADRPersonICN = P.PatientICN
	LEFT JOIN CDWWork.PatSub.PatientRace AS PR
		ON P.PatientSID = PR.PatientSID
	inner JOIN #enrollstatus AS EH
		ON VET.ADRPersonSID = EH.ADRPersonSID
WHERE (P.TestPatientFlag IS NULL OR P.TestPatientFlag <> 'Y')
	AND P.VeteranFlag = 'Y' and VET.VeteranFlag = 'Y';

CREATE INDEX IX_acu_patientsid ON OPCCCT_CIH.dflt.acupuncture_patient_list (PatientSID);

SELECT top 1000 t.*
FROM OPCCCT_CIH.dflt.acupuncture_patient_list t
INNER JOIN (
    SELECT PatientICN
    FROM OPCCCT_CIH.dflt.acupuncture_patient_list
    GROUP BY PatientICN
    HAVING COUNT(*) > 1
) dupes ON t.PatientICN = dupes.PatientICN
order by patienticn;

select count(*)
from OPCCCT_CIH.dflt.acupuncture_patient_list

select count(distinct patienticn)
from OPCCCT_CIH.dflt.acupuncture_patient_list

/***************************************************************
Outpatient diagnosis information for patients that have received
acupuncture.
Findings: Problemlist data is not as useful as hoped. The following fields are not useful:
-Of the 10,000 sample examined, only 18 records had a non-null onset date
-'EventDateTime' is also useless, only populated for 25 records of 10,000
	-'VDiagnosisDateTime' was populated for all sample records, this is what to use for the date of the diagnosis
	-'VisitDateTime' is also populated for all records and matches the 'VDiagnosisDateTime' for all records, so either can be used for the date of the diagnosis
-ActiveFlag is also useless
-service connected flag is null for over 95% of records (the sparsley populated records have N and Y so it's not null meaning no)
***************************************************************/

-- Fully-qualified dynamic table names, built once and reused throughout
DECLARE @TblOutpat   NVARCHAR(200) = 'OPCCCT_CIH.dflt.acupuncture_outpatient_diagnoses' + @Suffix;
DECLARE @TblInpat    NVARCHAR(200) = 'OPCCCT_CIH.dflt.acupuncture_inpatient_diagnoses' + @Suffix;
DECLARE @TblAll      NVARCHAR(200) = 'OPCCCT_CIH.dflt.acupuncture_all_diagnoses' + @Suffix;
DECLARE @TblSummary  NVARCHAR(200) = 'OPCCCT_CIH.dflt.acupuncture_diagnoses_summary' + @Suffix;

-- Bare (unqualified) names, needed for CREATE INDEX index-name uniqueness
DECLARE @IxOutpat  NVARCHAR(200) = 'IX_acu_patienticn' + @Suffix;
DECLARE @IxInpat   NVARCHAR(200) = 'IX_acu_inpatienticn' + @Suffix;
DECLARE @IxAll     NVARCHAR(200) = 'IX_acu_all_diag_patienticn' + @Suffix;
DECLARE @IxSummary NVARCHAR(200) = 'IX_acu_diag_summary_patienticn' + @Suffix;

DECLARE @SQL NVARCHAR(MAX);
DECLARE @StepStart DATETIME;
DECLARE @PipelineStart DATETIME = GETDATE();
SET @StepStart = GETDATE();

/******************************************************************************
STEP 1: Outpatient diagnoses
******************************************************************************/

SET @SQL = N'DROP TABLE IF EXISTS ' + @TblOutpat + N';';
EXEC sp_executesql @SQL;

IF @AcuVisitOnly = 0
BEGIN
	SET @SQL = N'
	SELECT
		 ACU.PatientICN
		,OD.PatientSID
		,OD.VisitSID
		,OD.VDiagnosisDateTime
		,ICD.ICD10Code
		,ICD.DRGIdentifier AS ICD10_DRG
		,OD.PrimarySecondary
	INTO ' + @TblOutpat + N'
	FROM CDWWork.Outpat.VDiagnosis AS OD
		INNER JOIN OPCCCT_CIH.dflt.acupuncture_patient_list AS ACU
			ON OD.PatientSID = ACU.PatientSID
		LEFT JOIN CDWWork.Dim.ICD10 AS ICD
			ON OD.ICD10SID = ICD.ICD10SID
	WHERE ICD.ICD10Code IS NOT NULL
		AND ICD.ICD10Code <> ''*Unknown at this time*''
		AND OD.VDiagnosisDateTime >= ''2020-10-01'';';
END
ELSE
BEGIN
	SET @SQL = N'
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
	INTO ' + @TblOutpat + N'
	FROM CDWWork.Outpat.VDiagnosis AS OD
		INNER JOIN OPCCCT_CIH.dflt.acupuncture_VA_encounters AS ACU
			ON OD.VisitSID = acu.VisitSID
		LEFT JOIN CDWWork.Dim.ICD10 AS ICD
			ON OD.ICD10SID = ICD.ICD10SID
	WHERE ICD.ICD10Code IS NOT NULL
		AND ICD.ICD10Code <> ''*Unknown at this time*''
		AND OD.VDiagnosisDateTime >= ''2020-10-01'';';
END

EXEC sp_executesql @SQL;

SET @SQL = N'CREATE INDEX ' + @IxOutpat + N' ON ' + @TblOutpat + N' (PatientICN);';
EXEC sp_executesql @SQL;

PRINT 'Outpatient duration (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';

/*Below is just for getting a sample of patients to see what the data looks like*/
SET @SQL = N'
DROP TABLE IF EXISTS #sample_patients;

SELECT TOP 100 PatientICN
INTO #sample_patients
FROM (SELECT DISTINCT PatientICN FROM ' + @TblOutpat + N') AS p
ORDER BY NEWID();

SELECT d.*
FROM ' + @TblOutpat + N' AS d
INNER JOIN #sample_patients AS s
	ON d.PatientICN = s.PatientICN;';
EXEC sp_executesql @SQL;

PRINT 'Get Outpatient Sample (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';

/******************************************************************************
STEP 2: Pull inpatient diagnoses. Unaffected by @AcuVisitOnly logic-wise (still
always patient-level, since no visit linkage exists for inpatient), but the
OUTPUT TABLE NAME still gets the suffix so it lines up with its matching run.
******************************************************************************/
SET @StepStart = GETDATE();

SET @SQL = N'DROP TABLE IF EXISTS ' + @TblInpat + N';';
EXEC sp_executesql @SQL;

SET @SQL = N'
SELECT DISTINCT
	 ACU.PatientICN
	,ID.PatientSID
	,ID.InpatientSID
	,INP.AdmitDateTime
	,ICD.ICD10Code
	,ICD.DRGIdentifier
	,CASE WHEN ID.OrdinalNumber = 0 THEN ''P'' ELSE ''S'' END AS PrimarySecondary
INTO ' + @TblInpat + N'
FROM CDWWork.Inpat.InpatientDiagnosis AS ID
	INNER JOIN CDWWork.Dim.ICD10 AS ICD
		ON ID.ICD10SID = ICD.ICD10SID
	INNER JOIN OPCCCT_CIH.dflt.acupuncture_patient_list AS ACU
		ON ID.PatientSID = ACU.PatientSID
	LEFT JOIN CDWWork.Inpat.Inpatient AS INP
		ON ID.InpatientSID = INP.InpatientSID
WHERE ICD.ICD10Code <> ''*Unknown at this time*''
	AND INP.AdmitDateTime >= ''2020-10-01'';';
EXEC sp_executesql @SQL;

SET @SQL = N'CREATE INDEX ' + @IxInpat + N' ON ' + @TblInpat + N' (PatientICN);';
EXEC sp_executesql @SQL;

PRINT 'Get Inpatient Duration (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';

/******************************************************************************
STEP 3: Combine outpatient + inpatient into one longitudinal diagnosis table.

Option A (default, matches @AcuVisitOnly semantics literally):
  When visit-only mode is on, inpatient rows are excluded entirely, since they
  can never be "acupuncture visit" diagnoses.

Option B (kept for reference below, commented out):
  Always include inpatient regardless of @AcuVisitOnly.
******************************************************************************/
SET @StepStart = GETDATE();

SET @SQL = N'DROP TABLE IF EXISTS ' + @TblAll + N';';
EXEC sp_executesql @SQL;

-- ===== OPTION A (default): exclude inpatient when @AcuVisitOnly = 1 =====
SET @SQL = N'
SELECT
	 PatientICN
	,PatientSID
	,VisitSID AS EncounterSID
	,VDiagnosisDateTime AS DiagnosisDateTime
	,ICD10Code
	,ICD10_DRG AS DRGIdentifier
	,PrimarySecondary
	,''Outpatient'' AS EncounterType
INTO ' + @TblAll + N'
FROM ' + @TblOutpat + N'

UNION ALL

SELECT
	 PatientICN
	,PatientSID
	,InpatientSID AS EncounterSID
	,AdmitDateTime AS DiagnosisDateTime
	,ICD10Code
	,DRGIdentifier
	,PrimarySecondary
	,''Inpatient'' AS EncounterType
FROM ' + @TblInpat + N'
WHERE ' + CAST(@AcuVisitOnly AS VARCHAR(1)) + N' = 0;';  -- key line: makes inpatient a no-op when visit-only mode is on

EXEC sp_executesql @SQL;

SET @SQL = N'CREATE INDEX ' + @IxAll + N' ON ' + @TblAll + N' (PatientICN);';
EXEC sp_executesql @SQL;

PRINT 'Combine the diagnoses (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';

/******************************************************************************
-- Collapses repeated diagnosis rows per PatientICN + PatientSID + ICD10Code into one summary row.
-- (PatientSID can differ across facilities/merges for the same PatientICN.
-- PrimarySecondary is set to primary if the diagnosis was ever set as the primary diagnosis
******************************************************************************/

/******************************************************************************
STEP 4: Build final summary — one row per PatientICN + PatientSID + ICD10Code
******************************************************************************/
SET @StepStart = GETDATE();

SET @SQL = N'DROP TABLE IF EXISTS ' + @TblSummary + N';';
EXEC sp_executesql @SQL;

SET @SQL = N'
WITH agg AS (
	SELECT
		 PatientICN
		,PatientSID
		,ICD10Code
		,MIN(DiagnosisDateTime) AS FirstDiagnosedDate
		,MAX(DiagnosisDateTime) AS MostRecentDiagnosedDate
		,COUNT(*) AS TimesDiagnosedTotal
		,SUM(CASE WHEN EncounterType = ''Outpatient'' THEN 1 ELSE 0 END) AS TimesDiagnosedOutpatient
		,SUM(CASE WHEN EncounterType = ''Inpatient'' THEN 1 ELSE 0 END) AS TimesDiagnosedInpatient
		,MAX(CASE WHEN PrimarySecondary = ''P'' THEN 1 ELSE 0 END) AS EverPrimaryFlag
		,MAX(CASE WHEN PrimarySecondary = ''P'' AND EncounterType = ''Outpatient'' THEN 1 ELSE 0 END) AS EverPrimaryFlagOutpatient
		,MAX(CASE WHEN PrimarySecondary = ''P'' AND EncounterType = ''Inpatient'' THEN 1 ELSE 0 END) AS EverPrimaryFlagInpatient
	FROM ' + @TblAll + N'
	GROUP BY PatientICN, PatientSID, ICD10Code
),

ranked_overall AS (
	SELECT
		 PatientICN
		,PatientSID
		,ICD10Code
		,DRGIdentifier
		,PrimarySecondary
		,EncounterType
		,ROW_NUMBER() OVER (
			PARTITION BY PatientICN, PatientSID, ICD10Code
			ORDER BY DiagnosisDateTime DESC
		 ) AS rn
	FROM ' + @TblAll + N'
),

most_recent_diagnosis AS (
	SELECT
		 PatientICN
		,PatientSID
		,MAX(DiagnosisDateTime) AS PatientMostRecentDiagnosis
	FROM ' + @TblAll + N'
	GROUP BY PatientICN, PatientSID
)

SELECT
	 a.PatientICN
	,a.PatientSID
	,m.PatientMostRecentDiagnosis
	,a.ICD10Code
	,ro.DRGIdentifier
	,a.FirstDiagnosedDate
	,a.MostRecentDiagnosedDate
	,a.TimesDiagnosedTotal
	,a.TimesDiagnosedOutpatient
	,a.TimesDiagnosedInpatient
	,a.EverPrimaryFlag
	,a.EverPrimaryFlagOutpatient
	,a.EverPrimaryFlagInpatient
	,ro.PrimarySecondary AS MostRecentPrimarySecondary
	,ro.EncounterType AS MostRecentEncounterType
INTO ' + @TblSummary + N'
FROM agg AS a
INNER JOIN most_recent_diagnosis AS m
	ON a.PatientICN = m.PatientICN
	AND a.PatientSID = m.PatientSID
INNER JOIN ranked_overall AS ro
	ON a.PatientICN = ro.PatientICN
	AND a.PatientSID = ro.PatientSID
	AND a.ICD10Code = ro.ICD10Code
	AND ro.rn = 1;';

EXEC sp_executesql @SQL;

SET @SQL = N'CREATE INDEX ' + @IxSummary + N' ON ' + @TblSummary + N' (PatientICN);';
EXEC sp_executesql @SQL;

PRINT 'Flattened Diagnosis Table (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
PRINT 'Total pipeline duration (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @PipelineStart, GETDATE()) AS VARCHAR) + ' seconds';
PRINT 'Output tables created:';
PRINT '  ' + @TblOutpat;
PRINT '  ' + @TblInpat;
PRINT '  ' + @TblAll;
PRINT '  ' + @TblSummary;

/***************************************************************
Vital signs / pain-score data.
Found that the 'Vital Sign Qualifer' table is empty, at least for pain scores so not useful

CONFIG FLAG
@AcuVisitOnly = 0 -> "any vital sign for a patient who ever received acupuncture"
                     (joins on acupuncture_patient_list, PatientSID only)
@AcuVisitOnly = 1 -> "vital signs associated with an acupuncture visit"
                     (joins on acupuncture_VA_encounters via PatientSID +
                      LocationSID + same calendar date as the visit)

IMPORTANT CAVEAT ON VISIT-ONLY MODE: vital signs have no VisitSID, so "tied to
a visit" is APPROXIMATED as: same patient, same location, same calendar day as
an acupuncture encounter. This is a looser match than the diagnosis table's
VisitSID join

TABLE NAMING: output table name gets a suffix based on the flag:
  @AcuVisitOnly = 0 -> ..._allpatients
  @AcuVisitOnly = 1 -> ..._visitonly
***************************************************************/

/*below is only needed if running as a chunk and not the entire script*/

/*remove this comment here if running just this chunk of code
DECLARE @AcuVisitOnly BIT = 1;  -- set to 0 or 1

DECLARE @Suffix VARCHAR(20) = CASE WHEN @AcuVisitOnly = 1 THEN '_acu_only' ELSE '_all' END;

DECLARE @SQL NVARCHAR(MAX);
DECLARE @StepStart DATETIME = GETDATE();
remove this comment here if running just a chunk of the code*/

DECLARE @TblVitals NVARCHAR(200) = 'OPCCCT_CIH.dflt.acupuncture_vital_signs' + @Suffix;

SET @SQL = N'DROP TABLE IF EXISTS ' + @TblVitals + N';';
EXEC sp_executesql @SQL;

IF @AcuVisitOnly = 0
BEGIN
	-- Any vital sign for a patient who ever received acupuncture (patient-level)
	SET @SQL = N'
	SELECT DISTINCT
		 ACU.PatientICN
		,VS.PatientSID
		,VS.LocationSID
		,VS.VitalTypeSID
		,VS.VitalSignTakenDateTime
		,VS.VitalResult
		,VS.VitalResultNumeric
		,VT.VitalType
	INTO ' + @TblVitals + N'
	FROM CDWWork.Vital.VitalSign AS VS
		INNER JOIN CDWWork.Dim.VitalType AS VT
			ON VS.VitalTypeSID = VT.VitalTypeSID
		INNER JOIN OPCCCT_CIH.dflt.acupuncture_patient_list AS ACU
			ON VS.PatientSID = ACU.PatientSID
	WHERE (VS.EnteredInErrorFlag IS NULL OR VS.EnteredInErrorFlag <> ''Y'')
		AND VS.VitalSignTakenDateTime >= ''2020-10-01''
		AND VT.VitalType NOT IN (''HEIGHT'',''CIRCUMFERENCE/GIRTH'',''WEIGHT'',''CENTRAL VENOUS PRESSURE''
								,''*Missing*'',''PULSE OXIMETRY'',''TEMPERATURE'',''BLOOD PRESSURE''
								,''PULSE'',''RESPIRATION'')
		AND TRY_CAST(VS.VitalResult AS INT) BETWEEN 0 AND 10;';
END
ELSE
BEGIN
	-- Vital signs matched to an acupuncture visit: same PatientSID + LocationSID
	-- + same calendar date as the acupuncture encounter.
	-- Adjust ACU.VisitDateTime below if the encounter table's date column has
	-- a different name (e.g. VisitDateTime vs VDiagnosisDateTime-equivalent).
	SET @SQL = N'
		WITH acu_visit_location AS (
		SELECT
			 ACU.PatientICN
			,ACU.VisitSID
			,OV.LocationSID
			,OV.VisitDateTime
		FROM OPCCCT_CIH.dflt.acupuncture_VA_encounters AS ACU
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
	INTO ' + @TblVitals + N'
	FROM CDWWork.Vital.VitalSign AS VS
		INNER JOIN CDWWork.Dim.VitalType AS VT
			ON VS.VitalTypeSID = VT.VitalTypeSID
		INNER JOIN acu_visit_location AS AVL
			ON VS.LocationSID = AVL.LocationSID
			AND CAST(VS.VitalSignTakenDateTime AS DATE) = CAST(AVL.VisitDateTime AS DATE)
	WHERE (VS.EnteredInErrorFlag IS NULL OR VS.EnteredInErrorFlag <> ''Y'')
		AND VS.VitalSignTakenDateTime >= ''2020-10-01''
		AND VT.VitalType NOT IN (''HEIGHT'',''CIRCUMFERENCE/GIRTH'',''WEIGHT'',''CENTRAL VENOUS PRESSURE''
								,''*Missing*'',''PULSE OXIMETRY'',''TEMPERATURE'',''BLOOD PRESSURE''
								,''PULSE'',''RESPIRATION'')
		AND TRY_CAST(VS.VitalResult AS INT) BETWEEN 0 AND 10;';
END

EXEC sp_executesql @SQL;

PRINT 'Vital signs duration (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
PRINT 'Output table: ' + @TblVitals;

/*Below is just for getting a sample of patients to see what the data looks like*/
-- NOTE: DROP, SELECT INTO, and final SELECT must all run in the SAME
-- sp_executesql call -- a temp table created in dynamic SQL does not persist
-- across separate EXEC calls or back to the outer batch.
SET @SQL = N'
DROP TABLE IF EXISTS #sample_patients;

SELECT TOP 1000 PatientICN
INTO #sample_patients
FROM (SELECT DISTINCT PatientICN FROM ' + @TblVitals + N') AS p
ORDER BY NEWID();

SELECT d.*
FROM ' + @TblVitals + N' AS d
INNER JOIN #sample_patients AS s
	ON d.PatientICN = s.PatientICN;';
EXEC sp_executesql @SQL;

/***************************************************************
Mental Health Factors.

The transformedScores in surveyResult are null.
Filtering to the surveys that appear for at least 25% of patients.
CSSRS survey is annoying. All the other surveys are just a total.
CSSRS is 8 different questions that don't say what the question asked,
so that's the reason for the weird text join below to get the actual
text associated with the question.

CONFIG FLAG
@AcuVisitOnly = 0 -> "any mental health survey for a patient who ever
                     received acupuncture" (patient-level, no visit matching
                     at all -- this is the original logic, unchanged)
@AcuVisitOnly = 1 -> "mental health survey matched to the nearest acupuncture
                     visit" using the B/F nearest-match rule below

MATCHING LOGIC (visit-only mode), per acupuncture visit, per SurveyName +
SurveyScale (SurveyScale is what distinguishes individual C-SSRS questions
from each other; for non-CSSRS surveys it's effectively one value per
survey):

  B = days from nearest survey ON OR BEFORE the visit (backward-looking)
  F = days to nearest survey AFTER the visit (forward-looking)

  - If no backward survey exists at all -> use forward (if one exists)
  - Else use FORWARD if F <= MIN(B/2, 14), i.e. forward wins if it's
    within 2 weeks AND at least twice as close as backward
  - Else use BACKWARD
  - If neither exists -> no match (that visit/survey combo won't appear)

Visit-only output is LONG format: one row per VisitSID + SurveyName +
SurveyScale, with the matched survey's date, score, and signed day-distance
from the visit (negative = backward/before visit, positive = forward/after
visit) so matches can be audited.

TABLE NAMING: output table name gets a suffix based on the flag:
  @AcuVisitOnly = 0 -> ..._allpatients
  @AcuVisitOnly = 1 -> ..._visitonly
***************************************************************/

--/*remove this comment here if running just this chunk of code
DECLARE @AcuVisitOnly BIT = 1;  -- set to 0 or 1

DECLARE @Suffix VARCHAR(20) = CASE WHEN @AcuVisitOnly = 1 THEN '_acu_only' ELSE '_all' END;

DECLARE @SQL NVARCHAR(MAX);
DECLARE @StepStart DATETIME = GETDATE();
--*remove this comment here if running just this chunk of code*/

DECLARE @TblMH NVARCHAR(200) = 'OPCCCT_CIH.dflt.acupuncture_mental_health_scores' + @Suffix;
DECLARE @IxMH  NVARCHAR(200) = 'IX_acu_mh_patienticn' + @Suffix;

SET @SQL = N'DROP TABLE IF EXISTS ' + @TblMH + N';';
EXEC sp_executesql @SQL;

IF @AcuVisitOnly = 0
BEGIN
	-- Original logic: any survey for a patient who ever received acupuncture,
	-- no visit matching, no day-distance columns.
	SET @SQL = N'
	SELECT DISTINCT
		 m.PatientSID
		,acu.PatientICN
		,m.SurveySID
		,m.SurveyName
		,m.SurveyGivenDateTime
		,m.SurveyScale
		,CASE
			WHEN m.SurveyName = ''C-SSRS'' THEN sq.SurveyQuestionText
			ELSE NULL
		 END AS QuestionText
		,CASE
			WHEN m.SurveyName = ''C-SSRS'' THEN sc.Designator
			ELSE NULL
		 END AS QuestionDesignator
		,m.RawScore
	INTO ' + @TblMH + N'
	FROM CDWWork.MH.SurveyResult AS m
	INNER JOIN OPCCCT_CIH.dflt.acupuncture_patient_list AS acu
		ON m.PatientSID = acu.PatientSID
	LEFT JOIN CDWWork.Dim.SurveyContent AS sc
		ON m.SurveySID = sc.SurveySID
		AND m.SurveyName = ''C-SSRS''
		AND TRY_CAST(REPLACE(LOWER(m.SurveyScale), ''ques'', '''') AS INT) = sc.QuestionSequence
	LEFT JOIN CDWWork.Dim.SurveyQuestion AS sq
		ON sc.SurveyQuestionSID = sq.SurveyQuestionSID
	WHERE m.SurveyGivenDateTime >= ''2020-10-01''
		AND m.SurveyName IN (''C-SSRS'',''AUDC'',''PHQ-2'',''PC-PTSD-5'',''PHQ9''
							 ,''GAD-7'',''MORSE FALL SCALE'',''BRADEN SCALE'');';

	EXEC sp_executesql @SQL;

	SET @SQL = N'CREATE INDEX ' + @IxMH + N' ON ' + @TblMH + N' (PatientICN);';
	EXEC sp_executesql @SQL;
END
ELSE
BEGIN
	-- Visit-matched logic: nearest survey per visit per SurveyName+SurveyScale,
	-- using the B/F decision rule.
	SET @SQL = N'
	WITH visits AS (
		SELECT
			 ACU.PatientICN
			,ACU.VisitSID
			,OV.PatientSID
			,OV.VisitDateTime
		FROM OPCCCT_CIH.dflt.acupuncture_VA_encounters AS ACU
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
			,CASE
				WHEN m.SurveyName = ''C-SSRS'' THEN sq.SurveyQuestionText
				ELSE NULL
			 END AS QuestionText
			,CASE
				WHEN m.SurveyName = ''C-SSRS'' THEN sc.Designator
				ELSE NULL
			 END AS QuestionDesignator
			,m.RawScore
		FROM CDWWork.MH.SurveyResult AS m
		INNER JOIN OPCCCT_CIH.dflt.acupuncture_patient_list AS acu
			ON m.PatientSID = acu.PatientSID
		LEFT JOIN CDWWork.Dim.SurveyContent AS sc
			ON m.SurveySID = sc.SurveySID
			AND m.SurveyName = ''C-SSRS''
			AND TRY_CAST(REPLACE(LOWER(m.SurveyScale), ''ques'', '''') AS INT) = sc.QuestionSequence
		LEFT JOIN CDWWork.Dim.SurveyQuestion AS sq
			ON sc.SurveyQuestionSID = sq.SurveyQuestionSID
		WHERE m.SurveyGivenDateTime >= ''2020-10-01''
			AND m.SurveyName IN (''C-SSRS'',''AUDC'',''PHQ-2'',''PC-PTSD-5'',''PHQ9''
								 ,''GAD-7'',''MORSE FALL SCALE'',''BRADEN SCALE'')
	),

	-- 1-year window pushed INTO the join so the candidate cross product is
	-- bounded before it is ever materialized. This is logically equivalent to
	-- the old post-join <= 365 filters but avoids the every-visit x every-survey
	-- fan-out that made @AcuVisitOnly = 1 run for hours.
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

	-- Collapse each side to its single nearest row per key BEFORE the join.
	-- This is the fix: filtering rn = 1 inside each CTE prevents the
	-- N x M fan-out that occurred when the FULL OUTER JOIN was applied to
	-- all candidates and rn was filtered post-join.
	backward_best AS (
		SELECT * FROM backward_ranked WHERE rn = 1
	),

	forward_best AS (
		SELECT * FROM forward_ranked WHERE rn = 1
	),

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
			WHEN DaysBackward = 0 THEN ''Same day''
			WHEN DaysBackward IS NULL THEN ''Forward (no backward available)''
			WHEN DaysForward IS NOT NULL AND DaysForward <= ForwardThreshold THEN ''Forward (ratio/cap rule)''
			ELSE ''Backward (default)''
		 END AS MatchDirection
	INTO ' + @TblMH + N'
	FROM decision
	WHERE DaysBackward IS NOT NULL OR DaysForward IS NOT NULL;';

	EXEC sp_executesql @SQL;

	SET @SQL = N'CREATE INDEX ' + @IxMH + N' ON ' + @TblMH + N' (PatientICN);';
	EXEC sp_executesql @SQL;
END

PRINT 'Mental health scores duration (' + @Suffix + '): ' + CAST(DATEDIFF(SECOND, @StepStart, GETDATE()) AS VARCHAR) + ' seconds';
PRINT 'Output table: ' + @TblMH;

/*Below is just for getting a sample of patients to see what the data looks like*/
-- NOTE: DROP, SELECT INTO, and final SELECT must all run in the SAME
-- sp_executesql call -- a temp table created in dynamic SQL does not persist
-- across separate EXEC calls or back to the outer batch.
SET @SQL = N'
DROP TABLE IF EXISTS #sample_patients;

SELECT TOP 1000 PatientICN
INTO #sample_patients
FROM (SELECT DISTINCT PatientICN FROM ' + @TblMH + N') AS p
ORDER BY NEWID();

SELECT d.*
FROM ' + @TblMH + N' AS d
INNER JOIN #sample_patients AS s
	ON d.PatientICN = s.PatientICN;';
EXEC sp_executesql @SQL;

select count(*)
from OPCCCT_CIH.Dflt.acupuncture_mental_health_scores_all

select count(*)
from OPCCCT_CIH.Dflt.acupuncture_mental_health_scores_acu_only