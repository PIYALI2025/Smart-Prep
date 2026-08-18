"""
app/attendance/models.py
------------------------
SQLAlchemy ORM models for the Attendance Management System.

Tables
------
1. timetable_periods   – Named period slots with start/end time
2. weekly_routine      – Day-of-week → subject/period mapping
3. holidays            – Weekly recurring off-days (e.g., every Sunday)
4. extra_off_days      – One-off extra holiday dates
5. attendance_records  – Per-student, per-date, per-period mark
6. attendance_threshold – Mandatory attendance % per subject (or global)
"""

import uuid
from datetime import datetime, date, time

from sqlalchemy import (
    Column, String, Integer, Float, Boolean,
    Date, Time, DateTime, Enum, UniqueConstraint, ForeignKey,
    CheckConstraint, text, TypeDecorator, CHAR,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.core.database import Base, _is_sqlite
import enum


# ── Cross-database UUID type ──────────────────────────────────────────────────
# Uses native UUID on PostgreSQL, CHAR(36) string on SQLite (for local dev).

class UUIDType(TypeDecorator):
    """Platform-independent UUID type."""
    impl = CHAR
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_UUID(as_uuid=True))
        return dialect.type_descriptor(CHAR(36))

    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        if dialect.name == "postgresql":
            return value if isinstance(value, uuid.UUID) else uuid.UUID(str(value))
        return str(value) if isinstance(value, uuid.UUID) else str(uuid.UUID(str(value)))

    def process_result_value(self, value, dialect):
        if value is None:
            return value
        return value if isinstance(value, uuid.UUID) else uuid.UUID(str(value))

# Alias for convenience
UUID = UUIDType



# ─────────────────────────── Enumerations ────────────────────────────────────

class DayOfWeek(str, enum.Enum):
    MONDAY    = "monday"
    TUESDAY   = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY  = "thursday"
    FRIDAY    = "friday"
    SATURDAY  = "saturday"
    SUNDAY    = "sunday"


class AttendanceMark(str, enum.Enum):
    PRESENT  = "present"
    ABSENT   = "absent"
    LATE     = "late"
    OFF_DAY  = "off_day"    # holiday / off – doesn't count against student


# ─────────────────────────── Table 1: Periods ────────────────────────────────

class TimetablePeriod(Base):
    """
    Defines a named period slot (e.g., 'Period 1', 'Lunch', 'Period 5').
    Periods are school-wide and optionally scoped by class_id.
    """
    __tablename__ = "timetable_periods"

    id         = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id   = Column(String(64), nullable=False, index=True)
    name       = Column(String(64), nullable=False)           # e.g. "Period 1"
    start_time = Column(Time, nullable=False)                  # e.g. 09:00
    end_time   = Column(Time, nullable=False)                  # e.g. 09:45
    order      = Column(Integer, nullable=False, default=0)    # display order
    is_active  = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow,
                        onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("class_id", "name", name="uq_period_class_name"),
        CheckConstraint("end_time > start_time", name="ck_period_time_order"),
    )

    routine_entries  = relationship("WeeklyRoutine",    back_populates="period",
                                    cascade="all, delete-orphan")
    attendance_marks = relationship("AttendanceRecord", back_populates="period",
                                    cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<TimetablePeriod {self.name} {self.start_time}-{self.end_time}>"


# ─────────────────────────── Table 2: Weekly Routine ─────────────────────────

class WeeklyRoutine(Base):
    """
    Maps a (class_id, day_of_week, period_id) → subject_name.
    One entry = one subject taught in one period on one day.
    """
    __tablename__ = "weekly_routine"

    id           = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id     = Column(String(64), nullable=False, index=True)
    day_of_week  = Column(Enum(DayOfWeek), nullable=False)
    period_id    = Column(UUID(),
                          ForeignKey("timetable_periods.id", ondelete="CASCADE"),
                          nullable=False)
    subject_name = Column(String(128), nullable=False)
    teacher_name = Column(String(128), nullable=True)
    created_at   = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at   = Column(DateTime, default=datetime.utcnow,
                          onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("class_id", "day_of_week", "period_id",
                         name="uq_routine_class_day_period"),
    )

    period = relationship("TimetablePeriod", back_populates="routine_entries")

    def __repr__(self) -> str:
        return (f"<WeeklyRoutine {self.day_of_week} P={self.period_id} "
                f"→ {self.subject_name}>")


# ─────────────────────────── Table 3: Weekly Holidays ────────────────────────

class Holiday(Base):
    """
    Recurring weekly holidays (e.g., every Sunday for class_id 'ALL').
    These affect all students in the class; attendance is not recorded on these days.
    """
    __tablename__ = "holidays"

    id          = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id    = Column(String(64), nullable=False, index=True)
    day_of_week = Column(Enum(DayOfWeek), nullable=False)
    description = Column(String(256), nullable=True)
    created_at  = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("class_id", "day_of_week", name="uq_holiday_class_day"),
    )

    def __repr__(self) -> str:
        return f"<Holiday class={self.class_id} day={self.day_of_week}>"


# ─────────────────────────── Table 4: Extra Off Days ─────────────────────────

class ExtraOffDay(Base):
    """
    One-off extra holiday / off-day dates (e.g., Republic Day, school event).
    Not tied to a recurring day-of-week.
    """
    __tablename__ = "extra_off_days"

    id          = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id    = Column(String(64), nullable=False, index=True)
    off_date    = Column(Date, nullable=False)
    reason      = Column(String(256), nullable=True)
    created_at  = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("class_id", "off_date", name="uq_extra_offday_class_date"),
    )

    def __repr__(self) -> str:
        return f"<ExtraOffDay class={self.class_id} date={self.off_date}>"


# ─────────────────────────── Table 5: Attendance Records ─────────────────────

class AttendanceRecord(Base):
    """
    Stores the attendance mark for one student on one date for one period.

    mark values:
      present  – student was present
      absent   – student was absent
      off_day  – period was a holiday/off (does not count against student)
    """
    __tablename__ = "attendance_records"

    id         = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id   = Column(String(64), nullable=False, index=True)
    student_id = Column(String(64), nullable=False, index=True)   # Supabase auth UUID
    period_id  = Column(UUID(),
                        ForeignKey("timetable_periods.id", ondelete="CASCADE"),
                        nullable=False)
    date       = Column(Date, nullable=False)
    mark       = Column(Enum(AttendanceMark), nullable=False)
    marked_by  = Column(String(64), nullable=True)   # teacher UUID
    notes      = Column(String(256), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow,
                        onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("student_id", "period_id", "date",
                         name="uq_attendance_student_period_date"),
    )

    period = relationship("TimetablePeriod", back_populates="attendance_marks")

    def __repr__(self) -> str:
        return (f"<AttendanceRecord student={self.student_id} "
                f"date={self.date} period={self.period_id} mark={self.mark}>")


# ─────────────────────────── Table 6: Threshold Settings ─────────────────────

class AttendanceThreshold(Base):
    """
    Mandatory attendance percentage threshold.
    scope:
      global   – applies to all subjects in the class
      subject  – applies only to subject_name
    """
    __tablename__ = "attendance_thresholds"

    id           = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id     = Column(String(64), nullable=False, index=True)
    scope        = Column(String(16), nullable=False, default="global")  # 'global'|'subject'
    subject_name = Column(String(128), nullable=True)    # NULL when scope='global'
    threshold    = Column(Float, nullable=False, default=75.0)
    created_at   = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at   = Column(DateTime, default=datetime.utcnow,
                          onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        CheckConstraint("threshold >= 0 AND threshold <= 100",
                        name="ck_threshold_range"),
        UniqueConstraint("class_id", "scope", "subject_name",
                         name="uq_threshold_class_scope_subject"),
    )

    def __repr__(self) -> str:
        return (f"<AttendanceThreshold class={self.class_id} "
                f"scope={self.scope} subject={self.subject_name} "
                f"threshold={self.threshold}>")


# ─────────────────────────── Table 7: Lecture Plan Entries ────────────────────

class LecturePlanEntry(Base):
    """
    Represents one subject + topic taught in one period on one date by one teacher.
    Includes subtopics covered and an exam-weightage indicator for gap prioritization.
    """
    __tablename__ = "lecture_plan_entries"

    id             = Column(UUID(), primary_key=True, default=uuid.uuid4)
    class_id       = Column(String(64), nullable=False, index=True)
    section        = Column(String(16), nullable=False, default="A", index=True)
    subject_name   = Column(String(128), nullable=False, index=True)
    period_id      = Column(UUID(),
                            ForeignKey("timetable_periods.id", ondelete="CASCADE"),
                            nullable=False)
    date           = Column(Date, nullable=False, index=True)
    teacher_id     = Column(String(64), nullable=True)
    topic          = Column(String(256), nullable=False)
    subtopics      = Column(String(512), nullable=True)
    exam_weightage = Column(Float, nullable=False, default=5.0)  # e.g., 1.0 - 10.0 scale or %
    created_at     = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at     = Column(DateTime, default=datetime.utcnow,
                            onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("class_id", "section", "date", "period_id",
                         name="uq_lecture_plan_class_sec_date_period"),
    )

    period = relationship("TimetablePeriod")
    gaps   = relationship("GapRecord", back_populates="lecture_plan",
                          cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return (f"<LecturePlanEntry {self.class_id}-{self.section} {self.subject_name} "
                f"{self.date} P={self.period_id} topic={self.topic}>")


# ─────────────────────────── Table 8: Gap Records ────────────────────────────

class GapRecord(Base):
    """
    Created automatically when a student is marked absent for a period with a linked
    lecture-plan entry. Tracks learning gaps, priority scores, and review status.
    """
    __tablename__ = "gap_records"

    id              = Column(UUID(), primary_key=True, default=uuid.uuid4)
    student_id      = Column(String(64), nullable=False, index=True)
    lecture_plan_id = Column(UUID(),
                             ForeignKey("lecture_plan_entries.id", ondelete="CASCADE"),
                             nullable=False)
    class_id        = Column(String(64), nullable=False, index=True)
    subject_name    = Column(String(128), nullable=False)
    date            = Column(Date, nullable=False)
    period_id       = Column(UUID(),
                             ForeignKey("timetable_periods.id", ondelete="CASCADE"),
                             nullable=False)
    reason          = Column(String(64), nullable=False, default="absence")
    priority_score  = Column(Float, nullable=False, default=5.0)
    status          = Column(String(32), nullable=False, default="unresolved")  # unresolved | reviewed
    created_at      = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at      = Column(DateTime, default=datetime.utcnow,
                             onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("student_id", "lecture_plan_id",
                         name="uq_gap_student_lecture_plan"),
    )

    lecture_plan = relationship("LecturePlanEntry", back_populates="gaps")
    period       = relationship("TimetablePeriod")

    def __repr__(self) -> str:
        return (f"<GapRecord student={self.student_id} lecture_plan={self.lecture_plan_id} "
                f"score={self.priority_score} status={self.status}>")

