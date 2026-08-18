"""
app/attendance/schemas.py
--------------------------
Pydantic v2 schemas for request bodies and API responses.
Organised by feature area:
  1.1  Timetable Settings  (periods, routine, holidays, extra off-days)
  1.2  Attendance Marking
  1.3  Attendance Stats
  1.4  Threshold Settings
"""

from __future__ import annotations

import uuid
from datetime import date, time
from typing import Optional, List

from pydantic import BaseModel, Field, field_validator, model_validator, ConfigDict


# ═══════════════════════════════════════════════════════════════════════════════
# Shared helpers
# ═══════════════════════════════════════════════════════════════════════════════

class OrmBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ═══════════════════════════════════════════════════════════════════════════════
# 1.1 — Timetable Periods
# ═══════════════════════════════════════════════════════════════════════════════

class PeriodCreate(BaseModel):
    class_id: str   = Field(..., min_length=1, max_length=64, examples=["CLASS-10A"])
    name: str       = Field(..., min_length=1, max_length=64, examples=["Period 1"])
    start_time: time = Field(..., examples=["09:00:00"])
    end_time: time   = Field(..., examples=["09:45:00"])
    order: int       = Field(default=0, ge=0)

    @model_validator(mode="after")
    def end_after_start(self) -> "PeriodCreate":
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be after start_time")
        return self


class PeriodUpdate(BaseModel):
    name: Optional[str]       = Field(None, min_length=1, max_length=64)
    start_time: Optional[time] = None
    end_time: Optional[time]   = None
    order: Optional[int]       = Field(None, ge=0)
    is_active: Optional[bool]  = None

    @model_validator(mode="after")
    def end_after_start(self) -> "PeriodUpdate":
        if self.start_time and self.end_time:
            if self.end_time <= self.start_time:
                raise ValueError("end_time must be after start_time")
        return self


class PeriodResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    name: str
    start_time: time
    end_time: time
    order: int
    is_active: bool


# ═══════════════════════════════════════════════════════════════════════════════
# 1.1 — Weekly Routine
# ═══════════════════════════════════════════════════════════════════════════════

class RoutineCreate(BaseModel):
    class_id: str      = Field(..., min_length=1, max_length=64)
    day_of_week: str   = Field(..., examples=["monday"])
    period_id: uuid.UUID
    subject_name: str  = Field(..., min_length=1, max_length=128)
    teacher_name: Optional[str] = Field(None, max_length=128)

    @field_validator("day_of_week")
    @classmethod
    def valid_day(cls, v: str) -> str:
        valid = {"monday","tuesday","wednesday","thursday","friday","saturday","sunday"}
        if v.lower() not in valid:
            raise ValueError(f"day_of_week must be one of {valid}")
        return v.lower()


class RoutineUpdate(BaseModel):
    subject_name: Optional[str]  = Field(None, min_length=1, max_length=128)
    teacher_name: Optional[str]  = Field(None, max_length=128)


class RoutineResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    day_of_week: str
    period_id: uuid.UUID
    subject_name: str
    teacher_name: Optional[str]
    period: Optional[PeriodResponse] = None


# ═══════════════════════════════════════════════════════════════════════════════
# 1.1 — Holidays (recurring weekly)
# ═══════════════════════════════════════════════════════════════════════════════

class HolidayCreate(BaseModel):
    class_id: str    = Field(..., min_length=1, max_length=64)
    day_of_week: str = Field(..., examples=["sunday"])
    description: Optional[str] = Field(None, max_length=256)

    @field_validator("day_of_week")
    @classmethod
    def valid_day(cls, v: str) -> str:
        valid = {"monday","tuesday","wednesday","thursday","friday","saturday","sunday"}
        if v.lower() not in valid:
            raise ValueError(f"day_of_week must be one of {valid}")
        return v.lower()


class HolidayResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    day_of_week: str
    description: Optional[str]


# ═══════════════════════════════════════════════════════════════════════════════
# 1.1 — Extra Off Days (one-off)
# ═══════════════════════════════════════════════════════════════════════════════

class ExtraOffDayCreate(BaseModel):
    class_id: str = Field(..., min_length=1, max_length=64)
    off_date: date
    reason: Optional[str] = Field(None, max_length=256)


class ExtraOffDayResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    off_date: date
    reason: Optional[str]


# ═══════════════════════════════════════════════════════════════════════════════
# 1.2 — Attendance Marking
# ═══════════════════════════════════════════════════════════════════════════════

VALID_MARKS = {"present", "absent", "late", "off_day"}


class AttendanceMarkCreate(BaseModel):
    class_id: str    = Field(..., min_length=1, max_length=64)
    student_id: str  = Field(..., min_length=1, max_length=64)
    period_id: uuid.UUID
    date: date
    mark: str        = Field(..., examples=["present"])
    marked_by: Optional[str] = None
    notes: Optional[str]     = Field(None, max_length=256)

    @field_validator("mark")
    @classmethod
    def valid_mark(cls, v: str) -> str:
        if v.lower() not in VALID_MARKS:
            raise ValueError(f"mark must be one of {VALID_MARKS}")
        return v.lower()


class AttendanceMarkUpdate(BaseModel):
    mark: str = Field(..., examples=["absent"])
    notes: Optional[str] = Field(None, max_length=256)

    @field_validator("mark")
    @classmethod
    def valid_mark(cls, v: str) -> str:
        if v.lower() not in VALID_MARKS:
            raise ValueError(f"mark must be one of {VALID_MARKS}")
        return v.lower()


class AttendanceRecordResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    student_id: str
    period_id: uuid.UUID
    date: date
    mark: str
    marked_by: Optional[str]
    notes: Optional[str]
    period: Optional[PeriodResponse] = None


# ═══════════════════════════════════════════════════════════════════════════════
# 1.3 — Attendance Stats / Counting
# ═══════════════════════════════════════════════════════════════════════════════

class SubjectStats(BaseModel):
    subject_name: str
    total_classes: int       # periods held (present + absent)
    present_count: int
    absent_count: int
    off_day_count: int
    attendance_pct: float    # present / (present + absent) * 100
    is_below_threshold: bool


class OverallStats(BaseModel):
    student_id: str
    class_id: str
    total_classes: int
    present_count: int
    absent_count: int
    off_day_count: int
    overall_attendance_pct: float
    subjects: List[SubjectStats]


# ═══════════════════════════════════════════════════════════════════════════════
# 1.4 — Threshold Settings
# ═══════════════════════════════════════════════════════════════════════════════

class ThresholdCreate(BaseModel):
    class_id: str    = Field(..., min_length=1, max_length=64)
    scope: str       = Field("global", examples=["global", "subject"])
    subject_name: Optional[str] = Field(None, max_length=128)
    threshold: float = Field(..., ge=0.0, le=100.0, examples=[75.0])

    @model_validator(mode="after")
    def subject_required_for_subject_scope(self) -> "ThresholdCreate":
        if self.scope == "subject" and not self.subject_name:
            raise ValueError("subject_name is required when scope='subject'")
        if self.scope == "global":
            self.subject_name = None
        return self


class ThresholdUpdate(BaseModel):
    threshold: float = Field(..., ge=0.0, le=100.0)


class ThresholdResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    scope: str
    subject_name: Optional[str]
    threshold: float


class ThresholdCheckItem(BaseModel):
    subject_name: str
    attendance_pct: float
    threshold: float
    is_below: bool
    classes_needed: int     # how many more present to meet threshold


class ThresholdCheckResponse(BaseModel):
    student_id: str
    class_id: str
    overall_pct: float
    global_threshold: float
    overall_below: bool
    subjects: List[ThresholdCheckItem]


# ═══════════════════════════════════════════════════════════════════════════════
# 1.5 — Lecture Plan Entries
# ═══════════════════════════════════════════════════════════════════════════════

class LecturePlanCreate(BaseModel):
    class_id: str              = Field(..., min_length=1, max_length=64, examples=["CLASS-10A"])
    section: str               = Field("A", min_length=1, max_length=16, examples=["A"])
    subject_name: str          = Field(..., min_length=1, max_length=128, examples=["Mathematics"])
    period_id: uuid.UUID
    date: date
    teacher_id: Optional[str]  = Field(None, max_length=64)
    topic: str                 = Field(..., min_length=1, max_length=256, examples=["Quadratic Equations"])
    subtopics: Optional[str]   = Field(None, max_length=512, examples=["Factoring, Quadratic Formula"])
    exam_weightage: float      = Field(5.0, ge=0.0, le=100.0, examples=[8.5])


class LecturePlanUpdate(BaseModel):
    topic: Optional[str]            = Field(None, min_length=1, max_length=256)
    subtopics: Optional[str]        = Field(None, max_length=512)
    exam_weightage: Optional[float] = Field(None, ge=0.0, le=100.0)
    teacher_id: Optional[str]       = Field(None, max_length=64)


class LecturePlanResponse(OrmBase):
    id: uuid.UUID
    class_id: str
    section: str
    subject_name: str
    period_id: uuid.UUID
    date: date
    teacher_id: Optional[str]
    topic: str
    subtopics: Optional[str]
    exam_weightage: float
    created_at: Optional[object] = None


# ═══════════════════════════════════════════════════════════════════════════════
# 1.6 — Gap Records
# ═══════════════════════════════════════════════════════════════════════════════

class GapRecordResponse(OrmBase):
    id: uuid.UUID
    student_id: str
    lecture_plan_id: uuid.UUID
    class_id: str
    subject_name: str
    date: date
    period_id: uuid.UUID
    reason: str
    priority_score: float
    status: str
    created_at: Optional[object] = None
    lecture_plan: Optional[LecturePlanResponse] = None


# ═══════════════════════════════════════════════════════════════════════════════
# 1.7 — Roster & Session Context
# ═══════════════════════════════════════════════════════════════════════════════

class RosterStudentItem(BaseModel):
    student_id: str
    name: Optional[str] = None
    status: str = Field("unmarked", examples=["present", "absent", "late", "unmarked"])
    record_id: Optional[uuid.UUID] = None
    notes: Optional[str] = None


class RosterSessionInfo(BaseModel):
    class_id: str
    section: str
    date: date
    period_id: uuid.UUID
    period_name: Optional[str] = None
    subject_name: Optional[str] = None
    lecture_plan: Optional[LecturePlanResponse] = None


class RosterResponse(BaseModel):
    session_info: RosterSessionInfo
    total_students: int
    students: List[RosterStudentItem]


# ═══════════════════════════════════════════════════════════════════════════════
# 1.8 — Bulk Marking
# ═══════════════════════════════════════════════════════════════════════════════

class StudentMarkItem(BaseModel):
    student_id: str = Field(..., min_length=1, max_length=64)
    status: str     = Field(..., examples=["present", "absent", "late"])
    notes: Optional[str] = Field(None, max_length=256)

    @field_validator("status")
    @classmethod
    def valid_status(cls, v: str) -> str:
        if v.lower() not in VALID_MARKS:
            raise ValueError(f"status must be one of {VALID_MARKS}")
        return v.lower()


class BulkMarkAttendanceRequest(BaseModel):
    class_id: str              = Field(..., min_length=1, max_length=64)
    section: str               = Field("A", min_length=1, max_length=16)
    date: date
    period_id: uuid.UUID
    subject_name: Optional[str]= Field(None, max_length=128)
    is_unplanned: bool         = Field(False, description="Flag as unplanned/free period if no lecture plan exists")
    records: List[StudentMarkItem]


class BulkMarkAttendanceResponse(BaseModel):
    class_id: str
    section: str
    date: date
    period_id: uuid.UUID
    total_marked: int
    present_count: int
    absent_count: int
    late_count: int
    absent_students: List[str]
    gaps_created: int
    lecture_plan_id: Optional[uuid.UUID] = None


# ═══════════════════════════════════════════════════════════════════════════════
# 1.9 — Student History & Class Summary
# ═══════════════════════════════════════════════════════════════════════════════

class StudentHistoryItem(BaseModel):
    id: uuid.UUID
    date: date
    period_id: uuid.UUID
    period_name: Optional[str] = None
    subject_name: str
    topic: Optional[str] = None
    mark: str
    marked_by: Optional[str] = None
    notes: Optional[str] = None


class StudentHistoryResponse(BaseModel):
    student_id: str
    total_records: int
    records: List[StudentHistoryItem]


class StudentSubjectAttendance(BaseModel):
    subject_name: str
    attended_periods: int
    total_periods: int
    attendance_pct: float
    threshold: float
    is_below_threshold: bool


class ClassStudentSummaryItem(BaseModel):
    student_id: str
    student_name: Optional[str] = None
    overall_attended_periods: int
    overall_total_periods: int
    overall_attendance_pct: float
    has_warning: bool
    subjects: List[StudentSubjectAttendance]


class ClassAttendanceSummaryResponse(BaseModel):
    class_id: str
    section: Optional[str] = None
    total_students: int
    default_threshold: float
    students: List[ClassStudentSummaryItem]

