import os
import random
import string
import logging
import json
from azure.storage.blob import BlobServiceClient
from flask import Flask, render_template, make_response, request, Response
from flask_sqlalchemy_session import flask_scoped_session
from prometheus_flask_exporter import PrometheusMetrics
from sqlalchemy import create_engine, Column, Integer, MetaData, Table, String
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base


class ImageStore:
    container_name = "app-images"

    def __init__(self):
        self.storage_account_name = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME")
        self.storage_account_key = os.environ.get("AZURE_STORAGE_ACCOUNT_KEY")
        self.storage_endpoint = os.environ.get("AZURE_STORAGE_ENDPOINT") or None
        self.blob_client = self.create_blob_client()

    def list_containers(self):
        return [container.name for container in self.blob_client.list_containers()]

    def create_image_container(self):
        if self.container_name not in self.blob_client.list_containers():
            return self.blob_client.create_container(self.container_name)

    def list_images(self):
        container = self.blob_client.get_container_client(self.container_name)
        images = [f"/static/{blob.name}" for blob in container.list_blobs()]
        hello_azure_app.logger.debug(f"Found these images: {images}")
        return images

    def generate_azure_storage_connection_string(self):
        conn_str = str.format(
            (
                "DefaultEndpointsProtocol=http;"
                "AccountName={0};"
                "AccountKey={1};"
                "BlobEndpoint={2}/{0}"
            ),
            os.environ.get("AZURE_STORAGE_ACCOUNT_NAME"),
            os.environ.get("AZURE_STORAGE_ACCOUNT_KEY"),
            os.environ.get("AZURE_STORAGE_ENDPOINT"),
        )
        hello_azure_app.logger.debug(f"Connection string: {conn_str}")
        return conn_str

    def create_blob_client(self):
        return BlobServiceClient.from_connection_string(
            self.generate_azure_storage_connection_string()
        )


# TODO: These should be in classes.
Base = declarative_base()


class User(Base):
    __tablename__ = "click_data"
    id = Column(String, primary_key=True)
    click_count = Column(Integer)


def generate_id():
    return "".join(
        random.choice(string.ascii_lowercase + string.ascii_uppercase + string.digits)
        for _ in range(16)
    )


def create_table_if_nonexistent(engine, table_name):
    if not engine.has_table(table_name):
        metadata = MetaData(engine)
        Table(
            table_name,
            metadata,
            Column("id", String, primary_key=True),
            Column("click_count", Integer),
        )
        metadata.create_all()


def fetch_click_count(session, session_id):
    user = session.query(User).get(session_id)
    return 0 if user is None else user.click_count


def generate_database_connection_string():
    conn_str = str.format(
        "postgres://{0}:{1}@{2}:{3}/sessions",
        os.environ.get("SESSION_DB_USER"),
        os.environ.get("SESSION_DB_PASSWORD"),
        os.environ.get("SESSION_DB_HOST"),
        os.environ.get("SESSION_DB_PORT"),
    )
    hello_azure_app.logger.debug(f"Connecting to {conn_str}")
    return conn_str


def dependencies_ready():
    for dependency in ["blobstore", "database"]:
        attempts = 0
        while attempts < 30:
            try:
                socket.gethostbyname(dependency)
                return True
            except Exception:
                hello_azure_app.logger.warn(f"Waiting for {dependency} to become ready")
                time.sleep(1)
                attempts = attempts + 1
        return False


def environment_configured():
    environment_variables = [
        "SESSION_DB_USER",
        "SESSION_DB_PASSWORD",
        "SESSION_DB_HOST",
        "SESSION_DB_PORT",
        "AZURE_STORAGE_ENDPOINT",
        "AZURE_STORAGE_ACCOUNT_KEY",
        "AZURE_STORAGE_ACCOUNT_NAME",
    ]
    missing = [var for var in environment_variables if var not in os.environ]
    return (missing == [], missing)


def initialize_instrumentation(hello_azure_app):
    with open("VERSION") as version_file:
        metrics = PrometheusMetrics(hello_azure_app)
        metrics.info("app_info", "Hello Azure", version=version_file.read())


hello_azure_app = Flask(__name__)
initialize_instrumentation(hello_azure_app)
# So getLevelName returns an int if it's a valid log level or a
# string saying 'Level {name}' if it isn't. While I'm assuming that this
# was done to support custom log levels, it is horribly unintutive.
log_level = logging.getLevelName(os.environ.get("LOG_LEVEL") or "INFO")
if not type(log_level) is int:
    raise f"Invalid log level: {log_level}"
hello_azure_app.logger.setLevel(log_level)

session_conn_string = generate_database_connection_string()
db_engine = create_engine(session_conn_string)
create_table_if_nonexistent(db_engine, "click_data")
session_factory = sessionmaker(bind=db_engine)
session = flask_scoped_session(session_factory, hello_azure_app)

env_configured, missing_env_vars = environment_configured()
if not env_configured:
    raise Exception(f"Environment missing these variables: {missing_env_vars}")

# Normally I would use a circuit breaker pattern and have the page
# display services that are unavailable. We'll save that for
# `hello-distributed-computing` :)
if not dependencies_ready:
    raise Exception("One or more dependencies not ready.")


@hello_azure_app.route("/random_image")
def random_image():
    images = ImageStore().list_images()
    return Response(images[random.randint(0, len(images) - 1)], 200) or Response(
        "No images found", 404
    )


@hello_azure_app.route("/click", methods=["POST"])
def click():
    session_id = request.cookies.get("session_id")
    current_user = session.query(User).get(session_id)
    if current_user is None:
        session.add(User(id=session_id, click_count=1))
        session.commit()
        return "1", 201
    else:
        current_user.click_count = current_user.click_count + 1
        session.commit()
        return clicks()


@hello_azure_app.route("/clicks")
def clicks():
    session_id = request.cookies.get("session_id")
    return str(fetch_click_count(session, session_id))


@hello_azure_app.route("/")
def index():
    response = make_response(render_template("index.html.j2"))
    response.set_cookie("session_id", generate_id(), max_age=120)
    return response


hello_azure_app.run(host=os.environ.get("FLASK_HOST"), port=os.environ.get("FLASK_PORT"))
