"""
app/auth/mongo_db.py
--------------------
MongoDB connection for authentication and user management.
"""

from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings


# MongoDB configuration from shared application settings
MONGO_URI = settings.MONGO_URI
MONGO_DB_NAME = settings.MONGO_DB_NAME


# Create MongoDB client
client = AsyncIOMotorClient(MONGO_URI)

# Select database
db = client[MONGO_DB_NAME]

# Users collection
users_collection = db["users"]