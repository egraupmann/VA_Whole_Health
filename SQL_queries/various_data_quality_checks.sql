/****************************************************************
Mental health table investigation
***************************************************************/

SELECT TOP (1000) m.[PatientSID]
      ,m.[PatientICN]
      ,m.[SurveyName]
      ,m.[SurveyGivenDateTime]
      ,m.[SurveyScale]
      ,m.[RawScore]
      ,m.[TransformedScore1]
      ,m.[TransformedScore2]
      ,m.[TransformedScore3]
  FROM [OPCCCT_CIH].[Dflt].[acupuncture_mental_health_scores] as m

  /*count the number of different response frequencies*/
  select distinct m.SurveyName, m.SurveyScale, q.surveyquestiontext, q.hint, count(m.PatientICN)
  FROM [OPCCCT_CIH].[Dflt].[acupuncture_mental_health_scores] as m
    left join cdwwork.mh.surveyanswer as a on m.surveysid = a.surveysid
    left join cdwwork.dim.surveyquestion as q on a.SurveyQuestionSID = q.SurveyQuestionSID
  where m.surveyname is not null
  group by m.SurveyName, m.SurveyScale, q.surveyquestiontext, q.hint

  /*number of patients with at least 1 instance of each mental health survey type*/
  select distinct surveyname, count(distinct patienticn)
  from [OPCCCT_CIH].[Dflt].[acupuncture_mental_health_scores]
  group by SurveyName

/*number of patients with at least 1 mental health survey*/
select count(distinct patienticn) from [OPCCCT_CIH].[Dflt].[acupuncture_mental_health_scores]

SELECT distinct sc.Designator, sc.QuestionSequence, sq.SurveyQuestionText
FROM cdwwork.Dim.Survey s
    JOIN cdwwork.Dim.SurveyContent sc ON s.SurveySID = sc.SurveySID
    JOIN cdwwork.Dim.SurveyQuestion sq ON sc.SurveyQuestionSID = sq.SurveyQuestionSID
WHERE s.SurveyName in ('C-SSRS','PCL-5')
ORDER BY sc.QuestionSequence