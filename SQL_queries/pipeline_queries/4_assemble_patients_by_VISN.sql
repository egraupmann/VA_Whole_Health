/**************************************************************
This assembles a variety of information and demographics for the
current acupuncture users
**************************************************************/

/**************************************************************/
/*  Get the VISNs associated with all the referrals          */
/**************************************************************/
/*for VISTA*/
drop table if exists #VISTA_referral_VISN

SELECT a.*
      ,b.Sta3n
      ,c.VISN
into #VISTA_referral_VISN
FROM [OPCCCT_CIH].[Dflt].VISTA_comm_care_orders as a
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


/***************************************************/
/*make a current user dmeographics table*/
/***************************************************/
drop table if exists #acup_users;

with vista_race as (
    select distinct a.patientsid
          ,case when a.race_count>1 THEN 'MULTI-RACIAL' else a.race end as race_mod
    from (
            select b.patientsid, b.race, c.race_count
            from cdwwork.patsub.patientrace as b
                inner join (select patientsid , count(distinct race) as race_count
                            from cdwwork.patsub.patientrace
                            where race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
                            group by patientsid) as c on try_cast(b.patientsid as bigint) = try_cast(c.patientsid as bigint) 
            where b.race not in ('*Unknown at this time*','*Missing*','DECLINED TO ANSWER','UNKNOWN BY PATIENT')
           
        ) as a
)

select distinct a.patienticn
      ,case when b.BirthDateTime is null then f.BirthDateTime else b.BirthDateTime end as BirthDate
      ,case when b.gender is null then f.sex else b.gender end as gender
      ,case when d.race_mod is null then f.race else d.race_mod end as race
      ,case when c.ethnicity is null then f.ethnicGroup else c.ethnicity end as ethnicity
into #acup_users
From opccct_cih.dflt.ALL_ACUP_Referrals_and_Encounters as a
    left join cdwwork.spatient.spatient as b
        on cast(a.patienticn as varchar(50)) = b.patienticn
    left join cdwwork.patsub.patientethnicity as c
        on b.patientsid = c.patientsid
    left join vista_race as d
        on b.patientsid = d.patientsid
    left join cdwwork2.sveteranmill.sperson as f
        on a.patientsid = f.PersonSID
where eventDate >= '2020-10-01';

/***************************************************/
/*make a current user dmeographics table*/
drop table if exists #ALL_ACUP_User_Demographics_temp;

with ages AS (
    SELECT distinct patienticn,
           DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01')
           - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(birthdate AS DATE), '2026-10-01'), CAST(birthdate AS DATE)) > '2026-10-01'
                  THEN 1 ELSE 0 END AS age
    FROM #acup_users
) 
select a.PatientICN
      ,case when a.gender='F' then 'Female'
            when a.gender='M' then 'Male'
            else a.gender end as gender
      ,a.ethnicity
      ,a.race
    ,case when race in ('*Implied NULL*','Prefer Not To Answer','UNKNOWN') and ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when ethnicity='HISPANIC OR LATINO' then 'HISPANIC OR LATINO'
          when race='WHITE NOT OF HISP ORIG' then 'WHITE'
          when race='zzOther Race' then 'UNKNOWN'
          when race='NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' then 'Native Hawaiian or Pacific Islander'
          when race in ('*Implied NULL*','Prefer Not To Answer','Unknown') or race is null then 'UNKNOWN'
          else race end as race_mod
    ,age
    ,CASE WHEN age < 35 THEN '<35'
           WHEN age BETWEEN 35 AND 44 THEN '35-44'
           WHEN age BETWEEN 45 AND 54 THEN '45-54'
           WHEN age BETWEEN 55 AND 64 THEN '55-64'
           WHEN age BETWEEN 65 AND 74 THEN '65-74'
           WHEN age >= 75 THEN '75+' ELSE 'UNKNOWN' END AS age_bin 
into #ALL_ACUP_User_Demographics_temp
from #acup_users as a
    left join ages as b on a.patienticn = b.patienticn;



/************************************************
lets explore patient locations
*************************************************************/
drop table if exists opccct_cih.dflt.ALL_ACUP_User_Demographics;

with get_zips as (
    select DISTINCT
           a.PatientICN
          ,a.gender
          ,a.race_mod
          ,a.age
          ,a.age_bin
          ,b.Zip
          ,b.FIPSCode
    from #ALL_ACUP_User_Demographics_temp as a
        left join [CDWWork].[SPatient].[SPatientGISAddress] as b
            on cast(a.PatientICN as varchar(10)) = cast(b.PatientICN as varchar(10))
    where a.PatientICN is not null
),
counts as (
    select patienticn
          ,count(patienticn) as pat_count
          ,sum(case when FIPSCODe is null then 1 else 0 end) as null_fips_count
          ,sum(case when Zip is null then 1 else 0 end) as null_zip_count
          ,sum(case when race_mod='UNKNOWN' then 1 else 0 end) as unknown_race
          ,sum(case when race_mod<>'UNKNOWN' then 1 else 0 end) as not_unknown_race
    from get_zips
    group by PatientICN
),
remove_records as (
    select a.*
            ,b.pat_count
            ,b.null_fips_count
            ,b.null_zip_count
            ,b.unknown_race
            ,not_unknown_race
            ,case when pat_count>1 then 
                case when null_fips_count>0 and FIPSCode is null then 1
                     when null_zip_count>0 and zip is null then 1
                     when unknown_race>0 and race_mod='UNKNOWN' and not_unknown_race>0 then 1 
                     else 0 end
                else 0 end as remove_record
    from get_zips  as a
        inner join counts as b
            on a.patienticn = b.patienticn
),
new_dupe_count as (
    select patienticn
          ,count(patienticn) as pat_count_update
    from remove_records
    where remove_record = 0
    group by PatientICN
), remaining_dupes as (
    select a.*
          , b.pat_count_update
    from remove_records as a
        inner join new_dupe_count as b        
            on a.patienticn = b.patienticn
    where remove_record=0
), ranked_rows as (
    select *,
        ROW_NUMBER() over (partition by patientICN order by age desc) as rn
    from remaining_dupes
), final as (
    select *
    from ranked_rows
    where rn=1 
)
select a.*, b.Zip, b.FIPSCode
into opccct_cih.dflt.ALL_ACUP_User_Demographics
from #ALL_ACUP_User_Demographics_temp as a
    left join final as b
        on a.PatientICN = b.PatientICN;
