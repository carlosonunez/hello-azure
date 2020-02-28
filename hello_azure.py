import os, random, string
from azure.storage.blob import BlobServiceClient
from flask import Flask, render_template, make_response, request
from flask_sqlalchemy_session import flask_scoped_session
from sqlalchemy import create_engine, Column, Integer, MetaData, Table, String
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

class ImageStore():
    container_name = 'app_images'
    def __init__(self):
        self.storage_account_name = self.env_get_or_fail('AZURE_STORAGE_ACCOUNT_NAME')
        self.storage_account_key = self.env_get_or_fail('AZURE_STORAGE_ACCOUNT_KEY')
        self.storage_endpoint = self.env_get_or_fail('AZURE_ENDPOINT') or None
        self.blob_client = self.create_blob_client()

    def create_image_container(self):
        return self.blob_client.create_container(self.container_name)

    def list_images(self):
        container = self.blob_client.get_container(self.container_name)
        [ blob.name for blob in container.list_blobs() ]
   
        env_vars = ['AZURE_STORAGE_ACCOUNT_NAME',
                    'AZURE_STORAGE_ACCOUNT_KEY',
                    'AZURE_ENDPOINT']
        defined = [ var for var in env_vars if var in os.environ ]
        undefined = list(set(env_vars) - set(defined))
        return (not undefined, undefined)

    def env_get_or_fail(self, key):
        try:
            os.environ.get(key)
        except Exception:
            raise Exception(f"Please define {key} in your environment.")

    def generate_azure_storage_connection_string(self):
        return str.format("""DefaultEndpointsProtocol=http;
                            AccountName={0};
                            AccountKey={1};
                            BlobEndpoint={2}""",
                            os.environ.get('AZURE_ACCOUNT_NAME'),
                            os.environ.get('AZURE_ACCOUNT_KEY'),
                            os.environ.get('AZURE_ENDPOINT'))

    def create_blob_client(self):
        BlobServiceClient.from_connection_string(self.generate_azure_storage_connection_string())


# TODO: These should be in classes.
Base = declarative_base()
class User(Base):
    __tablename__ = 'click_data'
    id = Column(String, primary_key=True)
    click_count = Column(Integer)

def generate_id():
    return ''.join(random.choice(string.ascii_lowercase + \
            string.ascii_uppercase + \
            string.digits) for _ in range(16))

def create_table_if_nonexistent(engine, table_name):
    if not engine.has_table(table_name):
        metadata = MetaData(engine)
        Table(table_name, metadata,
                Column('id', String, primary_key=True),
                Column('click_count', Integer))
        metadata.create_all()

def fetch_click_count(session, session_id):
    user = session.query(User).get(session_id)
    return 0 if user is None else user.click_count

def generate_database_connection_string():
    for var in ['USER', 'PASSWORD', 'HOST', 'PORT']:
        env_var_to_find = f"SESSION_DB_{var}"
        if not os.environ.get(env_var_to_find):
            raise f"Please define {env_var_to_find}"

    return str.format("postgres://{0}:{1}@{2}:{3}/sessions",
            os.environ.get('SESSION_DB_USER'),
            os.environ.get('SESSION_DB_PASSWORD'),
            os.environ.get('SESSION_DB_HOST'),
            os.environ.get('SESSION_DB_PORT'))


hello_azure_app = Flask(__name__)
session_conn_string = generate_database_connection_string();
db_engine = create_engine(session_conn_string)
create_table_if_nonexistent(db_engine, 'click_data')
session_factory = sessionmaker(bind=db_engine)
session = flask_scoped_session(session_factory, hello_azure_app)

@hello_azure_app.route('/image')
def image():
    return ImageStore().list_images() or 'No images found', 404

@hello_azure_app.route('/click', methods=['POST'])
def click():
    session_id = request.cookies.get('session_id')
    current_user = session.query(User).get(session_id)
    if current_user is None:
        session.add(User(id=session_id, click_count=1))
        session.commit()
        return '1', 201
    else:
        current_user.click_count = current_user.click_count + 1
        session.commit()
        return clicks()

@hello_azure_app.route('/clicks')
def clicks():
    session_id = request.cookies.get('session_id')
    return str(fetch_click_count(session, session_id))

@hello_azure_app.route('/')
def index():
    response = make_response(render_template('index.html.j2'))
    response.set_cookie('session_id', generate_id(), max_age=120)
    return response

hello_azure_app.run(host=os.environ.get('FLASK_HOST'),
                    port=os.environ.get('FLASK_PORT'))
