/**************************************************************
Add the additional descriptors to each person for use in 
controlling as many variables as possible for a LOGIT model
*************************************************************/
drop table if exists opccct_cih.dflt.logit_patient_data;

select a.PatientICN
               ,a.age
               ,a.condition
               ,case when a.[group]='Group A' then concat(a.[group],' - ',a.Group_A_Evidence_Certainty_Rating)
                     else a.[group] end as evidence_group
               ,sum(a.diagnosis_count) as times_diagnosed
               ,a.VISN
               ,a.current_acupuncture_user
               ,b.gender
               ,b.race_mod
               ,cast(case when cast(d.FIPSCode as varchar(50)) is null then 'UNKNOWN' else cast(d.FIPSCode as varchar(50)) end as varchar(50)) as FIPSCode
               ,case when e.rucc_2023 is null then 0 else e.rucc_2023 end as rurality
into opccct_cih.dflt.logit_patient_data
from vhacdwa01.[OPCCCT_CIH].[Dflt].[ALL_Tiered_Diagnoses_FY26] as a
    inner join (select *
        from vhacdwa01.opccct_cih.dflt.all_enrolled_vet_demographics 
        where [EnrolledFY26]=1) as b on a.patienticn = b.patienticn
    inner join [OPCCCT_CIH].[Dflt].[unmet_condition_level_table] as c
        on a.Condition = c.condition
    left join [OPCCCT_CIH].[Dflt].[all_enrolled_vet_demographics] as d
        on a.patienticn = d.patientICN
    left join [OPCCCT_CIH].[Dflt].county_acupuncture_map_data as e
        on d.FIPSCode = e.county_fips
where b.EnrolledFY26=1  and (case when a.[group]='Exclude' and a.current_acupuncture_user=0 then 1 else 0 end)=0
group by a.PatientICN
        ,a.age
        ,a.condition
        ,a.VISN
        ,a.current_acupuncture_user
        ,b.gender
        ,b.race_mod
        ,cast(case when cast(d.FIPSCode as varchar(50)) is null then 'UNKNOWN' else cast(d.FIPSCode as varchar(50)) end as varchar(50))
        ,case when e.rucc_2023 is null then 0 else e.rucc_2023 end
        ,case when a.[group]='Group A' then concat(a.[group],' - ',a.Group_A_Evidence_Certainty_Rating)
                     else a.[group] end;


/********************************************************
compare CC vs VA facility use by rurality
*******************************************************/
select DISTINCT
       b.eventType
      ,a.rurality
      ,count(DISTINCT a.patientICN) as pat_count
from opccct_cih.dflt.logit_patient_data as a
    inner join [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters] as b
        on a.PatientICN = b.PatientICN
where a.current_acupuncture_user=1 And b.FiscalYear=2026
group by b.eventType
      ,a.rurality;



select top 1000 *
from [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters]

/********************************************************
Aggregate some geographic info
*******************************************************/
select fipscode
      ,count(*) as vet_count
      ,sum(current_acupuncture_user) as user_count
from opccct_cih.dflt.all_enrolled_vet_demographics
where EnrolledFY26=1
group by fipscode;

select top 1000 *
from opccct_cih.dflt.logit_patient_data


SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'all_enrolled_vet_demographics'
ORDER BY ORDINAL_POSITION;


DECLARE @yr INT = 2021;
DECLARE @sql NVARCHAR(MAX);
DECLARE @yr_short VARCHAR(2);

WHILE @yr <= 2026
BEGIN
    -- Get 2-digit year suffix (e.g. 2021 -> '21')
    SET @yr_short = RIGHT(CAST(@yr AS VARCHAR), 2);

    SET @sql = '
        WITH service_type AS (
            SELECT DISTINCT
                   a.patientICN
                  ,CASE WHEN eventType = ''Encounter'' THEN 1 ELSE 0 END AS VAMC
                  ,CASE WHEN eventType = ''Referral''  THEN 1 ELSE 0 END AS CC
            FROM [OPCCCT_CIH].[Dflt].[ALL_ACUP_Referrals_and_Encounters] AS a
            WHERE FiscalYear = ' + CAST(@yr AS VARCHAR) + '
        ),
        service_dist AS (
            SELECT patientICN
                  ,CASE WHEN SUM(VAMC) > 0 THEN patientICN END AS VAMC
                  ,CASE WHEN SUM(CC)   > 0 THEN patientICN END AS CC
            FROM service_type
            GROUP BY patientICN
        )
        SELECT ' + CAST(@yr AS VARCHAR) + ' AS FY
              ,COUNT(DISTINCT a.PatientICN) AS pop_count
              ,COUNT(DISTINCT CASE WHEN current_acupuncture_user = 1 THEN a.PatientICN END) AS users_distinct
              ,COUNT(DISTINCT VAMC) AS users_vamc
              ,COUNT(DISTINCT CC)   AS users_cc
              ,COUNT(DISTINCT VAMC) + COUNT(DISTINCT CC) 
                  - COUNT(DISTINCT CASE WHEN current_acupuncture_user = 1 THEN a.PatientICN END) AS users_overlap
        FROM vhacdwa01.[OPCCCT_CIH].[Dflt].all_tiered_diagnoses_fy' + @yr_short + ' AS a
            INNER JOIN (
                SELECT * 
                FROM vhacdwa01.opccct_cih.dflt.ALL_Enrolled_Vets
                WHERE EnrolledFY' + @yr_short + ' = 1
            ) AS b ON a.PatientICN = b.ADRPersonICN
            LEFT JOIN service_dist AS c ON a.PatientICN = c.PatientICN
        WHERE [group] <> ''Exclude''
    ';

    EXEC sp_executesql @sql;

    SET @yr = @yr + 1;
END

