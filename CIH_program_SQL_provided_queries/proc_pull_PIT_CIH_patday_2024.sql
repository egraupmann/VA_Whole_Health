/* procedure to pull community care CIH from PIT tables */
/* last updated by Claire Chen | 02/24/2023 */

USE [ORD_Fix_202309007D];
GO

DROP PROC IF EXISTS WH_CIH.MakePITCIHPatday
GO
CREATE PROC WH_CIH.MakePITCIHPatday(
	@StartDateTime varchar(25),
	@EndDateTime varchar(25)
	)
AS
BEGIN

/* collect claims */

DROP TABLE IF EXISTS #cpt_codes;
SELECT DISTINCT CPTCode 
	, CIHType
INTO #cpt_codes
FROM WH_CIH.CPT 
WHERE (CIHType = 'Acup-Trad'
	OR CIHType = 'Chiropractic'
	OR CIHType = 'Massage');

DROP TABLE IF EXISTS #PITClaimDetails;
SELECT DISTINCT G.ScrSSN 
	,G.PatientSID
	--, A.PITPatientSID
	--, F.MemberID
	, C.StationID
	, A.ServiceFromDate
	, CASE WHEN	
		H.CIHType = 'Acup-Trad' THEN 'Acup. Trad. CC'
		WHEN H.CIHType = 'Chiropractic' THEN 'Chiropractic CC'
		WHEN H.CIHType = 'Massage' THEN 'Massage CC' 
		END AS therapy
	, A.PayFlag
	, A.IsCurrentFlag
	, E.ClaimStatus
Into #PITClaimDetails 
FROM [ORD_Fix_202309007D].[Src].PIT_PITProfessionalClaimDetails_Archive A 
	INNER JOIN CDWWork_Archive.NDim.PITProcedureCode B 
		ON A.PITProcedureCodeSID = B. PITProcedureCodeSID
	LEFT JOIN CDWWork_Archive.ndim.PITVAStation C 
		ON A.PITVAStationSID = C.PITVAStationSID
	LEFT JOIN CDWWork_Archive.ndim.PITVAProgram D 
		ON A.PITVAProgramSID = D.PITVAProgramSID
	INNER JOIN [ORD_Fix_202309007D].[Src].[PIT_PITClaim_Archive] E 
		ON A.PITClaimSID = E.PITClaimSID
	LEFT JOIN [ORD_Fix_202309007D].[Src].[SVeteran_PITPatient_Archive] F
		ON A.PITPatientSID = F.PITPatientSID
	LEFT JOIN [ORD_Fix_202309007D].[Src].[Spatient_Spatient] G
		ON F.MemberID = G.PatientSSN
	INNER JOIN [ORD_Fix_202309007D].[Dflt].[CohortForJamie] as coh
			  ON (g.patientsid = coh.patientsid)
	LEFT JOIN #cpt_codes H
		ON B.PITProcedureCode = H.CPTCode 
/* filter to CPT codes for any of acup-trad, massage, or chiro */
WHERE H.CPTCode IS NOT NULL								
	AND A.ServiceFromDate >= CONVERT(date, @StartDateTime) 
	AND A.ServiceFromDate <= CONVERT(date, @EndDateTime) 
	AND A.PayFlag = 'Y'
	AND A.IsCurrentFlag = 'Y'
	AND E.ClaimStatus IN ('Accepted', 'PAID');

/* get distinct patient-day-therapies */
DROP TABLE IF EXISTS WH_CIH.temp_pit_cih_patday;
SELECT DISTINCT ScrSSN
	,PatientSID
	, StationID as Sta6a
	, SUBSTRING(StationID, 1, 3) AS Sta3n
	, ServiceFromDate as VisitDate
	, therapy
INTO WH_CIH.temp_pit_cih_patday
FROM #PITClaimDetails;

END