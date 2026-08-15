"""
app/attendance/crud.py
-----------------------
Database CRUD operations for the Attendance Management System.
All functions take a SQLAlchemy Session and return ORM objects or raise
HTTPException for common error cases.
"""

from __future__ import annotations

import uuid
from datetime import date
from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy import and_, extract
from sqlalchemy.orm import Session, joinedload

from app.attendance.models import (
    TimetablePeriod, WeeklyRoutine, Holiday,
    ExtraOffDay, AttendanceRecord, AttendanceThreshold,
    DayOfWeek, AttendanceMark,
)
from app.attendance import schemas
from app.core.config import settings


# ══════════════════════════════════════════════════════════════════════════════
# 1.1  Timetable Periods
# ══════════════════════════════════════════════════════════════════════════════

def create_period(db: Session, data: schemas.PeriodCreate) -> TimetablePeriod:
    period = TimetablePeriod(
        class_id   = data.class_id,
        name       = data.name,
        start_time = data.start_time,
        end_time   = data.end_time,
        order      = data.order,
    )
    db.add(period)
    try:
        db.commit()
        db.refresh(period)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Period '{data.name}' already exists in class '{data.class_id}'.",
        )
    return period


def list_periods(db: Session, class_id: str) -> List[TimetablePeriod]:
    return (
        db.query(TimetablePeriod)
        .filter(TimetablePeriod.class_id == class_id)
        .order_by(TimetablePeriod.order, TimetablePeriod.start_time)
        .all()
    )


def get_period(db: Session, period_id: uuid.UUID) -> TimetablePeriod:
    period = db.query(TimetablePeriod).get(period_id)
    if not period:
        raise HTTPException(status_code=404, detail="Period not found.")
    return period


def update_period(
    db: Session, period_id: uuid.UUID, data: schemas.PeriodUpdate
) -> TimetablePeriod:
    period = get_period(db, period_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(period, field, value)
    db.commit()
    db.refresh(period)
    return period


def delete_period(db: Session, period_id: uuid.UUID) -> None:
    period = get_period(db, period_id)
    db.delete(period)
    db.commit()


# ══════════════════════════════════════════════════════════════════════════════
# 1.1  Weekly Routine
# ══════════════════════════════════════════════════════════════════════════════

def create_routine(db: Session, data: schemas.RoutineCreate) -> WeeklyRoutine:
    # Validate period belongs to class
    period = db.query(TimetablePeriod).filter(
        TimetablePeriod.id == data.period_id,
        TimetablePeriod.class_id == data.class_id,
    ).first()
    if not period:
        raise HTTPException(
            status_code=404,
            detail="Period not found in this class.",
        )

    entry = WeeklyRoutine(
        class_id     = data.class_id,
        day_of_week  = DayOfWeek(data.day_of_week),
        period_id    = data.period_id,
        subject_name = data.subject_name,
        teacher_name = data.teacher_name,
    )
    db.add(entry)
    try:
        db.commit()
        db.refresh(entry)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A routine entry already exists for this class/day/period.",
        )
    return entry


def list_routine(db: Session, class_id: str) -> List[WeeklyRoutine]:
    return (
        db.query(WeeklyRoutine)
        .options(joinedload(WeeklyRoutine.period))
        .filter(WeeklyRoutine.class_id == class_id)
        .order_by(WeeklyRoutine.day_of_week, WeeklyRoutine.period_id)
        .all()
    )


def get_routine_entry(db: Session, entry_id: uuid.UUID) -> WeeklyRoutine:
    entry = db.query(WeeklyRoutine).get(entry_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Routine entry not found.")
    return entry


def update_routine(
    db: Session, entry_id: uuid.UUID, data: schemas.RoutineUpdate
) -> WeeklyRoutine:
    entry = get_routine_entry(db, entry_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    return entry


def delete_routine(db: Session, entry_id: uuid.UUID) -> None:
    entry = get_routine_entry(db, entry_id)
    db.delete(entry)
    db.commit()


# ══════════════════════════════════════════════════════════════════════════════
# 1.1  Weekly Holidays
# ══════════════════════════════════════════════════════════════════════════════

def create_holiday(db: Session, data: schemas.HolidayCreate) -> Holiday:
    holiday = Holiday(
        class_id    = data.class_id,
        day_of_week = DayOfWeek(data.day_of_week),
        description = data.description,
    )
    db.add(holiday)
    try:
        db.commit()
        db.refresh(holiday)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"'{data.day_of_week}' is already marked as a holiday for this class.",
        )
    return holiday


def list_holidays(db: Session, class_id: str) -> List[Holiday]:
    return (
        db.query(Holiday)
        .filter(Holiday.class_id == class_id)
        .all()
    )


def delete_holiday(db: Session, holiday_id: uuid.UUID) -> None:
    holiday = db.query(Holiday).get(holiday_id)
    if not holiday:
        raise HTTPException(status_code=404, detail="Holiday not found.")
    db.delete(holiday)
    db.commit()


# ══════════════════════════════════════════════════════════════════════════════
# 1.1  Extra Off Days
# ══════════════════════════════════════════════════════════════════════════════

def create_extra_off_day(db: Session, data: schemas.ExtraOffDayCreate) -> ExtraOffDay:
    off_day = ExtraOffDay(
        class_id = data.class_id,
        off_date = data.off_date,
        reason   = data.reason,
    )
    db.add(off_day)
    try:
        db.commit()
        db.refresh(off_day)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"'{data.off_date}' is already marked as an off-day for this class.",
        )
    return off_day


def list_extra_off_days(
    db: Session, class_id: str, year: Optional[int] = None, month: Optional[int] = None
) -> List[ExtraOffDay]:
    q = db.query(ExtraOffDay).filter(ExtraOffDay.class_id == class_id)
    if year:
        q = q.filter(extract("year", ExtraOffDay.off_date) == year)
    if month:
        q = q.filter(extract("month", ExtraOffDay.off_date) == month)
    return q.order_by(ExtraOffDay.off_date).all()


def delete_extra_off_day(db: Session, off_day_id: uuid.UUID) -> None:
    off_day = db.query(ExtraOffDay).get(off_day_id)
    if not off_day:
        raise HTTPException(status_code=404, detail="Extra off-day not found.")
    db.delete(off_day)
    db.commit()


# ══════════════════════════════════════════════════════════════════════════════
# 1.2  Attendance Marking
# ══════════════════════════════════════════════════════════════════════════════

def mark_attendance(
    db: Session, data: schemas.AttendanceMarkCreate
) -> AttendanceRecord:
    record = AttendanceRecord(
        class_id   = data.class_id,
        student_id = data.student_id,
        period_id  = data.period_id,
        date       = data.date,
        mark       = AttendanceMark(data.mark),
        marked_by  = data.marked_by,
        notes      = data.notes,
    )
    db.add(record)
    try:
        db.commit()
        db.refresh(record)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Attendance already marked for this student/period/date. Use PUT to update.",
        )
    return record


def get_attendance_record(db: Session, record_id: uuid.UUID) -> AttendanceRecord:
    record = db.query(AttendanceRecord).get(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found.")
    return record


def update_attendance(
    db: Session, record_id: uuid.UUID, data: schemas.AttendanceMarkUpdate
) -> AttendanceRecord:
    record = get_attendance_record(db, record_id)
    record.mark  = AttendanceMark(data.mark)
    record.notes = data.notes
    db.commit()
    db.refresh(record)
    return record


def delete_attendance(db: Session, record_id: uuid.UUID) -> None:
    record = get_attendance_record(db, record_id)
    db.delete(record)
    db.commit()


def get_student_calendar(
    db: Session,
    student_id: str,
    class_id: str,
    year: Optional[int] = None,
    month: Optional[int] = None,
) -> List[AttendanceRecord]:
    """Return all attendance records for a student, optionally filtered by month."""
    q = (
        db.query(AttendanceRecord)
        .options(joinedload(AttendanceRecord.period))
        .filter(
            AttendanceRecord.student_id == student_id,
            AttendanceRecord.class_id   == class_id,
        )
    )
    if year:
        q = q.filter(extract("year",  AttendanceRecord.date) == year)
    if month:
        q = q.filter(extract("month", AttendanceRecord.date) == month)
    return q.order_by(AttendanceRecord.date, AttendanceRecord.period_id).all()


# ══════════════════════════════════════════════════════════════════════════════
# 1.3  Attendance Stats (raw DB fetch — aggregation in utils.py)
# ══════════════════════════════════════════════════════════════════════════════

def get_student_records_with_subject(
    db: Session,
    student_id: str,
    class_id: str,
    subject_name: Optional[str] = None,
) -> List[dict]:
    """
    Join attendance_records → weekly_routine to get subject_name per record.
    Returns a list of dicts: {subject_name, mark}.
    """
    from sqlalchemy import select, case

    # Sub-query: period_id + date → subject_name via WeeklyRoutine
    results = (
        db.query(
            AttendanceRecord.mark,
            WeeklyRoutine.subject_name,
        )
        .join(
            TimetablePeriod,
            AttendanceRecord.period_id == TimetablePeriod.id,
        )
        .outerjoin(
            WeeklyRoutine,
            and_(
                WeeklyRoutine.period_id  == AttendanceRecord.period_id,
                WeeklyRoutine.class_id   == AttendanceRecord.class_id,
            ),
        )
        .filter(
            AttendanceRecord.student_id == student_id,
            AttendanceRecord.class_id   == class_id,
        )
    )

    if subject_name:
        results = results.filter(WeeklyRoutine.subject_name == subject_name)

    return [
        {"subject_name": row.subject_name or "Unassigned", "mark": row.mark.value}
        for row in results.all()
    ]


# ══════════════════════════════════════════════════════════════════════════════
# 1.4  Threshold Settings
# ══════════════════════════════════════════════════════════════════════════════

def create_threshold(
    db: Session, data: schemas.ThresholdCreate
) -> AttendanceThreshold:
    threshold = AttendanceThreshold(
        class_id     = data.class_id,
        scope        = data.scope,
        subject_name = data.subject_name,
        threshold    = data.threshold,
    )
    db.add(threshold)
    try:
        db.commit()
        db.refresh(threshold)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A threshold for this class/scope/subject already exists. Use PUT to update.",
        )
    return threshold


def list_thresholds(db: Session, class_id: str) -> List[AttendanceThreshold]:
    return (
        db.query(AttendanceThreshold)
        .filter(AttendanceThreshold.class_id == class_id)
        .all()
    )


def get_threshold(db: Session, threshold_id: uuid.UUID) -> AttendanceThreshold:
    t = db.query(AttendanceThreshold).get(threshold_id)
    if not t:
        raise HTTPException(status_code=404, detail="Threshold not found.")
    return t


def update_threshold(
    db: Session, threshold_id: uuid.UUID, data: schemas.ThresholdUpdate
) -> AttendanceThreshold:
    t = get_threshold(db, threshold_id)
    t.threshold = data.threshold
    db.commit()
    db.refresh(t)
    return t


def get_threshold_map(db: Session, class_id: str) -> tuple[float, dict]:
    """
    Returns (global_threshold, {subject_name: threshold}).
    Falls back to settings.DEFAULT_ATTENDANCE_THRESHOLD if no global set.
    """
    thresholds = list_thresholds(db, class_id)
    global_threshold = settings.DEFAULT_ATTENDANCE_THRESHOLD
    subject_map: dict[str, float] = {}
    for t in thresholds:
        if t.scope == "global":
            global_threshold = t.threshold
        else:
            subject_map[t.subject_name] = t.threshold
    return global_threshold, subject_map
