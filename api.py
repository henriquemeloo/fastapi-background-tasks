from time import sleep
from random import random
import traceback
import uuid

from fastapi import FastAPI, HTTPException, BackgroundTasks
from sqlmodel import create_engine, select, Session, SQLModel

from models import Job, JobRequest


app = FastAPI()


DATABASE_URI = "postgresql://postgres:postgres@postgres:5432/jobs"


@app.on_event("startup")
def create_db_and_tables():
    engine = create_engine(DATABASE_URI, echo=True)
    SQLModel.metadata.create_all(engine)


def create_stream(n):
    print("Doing some heavy work that might fail...")
    sleep(n)
    if random() < .3:
        raise RuntimeError("Oops...")
    print("Done")
    return f"Heavy work done for {n} seconds"


def _heavy_work(job: Job, func, *args):
    engine = create_engine(DATABASE_URI, echo=True)
    try:
        # Write return value to database
        return_value = func(*args)
        job.status = "succeeded"
    except Exception:
        # Log exception to database
        return_value = traceback.format_exc()
        job.status = "failed"
    finally:
        job.return_value = return_value
        with Session(engine) as session:
            session.add(job)
            session.commit()


@app.post("/job")
def create_job(background_tasks: BackgroundTasks, job_request: JobRequest):
    engine = create_engine(DATABASE_URI, echo=True)
    with Session(engine) as session:
        job = Job(status="queued")
        session.add(job)
        session.commit()
        session.refresh(job)
    background_tasks.add_task(
        _heavy_work, job, create_stream, job_request.delay)
    return {
        "job_id": job.id
    }


@app.get("/jobs/{job_id}")
def get_job_status(job_id: uuid.UUID):
    engine = create_engine(DATABASE_URI, echo=True)
    with Session(engine) as session:
        statement = select(Job).where(Job.id == job_id)
        records = session.exec(statement)
        try:
            job = records.one()
        except Exception as e:
            raise HTTPException(status_code=404, detail="Job not found") from e

    if job.status == "failed":
        raise HTTPException(
            status_code=500,
            detail=f"Job failed with exception: {job.return_value}")

    if job.status == "running":
        return {
            "status": "running"
        }

    return {
        "status": job.status,
        "result": job.return_value
    }
