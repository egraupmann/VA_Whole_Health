/***************************************************************
PIT community-care acupuncture cohort

Purpose:
	- Identify acupuncture users in community care/PIT professional claims.
	- Create a unique encounter-level dataset for acupuncture services.
	- Create an individual patient-level cohort dataset for downstream
	  veteran-level joins.

This script applies the newer CIH PIT logic to acupuncture only:
	- uses CPT codes 97810, 97811, 97813, 97814 rather than the old
	  hard-coded PITProcedureCodeSID list
	- requires paid/current claim lines
	- keeps claims with status Accepted or PAID
	- maps PIT acupuncture claims to Acup. Trad. CC, matching the
	  newer PIT CIH script

The PIT scripts reviewed use PIT professional claims. The newer script
uses project/archive table names. This standalone version uses the
general CDWWork PIT tables used in the original acupuncture PIT script.
If your CDW extract uses archive/source table names, swap the FROM/JOIN
objects for the corresponding archive tables while keeping the logic.

CDW-Domain-Layout linkage fields used here:
	- PIT.PITProfessionalClaimDetails.PITPatientSID
	  -> SVeteran.PITPatient.PITPatientSID
	- PIT.PITProfessionalClaimDetails.PITClaimSID
	  -> PIT.PITClaim.PITClaimSID
	- PIT.PITProfessionalClaimDetails.PITProcedureCodeSID
	  -> NDim.PITProcedureCode.PITProcedureCodeSID
	- PIT.PITProfessionalClaimDetails.PITVAStationSID
	  -> NDim.PITVAStation.PITVAStationSID
	- PIT.PITProfessionalClaimDetails.PITPlaceOfServiceSID
	  -> NDim.PITPlaceOfService.PITPlaceOfServiceSID
	- PIT professional claim provider SIDs
	  -> SStaff.PITProvider.PITProviderSID
	- SVeteran.PITPatient.PatientICN, MemberID, and SSN are retained
	  for linkage. The bridge to broader veteran-level CDW tables is
	  SPatient.SPatient.PatientSID, found by PatientICN first, then
	  MemberID/SSN to SPatient.PatientSSN.

Output temp tables:
	- #pit_acu_claim_lines:
		one row per acupuncture PIT professional claim line
	- #pit_acu_encounters:
		one row per unique acupuncture community-care encounter, defined
		as cohort patient + service date + station
	- #pit_acu_patient_day:
		one row per cohort patient + acupuncture service date
	- #pit_acu_patient_cohort:
		one row per acupuncture community-care user
	- #pit_acu_patient_sid_crosswalk:
		all SPatient.PatientSID rows found for each community-care user,
		for downstream joins to broader CDW clinical domains

Notes:
	- PIT CPT logic does not distinguish BFA from traditional
	  acupuncture. The newer PIT CIH script maps acupuncture CPT claims
	  to Acup. Trad. CC, so this script does the same.
	- The default date range below matches the broader refined CDW pull.
	  PIT availability may differ by CDW environment and time period.
***************************************************************/

SET NOCOUNT ON;

DECLARE @StartDate date = CONVERT(date, '2022-10-01');
DECLARE @EndDate   date = CONVERT(date, '2026-06-30');

DECLARE @RequireLinkedSPatient bit = 1;
DECLARE @RequireVeteranFlag bit = 1;
DECLARE @ExcludePossibleTestPatients bit = 1;

/***************************************************************
Clean up temp tables
***************************************************************/

DROP TABLE IF EXISTS #pit_acu_cpt_lookup;
DROP TABLE IF EXISTS #pit_acu_claim_lines;
DROP TABLE IF EXISTS #pit_acu_encounters;
DROP TABLE IF EXISTS #pit_acu_patient_day;
DROP TABLE IF EXISTS #pit_acu_patient_cohort;
DROP TABLE IF EXISTS #pit_acu_patient_sid_crosswalk;

/***************************************************************
Newer PIT acupuncture CPT logic

The original PIT acupuncture script filtered on:
	PITProcedureCodeSID in (6019, 10373, 10419, 16036)

The newer PIT CIH script joins PITProcedureCode to a CPT lookup and
uses CPTCode for CIHType = Acup-Trad. This keeps that newer logic
without pulling non-acupuncture CIH services.
***************************************************************/

CREATE TABLE #pit_acu_cpt_lookup (
	CPTCode varchar(10) NOT NULL PRIMARY KEY,
	CIHType varchar(25) NOT NULL,
	Therapy varchar(50) NOT NULL
);

INSERT INTO #pit_acu_cpt_lookup (CPTCode, CIHType, Therapy)
VALUES
	('97810', 'Acup-Trad', 'Acup. Trad. CC'),
	('97811', 'Acup-Trad', 'Acup. Trad. CC'),
	('97813', 'Acup-Trad', 'Acup. Trad. CC'),
	('97814', 'Acup-Trad', 'Acup. Trad. CC');

/***************************************************************
Claim-line evidence table

This table is intentionally line-level for auditability. A single
acupuncture encounter can have multiple CPT claim lines, especially
when initial and add-on acupuncture codes are billed for the same date.
***************************************************************/

SELECT DISTINCT
	CAST('PIT Professional Claim' AS varchar(50)) AS CommunityCareSource,
	A.PITProfessionalClaimDetailsSID,
	A.PITClaimSID,
	A.PITPatientSID,
	A.BillingPITProviderSID,
	A.RenderingPITProviderSID,
	A.PITVAProgramSID,
	A.PITVAStationSID,
	A.PITPlaceOfServiceSID,
	A.PITETLBatchID,
	A.ServiceFromDate,
	A.ServiceToDate,
	CONVERT(date, A.ServiceFromDate) AS VisitDate,
	A.ServiceDate,
	A.PaidDate,
	A.ChargeAmount,
	A.PaidAmount,
	TRY_CONVERT(decimal(18, 2), A.ChargeAmount) AS ChargeAmountNumeric,
	TRY_CONVERT(decimal(18, 2), A.PaidAmount) AS PaidAmountNumeric,
	A.Units,
	TRY_CONVERT(decimal(18, 2), A.Units) AS UnitsNumeric,
	A.ModifierCode,
	A.ServiceLineNumber,
	A.InvoiceNumber,
	A.ObligationNumber,
	A.ProgramType,
	A.PayFlag,
	A.IsCurrentFlag,
	CL.ClaimStatus,
	CL.CurrentFlag AS ClaimCurrentFlag,
	PC.PITProcedureCodeSID,
	PC.PITProcedureCode,
	PC.PITProcedureCodeDescription,
	PC.CPTCategory,
	PC.MajorCPTCategory,
	CPT.CPTCode,
	CPT.CIHType,
	CPT.Therapy,
	VS.Station,
	VS.StationID AS Sta6a,
	SUBSTRING(VS.StationID, 1, 3) AS Sta3n,
	VS.VISN,
	VS.StateCode AS StationStateCode,
	VP.PITVAProgram,
	VP.PITVAProgramShortName,
	POS.PITPlaceOfService,
	POS.PITPlaceOfServiceDescription,
	RP.NPI AS RenderingProviderNPI,
	RP.ProviderName AS RenderingProviderName,
	RP.ProviderTypeName AS RenderingProviderTypeName,
	BP.NPI AS BillingProviderNPI,
	BP.ProviderName AS BillingProviderName,
	PP.MemberID AS PITMemberID,
	PP.SSN AS PITPatientSSN,
	PP.PatientICN AS PITPatientICN,
	PP.VeteranFlag AS PITVeteranFlag,
	PP.DependentFlag AS PITDependentFlag,
	PP.SexFlag AS PITSexFlag,
	PP.DateOfBirth AS PITDateOfBirth,
	SP.PatientSID,
	SP.ScrSSN,
	SP.SPatientICN,
	SP.PatientSSN AS SPatientSSN,
	SP.SPatientVeteranFlag,
	SP.CDWPossibleTestPatientFlag,
	CASE
		WHEN SP.PatientSID IS NULL THEN 'Not linked'
		WHEN SP.LinkPriority = 1 THEN 'PITPatient.PatientICN_to_SPatient.PatientICN'
		WHEN SP.LinkPriority = 2 THEN 'PITPatient.MemberID_to_SPatient.PatientSSN'
		WHEN SP.LinkPriority = 3 THEN 'PITPatient.SSN_to_SPatient.PatientSSN'
		ELSE 'Linked by fallback'
	END AS PatientLinkMethod,
	CASE
		WHEN SP.PatientSID IS NOT NULL THEN CONCAT('PatientSID:', CONVERT(varchar(50), SP.PatientSID))
		WHEN NULLIF(LTRIM(RTRIM(PP.PatientICN)), '') IS NOT NULL THEN CONCAT('PITPatientICN:', NULLIF(LTRIM(RTRIM(PP.PatientICN)), ''))
		WHEN NULLIF(LTRIM(RTRIM(PP.MemberID)), '') IS NOT NULL THEN CONCAT('PITMemberID:', NULLIF(LTRIM(RTRIM(PP.MemberID)), ''))
		ELSE CONCAT('PITPatientSID:', CONVERT(varchar(50), A.PITPatientSID))
	END AS CohortPatientKey
INTO #pit_acu_claim_lines
FROM CDWWork.PIT.PITProfessionalClaimDetails AS A
	INNER JOIN CDWWork.NDim.PITProcedureCode AS PC
		ON A.PITProcedureCodeSID = PC.PITProcedureCodeSID
	INNER JOIN #pit_acu_cpt_lookup AS CPT
		ON PC.PITProcedureCode = CPT.CPTCode
	INNER JOIN CDWWork.PIT.PITClaim AS CL
		ON A.PITClaimSID = CL.PITClaimSID
	LEFT JOIN CDWWork.SVeteran.PITPatient AS PP
		ON A.PITPatientSID = PP.PITPatientSID
	LEFT JOIN CDWWork.NDim.PITVAStation AS VS
		ON A.PITVAStationSID = VS.PITVAStationSID
	LEFT JOIN CDWWork.NDim.PITVAProgram AS VP
		ON A.PITVAProgramSID = VP.PITVAProgramSID
	LEFT JOIN CDWWork.NDim.PITPlaceOfService AS POS
		ON A.PITPlaceOfServiceSID = POS.PITPlaceOfServiceSID
	LEFT JOIN CDWWork.SStaff.PITProvider AS RP
		ON A.RenderingPITProviderSID = RP.PITProviderSID
	LEFT JOIN CDWWork.SStaff.PITProvider AS BP
		ON A.BillingPITProviderSID = BP.PITProviderSID
	OUTER APPLY (
		SELECT TOP (1)
			SP0.PatientSID,
			SP0.ScrSSN,
			SP0.PatientICN AS SPatientICN,
			SP0.PatientSSN,
			SP0.VeteranFlag AS SPatientVeteranFlag,
			SP0.CDWPossibleTestPatientFlag,
			CASE
				WHEN NULLIF(LTRIM(RTRIM(PP.PatientICN)), '') IS NOT NULL
					AND PP.PatientICN = SP0.PatientICN THEN 1
				WHEN NULLIF(LTRIM(RTRIM(PP.MemberID)), '') IS NOT NULL
					AND PP.MemberID = SP0.PatientSSN THEN 2
				WHEN NULLIF(LTRIM(RTRIM(PP.SSN)), '') IS NOT NULL
					AND PP.SSN = SP0.PatientSSN THEN 3
				ELSE 4
			END AS LinkPriority
		FROM CDWWork.SPatient.SPatient AS SP0
		WHERE (
				NULLIF(LTRIM(RTRIM(PP.PatientICN)), '') IS NOT NULL
				AND PP.PatientICN = SP0.PatientICN
			)
			OR (
				NULLIF(LTRIM(RTRIM(PP.MemberID)), '') IS NOT NULL
				AND PP.MemberID = SP0.PatientSSN
			)
			OR (
				NULLIF(LTRIM(RTRIM(PP.SSN)), '') IS NOT NULL
				AND PP.SSN = SP0.PatientSSN
			)
		ORDER BY
			CASE
				WHEN NULLIF(LTRIM(RTRIM(PP.PatientICN)), '') IS NOT NULL
					AND PP.PatientICN = SP0.PatientICN THEN 1
				WHEN NULLIF(LTRIM(RTRIM(PP.MemberID)), '') IS NOT NULL
					AND PP.MemberID = SP0.PatientSSN THEN 2
				WHEN NULLIF(LTRIM(RTRIM(PP.SSN)), '') IS NOT NULL
					AND PP.SSN = SP0.PatientSSN THEN 3
				ELSE 4
			END,
			CASE WHEN SP0.VeteranFlag = 'Y' THEN 0 ELSE 1 END,
			CASE WHEN ISNULL(SP0.CDWPossibleTestPatientFlag, 'N') = 'Y' THEN 1 ELSE 0 END,
			SP0.PatientSID
	) AS SP
WHERE A.ServiceFromDate >= @StartDate
	AND A.ServiceFromDate < DATEADD(day, 1, @EndDate)
	AND A.PayFlag = 'Y'
	AND A.IsCurrentFlag = 'Y'
	AND CL.ClaimStatus IN ('Accepted', 'PAID')
	AND (@RequireLinkedSPatient = 0 OR SP.PatientSID IS NOT NULL)
	AND (@RequireVeteranFlag = 0 OR COALESCE(SP.SPatientVeteranFlag, PP.VeteranFlag) = 'Y')
	AND (@ExcludePossibleTestPatients = 0 OR ISNULL(SP.CDWPossibleTestPatientFlag, 'N') <> 'Y');

/***************************************************************
Unique encounter-level dataset

Encounter definition:
	cohort patient + service date + station

This matches the spirit of the newer PIT patient-day output while
retaining station and claim-line audit fields. If a patient has multiple
acupuncture CPT lines on the same day at the same station, those lines
collapse to one encounter row.
***************************************************************/

SELECT
	CLN.CohortPatientKey,
	MAX(CLN.PatientSID) AS PatientSID,
	MAX(CLN.ScrSSN) AS ScrSSN,
	MAX(CLN.SPatientICN) AS SPatientICN,
	MAX(CLN.SPatientSSN) AS SPatientSSN,
	MAX(CLN.PITPatientSID) AS PITPatientSID,
	MAX(CLN.PITMemberID) AS PITMemberID,
	MAX(CLN.PITPatientICN) AS PITPatientICN,
	MAX(CLN.PITPatientSSN) AS PITPatientSSN,
	MAX(CLN.PatientLinkMethod) AS PatientLinkMethod,
	MAX(CLN.PITVeteranFlag) AS PITVeteranFlag,
	MAX(CLN.SPatientVeteranFlag) AS SPatientVeteranFlag,
	MAX(CLN.CDWPossibleTestPatientFlag) AS CDWPossibleTestPatientFlag,
	CLN.VisitDate,
	MIN(CLN.ServiceFromDate) AS FirstServiceFromDate,
	MAX(CLN.ServiceToDate) AS LastServiceToDate,
	MAX(CLN.Sta6a) AS Sta6a,
	MAX(CLN.Sta3n) AS Sta3n,
	MAX(CLN.Station) AS Station,
	MAX(CLN.VISN) AS VISN,
	MAX(CLN.StationStateCode) AS StationStateCode,
	MAX(CLN.PITVAProgramSID) AS PITVAProgramSID,
	MAX(CLN.PITVAProgram) AS PITVAProgram,
	MAX(CLN.PITVAProgramShortName) AS PITVAProgramShortName,
	MAX(CLN.ProgramType) AS ProgramType,
	MAX(CLN.PITPlaceOfServiceSID) AS PITPlaceOfServiceSID,
	MAX(CLN.PITPlaceOfService) AS PITPlaceOfService,
	MAX(CLN.PITPlaceOfServiceDescription) AS PITPlaceOfServiceDescription,
	MAX(CLN.Therapy) AS Therapy,
	MAX(CASE WHEN CLN.CPTCode = '97810' THEN 1 ELSE 0 END) AS HasCPT97810,
	MAX(CASE WHEN CLN.CPTCode = '97811' THEN 1 ELSE 0 END) AS HasCPT97811,
	MAX(CASE WHEN CLN.CPTCode = '97813' THEN 1 ELSE 0 END) AS HasCPT97813,
	MAX(CASE WHEN CLN.CPTCode = '97814' THEN 1 ELSE 0 END) AS HasCPT97814,
	COUNT(DISTINCT CLN.PITClaimSID) AS ClaimCount,
	COUNT(DISTINCT CLN.PITProfessionalClaimDetailsSID) AS ClaimLineCount,
	MIN(CLN.PITClaimSID) AS RepresentativePITClaimSID,
	MIN(CLN.PITProfessionalClaimDetailsSID) AS RepresentativePITProfessionalClaimDetailsSID,
	SUM(ISNULL(CLN.UnitsNumeric, 0)) AS TotalUnits,
	SUM(ISNULL(CLN.ChargeAmountNumeric, 0)) AS TotalChargeAmount,
	SUM(ISNULL(CLN.PaidAmountNumeric, 0)) AS TotalPaidAmount,
	MAX(CLN.RenderingProviderNPI) AS RenderingProviderNPI,
	MAX(CLN.RenderingProviderName) AS RenderingProviderName,
	MAX(CLN.RenderingProviderTypeName) AS RenderingProviderTypeName,
	MAX(CLN.BillingProviderNPI) AS BillingProviderNPI,
	MAX(CLN.BillingProviderName) AS BillingProviderName
INTO #pit_acu_encounters
FROM #pit_acu_claim_lines AS CLN
GROUP BY
	CLN.CohortPatientKey,
	CLN.VisitDate,
	CLN.Sta6a;

/***************************************************************
Patient-day dataset

This is the closest PIT equivalent to the newer script's
temp_pit_cih_patday output, limited to acupuncture.
***************************************************************/

SELECT DISTINCT
	ENC.CohortPatientKey,
	ENC.PatientSID,
	ENC.ScrSSN,
	ENC.SPatientICN,
	ENC.SPatientSSN,
	ENC.PITPatientSID,
	ENC.PITMemberID,
	ENC.PITPatientICN,
	ENC.PatientLinkMethod,
	ENC.VisitDate,
	ENC.Therapy
INTO #pit_acu_patient_day
FROM #pit_acu_encounters AS ENC;

/***************************************************************
Individual patient cohort dataset
***************************************************************/

SELECT
	ENC.CohortPatientKey,
	MAX(ENC.PatientSID) AS PatientSID,
	MAX(ENC.ScrSSN) AS ScrSSN,
	MAX(ENC.SPatientICN) AS SPatientICN,
	MAX(ENC.SPatientSSN) AS SPatientSSN,
	MAX(ENC.PITPatientSID) AS PITPatientSID,
	MAX(ENC.PITMemberID) AS PITMemberID,
	MAX(ENC.PITPatientICN) AS PITPatientICN,
	MAX(ENC.PITPatientSSN) AS PITPatientSSN,
	MAX(ENC.PatientLinkMethod) AS PatientLinkMethod,
	MAX(ENC.PITVeteranFlag) AS PITVeteranFlag,
	MAX(ENC.SPatientVeteranFlag) AS SPatientVeteranFlag,
	MAX(ENC.CDWPossibleTestPatientFlag) AS CDWPossibleTestPatientFlag,
	MIN(ENC.VisitDate) AS FirstAcupunctureCCVisitDate,
	MAX(ENC.VisitDate) AS LastAcupunctureCCVisitDate,
	COUNT(*) AS AcupunctureCCEncounterCount,
	COUNT(DISTINCT ENC.VisitDate) AS AcupunctureCCPatientDayCount,
	SUM(ENC.ClaimCount) AS AcupunctureCCClaimCount,
	SUM(ENC.ClaimLineCount) AS AcupunctureCCClaimLineCount,
	COUNT(DISTINCT ENC.Sta6a) AS AcupunctureCCStationCount,
	SUM(ENC.TotalUnits) AS TotalUnits,
	SUM(ENC.TotalChargeAmount) AS TotalChargeAmount,
	SUM(ENC.TotalPaidAmount) AS TotalPaidAmount,
	MAX(ENC.HasCPT97810) AS EverCPT97810,
	MAX(ENC.HasCPT97811) AS EverCPT97811,
	MAX(ENC.HasCPT97813) AS EverCPT97813,
	MAX(ENC.HasCPT97814) AS EverCPT97814
INTO #pit_acu_patient_cohort
FROM #pit_acu_encounters AS ENC
GROUP BY ENC.CohortPatientKey;

/***************************************************************
PatientSID crosswalk for downstream CDW joins

The individual patient cohort is one row per community-care user.
For clinical domains that require PatientSID, use this crosswalk to
retrieve all SPatient.PatientSID rows linked by PatientICN first, then
ScrSSN, then PIT MemberID/SSN to SPatient.PatientSSN.
***************************************************************/

SELECT DISTINCT
	COH.CohortPatientKey,
	SPX.PatientSID,
	SPX.Sta3n,
	SPX.PatientICN,
	SPX.ScrSSN,
	SPX.PatientSSN,
	SPX.VeteranFlag,
	SPX.TestPatientFlag,
	SPX.CDWPossibleTestPatientFlag,
	CASE
		WHEN COH.SPatientICN IS NOT NULL AND COH.SPatientICN = SPX.PatientICN
			THEN 'Cohort.PatientICN_to_SPatient.PatientICN'
		WHEN COH.ScrSSN IS NOT NULL AND COH.ScrSSN = SPX.ScrSSN
			THEN 'Cohort.ScrSSN_to_SPatient.ScrSSN'
		WHEN COH.PITMemberID IS NOT NULL AND COH.PITMemberID = SPX.PatientSSN
			THEN 'Cohort.PITMemberID_to_SPatient.PatientSSN'
		WHEN COH.PITPatientSSN IS NOT NULL AND COH.PITPatientSSN = SPX.PatientSSN
			THEN 'Cohort.PITPatientSSN_to_SPatient.PatientSSN'
		ELSE 'Linked by fallback'
	END AS PatientSIDLinkMethod
INTO #pit_acu_patient_sid_crosswalk
FROM #pit_acu_patient_cohort AS COH
	INNER JOIN CDWWork.SPatient.SPatient AS SPX
		ON (
				COH.SPatientICN IS NOT NULL
				AND COH.SPatientICN = SPX.PatientICN
			)
			OR (
				COH.ScrSSN IS NOT NULL
				AND COH.ScrSSN = SPX.ScrSSN
			)
			OR (
				COH.PITMemberID IS NOT NULL
				AND COH.PITMemberID = SPX.PatientSSN
			)
			OR (
				COH.PITPatientSSN IS NOT NULL
				AND COH.PITPatientSSN = SPX.PatientSSN
			)
WHERE (@RequireVeteranFlag = 0 OR SPX.VeteranFlag = 'Y')
	AND (@ExcludePossibleTestPatients = 0 OR ISNULL(SPX.CDWPossibleTestPatientFlag, 'N') <> 'Y');

/***************************************************************
Review counts and outputs
***************************************************************/

SELECT
	COUNT(*) AS AcupunctureCCClaimLineRows,
	COUNT(DISTINCT CohortPatientKey) AS AcupunctureCCUsersFromClaimLines
FROM #pit_acu_claim_lines;

SELECT
	COUNT(*) AS AcupunctureCCEncounterRows,
	COUNT(DISTINCT CohortPatientKey) AS AcupunctureCCUsersFromEncounters
FROM #pit_acu_encounters;

SELECT
	COUNT(*) AS AcupunctureCCPatientRows
FROM #pit_acu_patient_cohort;

SELECT
	COUNT(*) AS AcupunctureCCPatientSIDCrosswalkRows,
	COUNT(DISTINCT CohortPatientKey) AS AcupunctureCCUsersWithCrosswalkSID
FROM #pit_acu_patient_sid_crosswalk;

SELECT *
FROM #pit_acu_encounters
ORDER BY CohortPatientKey, VisitDate, Sta6a;

SELECT *
FROM #pit_acu_patient_cohort
ORDER BY FirstAcupunctureCCVisitDate, CohortPatientKey;

SELECT *
FROM #pit_acu_patient_sid_crosswalk
ORDER BY CohortPatientKey, Sta3n, PatientSID;
