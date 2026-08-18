"""
backend/seed_data.py
--------------------
Seed script to initialize SQLite database tables and populate both SQLite
and MongoDB with realistic MVP test data for Smart-Prep.
"""

import asyncio
from datetime import date, datetime, time, timedelta
import uuid
import motor.motor_asyncio
from passlib.context import CryptContext
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.database import Base, engine, SessionLocal
from app.attendance.models import (
    TimetablePeriod,
    WeeklyRoutine,
    Holiday,
    ExtraOffDay,
    AttendanceRecord,
    AttendanceThreshold,
    LecturePlanEntry,
    GapRecord,
    DayOfWeek,
    AttendanceMark,
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


async def seed_mongodb():
    print("--- [1/2] Seeding MongoDB Auth Data ---")
    client = motor.motor_asyncio.AsyncIOMotorClient(settings.MONGO_URI)
    db = client[settings.MONGO_DB_NAME]
    users_col = db["users"]

    # Clear existing demo users
    await users_col.delete_many({"email": {"$in": [
        "student@smartprep.com",
        "mentor@smartprep.com",
        "student2@smartprep.com",
        "student3@smartprep.com",
        "student4@smartprep.com",
        "student5@smartprep.com",
    ]}})

    hashed_pw = pwd_context.hash("password123")

    demo_users = [
        {
            "username": "aarav_student",
            "email": "student@smartprep.com",
            "password": hashed_pw,
            "role": "student",
            "dob": "2008-04-12",
            "institution_type": "School",
            "board": "CBSE",
            "standard": "Class 10-A",
            "time_start": "09:00:00",
            "time_end": "13:30:00",
            "created_at": datetime.utcnow(),
        },
        {
            "username": "dr_ramanathan",
            "email": "mentor@smartprep.com",
            "password": hashed_pw,
            "role": "mentor",
            "institution": "Delhi Public School",
            "board": "CBSE",
            "subject": "Mathematics",
            "created_at": datetime.utcnow(),
        },
        {
            "username": "priya_patel",
            "email": "student2@smartprep.com",
            "password": hashed_pw,
            "role": "student",
            "dob": "2008-07-22",
            "institution_type": "School",
            "board": "CBSE",
            "standard": "Class 10-A",
            "created_at": datetime.utcnow(),
        },
        {
            "username": "rohit_verma",
            "email": "student3@smartprep.com",
            "password": hashed_pw,
            "role": "student",
            "dob": "2008-01-15",
            "institution_type": "School",
            "board": "CBSE",
            "standard": "Class 10-A",
            "created_at": datetime.utcnow(),
        },
        {
            "username": "ananya_das",
            "email": "student4@smartprep.com",
            "password": hashed_pw,
            "role": "student",
            "dob": "2008-11-05",
            "institution_type": "School",
            "board": "CBSE",
            "standard": "Class 10-A",
            "created_at": datetime.utcnow(),
        },
        {
            "username": "kavita_singh",
            "email": "student5@smartprep.com",
            "password": hashed_pw,
            "role": "student",
            "dob": "2008-09-30",
            "institution_type": "School",
            "board": "CBSE",
            "standard": "Class 10-A",
            "created_at": datetime.utcnow(),
        },
    ]

    inserted = await users_col.insert_many(demo_users)
    print(f"MongoDB: Successfully seeded {len(inserted.inserted_ids)} users.")
    
    # Fetch student 1 ID to correlate with student attendance
    main_student = await users_col.find_one({"email": "student@smartprep.com"})
    main_mentor = await users_col.find_one({"email": "mentor@smartprep.com"})
    client.close()
    return str(main_student["_id"]), str(main_mentor["_id"])


def seed_sqlite(student_id: str, mentor_id: str):
    print("--- [2/2] Seeding SQLite Attendance & Gap Data ---")
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    db = SessionLocal()
    class_id = "CLASS-10A"

    try:
        # 1. Periods
        periods_data = [
            ("Period 1", time(9, 0), time(9, 45), 1),
            ("Period 2", time(9, 50), time(10, 35), 2),
            ("Period 3", time(10, 40), time(11, 25), 3),
            ("Period 4", time(11, 45), time(12, 30), 4),
            ("Period 5", time(12, 35), time(13, 20), 5),
        ]
        periods = []
        for name, start, end, order in periods_data:
            p = TimetablePeriod(
                id=uuid.uuid4(),
                class_id=class_id,
                name=name,
                start_time=start,
                end_time=end,
                order=order,
                is_active=True,
            )
            db.add(p)
            periods.append(p)
        db.flush()

        # 2. Weekly Routine (Monday to Friday)
        subjects_schedule = {
            DayOfWeek.MONDAY: ["Mathematics", "Physics", "Chemistry", "English", "Computer Science"],
            DayOfWeek.TUESDAY: ["Physics", "Mathematics", "Biology", "English", "Physical Education"],
            DayOfWeek.WEDNESDAY: ["Chemistry", "Physics", "Mathematics", "Computer Science", "English"],
            DayOfWeek.THURSDAY: ["Mathematics", "Chemistry", "Physics", "English", "Social Science"],
            DayOfWeek.FRIDAY: ["Computer Science", "Mathematics", "Physics", "Chemistry", "Library"],
        }
        for day, subjects in subjects_schedule.items():
            for idx, subj in enumerate(subjects):
                r = WeeklyRoutine(
                    id=uuid.uuid4(),
                    class_id=class_id,
                    day_of_week=day,
                    period_id=periods[idx].id,
                    subject_name=subj,
                    teacher_name="Dr. Ramanathan" if subj == "Mathematics" else "Prof. Sharma",
                )
                db.add(r)

        # 3. Weekly Holidays
        for holiday_day in [DayOfWeek.SATURDAY, DayOfWeek.SUNDAY]:
            h = Holiday(
                id=uuid.uuid4(),
                class_id=class_id,
                day_of_week=holiday_day,
                description="Weekend Off",
            )
            db.add(h)

        # 4. Attendance Thresholds
        db.add(AttendanceThreshold(
            id=uuid.uuid4(),
            class_id=class_id,
            scope="global",
            subject_name=None,
            threshold=75.0,
        ))
        db.add(AttendanceThreshold(
            id=uuid.uuid4(),
            class_id=class_id,
            scope="subject",
            subject_name="Mathematics",
            threshold=80.0,
        ))

        # 5. Lecture Plan Entries for recent days
        today = date.today()
        lecture_plans_list = [
            {
                "days_ago": 1,
                "period_idx": 0,
                "subject": "Mathematics",
                "topic": "Quadratic Equations — Discriminant & Root Nature",
                "subtopics": "Standard form ax^2+bx+c=0, Discriminant Delta = b^2-4ac, Real/Complex roots",
                "weightage": 9.0,
            },
            {
                "days_ago": 2,
                "period_idx": 1,
                "subject": "Physics",
                "topic": "Electromagnetic Induction — Faraday's Laws & Lenz's Rule",
                "subtopics": "Magnetic flux, Induced EMF, Direction of induced current",
                "weightage": 8.5,
            },
            {
                "days_ago": 3,
                "period_idx": 2,
                "subject": "Chemistry",
                "topic": "Chemical Bonding — Hybridization & VSEPR Theory",
                "subtopics": "sp, sp2, sp3 hybridization, Geometry of molecules, Lone pair repulsions",
                "weightage": 7.5,
            },
            {
                "days_ago": 4,
                "period_idx": 0,
                "subject": "Mathematics",
                "topic": "Arithmetic Progressions — nth Term & Sum Formula",
                "subtopics": "General term a_n = a + (n-1)d, Sum of first n terms S_n",
                "weightage": 8.0,
            },
            {
                "days_ago": 5,
                "period_idx": 3,
                "subject": "Computer Science",
                "topic": "Binary Search Trees & Time Complexity",
                "subtopics": "Tree traversal (Inorder, Preorder, Postorder), O(log N) lookup",
                "weightage": 6.5,
            },
        ]

        created_lp_entries = []
        for lp in lecture_plans_list:
            lp_date = today - timedelta(days=lp["days_ago"])
            entry = LecturePlanEntry(
                id=uuid.uuid4(),
                class_id=class_id,
                section="A",
                subject_name=lp["subject"],
                period_id=periods[lp["period_idx"]].id,
                date=lp_date,
                teacher_id=mentor_id,
                topic=lp["topic"],
                subtopics=lp["subtopics"],
                exam_weightage=lp["weightage"],
            )
            db.add(entry)
            created_lp_entries.append((entry, lp))
        db.flush()

        # 6. Past 20 days attendance records for student_id
        student_list = [student_id, "student-uuid-002", "student-uuid-003", "student-uuid-004", "student-uuid-005"]
        
        for d in range(1, 21):
            cur_date = today - timedelta(days=d)
            if cur_date.weekday() in [5, 6]:  # Skip weekends
                continue

            for p_idx, p in enumerate(periods):
                for s_id in student_list:
                    # Deterministic attendance pattern: main student is absent on specific days
                    is_main = (s_id == student_id)
                    if is_main and d in [1, 2, 3, 7, 12, 16]:
                        mark = AttendanceMark.ABSENT
                    else:
                        mark = AttendanceMark.PRESENT

                    rec = AttendanceRecord(
                        id=uuid.uuid4(),
                        class_id=class_id,
                        student_id=s_id,
                        period_id=p.id,
                        date=cur_date,
                        mark=mark,
                        marked_by=mentor_id,
                    )
                    db.add(rec)

        # 7. Learning Gaps for the main student
        # For the missed lectures in recent days, create GapRecords
        for entry, lp in created_lp_entries[:3]:
            gap = GapRecord(
                id=uuid.uuid4(),
                student_id=student_id,
                lecture_plan_id=entry.id,
                class_id=class_id,
                subject_name=entry.subject_name,
                date=entry.date,
                period_id=entry.period_id,
                reason="absence",
                priority_score=round(lp["weightage"] * 0.95, 1),
                status="unresolved",
            )
            db.add(gap)

        db.commit()
        print(f"SQLite: Successfully populated all timetable, routine, attendance, and gap tables for {class_id}.")
    finally:
        db.close()


async def main():
    student_id, mentor_id = await seed_mongodb()
    seed_sqlite(student_id, mentor_id)
    print("\n✅ Seed complete! You can now log in with:")
    print("   Student: student@smartprep.com / password123")
    print("   Mentor:  mentor@smartprep.com  / password123")


if __name__ == "__main__":
    asyncio.run(main())
