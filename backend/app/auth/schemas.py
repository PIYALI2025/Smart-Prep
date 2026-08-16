from pydantic import BaseModel, EmailStr
from datetime import date, time

class UserBase(BaseModel):
    username: str
    email: EmailStr
    password: str

class StudentRegister(UserBase):
    dob: date
    institution_type: str  # School / College / Self / University
    board: str
    standard: str          # Class / Semester
    time_start: time
    time_end: time

class MentorRegister(UserBase):
    institution: str
    board: str
    subject: str

# Login Payload Schema
class UserLogin(BaseModel):
    email: EmailStr
    password: str

# Token Response Schema
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"