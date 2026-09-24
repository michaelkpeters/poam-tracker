import os
import sys

from config import Config
from models import db, User
from app import create_app


def init_database():
    app = create_app()
    with app.app_context():
        db.create_all()

        # Create default admin if not exists
        admin = User.query.filter_by(username=Config.ADMIN_USERNAME).first()
        if not admin:
            admin = User(
                username=Config.ADMIN_USERNAME,
                role='administrator',
                active=True
            )
            admin.set_password(Config.ADMIN_PASSWORD)
            db.session.add(admin)
            db.session.commit()
            print(f"Created admin user: {Config.ADMIN_USERNAME}")
        else:
            print(f"Admin user already exists: {Config.ADMIN_USERNAME}")

        print("Database initialized successfully.")


if __name__ == '__main__':
    init_database()
