"""Collie lambda function definition."""
from mangum import Mangum

from api import app


lambda_handler = Mangum(app, lifespan="off")
