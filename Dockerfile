FROM python:3.8-alpine as base
MAINTAINER Carlos Nunez <cn@contino.io>

COPY requirements.txt /
RUN pip install -r requirements.txt

FROM base as app
RUN mkdir /app
COPY . /app

USER nobody
ENV FLASK_APP=hello_azure
WORKDIR /app/hello_azure
