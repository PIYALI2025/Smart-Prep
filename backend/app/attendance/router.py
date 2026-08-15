"""
app/attendance/router.py
------------------------
FastAPI router exposing all Attendance Management System endpoints.

Feature areas
-------------
1.1  Timetable Settings  – periods, routine, holidays, extra off-days
1.2  Attendance Marking  – mark / update / clear / calendar view
1.3  Attendance Stats    – period-wise and overall counting
1.4  Threshold Settings  – set / update / check threshold compliance
"""

from __future__ import annotations

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.auth.dependencies import get_current_user_id
from app.attendance import crud, schemas
from app.attendance.utils import (
    attendance_percentage,
    aggregate_by_subject,
    classes_needed_for_threshold,
)

router = APIRouter(prefix="/attendance", tags=["Attendance Management"])


# ══════════════════════════════════════════════════════════════════════════════
# 1.1 ── Timetable Periods
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/periods",
    response_model=schemas.PeriodResponse,
    status_code=201,
    summary="Create a period slot",
    description="Define a named period (e.g. 'Period 1') with start/end time for a class.",
)
def create_period(
    data: schemas.PeriodCreate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.create_period(db, data)


@router.get(
    "/periods",
    response_model=List[schemas.PeriodResponse],
    summary="List all periods",
    description="Retrieve all period slots for a class, ordered by display order.",
)
def list_periods(
    class_id: str = Query(..., description="Class identifier"),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.list_periods(db, class_id)


@router.put(
    "/periods/{period_id}",
    response_model=schemas.PeriodResponse,
    summary="Update a period slot",
)
def update_period(
    period_id: uuid.UUID,
    data: schemas.PeriodUpdate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.update_period(db, period_id, data)


@router.delete(
    "/periods/{period_id}",
    status_code=204,
    summary="Delete a period slot",
    description="Deletes the period and cascades to routine entries and attendance records.",
)
def delete_period(
    period_id: uuid.UUID,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    crud.delete_period(db, period_id)


# ══════════════════════════════════════════════════════════════════════════════
# 1.1 ── Weekly Routine
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/routine",
    response_model=schemas.RoutineResponse,
    status_code=201,
    summary="Assign a subject to a day+period",
    description=(
        "Create a weekly routine entry: on a given day_of_week, "
        "a specific period will have a particular subject."
    ),
)
def create_routine(
    data: schemas.RoutineCreate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.create_routine(db, data)


@router.get(
    "/routine",
    response_model=List[schemas.RoutineResponse],
    summary="Get full weekly routine",
    description="Returns all day+period→subject mappings for a class, with period details.",
)
def list_routine(
    class_id: str = Query(..., description="Class identifier"),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.list_routine(db, class_id)


@router.put(
    "/routine/{entry_id}",
    response_model=schemas.RoutineResponse,
    summary="Update a routine entry",
)
def update_routine(
    entry_id: uuid.UUID,
    data: schemas.RoutineUpdate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.update_routine(db, entry_id, data)


@router.delete(
    "/routine/{entry_id}",
    status_code=204,
    summary="Remove a routine entry",
)
def delete_routine(
    entry_id: uuid.UUID,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    crud.delete_routine(db, entry_id)


# ══════════════════════════════════════════════════════════════════════════════
# 1.1 ── Weekly Holidays
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/holidays",
    response_model=schemas.HolidayResponse,
    status_code=201,
    summary="Add a weekly recurring holiday",
    description="Mark a day-of-week (e.g. 'sunday') as a standing holiday for a class.",
)
def create_holiday(
    data: schemas.HolidayCreate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.create_holiday(db, data)


@router.get(
    "/holidays",
    response_model=List[schemas.HolidayResponse],
    summary="List weekly holidays",
)
def list_holidays(
    class_id: str = Query(...),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.list_holidays(db, class_id)


@router.delete(
    "/holidays/{holiday_id}",
    status_code=204,
    summary="Remove a weekly holiday",
)
def delete_holiday(
    holiday_id: uuid.UUID,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    crud.delete_holiday(db, holiday_id)


# ══════════════════════════════════════════════════════════════════════════════
# 1.1 ── Extra Off Days (one-off)
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/extra-off-days",
    response_model=schemas.ExtraOffDayResponse,
    status_code=201,
    summary="Add a one-off extra holiday",
    description="Mark a specific calendar date as an off-day (e.g. Republic Day, sports day).",
)
def create_extra_off_day(
    data: schemas.ExtraOffDayCreate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.create_extra_off_day(db, data)


@router.get(
    "/extra-off-days",
    response_model=List[schemas.ExtraOffDayResponse],
    summary="List extra off-days",
)
def list_extra_off_days(
    class_id: str = Query(...),
    year: Optional[int]  = Query(None, description="Filter by year"),
    month: Optional[int] = Query(None, ge=1, le=12, description="Filter by month (1–12)"),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.list_extra_off_days(db, class_id, year, month)


@router.delete(
    "/extra-off-days/{off_day_id}",
    status_code=204,
    summary="Remove an extra off-day",
)
def delete_extra_off_day(
    off_day_id: uuid.UUID,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    crud.delete_extra_off_day(db, off_day_id)


# ══════════════════════════════════════════════════════════════════════════════
# 1.2 ── Attendance Marking
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/mark",
    response_model=schemas.AttendanceRecordResponse,
    status_code=201,
    summary="Mark attendance",
    description=(
        "Record attendance for a student on a date for a specific period. "
        "Valid marks: **present**, **absent**, **off_day**."
    ),
)
def mark_attendance(
    data: schemas.AttendanceMarkCreate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.mark_attendance(db, data)


@router.put(
    "/mark/{record_id}",
    response_model=schemas.AttendanceRecordResponse,
    summary="Update an attendance mark",
    description="Change an existing attendance mark (e.g. correct absent → present).",
)
def update_attendance(
    record_id: uuid.UUID,
    data: schemas.AttendanceMarkUpdate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.update_attendance(db, record_id, data)


@router.delete(
    "/mark/{record_id}",
    status_code=204,
    summary="Clear an attendance mark",
    description="Delete an attendance record entirely (equivalent to 'clear marking').",
)
def delete_attendance(
    record_id: uuid.UUID,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    crud.delete_attendance(db, record_id)


@router.get(
    "/calendar/{student_id}",
    response_model=List[schemas.AttendanceRecordResponse],
    summary="Get student calendar",
    description=(
        "Return all attendance records for a student. "
        "Filter by class_id, and optionally by year/month."
    ),
)
def get_student_calendar(
    student_id: str,
    class_id: str = Query(...),
    year: Optional[int]  = Query(None),
    month: Optional[int] = Query(None, ge=1, le=12),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.get_student_calendar(db, student_id, class_id, year, month)


# ══════════════════════════════════════════════════════════════════════════════
# 1.3 ── Attendance Stats / Counting
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/stats/{student_id}",
    response_model=schemas.OverallStats,
    summary="Overall + per-subject attendance stats",
    description=(
        "Returns total and subject-wise attendance counts and percentages, "
        "plus whether each subject is below its threshold."
    ),
)
def get_overall_stats(
    student_id: str,
    class_id: str = Query(...),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    records = crud.get_student_records_with_subject(db, student_id, class_id)
    global_threshold, subject_threshold_map = crud.get_threshold_map(db, class_id)

    subject_stats, total_present, total_absent, total_off = aggregate_by_subject(
        records, subject_threshold_map, global_threshold
    )

    return schemas.OverallStats(
        student_id              = student_id,
        class_id                = class_id,
        total_classes           = total_present + total_absent,
        present_count           = total_present,
        absent_count            = total_absent,
        off_day_count           = total_off,
        overall_attendance_pct  = attendance_percentage(total_present, total_absent),
        subjects                = [schemas.SubjectStats(**s) for s in subject_stats],
    )


@router.get(
    "/stats/{student_id}/subject/{subject_name}",
    response_model=schemas.SubjectStats,
    summary="Per-subject attendance stats",
    description="Returns attendance stats for one specific subject for a student.",
)
def get_subject_stats(
    student_id: str,
    subject_name: str,
    class_id: str = Query(...),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    records = crud.get_student_records_with_subject(
        db, student_id, class_id, subject_name
    )
    global_threshold, subject_threshold_map = crud.get_threshold_map(db, class_id)
    threshold = subject_threshold_map.get(subject_name, global_threshold)

    present  = sum(1 for r in records if r["mark"] == "present")
    absent   = sum(1 for r in records if r["mark"] == "absent")
    off_day  = sum(1 for r in records if r["mark"] == "off_day")
    pct      = attendance_percentage(present, absent)

    return schemas.SubjectStats(
        subject_name       = subject_name,
        total_classes      = present + absent,
        present_count      = present,
        absent_count       = absent,
        off_day_count      = off_day,
        attendance_pct     = pct,
        is_below_threshold = pct < threshold,
    )


# ══════════════════════════════════════════════════════════════════════════════
# 1.4 ── Threshold Settings
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/threshold",
    response_model=schemas.ThresholdResponse,
    status_code=201,
    summary="Set attendance threshold",
    description=(
        "Set the mandatory attendance percentage. "
        "Use scope='global' for class-wide, scope='subject' + subject_name for a single subject."
    ),
)
def create_threshold(
    data: schemas.ThresholdCreate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.create_threshold(db, data)


@router.get(
    "/threshold",
    response_model=List[schemas.ThresholdResponse],
    summary="List all thresholds",
    description="Retrieve all attendance thresholds (global and per-subject) for a class.",
)
def list_thresholds(
    class_id: str = Query(...),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.list_thresholds(db, class_id)


@router.put(
    "/threshold/{threshold_id}",
    response_model=schemas.ThresholdResponse,
    summary="Update a threshold",
)
def update_threshold(
    threshold_id: uuid.UUID,
    data: schemas.ThresholdUpdate,
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    return crud.update_threshold(db, threshold_id, data)


@router.get(
    "/threshold/check/{student_id}",
    response_model=schemas.ThresholdCheckResponse,
    summary="Check threshold compliance",
    description=(
        "For each subject, returns whether the student is below the attendance threshold "
        "and how many more classes they need to attend to meet it."
    ),
)
def check_threshold(
    student_id: str,
    class_id: str = Query(...),
    db: Session = Depends(get_db),
    _user: str = Depends(get_current_user_id),
):
    records = crud.get_student_records_with_subject(db, student_id, class_id)
    global_threshold, subject_threshold_map = crud.get_threshold_map(db, class_id)

    subject_stats_list, total_present, total_absent, _ = aggregate_by_subject(
        records, subject_threshold_map, global_threshold
    )

    check_items = []
    for s in subject_stats_list:
        threshold = subject_threshold_map.get(s["subject_name"], global_threshold)
        check_items.append(schemas.ThresholdCheckItem(
            subject_name   = s["subject_name"],
            attendance_pct = s["attendance_pct"],
            threshold      = threshold,
            is_below       = s["is_below_threshold"],
            classes_needed = classes_needed_for_threshold(
                s["present_count"], s["absent_count"], threshold
            ),
        ))

    overall_pct = attendance_percentage(total_present, total_absent)

    return schemas.ThresholdCheckResponse(
        student_id        = student_id,
        class_id          = class_id,
        overall_pct       = overall_pct,
        global_threshold  = global_threshold,
        overall_below     = overall_pct < global_threshold,
        subjects          = check_items,
    )
