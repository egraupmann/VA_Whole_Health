SELECT YEAR([VisitDateTime]) as visit_year,
	SrcSystem, Count(distinct [VisitSID]) as vist_count
Into OPCCCT_CIH.DFLT.[test sum]
FROM [OPCCCT_Analytics].[DOEx].[WholeHealth_1_VISITS]
where [VisitDateTime] >='2022-10-10' AND [VisitDateTime] <='2026-04-30' AND ([NationalChar4] in ('ACUP') OR [NationalChar4] in ('IACT'))
group by YEAR([VisitDateTime]), SrcSystem
order by visit_year;