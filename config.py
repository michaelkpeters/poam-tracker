import os
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.abspath(os.path.dirname(__file__))


DATA_DIR = os.environ.get('DATA_DIR') or os.path.join(BASE_DIR, 'data')
os.makedirs(DATA_DIR, exist_ok=True)


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'poam-tracker-dev-secret-key-change-in-production'
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or \
        'sqlite:///' + os.path.join(DATA_DIR, 'poam.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    UPLOAD_FOLDER = os.path.join(DATA_DIR, 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB max upload
    ADMIN_USERNAME = os.environ.get('ADMIN_USERNAME') or 'admin'
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD') or 'admin123'
    ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg', 'gif', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'zip'}
