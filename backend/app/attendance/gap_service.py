"""
app/attendance/gap_service.py
------------------------------
Reusable business logic for learning gap detection, prioritization,
and student notification when absences occur on covered lecture topics.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date
from typing import List, Optional

from sqlalchemy.orm import Session

from app.attendance.models import GapRecord, LecturePlanEntry

logger = logging.getLogger("attendance.gap_service")


def calculate_gap_priority(
    exam_weightage: float,
    exam_date: Optional[date] = None,
    session_date: Optional[date] = None,
) -> float:
    """
    Computes initial priority score for a missed topic gap.
    Weighted formula:
      - 80% driven by topic exam_weightage (scale 0-10 or 0-100)
      - 20% placeholder component for time remaining until exam.

    TODO: Wire to actual exam-date tracking / academic calendar when built.
    """
    # Base weight contribution (assumes weightage normalized or scale ~1-10)
    base_score = float(exam_weightage)

    # Time-to-exam proximity factor (placeholder: default 1.0 multiplier)
    # TODO: Calculate days_until_exam = (exam_date - session_date).days and scale
    time_proximity_factor = 1.0

    priority = round((base_score * 0.8) + (time_proximity_factor * 2.0), 2)
    return max(1.0, priority)


def notify_student_absence_gap(
    student_id: str,
    subject_name: str,
    topic: str,
    session_date: date,
    priority_score: float,
) -> None:
    """
    Queues a same-day notification event for the absent student informing them
    of missed lecture content.

    Stub implementation logging the event; designed to easily hook into Firebase
    Cloud Messaging (FCM) or push notification service.
    """
    logger.info(
        f"[NOTIFICATION QUEUED] Student {student_id} missed lecture on "
        f"'{subject_name}: {topic}' on {session_date}. Priority: {priority_score}"
    )


def create_gaps_for_absences(
    db: Session,
    class_id: str,
    session_date: date,
    period_id: uuid.UUID,
    absent_student_ids: List[str],
    lecture_plan: Optional[LecturePlanEntry],
) -> List[GapRecord]:
    """
    Creates gap records for students marked absent for a session with a linked lecture plan.
    Idempotent: skips students that already have a gap record for this specific lecture topic.

    Returns the list of newly created GapRecord objects.
    """
    if not lecture_plan or not absent_student_ids:
        return []

    created_gaps: List[GapRecord] = []
    priority = calculate_gap_priority(
        exam_weightage=lecture_plan.exam_weightage,
        session_date=session_date,
    )

    for student_id in absent_student_ids:
        # Check if gap record already exists for this (student, lecture_plan)
        existing = (
            db.query(GapRecord)
            .filter(
                GapRecord.student_id == student_id,
                GapRecord.lecture_plan_id == lecture_plan.id,
            )
            .first()
        )
        if existing:
            continue

        gap = GapRecord(
            student_id      = student_id,
            lecture_plan_id = lecture_plan.id,
            class_id        = class_id,
            subject_name    = lecture_plan.subject_name,
            date            = session_date,
            period_id       = period_id,
            reason          = "absence",
            priority_score  = priority,
            status          = "unresolved",
        )
        db.add(gap)
        created_gaps.append(gap)

        # Trigger notification stub
        notify_student_absence_gap(
            student_id     = student_id,
            subject_name   = lecture_plan.subject_name,
            topic          = lecture_plan.topic,
            session_date   = session_date,
            priority_score = priority,
        )

    if created_gaps:
        db.commit()
        for g in created_gaps:
            db.refresh(g)

    return created_gaps
