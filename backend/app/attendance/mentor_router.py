"""
app/attendance/mentor_router.py
-------------------------------
Endpoints for mentor workflows including batch attendance and class missed lecture summaries.
"""

from typing import List
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
import sqlalchemy as sa
from sqlalchemy.orm import Session

from app.core.database import get_db

router = APIRouter(prefix="/lecture-plan", tags=["Mentor / Lecture Plan"])


# ── Schemas ───────────────────────────────────────────────────────────────────
class AttendanceRecordItem(BaseModel):
    student_id: str
    mark: str  # 'present' or 'absent'


class BatchAttendancePayload(BaseModel):
    class_id: str
    period_id: str
    date: str
    records: List[AttendanceRecordItem]


# ── Batch Attendance Endpoint ─────────────────────────────────────────────────
@router.post("/attendance/batch", status_code=status.HTTP_201_CREATED)
def mark_batch_attendance(payload: BatchAttendancePayload, db: Session = Depends(get_db)):
    """Batch log attendance for multiple students."""
    query = sa.text("""
        INSERT INTO attendance_records (id, student_id, class_id, period_id, date, mark)
        VALUES (gen_random_uuid(), :student_id, :class_id, :period_id, :date, :mark);
    """)
    for item in payload.records:
        db.execute(query, {
            "student_id": item.student_id,
            "class_id": payload.class_id,
            "period_id": payload.period_id,
            "date": payload.date,
            "mark": item.mark
        })
    db.commit()
    return {"message": f"Successfully processed attendance for {len(payload.records)} students."}


# ── Class Missed Lectures Summary Endpoint ───────────────────────────────────
@router.get("/class-summary/{class_id}")
def get_class_missed_summary(class_id: str, date: str, db: Session = Depends(get_db)):
    """Get all absent students for a specific class and date alongside their unique missed topics."""
    query = sa.text("""
        SELECT DISTINCT
            ar.student_id,
            ar.date,
            tp.name AS period_name,
            lp.subject_name,
            lp.topic_number,
            lp.topic_title,
            lp.description
        FROM attendance_records ar
        JOIN timetable_periods tp ON ar.period_id = tp.id
        JOIN lecture_coverage lc ON lc.period_id = ar.period_id AND lc.date = ar.date
        JOIN lecture_plans lp ON lc.lecture_plan_id = lp.id
        WHERE ar.class_id = :class_id 
          AND ar.date = :date 
          AND ar.mark = 'absent'
        ORDER BY ar.student_id, tp.name, lp.topic_number;
    """)
    
    results = db.execute(query, {"class_id": class_id, "date": date}).mappings().all()
    return list(results)