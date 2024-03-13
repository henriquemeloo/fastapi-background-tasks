# FastAPI with background tasks

Testing the [background tasks](https://fastapi.tiangolo.com/tutorial/background-tasks/) feature
from FastAPI to send application "heavy" work to the background and return a response to the client
sooner. This implementation makes use of a postgres database to store jobs metadata, so the user
can query the state of their job after making the request.

## Deploying a new version

- Push lambda image
- Point lambda to the new image
- Publish a new lambda version
- Check if the alias is pointing to the new version
- For any changes on the API Gateway:
  - Deploy a new version for the stage
