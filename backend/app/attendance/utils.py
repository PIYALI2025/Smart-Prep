"""
app/attendance/utils.py
-----------------------
Pure-Python helpers for attendance calculation logic.
No DB access – all functions take plain data structures.
"""

from __future__ import annotations

from datetime import date
from typing import List, Dict, Tuple


# ─────────────────────────────────────────────────────────────────────────────
# Attendance percentage calculation
# ─────────────────────────────────────────────────────────────────────────────

def attendance_percentage(present: int, absent: int) -> float:
    """
    Returns attendance % = present / (present + absent) * 100.
    Returns 0.0 when no classes have been held.
    off_day records are excluded from both numerator and denominator.
    """
    total = present + absent
    if total == 0:
        return 0.0
    return round(present / total * 100, 2)


# ─────────────────────────────────────────────────────────────────────────────
# Classes needed to reach threshold
# ─────────────────────────────────────────────────────────────────────────────

def classes_needed_for_threshold(
    present: int,
    absent: int,
    threshold: float,
) -> int:
    """
    Calculate how many additional consecutive-present classes a student
    needs to reach the given threshold percentage.

    Returns 0 if already at or above threshold.
    """
    if attendance_percentage(present, absent) >= threshold:
        return 0

    # Solve: (present + x) / (present + absent + x) >= threshold/100
    # => present + x >= threshold/100 * (present + absent + x)
    # => x * (1 - threshold/100) >= threshold/100 * (present + absent) - present
    t = threshold / 100.0
    numerator = t * (present + absent) - present
    denominator = 1.0 - t

    if denominator <= 0:
        return 0  # threshold is 100 % – theoretically infinite classes needed

    return max(0, int(numerator / denominator) + 1)


# ─────────────────────────────────────────────────────────────────────────────
# Day-of-week helpers
# ─────────────────────────────────────────────────────────────────────────────

DAY_NAMES = [
    "monday", "tuesday", "wednesday", "thursday",
    "friday", "saturday", "sunday",
]


def day_name(d: date) -> str:
    """Return the lowercase day-of-week name for a given date."""
    return DAY_NAMES[d.weekday()]


def is_weekly_holiday(d: date, holiday_days: List[str]) -> bool:
    """
    Check if date falls on a weekly holiday.
    holiday_days: list of lowercase day-of-week strings (e.g. ['sunday']).
    """
    return day_name(d) in {h.lower() for h in holiday_days}


def is_extra_off_day(d: date, off_dates: List[date]) -> bool:
    """Check if a date is in the list of extra off-day dates."""
    return d in set(off_dates)


def is_off_day(d: date, holiday_days: List[str], off_dates: List[date]) -> bool:
    """Combine weekly holiday and extra off-day checks."""
    return is_weekly_holiday(d, holiday_days) or is_extra_off_day(d, off_dates)


# ─────────────────────────────────────────────────────────────────────────────
# Subject-wise stats aggregation
# ─────────────────────────────────────────────────────────────────────────────

def aggregate_by_subject(
    records: List[Dict],
    threshold_map: Dict[str, float],   # subject_name → threshold %
    global_threshold: float,
) -> Tuple[List[Dict], int, int, int]:
    """
    Aggregate a flat list of attendance record dicts by subject.

    Each record dict must have:
        subject_name (str), mark (str: 'present'|'absent'|'off_day')

    Returns:
        (per_subject_stats_list, total_present, total_absent, total_off_day)

    per_subject_stats_list entries:
        subject_name, total_classes, present_count, absent_count,
        off_day_count, attendance_pct, is_below_threshold
    """
    from collections import defaultdict

    buckets: Dict[str, Dict[str, int]] = defaultdict(
        lambda: {"present": 0, "absent": 0, "off_day": 0}
    )

    for rec in records:
        subj = rec.get("subject_name", "Unknown")
        mark = rec.get("mark", "")
        if mark in ("present", "absent", "off_day"):
            buckets[subj][mark] += 1

    stats = []
    total_present = total_absent = total_off_day = 0

    for subj, counts in buckets.items():
        p, a, o = counts["present"], counts["absent"], counts["off_day"]
        pct = attendance_percentage(p, a)
        threshold = threshold_map.get(subj, global_threshold)
        stats.append({
            "subject_name": subj,
            "total_classes": p + a,
            "present_count": p,
            "absent_count": a,
            "off_day_count": o,
            "attendance_pct": pct,
            "is_below_threshold": pct < threshold,
        })
        total_present  += p
        total_absent   += a
        total_off_day  += o

    stats.sort(key=lambda x: x["subject_name"])
    return stats, total_present, total_absent, total_off_day
