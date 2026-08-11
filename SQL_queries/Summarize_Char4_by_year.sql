SELECT year(VisitDateTime) as VisitYear, month(VisitDateTime) as VisitMonth, NationalChar4
    , count(distinct VisitSID) as VisitCount, count(distinct PatientSID) as PatientCount

  FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_1_VISITS]
  WHERE [VisitDateTime] >= '2022-10-01' AND [VisitDateTime] < '2026-05-01'
    AND (NationalChar4 IN ('ACUP', 'IACT') OR NationalChar4 is null)
Group by year(VisitDateTime), month(VisitDateTime), NationalChar4
order by year(VisitDateTime), month(VisitDateTime), NationalChar4