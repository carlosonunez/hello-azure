FROM python:3.8-alpine as base
MAINTAINER Carlos Nunez <cn@contino.io>

COPY requirements.txt /
RUN apk update && apk add postgresql-dev gcc musl-dev libffi-dev
RUN pip install -r requirements.txt

FROM base as app
ENV FLASK_APP=hello_azure
RUN mkdir /app
COPY . /app
WORKDIR /app
USER nobody
