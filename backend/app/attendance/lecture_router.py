from fastapi import APIRouter, Depends, status
from typing import List
import sqlalchemy as sa
from app.attendance.schemas_lecture import (
    BulkLecturePlanUpload,
    LogCoverageRequest,
    MissedLectureResponse,
)
from app.auth.dependencies import get_current_user_id
from app.core.database import get_db

router = APIRouter(prefix="/lecture-plan", tags=["Lecture Plan & Missed Lectures"])


@router.post("/upload", status_code=status.HTTP_201_CREATED)
def upload_lecture_plan(
    payload: BulkLecturePlanUpload,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id)
):
    """Upload or update syllabus topic plans for a specific class and subject."""
    query = sa.text("""
        INSERT INTO lecture_plans (class_id, subject_name, topic_number, topic_title, description)
        VALUES (:class_id, :subject_name, :topic_number, :topic_title, :description)
        ON CONFLICT ON CONSTRAINT uq_lecture_plan_class_subject_topic
        DO UPDATE SET topic_title = EXCLUDED.topic_title, description = EXCLUDED.description;
    """)
    
    for topic in payload.topics:
        db.execute(query, {
            "class_id": payload.class_id,
            "subject_name": payload.subject_name,
            "topic_number": topic.topic_number,
            "topic_title": topic.topic_title,
            "description": topic.description,
        })
    db.commit()
    return {"message": f"Successfully registered {len(payload.topics)} topics."}


@router.post("/log-coverage", status_code=status.HTTP_201_CREATED)
def log_lecture_coverage(
    payload: LogCoverageRequest,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id)
):
    """Log which topic was covered in a specific period on a specific date."""
    query = sa.text("""
        INSERT INTO lecture_coverage (class_id, period_id, lecture_plan_id, date, taught_by)
        VALUES (:class_id, :period_id, :lecture_plan_id, :date, :taught_by)
        ON CONFLICT ON CONSTRAINT uq_coverage_period_date_plan DO NOTHING;
    """)
    db.execute(query, {
        "class_id": payload.class_id,
        "period_id": payload.period_id,
        "lecture_plan_id": payload.lecture_plan_id,
        "date": payload.date,
        "taught_by": payload.taught_by or user_id,
    })
    db.commit()
    return {"message": "Lecture coverage logged successfully."}


@router.get("/missed/{student_id}", response_model=List[MissedLectureResponse])
def get_missed_lectures(
    student_id: str,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id)
):
    """Retrieve all topics missed by a student based on attendance records."""
    query = sa.text("""
        SELECT 
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
        WHERE ar.student_id = :student_id
          AND ar.mark = 'absent'
        ORDER BY ar.date DESC, tp.order ASC;
    """)
    result = db.execute(query, {"student_id": student_id})
    rows = result.mappings().all()
    return rows