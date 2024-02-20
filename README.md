# FastAPI with background tasks

Testing the [background tasks](https://fastapi.tiangolo.com/tutorial/background-tasks/) feature
from FastAPI to send application "heavy" work to the background and return a response to the client
sooner. This implementation makes use of a postgres database to store jobs metadata, so the user
can query the state of their job after making the request.
