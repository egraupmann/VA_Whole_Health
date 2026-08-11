
/******************************************************************************/
/* Community Care encounter sample - grain: one row per Consult                */
/* StopCode 655 identified via:                                               */
/*   CDWWork.Con.Consult.ToRequestServiceSID                                  */
/*     -> CDWWork.Dim.AssociatedStopCode.RequestServiceSID                    */
/*     -> CDWWork.Dim.StopCode.StopCodeSID  (WHERE StopCode = 655)            */
/*                                                                            */
/* PERFORMANCE NOTE: restructured so TOP 1000 + ORDER BY is applied FIRST,    */
/* against only Con.Consult (cheap), BEFORE joining out to the one-to-many    */
/* tables (SConsultReason, SConsultActivityComment, Appointment). Previously */
/* those fan-out joins ran against every historical 655 consult before the   */
/* sort/TOP could trim it down - this version guarantees they only ever run  */
/* against the 1000 already-selected consults.                              */
/*                                                                            */
/* NOTE: A RequestService can map to more than one StopCode in                */
/* Dim.AssociatedStopCode. The DISTINCT in Step 1 guards against duplicate    */
/* consult rows if that happens.                                            */
/*                                                                            */
/* NOTE: SConsultReason / SConsultActivityComment / Appointment can each      */
/* still have multiple rows per ConsultSID. Because the join to them now      */
/* happens AFTER TOP 1000, this no longer affects runtime against the full   */
/* history - but it can still produce more than 1000 output rows if any of    */
/* the 1000 selected consults have multiple reasons/comments/appointments.    */
/* If you need exactly 1000 rows out, aggregate those three joins (e.g.       */
/* STRING_AGG for comments, MAX(AppointmentDateTime) for appointment) rather  */
/* than joining them raw - ask if you want that version.                    */
/******************************************************************************/

-- STEP 1: identify the 1000 target consults FIRST, cheaply, with no fan-out.
DROP TABLE IF EXISTS #Top1000Consults;
SELECT TOP 1000
    con.ConsultSID,
    con.PatientSID,
    con.RequestDateTime,
    con.RequestType,
    con.InpatOutpat,
    con.OrderStatusSID,
    con.ToRequestServiceSID,
    con.ProvisionalDiagnosis
INTO #Top1000Consults
FROM CDWWork.Con.Consult con
    INNER JOIN CDWWork.Dim.AssociatedStopCode asc_
        ON con.ToRequestServiceSID = asc_.RequestServiceSID
    INNER JOIN CDWWork.Dim.StopCode sc
        ON asc_.StopCodeSID = sc.StopCodeSID
WHERE sc.StopCode = 655
    AND con.RequestDateTime >= '2025-01-01'  -- adjust/remove as needed

select * 
from #Top1000Consults

-- STEP 2: now join out to everything else, including the one-to-many
-- tables - this only ever runs against 1000 consults, not the full history.
SELECT
    t.ConsultSID,
    t.PatientSID,
    pat.PatientICN,
    t.RequestDateTime,
    t.RequestType,
    t.InpatOutpat,
    t.OrderStatusSID,
    rs.ServiceName                     AS RequestedServiceName,
    appt.AppointmentSID,
    appt.AppointmentDateTime,
    appt.AppointmentStatus,
    vis.VisitSID,
    vis.VisitDateTime,
    vis.EncounterType,
    loc.LocationName,
    inst.InstitutionName,
    t.ProvisionalDiagnosis,
    reason.ConsultReason,
    cac.ConsultActivityComment
FROM #Top1000Consults t
    LEFT JOIN CDWWork.Dim.RequestService rs
        ON t.ToRequestServiceSID = rs.RequestServiceSID
    LEFT JOIN CDWWork.SPatient.SPatient pat
        ON t.PatientSID = pat.PatientSID
    LEFT JOIN CDWWork.Appt.Appointment appt
        ON t.ConsultSID = appt.ConsultSID
    LEFT JOIN CDWWork.Outpat.Visit vis
        ON appt.VisitSID = vis.VisitSID
    LEFT JOIN CDWWork.Dim.Location loc
        ON vis.LocationSID = loc.LocationSID
    LEFT JOIN CDWWork.Dim.Institution inst
        ON vis.InstitutionSID = inst.InstitutionSID
    LEFT JOIN CDWWork.SPatient.SConsultReason reason
        ON t.ConsultSID = reason.ConsultSID
    LEFT JOIN CDWWork.SPatient.SConsultActivityComment cac
        ON t.ConsultSID = cac.ConsultSID
ORDER BY t.RequestDateTime DESC;

DROP TABLE IF EXISTS #Top1000Consults;