import os
from app import app

if __name__ == '__main__':
    app.run(host=os.environ.get('FLASK_HOST'),
            port=os.environ.get('FLASK_PORT'))
