import os, random, string
from flask import Flask, render_template, make_response, request
from flask_sqlalchemy_session import flask_scoped_session
from sqlalchemy import create_engine, Column, Integer, MetaData, Table, String
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

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

hello_azure_app = Flask(__name__)
session_conn_string = str.format("postgres://{0}:{1}@{2}:{3}/sessions",
                                os.environ.get('SESSION_DB_USER'),
                                os.environ.get('SESSION_DB_PASSWORD'),
                                os.environ.get('SESSION_DB_HOST'),
                                os.environ.get('SESSION_DB_PORT'))
db_engine = create_engine(session_conn_string)
create_table_if_nonexistent(db_engine, 'click_data')
session_factory = sessionmaker(bind=db_engine)
session = flask_scoped_session(session_factory, hello_azure_app)

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
