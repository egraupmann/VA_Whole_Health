/* procedure to pull community care CIH from IVC_CDS tables (consolidated community care tables) */
/* last updated by Claire Chen | 06/13/2023 */
/* runs on the A06 server for now (will need to be transfered to RB03 once CIHEC is migrated to that server */

/* some notes on IVC_CDS database

link to data documentation: https://vaww.virec.research.va.gov/Reports/DR/DR-IVC-CDS.pdf

Data sources
	- VistA Fee Basis Package (Fee)
	- Fee Basis Claims System (FBCS)
	- Electronic Claims Adjudication Management System (eCAMS)
	- Community Care Reimbursement System (CCRS)

Data currently only goes back to FY19 - DO NOT PULL for earlier claims
*/


USE [ORD_Fix_20260720];
GO

DROP PROC IF EXISTS WH_CIH.MakeIVCCDS_CIHPatday
GO
CREATE PROC WH_CIH.MakeIVCCDS_CIHPatday(
	@StartDateTime varchar(25),
	@EndDateTime varchar(25)
	)
AS
BEGIN

--SELECT TOP 100 * FROM CDWWork.ivc_cds.CDS_Claim_Header;
--SELECT TOP 100 * FROM CDWWork.ivc_cds.CDS_Claim_Line;

/* collect claims */

DROP TABLE IF EXISTS #cpt_codes;
SELECT DISTINCT CPTCode 
	, CIHType
INTO #cpt_codes
FROM WH_CIH.CPT 
WHERE (CIHType = 'Acup-Trad'
	OR CIHType = 'Chiropractic'
	OR CIHType = 'Massage');

DROP TABLE IF EXISTS #IVCClaimDetails;
SELECT DISTINCT E.ScrSSN
	,E.PatientSID
	,C.Patient_ICN
	, C.Patient_SSN
	, C.Station_Number
	, C.ClaimID
	, C.Claim_Status_ID
	, C.Service_Start_Date
	, C.Service_End_Date
	, A.Line_Status_ID
	, C.ClaimSID
	, CASE WHEN	
		B.CIHType = 'Acup-Trad' THEN 'Acup. Trad. CC'
		WHEN B.CIHType = 'Chiropractic' THEN 'Chiropractic CC'
		WHEN B.CIHType = 'Massage' THEN 'Massage CC' 
		END AS therapy
	, A.Paid_Date
	, C.IsCurrent
	, D.Status_Description AS Claim_Status
	, D2.Status_Description AS Line_Status
	, C.Source_System
Into #IVCClaimDetails 
FROM Src.ivc_cds_CDS_Claim_Line A 
INNER JOIN #cpt_codes B 
	ON A.Procedure_code = B.CPTCode
LEFT JOIN Src.ivc_cds_CDS_Claim_Header C 
	ON A.ClaimID = C.ClaimID
LEFT JOIN Src.ivc_cds_CDS_Claim_Status D 
	ON C.Claim_Status_ID = D.Status_ID
LEFT JOIN Src.ivc_cds_CDS_Claim_Status D2
	ON A.Line_Status_ID = D2.Status_ID
LEFT JOIN Src.SPatient_SPatient E 
	ON C.Patient_ICN = E.PatientICN
/* filter to CPT codes for any of acup-trad, massage, or chiro */
WHERE B.CPTCode IS NOT NULL	
	AND C.Service_Start_Date between CONVERT(date, @StartDateTime) and  CONVERT(date, @EndDateTime) 

	AND C.IsCurrent = 'Y'
	AND D2.Status_Description IN ('APPROVED', 'PAID');

SELECT * FROM #IVCClaimDetails;

/* get distinct patient-day-therapies */
DROP TABLE IF EXISTS WH_CIH.temp_ivccds_cih_patday;
SELECT DISTINCT ScrSSN,
	PatientSID
	, Station_Number as Sta6a
	, SUBSTRING(Station_Number, 1, 3) AS Sta3n
	, Service_Start_Date as VisitDate
	, therapy
INTO WH_CIH.temp_ivccds_cih_patday
FROM #IVCClaimDetails;

END

