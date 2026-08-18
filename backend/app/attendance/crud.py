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
    LecturePlanEntry, GapRecord,
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


# ══════════════════════════════════════════════════════════════════════════════
# 1.5  Lecture Plan CRUD
# ══════════════════════════════════════════════════════════════════════════════

def create_lecture_plan(db: Session, data: schemas.LecturePlanCreate) -> LecturePlanEntry:
    entry = LecturePlanEntry(
        class_id       = data.class_id,
        section        = data.section,
        subject_name   = data.subject_name,
        period_id      = data.period_id,
        date           = data.date,
        teacher_id     = data.teacher_id,
        topic          = data.topic,
        subtopics      = data.subtopics,
        exam_weightage = data.exam_weightage,
    )
    db.add(entry)
    try:
        db.commit()
        db.refresh(entry)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A lecture plan already exists for this class/section/date/period.",
        )
    return entry


def get_lecture_plan(db: Session, plan_id: uuid.UUID) -> LecturePlanEntry:
    plan = db.query(LecturePlanEntry).get(plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Lecture plan entry not found.")
    return plan


def update_lecture_plan(
    db: Session, plan_id: uuid.UUID, data: schemas.LecturePlanUpdate
) -> LecturePlanEntry:
    plan = get_lecture_plan(db, plan_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(plan, field, value)
    db.commit()
    db.refresh(plan)
    return plan


def list_lecture_plans(
    db: Session,
    class_id: str,
    section: str = "A",
    target_date: Optional[date] = None,
) -> List[LecturePlanEntry]:
    q = db.query(LecturePlanEntry).filter(
        LecturePlanEntry.class_id == class_id,
        LecturePlanEntry.section == section,
    )
    if target_date:
        q = q.filter(LecturePlanEntry.date == target_date)
    return q.order_by(LecturePlanEntry.date, LecturePlanEntry.period_id).all()


def find_lecture_plan_for_session(
    db: Session,
    class_id: str,
    section: str,
    target_date: date,
    period_id: uuid.UUID,
) -> Optional[LecturePlanEntry]:
    """Look up the lecture plan for a specific class/section/date/period."""
    return (
        db.query(LecturePlanEntry)
        .filter(
            LecturePlanEntry.class_id  == class_id,
            LecturePlanEntry.section   == section,
            LecturePlanEntry.date      == target_date,
            LecturePlanEntry.period_id == period_id,
        )
        .first()
    )


def delete_lecture_plan(db: Session, plan_id: uuid.UUID) -> None:
    plan = get_lecture_plan(db, plan_id)
    db.delete(plan)
    db.commit()


# ══════════════════════════════════════════════════════════════════════════════
# 1.6  Roster Context Lookup
# ══════════════════════════════════════════════════════════════════════════════

def get_roster_context(
    db: Session,
    class_id: str,
    section: str,
    target_date: date,
    period_id: uuid.UUID,
    student_ids: List[str],
) -> dict:
    """
    Build roster data for a given session slot: session info + per-student status.
    student_ids should be provided by the caller (e.g. from a class roster service).
    """
    # Lecture plan context
    lecture_plan = find_lecture_plan_for_session(db, class_id, section, target_date, period_id)
    period = db.query(TimetablePeriod).get(period_id)

    # Existing attendance records for this slot
    existing_records = (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.class_id  == class_id,
            AttendanceRecord.date      == target_date,
            AttendanceRecord.period_id == period_id,
        )
        .all()
    )
    record_map = {r.student_id: r for r in existing_records}

    students = []
    for sid in student_ids:
        rec = record_map.get(sid)
        students.append({
            "student_id": sid,
            "name": None,
            "status": rec.mark.value if rec else "unmarked",
            "record_id": rec.id if rec else None,
            "notes": rec.notes if rec else None,
        })

    session_info = {
        "class_id": class_id,
        "section": section,
        "date": target_date,
        "period_id": period_id,
        "period_name": period.name if period else None,
        "subject_name": lecture_plan.subject_name if lecture_plan else None,
        "lecture_plan": lecture_plan,
    }

    return {
        "session_info": session_info,
        "total_students": len(student_ids),
        "students": students,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 1.7  Bulk Attendance Marking
# ══════════════════════════════════════════════════════════════════════════════

def bulk_mark_attendance(
    db: Session,
    data: schemas.BulkMarkAttendanceRequest,
    marked_by: str,
) -> dict:
    """
    Upsert attendance for every student in data.records.
    Returns summary dict including counts and gap creation results.
    """
    from app.attendance.gap_service import create_gaps_for_absences

    lecture_plan = find_lecture_plan_for_session(
        db, data.class_id, data.section, data.date, data.period_id
    )

    # Validate unplanned rule
    if not lecture_plan and not data.is_unplanned:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "No lecture plan found for this class/section/date/period. "
                "Set is_unplanned=true to mark attendance for an unplanned/free period."
            ),
        )

    # Determine subject from lecture plan or request
    subject_name = (
        lecture_plan.subject_name
        if lecture_plan
        else (data.subject_name or "Unplanned")
    )

    present_count = 0
    absent_count  = 0
    late_count    = 0
    absent_student_ids: List[str] = []

    for item in data.records:
        # Upsert: find existing or create new
        existing = (
            db.query(AttendanceRecord)
            .filter(
                AttendanceRecord.class_id   == data.class_id,
                AttendanceRecord.student_id == item.student_id,
                AttendanceRecord.date       == data.date,
                AttendanceRecord.period_id  == data.period_id,
            )
            .first()
        )

        mark_enum = AttendanceMark(item.status)

        if existing:
            existing.mark      = mark_enum
            existing.marked_by = marked_by
            existing.notes     = item.notes
        else:
            record = AttendanceRecord(
                class_id   = data.class_id,
                student_id = item.student_id,
                period_id  = data.period_id,
                date       = data.date,
                mark       = mark_enum,
                marked_by  = marked_by,
                notes      = item.notes,
            )
            db.add(record)

        if item.status == "present":
            present_count += 1
        elif item.status == "absent":
            absent_count += 1
            absent_student_ids.append(item.student_id)
        elif item.status == "late":
            late_count += 1

    db.commit()

    # Auto-create gap records for absent students
    gaps = create_gaps_for_absences(
        db          = db,
        class_id    = data.class_id,
        session_date= data.date,
        period_id   = data.period_id,
        absent_student_ids = absent_student_ids,
        lecture_plan       = lecture_plan,
    )

    return {
        "class_id":        data.class_id,
        "section":         data.section,
        "date":            data.date,
        "period_id":       data.period_id,
        "total_marked":    len(data.records),
        "present_count":   present_count,
        "absent_count":    absent_count,
        "late_count":      late_count,
        "absent_students": absent_student_ids,
        "gaps_created":    len(gaps),
        "lecture_plan_id": lecture_plan.id if lecture_plan else None,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 1.8  Student History
# ══════════════════════════════════════════════════════════════════════════════

def get_student_history(
    db: Session,
    student_id: str,
    class_id: str,
    subject_name: Optional[str] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
) -> List[dict]:
    """
    Return attendance history for a student with period and lecture plan context.
    """
    q = (
        db.query(AttendanceRecord)
        .options(joinedload(AttendanceRecord.period))
        .filter(
            AttendanceRecord.student_id == student_id,
            AttendanceRecord.class_id   == class_id,
        )
    )
    if from_date:
        q = q.filter(AttendanceRecord.date >= from_date)
    if to_date:
        q = q.filter(AttendanceRecord.date <= to_date)

    records = q.order_by(AttendanceRecord.date.desc(), AttendanceRecord.period_id).all()

    history_items = []
    for rec in records:
        # Find matching lecture plan for topic context
        lp = find_lecture_plan_for_session(
            db, class_id, "A", rec.date, rec.period_id
        )

        # If filtering by subject and no match, try routine fallback
        actual_subject = lp.subject_name if lp else "Unassigned"
        if subject_name and actual_subject.lower() != subject_name.lower():
            # Check weekly routine for subject
            routine = (
                db.query(WeeklyRoutine)
                .filter(
                    WeeklyRoutine.class_id  == class_id,
                    WeeklyRoutine.period_id == rec.period_id,
                )
                .first()
            )
            actual_subject = routine.subject_name if routine else "Unassigned"
            if actual_subject.lower() != subject_name.lower():
                continue

        history_items.append({
            "id":           rec.id,
            "date":         rec.date,
            "period_id":    rec.period_id,
            "period_name":  rec.period.name if rec.period else None,
            "subject_name": actual_subject,
            "topic":        lp.topic if lp else None,
            "mark":         rec.mark.value,
            "marked_by":    rec.marked_by,
            "notes":        rec.notes,
        })

    return history_items


# ══════════════════════════════════════════════════════════════════════════════
# 1.9  Class Summary
# ══════════════════════════════════════════════════════════════════════════════

def get_class_summary(
    db: Session,
    class_id: str,
    section: str = "A",
    student_ids: Optional[List[str]] = None,
) -> dict:
    """
    Calculate per-subject attendance percentages for all students in a class.
    Returns data shaped for ClassAttendanceSummaryResponse.
    """
    global_threshold, subject_threshold_map = get_threshold_map(db, class_id)

    # Get all attendance records for the class
    q = db.query(AttendanceRecord).filter(
        AttendanceRecord.class_id == class_id,
    )
    if student_ids:
        q = q.filter(AttendanceRecord.student_id.in_(student_ids))

    all_records = q.all()

    # Group by student
    student_records: dict[str, list] = {}
    for rec in all_records:
        student_records.setdefault(rec.student_id, []).append(rec)

    students_summary = []
    for sid, records in student_records.items():
        # Per-subject breakdown
        subject_data: dict[str, dict] = {}
        total_attended = 0
        total_periods  = 0

        for rec in records:
            if rec.mark == AttendanceMark.OFF_DAY:
                continue

            # Try lecture plan first, then routine fallback for subject
            lp = find_lecture_plan_for_session(db, class_id, section, rec.date, rec.period_id)
            subj = lp.subject_name if lp else None

            if not subj:
                routine = (
                    db.query(WeeklyRoutine)
                    .filter(
                        WeeklyRoutine.class_id  == class_id,
                        WeeklyRoutine.period_id == rec.period_id,
                    )
                    .first()
                )
                subj = routine.subject_name if routine else "Unassigned"

            if subj not in subject_data:
                subject_data[subj] = {"attended": 0, "total": 0}

            subject_data[subj]["total"] += 1
            total_periods += 1

            if rec.mark in (AttendanceMark.PRESENT, AttendanceMark.LATE):
                subject_data[subj]["attended"] += 1
                total_attended += 1

        subjects = []
        has_warning = False
        for subj_name, counts in subject_data.items():
            threshold = subject_threshold_map.get(subj_name, global_threshold)
            pct = round((counts["attended"] / counts["total"]) * 100, 2) if counts["total"] else 0.0
            below = pct < threshold
            if below:
                has_warning = True
            subjects.append({
                "subject_name":       subj_name,
                "attended_periods":   counts["attended"],
                "total_periods":      counts["total"],
                "attendance_pct":     pct,
                "threshold":          threshold,
                "is_below_threshold": below,
            })

        overall_pct = round((total_attended / total_periods) * 100, 2) if total_periods else 0.0
        students_summary.append({
            "student_id":               sid,
            "student_name":             None,
            "overall_attended_periods": total_attended,
            "overall_total_periods":    total_periods,
            "overall_attendance_pct":   overall_pct,
            "has_warning":              has_warning,
            "subjects":                 subjects,
        })

    return {
        "class_id":          class_id,
        "section":           section,
        "total_students":    len(students_summary),
        "default_threshold": global_threshold,
        "students":          students_summary,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 1.10  Gap Record Queries
# ══════════════════════════════════════════════════════════════════════════════

def list_gaps(
    db: Session,
    student_id: Optional[str] = None,
    class_id: Optional[str] = None,
    status_filter: Optional[str] = None,
) -> List[GapRecord]:
    q = db.query(GapRecord).options(joinedload(GapRecord.lecture_plan))
    if student_id:
        q = q.filter(GapRecord.student_id == student_id)
    if class_id:
        q = q.filter(GapRecord.class_id == class_id)
    if status_filter:
        q = q.filter(GapRecord.status == status_filter)
    return q.order_by(GapRecord.priority_score.desc(), GapRecord.date.desc()).all()


def update_gap_status(db: Session, gap_id: uuid.UUID, new_status: str) -> GapRecord:
    gap = db.query(GapRecord).get(gap_id)
    if not gap:
        raise HTTPException(status_code=404, detail="Gap record not found.")
    gap.status = new_status
    db.commit()
    db.refresh(gap)
    return gap

