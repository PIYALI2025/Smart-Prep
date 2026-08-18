from fastapi import APIRouter, HTTPException, status, Depends
from passlib.context import CryptContext
from datetime import datetime
from app.auth.jwt import create_access_token
from bson import ObjectId

from app.auth.dependencies import get_current_user_id
from app.auth.mongo_db import users_collection
from app.auth.schemas import StudentRegister, MentorRegister, UserLogin, TokenResponse

router = APIRouter(prefix="/auth", tags=["Auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

# --- STUDENT REGISTRATION ---

@router.post("/student/register", status_code=status.HTTP_201_CREATED)
async def register_student(data: StudentRegister):
    # Check if email is already taken
    if await users_collection.find_one({"email": data.email}):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    student_dict = data.model_dump()
    student_dict["password"] = hash_password(data.password)
    student_dict["role"] = "student"
    student_dict["created_at"] = datetime.utcnow()
    
    # Convert date/time objects to string for MongoDB storage
    student_dict["dob"] = str(student_dict["dob"])
    student_dict["time_start"] = str(student_dict["time_start"])
    student_dict["time_end"] = str(student_dict["time_end"])

    result = await users_collection.insert_one(student_dict)
    return {
        "message": "Student registered successfully", 
        "id": str(result.inserted_id)
    }


# --- MENTOR REGISTRATION ---

@router.post("/mentor/register", status_code=status.HTTP_201_CREATED)
async def register_mentor(data: MentorRegister):
    # Check if email is already taken
    if await users_collection.find_one({"email": data.email}):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    mentor_dict = data.model_dump()
    mentor_dict["password"] = hash_password(data.password)
    mentor_dict["role"] = "mentor"
    mentor_dict["created_at"] = datetime.utcnow()

    result = await users_collection.insert_one(mentor_dict)
    return {
        "message": "Mentor registered successfully", 
        "id": str(result.inserted_id)
    }


@router.post("/login", response_model=TokenResponse)
async def login(credentials: UserLogin):

    user = await users_collection.find_one({
        "email": credentials.email
    })

    if not user or not verify_password(
        credentials.password,
        user["password"]
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    token_payload = {
        "sub": str(user["_id"]),
        "email": user["email"],
        "role": user["role"]
    }

    token = create_access_token(token_payload)

    return TokenResponse(
        access_token=token,
        token_type="bearer"
    )

@router.get("/me")
async def get_me(
    user_id: str = Depends(get_current_user_id)
):
    user = await users_collection.find_one({
        "_id": ObjectId(user_id)
    })

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return {
        "id": str(user["_id"]),
        "username": user["username"],
        "email": user["email"],
        "role": user["role"]
    }


@router.get("/students")
async def get_students():
    """List all registered students."""
    cursor = users_collection.find({"role": "student"})
    students = []
    async for user in cursor:
        students.append({
            "id": str(user["_id"]),
            "username": user["username"],
            "email": user["email"],
            "name": user.get("name", user["username"].replace("_", " ").upper()),
            "standard": user.get("standard", "Class 10-A")
        })
    return students

