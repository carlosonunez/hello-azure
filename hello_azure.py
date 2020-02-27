import os
from flask import Flask, render_template
from flask_sqlalchemy_session import flask_scoped_session
from sqlalchemy import create_engine, Column, Integer, MetaData, Table
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

# TODO: These should be in classes.
Base = declarative_base()
class User(Base):
    __tablename__ = 'click_data'
    click_count = Column(Integer, primary_key=True)


def create_table_if_nonexistent(engine, table_name):
    if not engine.has_table(table_name):
        metadata = MetaData(engine)
        Table(table_name, metadata, Column('click_count', Integer, primary_key=True))
        metadata.create_all()

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
    num_clicks = clicks()
    if num_clicks == 0:
        new_user = User(0)
        session.add(new_user)
        session.commit()
    else:
        session.query(User).update({"click_count": num_clicks + 1})
        session.commit()
    return '', 204

@hello_azure_app.route('/clicks')
def clicks():
    user = session.query(User)
    return '0' if user.count() == 0 else str(user.first().click_count)

@hello_azure_app.route('/')
def index():
    return render_template('index.html.j2')

hello_azure_app.run(host=os.environ.get('FLASK_HOST'),
                    port=os.environ.get('FLASK_PORT'))
