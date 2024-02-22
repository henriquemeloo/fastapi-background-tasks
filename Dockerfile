FROM python:3.11-slim as dev

WORKDIR /app

COPY requirements.txt .
# RUN pip install uv==0.1.5
# ENV VIRTUAL_ENV=/usr/local
RUN pip install --no-cache -r requirements.txt -t ./requirements
ENV PYTHONPATH=${PYTHONPATH}:${APP_PATH}/requirements/

ENTRYPOINT [ "python", "-m", "uvicorn", "api:app" ]


FROM public.ecr.aws/lambda/python:3.11 as prod
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}

COPY --from=dev /app/requirements/ ${LAMBDA_TASK_ROOT}/requirements/
ENV PYTHONPATH=${PYTHONPATH}:${LAMBDA_TASK_ROOT}/requirements/
RUN pip install mangum==0.17.0

COPY api.py .
COPY lambda_function.py .

CMD [ "lambda_function.lambda_handler" ]
