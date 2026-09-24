import datetime
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from flask_login import UserMixin

db = SQLAlchemy()


class User(UserMixin, db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(256), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='read_only')
    active = db.Column(db.Boolean, default=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)

    poams_created = db.relationship('POAM', backref='creator', lazy='dynamic')
    evidence_uploaded = db.relationship('Evidence', backref='uploader', lazy='dynamic')
    updates_added = db.relationship('Update', backref='author', lazy='dynamic')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def is_admin(self):
        return self.role == 'administrator'

    def is_read_only(self):
        return self.role == 'read_only'

    def is_evidence_gatherer(self):
        return self.role == 'evidence_gatherer'

    def can_edit_poams(self):
        return self.role == 'administrator'

    def can_upload_evidence(self):
        return self.role in ('administrator', 'evidence_gatherer')

    def can_manage_users(self):
        return self.role == 'administrator'

    def __repr__(self):
        return f'<User {self.username} ({self.role})>'


class POAM(db.Model):
    __tablename__ = 'poams'

    id = db.Column(db.Integer, primary_key=True)
    poam_number = db.Column(db.String(20), unique=True, nullable=False, index=True)

    finding_cve_kev_control = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), nullable=False, default='new')
    criticality_score = db.Column(db.Numeric(2, 1), nullable=False, default=0.0)

    date_made_aware = db.Column(db.Date, nullable=False)
    date_resolved = db.Column(db.Date, nullable=True)

    systems_impacted = db.Column(db.Text, nullable=False)
    background = db.Column(db.Text, nullable=False)
    mitigating_factors = db.Column(db.Text, nullable=True)

    estimated_resolution_date = db.Column(db.Date, nullable=True)
    why_no_estimated_resolution = db.Column(db.Text, nullable=True)

    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    evidence_items = db.relationship('Evidence', backref='poam', lazy='dynamic', cascade='all, delete-orphan')
    updates = db.relationship('Update', backref='poam', lazy='dynamic', cascade='all, delete-orphan', order_by='Update.created_at.desc()')

    def status_badge_class(self):
        return {
            'new': 'badge-new',
            'inprocess': 'badge-inprocess',
            'resolved': 'badge-resolved'
        }.get(self.status, 'badge-new')

    def status_label(self):
        return {
            'new': 'New',
            'inprocess': 'In Process',
            'resolved': 'Resolved'
        }.get(self.status, self.status)

    def is_overdue(self):
        if self.estimated_resolution_date and self.status != 'resolved':
            return self.estimated_resolution_date < datetime.date.today()
        return False

    def __repr__(self):
        return f'<POAM {self.poam_number}>'


class Evidence(db.Model):
    __tablename__ = 'evidence'

    id = db.Column(db.Integer, primary_key=True)
    poam_id = db.Column(db.Integer, db.ForeignKey('poams.id'), nullable=False)
    note = db.Column(db.Text, nullable=True)
    file_path = db.Column(db.String(512), nullable=True)
    file_name = db.Column(db.String(255), nullable=True)
    uploaded_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    uploaded_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)


class Update(db.Model):
    __tablename__ = 'updates'

    id = db.Column(db.Integer, primary_key=True)
    poam_id = db.Column(db.Integer, db.ForeignKey('poams.id'), nullable=False)
    update_text = db.Column(db.Text, nullable=False)
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
