/* PROC to apply exclusions across all CIH therapies */
/* uses all combined therapies from proc_pull_VA_CIH_visits */
/* updated 08/04/2026. Code originally provided by Jamie Douglas at the VA*/

/**** convert consolidated visits table into wide format per VisitSID ****/

DROP TABLE IF EXISTS #acup;
SELECT DISTINCT VisitSID, strong_evid as acup_ST, weak_evid as acup_WK
INTO #acup 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Acup-Trad', 'Acup-BFA');

DROP TABLE IF EXISTS #bio;
SELECT DISTINCT VisitSID, strong_evid as bio_ST, weak_evid as bio_WK
INTO #bio 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Biofeedback');

DROP TABLE IF EXISTS #chiro;
SELECT DISTINCT VisitSID, strong_evid as chiro_ST, weak_evid as chiro_WK
INTO #chiro 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Chiropractic'); 

DROP TABLE IF EXISTS #gima;
SELECT DISTINCT VisitSID, strong_evid as gima_ST, weak_evid as gima_WK
INTO #gima 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Guided Imagery');

DROP TABLE IF EXISTS #hyp;
SELECT DISTINCT VisitSID, strong_evid as hyp_ST, weak_evid as hyp_WK
INTO #hyp 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Hypnosis');

DROP TABLE IF EXISTS #mass;
SELECT DISTINCT VisitSID, strong_evid as mass_ST, weak_evid as mass_WK
INTO #mass 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Massage');

DROP TABLE IF EXISTS #med;
SELECT DISTINCT VisitSID, strong_evid as med_ST, weak_evid as med_WK
INTO #med 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Meditation');

DROP TABLE IF EXISTS #phys;
SELECT DISTINCT VisitSID, strong_evid as pt_ST, weak_evid as pt_WK
INTO #phys 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Physical Therapy');

DROP TABLE IF EXISTS #taichi;
SELECT DISTINCT VisitSID, strong_evid as taic_ST, weak_evid as taic_WK
INTO #taichi 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('TaiChi');

DROP TABLE IF EXISTS #yoga;
SELECT DISTINCT VisitSID, strong_evid as yoga_ST, weak_evid as yoga_WK
INTO #yoga 
FROM OPCCCT_CIH.dflt.temp_consolidated_methods
WHERE CIHType in ('Yoga');

DROP TABLE IF EXISTS #cih_all_wide;
SELECT DISTINCT V.VisitSID
	, CASE WHEN A.acup_ST  is not null THEN A.acup_ST ELSE 0 END AS acup_ST
	, CASE WHEN A.acup_WK  is not null THEN A.acup_WK ELSE 0 END AS acup_WK
	, CASE WHEN B.bio_ST   is not null THEN B.bio_ST ELSE 0 END AS bio_ST
	, CASE WHEN B.bio_WK   is not null THEN B.bio_WK ELSE 0 END AS bio_WK
	, CASE WHEN C.chiro_ST is not null THEN C.chiro_ST ELSE 0 END AS chiro_ST
	, CASE WHEN C.chiro_WK is not null THEN C.chiro_WK ELSE 0 END AS chiro_WK
	, CASE WHEN D.gima_ST  is not null THEN D.gima_ST ELSE 0 END AS gima_ST
	, CASE WHEN D.gima_WK  is not null THEN D.gima_WK ELSE 0 END AS gima_WK
	, CASE WHEN E.hyp_ST   is not null THEN E.hyp_ST ELSE 0 END AS hyp_ST
	, CASE WHEN E.hyp_WK   is not null THEN E.hyp_WK ELSE 0 END AS hyp_WK
	, CASE WHEN F.mass_ST  is not null THEN F.mass_ST ELSE 0 END AS mass_ST
	, CASE WHEN F.mass_WK  is not null THEN F.mass_WK ELSE 0 END AS mass_WK
	, CASE WHEN G.med_ST   is not null THEN G.med_ST ELSE 0 END AS med_ST
	, CASE WHEN G.med_WK   is not null THEN G.med_WK ELSE 0 END AS med_WK
	, CASE WHEN H.pt_ST    is not null THEN H.pt_ST ELSE 0 END AS pt_ST
	, CASE WHEN H.pt_WK    is not null THEN H.pt_WK ELSE 0 END AS pt_WK
	, CASE WHEN I.taic_ST  is not null THEN I.taic_ST ELSE 0 END AS taic_ST
	, CASE WHEN I.taic_WK  is not null THEN I.taic_WK ELSE 0 END AS taic_WK
	, CASE WHEN J.yoga_ST  is not null THEN J.yoga_ST ELSE 0 END AS yoga_ST
	, CASE WHEN J.yoga_WK  is not null THEN J.yoga_WK ELSE 0 END AS yoga_WK
	/**** assign indicator columns for whether each visit is identified as a specific therapy ****/
	, CASE WHEN acup_ST = 1 THEN 1 
		WHEN acup_ST = 0 AND acup_WK = 1 AND (coalesce(bio_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) + coalesce(hyp_ST, 0) 
		+ coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1
		ELSE 0 END AS Acup
	, CASE WHEN bio_ST = 1 THEN 1
		WHEN bio_ST = 0 AND acup_ST = 0 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) + coalesce(hyp_ST, 0) 
		+ coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0)  THEN 1
		ELSE 0 END AS Bio
	, CASE WHEN chiro_ST = 1 THEN 1
		WHEN chiro_ST = 0 AND chiro_WK = 1 
			AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) + coalesce(hyp_ST, 0) 
			+ coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0)
			+ coalesce(acup_WK, 0) + coalesce(bio_WK, 0) + coalesce(gima_WK, 0) + coalesce(hyp_WK, 0) 
			+ coalesce(mass_WK, 0) + coalesce(med_WK, 0) + coalesce(pt_WK, 0) + coalesce(taic_WK, 0) + coalesce(yoga_WK,0)= 0) THEN 1
		WHEN chiro_ST = 0 and chiro_WK = 1
			AND ((acup_ST = 0 AND acup_WK = 1) OR (bio_ST = 0 AND bio_WK = 1) OR (gima_ST = 0 AND gima_WK = 1) OR (hyp_ST = 0 and hyp_WK = 1)
			OR (mass_ST = 0 and mass_WK = 1) OR (med_ST = 0 and med_WK = 1) OR (pt_ST = 0 and pt_WK = 1) OR (taic_ST = 0 and taic_WK = 1)
			OR (yoga_ST = 0 and yoga_ST = 1)) THEN 0
		ELSE 0 END AS Chiro
	, CASE WHEN gima_ST = 1 THEN 1
		WHEN gima_ST = 0 AND gima_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(hyp_ST, 0) 
			+ coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1
		ELSE 0 END AS Gima
	, CASE WHEN hyp_ST = 1 THEN 1
		WHEN hyp_ST = 0 AND hyp_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) 
			+ coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1
		ELSE 0 END AS Hyp
	, CASE WHEN mass_ST = 1 THEN 1
		WHEN mass_ST = 0 AND mass_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) 
			+ coalesce(hyp_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1 
		ELSE 0 END AS Mass
	, CASE WHEN med_ST = 1 THEN 1
		WHEN med_ST = 0 AND med_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) 
			+ coalesce(hyp_ST, 0) + coalesce(mass_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1
		ELSE 0 END AS Med
	, CASE WHEN pt_ST = 1 THEN 1
		WHEN pt_ST = 0 AND pt_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) 
			+ coalesce(hyp_ST, 0) + coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(taic_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1
		ELSE 0 END AS Phys
	, CASE WHEN taic_ST = 1 THEN 1
		WHEN taic_ST = 0 AND taic_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) 
			+ coalesce(hyp_ST, 0) + coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(yoga_ST,0) = 0) THEN 1
		ELSE 0 END AS Taic
	, CASE WHEN yoga_ST = 1 THEN 1
		WHEN yoga_ST = 0 AND yoga_WK = 1 AND (coalesce(acup_ST, 0) + coalesce(chiro_ST, 0) + coalesce(chiro_ST, 0) + coalesce(gima_ST, 0) 
			+ coalesce(hyp_ST, 0) + coalesce(mass_ST, 0) + coalesce(med_ST, 0) + coalesce(pt_ST, 0) + coalesce(taic_ST,0) = 0) THEN 1
		ELSE 0 END AS Yoga
INTO #cih_all_wide
FROM (SELECT DISTINCT VisitSID from OPCCCT_CIH.dflt.temp_consolidated_methods) V
	LEFT JOIN #acup   A ON A.VisitSID = V.VisitSID
	LEFT JOIN #bio    B ON B.VisitSID = V.VisitSID
	LEFT JOIN #chiro  C ON C.VisitSID = V.VisitSID
	LEFT JOIN #gima   D ON D.VisitSID = V.VisitSID
	LEFT JOIN #hyp    E ON E.VisitSID = V.VisitSID
	LEFT JOIN #mass   F ON F.VisitSID = V.VisitSID
	LEFT JOIN #med    G ON G.VisitSID = V.VisitSID
	LEFT JOIN #phys   H ON H.VisitSID = V.VisitSID
	LEFT JOIN #taichi I ON I.VisitSID = V.VisitSID
	LEFT JOIN #yoga   J ON J.VisitSID = V.VisitSID;

/**** re-create long format of consolidated visits after applying exclusions ****/

drop table if exists OPCCCT_CIH.dflt.temp_consolidated_methods_cih;
with intermed as (
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Acup = 1 AND A.CIHType in ('Acup-Trad', 'Acup-BFA')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Bio = 1 AND A.CIHType in ('Biofeedback')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Chiro = 1 AND A.CIHType in ('Chiropractic')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Gima = 1 AND A.CIHType in ('Guided Imagery')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Hyp = 1 AND A.CIHType in ('Hypnosis')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Mass = 1 AND A.CIHType in ('Massage')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Med = 1 AND A.CIHType in ('Meditation')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Phys = 1 AND A.CIHType in ('Physical Therapy')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Taic = 1 AND A.CIHType in ('TaiChi')
	UNION
	SELECT DISTINCT ScrSSN, PatientSID, V.VisitSID, VisitDate, CIHType, Sta6a, Tele, PrimaryStopCode, SecondaryStopCode
		, CPT, CPT_num_terms, CPT_codes, NT, NT_num_terms, NT_terms, NT_inclusions, LocName, A.LocationName, LN_inclusions
		, HF, HF_num_terms, HF_terms, HF_inclusions, CHAR4, CHAR4_code, StopCode
	FROM #cih_all_wide V INNER JOIN OPCCCT_CIH.dflt.temp_consolidated_methods A on V.VisitSID = A.VisitSID WHERE V.Yoga = 1 AND A.CIHType in ('Yoga')
)
select *
INTO OPCCCT_CIH.dflt.temp_consolidated_methods_cih 
FROM intermed;
