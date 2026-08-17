from pydantic import BaseModel
from typing import Optional, List
from datetime import date
from uuid import UUID


class LecturePlanCreate(BaseModel):
    topic_number: int
    topic_title: str
    description: Optional[str] = None


class BulkLecturePlanUpload(BaseModel):
    class_id: str
    subject_name: str
    topics: List[LecturePlanCreate]


class LogCoverageRequest(BaseModel):
    class_id: str
    period_id: UUID
    lecture_plan_id: UUID
    date: date
    taught_by: Optional[str] = None


class MissedLectureResponse(BaseModel):
    date: date
    period_name: str
    subject_name: str
    topic_number: int
    topic_title: str
    description: Optional[str] = None