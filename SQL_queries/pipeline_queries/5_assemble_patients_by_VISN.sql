/**************************************************************/
/*  Get the VISNs associated with all the referrals          */
/**************************************************************/
/*for VISTA*/
drop table if exists #VISTA_referral_VISN

SELECT a.*
      ,b.Sta3n
      ,c.VISN
into #VISTA_referral_VISN
FROM [OPCCCT_CIH].[Dflt].[VISTA_comm_care_orders] as a
    inner join cdwwork.con.consult as b on a.consultSID = b.consultSID
    inner join cdwwork.dim.vistAsite as c on b.sta3n = c.sta3n;

/* for Millennium*/
drop table if exists #MILL_referral_VISN

SELECT a.*,
    loc.VISN
into #MILL_referral_VISN
FROM [OPCCCT_CIH].[Dflt].[MILL_comm_care_orders] as a
    inner join [CDWWork2].[StaffMill].[Referral] as b
        on a.[ReferralSID] = b.[ReferralSID]
    inner join CDWWork2.EncMill.Encounter as e ON b.OutboundEncounterSID = e.EncounterSID
    inner JOIN CDWWork2.Mill.VALocations as loc ON e.OrganizationNameSID = loc.OrganizationNameSID;

/******** Aggregate the referral VISN data  ***************/
drop table if exists #patients_by_VISN

select PatientSID
      ,FiscalYear
      ,SourceSystem
      ,VISN
      ,ConsultSID as ReferralSID
      ,RequestDateTime
into #patients_by_VISN
from #VISTA_referral_VISN

UNION

select PatientSID
      ,FiscalYear
      ,SourceSystem
      ,VISN
      ,ReferralSID
      ,RequestDateTime
from #MILL_referral_VISN

--attach the patientICN so I can dedupe same people spanning VISTA
--and Millennium
drop table if exists #with_ICN;

WITH mill_ICN AS(
	SELECT	PersonSID as PatientSID
		,case when AliasName LIKE '%zz%' then null --This zz record was for 1 patient that appears to be fake and was causing issues
												   --so simply got rid of it
			  else left(cast(AliasName as varchar(50)), 10) end as PatientICN
	FROM [CDWWork2].[VeteranMill].[PersonAlias]
	where AliasPool = 'ICN'
)

select a.*
	  , case when b.PatientICN IS NULL THEN c.PatientICN
					ELSE b.PatientICN end as PatientICN
into #with_ICN
from #patients_by_VISN as a
	left join mill_ICN as b 
		on a.PatientSID = b.PatientSID
	left join CDWWork.patient.patient as c
		on a.PatientSID = c.PatientSID;

/************** Now attach the VA encounter Info as well***************/
drop table if exists opccct_CIH.dflt.ALL_ACUP_Referrals_and_Encounters;

select a.PatientSID
      ,a.PatientICN
      ,a.SrcSystem
      ,a.VISN
      ,a.VisitDateTime as eventDate
      ,CASE WHEN MONTH(a.VisitDateTime) >= 10 THEN YEAR(a.VisitDateTime) + 1
			ELSE YEAR(a.VisitDateTime) END AS FiscalYear
      ,a.visitSID as eventID
      ,'Encounter' as eventType
into opccct_CIH.dflt.ALL_ACUP_Referrals_and_Encounters
From [OPCCCT_CIH].[Dflt].[ALL_ACUP_VA_encounters] as a

UNION

select b.PatientSID
      ,b.PatientICN
      ,b.SourceSystem as SrcSytem
      ,b.VISN
      ,b.RequestDateTime AS eventDate
      ,b.FiscalYear
      ,b.ReferralSID as eventID
      ,'Referral' as eventType
from #with_ICN as b;

/**************************************************************/
/* we now have the basic list of patients that are gettign 
acupuncture by VISN. Need to compare that to the total patients
in all of these VISNs to get a rate of usage and see if one 
area is higher than others*/
/**************************************************************/

/*decided that this logic is not correct, excludes a lot of people that are
shown as receiving care throughout the year as not enrolled so that's clearly wrong
However, kept because it does have numbers close to the public numbers so maybe all
that's needed are additional tweaks

/*  Get list of enrolled Veterans. After some research, it seems that 
enrolled veterans is tracked in the CDWWORK.enrollment table. Even though CDWWORK
stores VISTA encounters, it also has some tables that span VISTA & Millenium because
it's the original data server and enrollment isn't a site specific (which EHR 
system the site is using). So this table should apply for all Vets*/
drop table if exists #eligibilitystatus;

select patienticn, max(EligibilityStatusDateTime) as last_status
into #eligibilitystatus
from cdwwork.patient.patient
where TestPatientFlag IS NULL
group by patienticn

drop table if exists #elig_status;

select distinct a.patienticn, a.PatientSID, a.eligibilitystatus
            , a.Eligibility, a.IneligibleReason, a.EligibilityStatusDateTime
into #elig_status
from cdwwork.patient.patient as a
    left join #eligibilitystatus as b on a.PatientICN=b.PatientICN
where a.EligibilityStatusDateTime = b.last_status or b.last_status is null


select *
from #elig_status
where patienticn = '1043542914'

drop table if exists #Enroll_temp

select c.PatientICN
      ,c.eligibilitystatus
      ,max(c.EligibilityStatusDateTime) as EligibilityStatusDateTime
      ,min(a.[EnrollmentDateTime]) as EnrollmentStartDate
      ,max(a.[EnrollmentEndDateTime]) as EnrollmentEndDate
into #Enroll_temp
from cdwwork.patient.enrollment as a
    inner join cdwwork.dim.enrollmentstatus as b
        on a.EnrollmentStatusSID = b.EnrollmentStatusSID
    inner join (select patientsid
                      ,max(EnteredDateTime) as last_mod_date
                from cdwwork.patient.enrollment
                group by patientsid) as curr
            on a.patientsid = curr.patientsid 
                and a.entereddatetime = curr.last_mod_date
    inner join (select *
                from #elig_status
                where (eligibilitystatus='VERIFIED' or eligibilitystatus LIKE '%PENDING%')
                     and Eligibility is not null and IneligibleReason IS NULL) as c
                    --and EligibilityStatusDateTime is not null
        on a.PatientSID=c.PatientSID
where b.EnrollmentCategory IN ('ENROLLED','NOT ENROLLED') 
group by c.PatientICN, eligibilitystatus;

        
/******** Build out columns for each FY to indicate if the patient was enrolled
that particular year********************************/
drop table if exists opccct_cih.dflt.ALL_Enrolled_Vets

select [PatientICN]
      ,min([EnrollmentStartDate]) as [EnrollmentStartDate]
      ,max([EnrollmentEndDate]) as [EnrollmentEndDate]
      ,max(case when ('2021-10-01' >= a.EnrollmentStartDate OR a.EnrollmentStartDate IS NULL)
                          AND (a.EnrollmentEndDate>='2020-10-01' OR a.EnrollmentEndDate IS NULL)
                          AND (a.eligibilitystatus='VERIFIED') --Unless the FY is the most recent/current, only include an eligibility status of VERIFIED
                                                               --Statuses of still 'pending' are temporary and don't apply to previous years because they would 
                                                               --not have eligibility in those years
                THEN 1 ELSE 0 END) AS enrolled_FY21
      ,max(case when ('2022-10-01' > a.EnrollmentStartDate OR a.EnrollmentStartDate IS NULL)
                          AND (a.EnrollmentEndDate>'2021-10-01' OR a.EnrollmentEndDate IS NULL)
                          AND (a.eligibilitystatus='VERIFIED')
                THEN 1 ELSE 0 END) AS enrolled_FY22
      ,max(case when ('2023-10-01' > a.EnrollmentStartDate OR a.EnrollmentStartDate IS NULL)
                          AND (a.EnrollmentEndDate>='2022-10-01' OR a.EnrollmentEndDate IS NULL)
                          AND (a.eligibilitystatus='VERIFIED')
                THEN 1 ELSE 0 END) AS enrolled_FY23
      ,max(case when ('2024-10-01' > a.EnrollmentStartDate OR a.EnrollmentStartDate IS NULL)
                          AND (a.EnrollmentEndDate>='2023-10-01' OR a.EnrollmentEndDate IS NULL)
                          AND (a.eligibilitystatus='VERIFIED')
                THEN 1 ELSE 0 END) AS enrolled_FY24
      ,max(case when ('2025-10-01' > a.EnrollmentStartDate OR a.EnrollmentStartDate IS NULL)
                          AND (a.EnrollmentEndDate>='2024-10-01' OR a.EnrollmentEndDate IS NULL)
                          AND (a.eligibilitystatus='VERIFIED')
                          THEN 1 ELSE 0 END) AS enrolled_FY25
      ,max(case when ('2026-10-01' > a.EnrollmentStartDate OR a.EnrollmentStartDate IS NULL)
                          AND (a.EnrollmentEndDate>='2025-10-01' OR a.EnrollmentEndDate IS NULL)
                          AND (a.eligibilitystatus='VERIFIED')
                THEN 1 ELSE 0 END) AS enrolled_FY26
into opccct_cih.dflt.ALL_Enrolled_Vets
from #Enroll_temp as a
where (a.EnrollmentStartDate<a.EnrollmentEndDate OR a.EnrollmentStartDate IS NULL OR a.EnrollmentEndDate IS NULL)
    AND (a.EnrollmentEndDate>='2020-10-01' OR a.EnrollmentEndDate IS NULL)
group by PatientICN;

/*************** Summarize by Year *****************************/
select sum(enrolled_FY22) as enrolled_FY22
      ,sum(enrolled_FY23) as enrolled_FY23
      ,sum(enrolled_FY24) as enrolled_FY24
      ,sum(enrolled_FY25) as enrolled_FY25
      ,sum(enrolled_FY26) as enrolled_FY26
from opccct_cih.dflt.ALL_Enrolled_Vets;

*/

/* =========================================================================
Got the query below from the ADR enrollment CDW factbook. It produces some 
numbers a bit lower than some VetPop published numbers I found elsewhere but
it's pretty close and since it's the same logic as the factbook, seems good
enough for our purposes. Can later be refined if a close match is necessary
   ========================================================================= */

-- The six fiscal-year reference dates
IF OBJECT_ID('tempdb..#fydates') IS NOT NULL DROP TABLE #fydates;
CREATE TABLE #fydates (FY VARCHAR(4), AsOfDate DATE);
INSERT INTO #fydates VALUES
    ('FY21','2021-10-01'),
    ('FY22','2022-10-01'),
    ('FY23','2023-10-01'),
    ('FY24','2024-10-01'),
    ('FY25','2025-10-01'),
    ('FY26','2026-10-01');

/* -------------------------------------------------------------------------
   Step 1: For each FY date, find the in-effect enrollment record per person
   and keep only those who were Verified/Enrolled with a live ICN status.
   Produces one row per (person, FY-they-were-enrolled-in).
   ------------------------------------------------------------------------- */
IF OBJECT_ID('tempdb..#enrolled') IS NOT NULL DROP TABLE #enrolled;

WITH snapshot AS
(
    SELECT
        dt.FY,
        h.MVIPersonSID,
        h.ADREnrollStatusSID,
        h.ADRPersonSID,
        ROW_NUMBER() OVER (
            PARTITION BY dt.FY, h.MVIPersonSID
            ORDER BY h.RecordModifiedDate DESC,
                     COALESCE(h.NextRecordModifiedDate, '2100-12-31') DESC,
                     h.RecordModifiedCount DESC
        ) AS MostRecentStatusChangeRecord
    FROM #fydates dt
    JOIN CDWWork.ADR.ADREnrollHistory h WITH (NOLOCK)
        ON CAST(CASE WHEN h.EnrollStartDate IS NOT NULL THEN h.EnrollStartDate
                     WHEN h.EnrollEndDate   IS NOT NULL THEN h.EnrollEndDate
                     ELSE h.RecordModifiedDate END AS DATE) < dt.AsOfDate
       AND CAST(COALESCE(h.NextRecordModifiedDate, '2100-12-31') AS DATE) >= dt.AsOfDate

)
SELECT DISTINCT s.FY, s.MVIPersonSID, d.adrpersonicn
INTO #enrolled
FROM snapshot s
    inner JOIN CDWWork.NDim.ADREnrollStatus b ON s.ADREnrollStatusSID = b.ADREnrollStatusSID
    inner JOIN CDWWork.Veteran.MVIPerson    c ON s.MVIPersonSID       = c.MVIPersonSID
    inner join cdwwork.veteran.adrperson as d on s.ADRPersonSID = d.ADRPersonSID
WHERE s.MostRecentStatusChangeRecord = 1
  AND c.ICNStatusCode IN ('P','T')
  AND b.EnrollStatusName   = 'Verified'
  AND b.EnrollCategoryName = 'Enrolled';

/* -------------------------------------------------------------------------
   Step 2: Pivot to one row per person with a binary flag per fiscal year.
   ------------------------------------------------------------------------- */
drop table if exists opccct_cih.dflt.ALL_Enrolled_Vets;

SELECT
    MVIPersonSID,
    adrpersonicn,
    MAX(CASE WHEN FY = 'FY21' THEN 1 ELSE 0 END) AS EnrolledFY21,
    MAX(CASE WHEN FY = 'FY22' THEN 1 ELSE 0 END) AS EnrolledFY22,
    MAX(CASE WHEN FY = 'FY23' THEN 1 ELSE 0 END) AS EnrolledFY23,
    MAX(CASE WHEN FY = 'FY24' THEN 1 ELSE 0 END) AS EnrolledFY24,
    MAX(CASE WHEN FY = 'FY25' THEN 1 ELSE 0 END) AS EnrolledFY25,
    MAX(CASE WHEN FY = 'FY26' THEN 1 ELSE 0 END) AS EnrolledFY26
into opccct_cih.dflt.ALL_Enrolled_Vets
FROM #enrolled
GROUP BY MVIPersonSID, adrpersonicn
ORDER BY adrpersonicn;

/* -------------------------------------------------------------------------
   OPTIONAL sanity checks -- run these to validate before trusting the flags.
   ------------------------------------------------------------------------- */
-- Per-FY totals (each should be reproducible by your single-date query,
-- and land near the ~9M VHA benchmark):
SELECT sum(EnrolledFY21) AS EnrolledFY21,
       sum(EnrolledFY22) AS EnrolledFY22,
       sum(EnrolledFY23) AS EnrolledFY23,
       sum(EnrolledFY24) AS EnrolledFY24,
       sum(EnrolledFY25) AS EnrolledFY25,
       sum(EnrolledFY26) AS EnrolledFY26
FROM opccct_cih.dflt.ALL_Enrolled_Vets

/**************************************************************/
/* Now i need to get the VISNs for all of the enrolled VETs   */
/* to see exactly where they live and to know where to assign them*/
/**************************************************************/

/**************************************************************/
/*  Millenium encounter locations. I'm using encounters to    */
/*  Determine where the enrolled Vets receive care & that is  */
/* How they're assigned to a VISN. If they have care across   */
/*  Multiple VISNs in 1 year, they're assigned to the VISN w/ */
/* the most recent encounter VISN for that year               */
/**************************************************************/
drop table if exists #mill_enc_locs;

SELECT [EncounterSID]
      ,PatientSID
	  ,PatientICN
      ,[CreateDateTime]
      ,CASE WHEN MONTH(a.[CreateDateTime]) >= 10 THEN YEAR(a.[CreateDateTime]) + 1
			ELSE YEAR(a.[CreateDateTime]) END AS FiscalYear
      ,VISN
into #mill_enc_locs
FROM [CDWWork2].[Mill].[PatientEncounterAll] as a
    inner join cdwwork2.mill.valocations as b on a.[OrganizationNameSID] = b.[OrganizationNameSID]
    inner join (SELECT	PersonSID as PatientSID
					    ,case when AliasName LIKE '%zz%' then null --This zz record was for 1 patient that appears to 
																    --be fake and was causing issues so simply got rid of it
							    else left(cast(AliasName as varchar(50)), 10) end as PatientICN
			    FROM [CDWWork2].[VeteranMill].[PersonAlias]
			    where AliasPool = 'ICN') as c on c.PatientSID = a.PersonSID;

/***********assign to a VISN per each FY*************/
select DISTINCt a.patientICN,
               b.FiscalYear,
               a.VISN as FY_VISN
from #mill_enc_locs as a
    inner join (select patienticn
                      ,FiscalYear
                      ,max(createdatetime) as lastEncFY_DT
                from #mill_enc_locs
                group by PatientICN,FiscalYear) as b on a.PatientICN=b.PatientICN
                                                  and a.FiscalYear = b.FiscalYear
where a.CreateDateTime=b.lastEncFY_DT;







/*
/* get the Millennium patientICNs*/
WITH mill_ICN AS(
	SELECT	PersonSID as PatientSID
		,case when AliasName LIKE '%zz%' then null --This zz record was for 1 patient that appears to be fake and was causing issues
												   --so simply got rid of it
			  else left(cast(AliasName as varchar(50)), 10) end as PatientICN
	FROM [CDWWork2].[VeteranMill].[PersonAlias]
	where AliasPool = 'ICN'
)

/* patients can span multiple VISNs for care if they move or maybe
are on the border of 2, get counts of each patientICN VISN combos*/
 select a.PatientICN
        ,a.PatientSID
        ,c.visn
        ,count(a.patientICN) as patient_VISN_count
into #p_visn_counts
 from mill_ICN as a
    inner join [CDWWork2].[SVeteranMill].[EncounterHealthPlan] as b
        on a.PatientSID = b.personsid
    inner join [CDWWork2].Mill.VALocations as c
        on b.OrganizationNameSID = c.OrganizationNameSID
group by a.PatientICN, a.PatientSID, c.VISN;

select PatientICN
      ,PatientSID
      ,max(patient_VISN_count) as max_visn_count
into #max_visns
from #p_visn_counts as a
group by a.PatientICN, a.PatientSID;

select a.PatientICN
      ,a.PatientSID
      ,a.visn
into #patient_primary_visn
from #p_visn_counts as a
    inner join #max_visns as b on a.PatientICN=b.PatientICN
where a.patient_VISN_count = b.max_visn_count;

select top 1000 a.*, b.OrganizationNameSID
from [CDWWork2].[VeteranMill].[PersonAlias] as a
    inner join [CDWWork2].[SVeteranMill].[EncounterHealthPlan] as b
            on a.PersonSID = b.personsid
*/