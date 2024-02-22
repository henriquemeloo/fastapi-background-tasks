from time import sleep

from fastapi import FastAPI, BackgroundTasks


app = FastAPI()


def create_stream():
    for i in range(25):
        sleep(1)
        print(f"Still running, for about {i} seconds...")


@app.get("/job", status_code=202)
def create_job(background_tasks: BackgroundTasks):
    background_tasks.add_task(create_stream)
