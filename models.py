from enum import Enum
from typing import Optional
import uuid as uuid_

from pydantic import BaseModel
from sqlmodel import Field, SQLModel


class _JobStatusEnum(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class Job(SQLModel, table=True):
    """SQLModel class for Job ORM."""

    id: uuid_.UUID = Field(primary_key=True, default_factory=uuid_.uuid4)
    status: _JobStatusEnum
    return_value: Optional[str] = None


class JobRequest(BaseModel):
    delay: int = Field(gt=0, le=20)
