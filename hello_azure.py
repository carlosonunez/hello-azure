import os
from flask import Flask, render_template
hello_azure_app = Flask(__name__)

@hello_azure_app.route('/')
@hello_azure_app.route('/index')
def index():
    return render_template('index.html.j2')

hello_azure_app.run(host=os.environ.get('FLASK_HOST'),
                    port=os.environ.get('FLASK_PORT'))
