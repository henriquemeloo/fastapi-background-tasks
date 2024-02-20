FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install uv==0.1.5
ENV VIRTUAL_ENV=/usr/local
RUN uv pip install --no-cache -r requirements.txt

ENTRYPOINT [ "python", "-m", "uvicorn", "api:app" ]
