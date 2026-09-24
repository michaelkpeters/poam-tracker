import os
import datetime
from flask import Flask, render_template, redirect, url_for, flash, request, abort, send_from_directory
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from werkzeug.utils import secure_filename

from config import Config
from models import db, User, POAM, Evidence, Update
from forms import LoginForm, POAMForm, EvidenceForm, UpdateForm, UserForm
from auth import admin_required, edit_required, evidence_required

login_manager = LoginManager()


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    login_manager.init_app(app)
    login_manager.login_view = 'login'
    login_manager.login_message = 'Please log in to access this page.'
    login_manager.login_message_category = 'warning'

    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

    return app


app = create_app()


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']


def generate_poam_number():
    """Generate a POAM number in format POAM-YYYY-NNN."""
    current_year = datetime.datetime.now().year
    prefix = f"POAM-{current_year}-"

    # Find the highest existing number for this year
    latest = POAM.query.filter(
        POAM.poam_number.like(f"{prefix}%")
    ).order_by(POAM.poam_number.desc()).first()

    if latest:
        try:
            last_num = int(latest.poam_number.split('-')[-1])
            next_num = last_num + 1
        except ValueError:
            next_num = 1
    else:
        next_num = 1

    return f"{prefix}{next_num:03d}"


# ---------------------------------------------------------------------------
# Auth Routes
# ---------------------------------------------------------------------------

@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))

    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and user.check_password(form.password.data):
            if not user.active:
                flash('Account is disabled.', 'danger')
                return render_template('login.html', form=form)
            login_user(user)
            next_page = request.args.get('next')
            flash(f'Welcome, {user.username}!', 'success')
            return redirect(next_page) if next_page else redirect(url_for('dashboard'))
        else:
            flash('Invalid username or password.', 'danger')

    return render_template('login.html', form=form)


@app.route('/logout')
@login_required
def logout():
    logout_user()
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

@app.route('/')
@login_required
def dashboard():
    status_filter = request.args.get('status', '')
    search = request.args.get('search', '')

    query = POAM.query

    if status_filter:
        query = query.filter_by(status=status_filter)

    if search:
        query = query.filter(
            db.or_(
                POAM.poam_number.contains(search),
                POAM.finding_cve_kev_control.contains(search),
                POAM.systems_impacted.contains(search)
            )
        )

    poams = query.order_by(POAM.created_at.desc()).all()
    return render_template('dashboard.html', poams=poams, status_filter=status_filter, search=search)


# ---------------------------------------------------------------------------
# POAM CRUD
# ---------------------------------------------------------------------------

@app.route('/poam/new', methods=['GET', 'POST'])
@login_required
@edit_required
def poam_new():
    form = POAMForm()
    if form.validate_on_submit():
        poam = POAM(
            poam_number=generate_poam_number(),
            finding_cve_kev_control=form.finding_cve_kev_control.data,
            status=form.status.data,
            criticality_score=form.criticality_score.data,
            date_made_aware=form.date_made_aware.data,
            date_resolved=form.date_resolved.data,
            systems_impacted=form.systems_impacted.data,
            background=form.background.data,
            mitigating_factors=form.mitigating_factors.data,
            estimated_resolution_date=form.estimated_resolution_date.data,
            why_no_estimated_resolution=form.why_no_estimated_resolution.data,
            created_by=current_user.id
        )
        db.session.add(poam)
        db.session.commit()
        flash(f'POAM {poam.poam_number} created successfully.', 'success')
        return redirect(url_for('poam_detail', poam_id=poam.id))

    return render_template('poam_form.html', form=form, title='New POAM')


@app.route('/poam/<int:poam_id>')
@login_required
def poam_detail(poam_id):
    poam = POAM.query.get_or_404(poam_id)
    evidence_form = EvidenceForm()
    update_form = UpdateForm()
    return render_template('poam_detail.html', poam=poam, evidence_form=evidence_form, update_form=update_form)


@app.route('/poam/<int:poam_id>/edit', methods=['GET', 'POST'])
@login_required
@edit_required
def poam_edit(poam_id):
    poam = POAM.query.get_or_404(poam_id)
    form = POAMForm(obj=poam)

    if form.validate_on_submit():
        poam.finding_cve_kev_control = form.finding_cve_kev_control.data
        poam.status = form.status.data
        poam.criticality_score = form.criticality_score.data
        poam.date_made_aware = form.date_made_aware.data
        poam.date_resolved = form.date_resolved.data
        poam.systems_impacted = form.systems_impacted.data
        poam.background = form.background.data
        poam.mitigating_factors = form.mitigating_factors.data
        poam.estimated_resolution_date = form.estimated_resolution_date.data
        poam.why_no_estimated_resolution = form.why_no_estimated_resolution.data
        poam.updated_at = datetime.datetime.utcnow()

        db.session.commit()
        flash(f'POAM {poam.poam_number} updated successfully.', 'success')
        return redirect(url_for('poam_detail', poam_id=poam.id))

    # Pre-populate form
    if request.method == 'GET':
        form.finding_cve_kev_control.data = poam.finding_cve_kev_control
        form.status.data = poam.status
        form.criticality_score.data = float(poam.criticality_score) if poam.criticality_score else 0.0
        form.date_made_aware.data = poam.date_made_aware
        form.date_resolved.data = poam.date_resolved
        form.systems_impacted.data = poam.systems_impacted
        form.background.data = poam.background
        form.mitigating_factors.data = poam.mitigating_factors
        form.estimated_resolution_date.data = poam.estimated_resolution_date
        form.why_no_estimated_resolution.data = poam.why_no_estimated_resolution

    return render_template('poam_form.html', form=form, title=f'Edit {poam.poam_number}', poam=poam)


@app.route('/poam/<int:poam_id>/delete', methods=['POST'])
@login_required
@admin_required
def poam_delete(poam_id):
    poam = POAM.query.get_or_404(poam_id)
    poam_number = poam.poam_number

    # Delete associated evidence files
    for ev in poam.evidence_items.all():
        if ev.file_path and os.path.exists(ev.file_path):
            try:
                os.remove(ev.file_path)
            except OSError:
                pass

    db.session.delete(poam)
    db.session.commit()
    flash(f'POAM {poam_number} deleted.', 'info')
    return redirect(url_for('dashboard'))


# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------

@app.route('/poam/<int:poam_id>/evidence', methods=['POST'])
@login_required
@evidence_required
def poam_add_evidence(poam_id):
    poam = POAM.query.get_or_404(poam_id)
    form = EvidenceForm()

    if form.validate_on_submit():
        file_path = None
        file_name = None
        file = form.file.data

        if file and file.filename:
            if allowed_file(file.filename):
                filename = secure_filename(file.filename)
                # Prefix with timestamp to avoid collisions
                timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f"{timestamp}_{filename}"
                file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                file.save(file_path)
                file_name = file.filename
            else:
                flash('File type not allowed.', 'danger')
                return redirect(url_for('poam_detail', poam_id=poam.id))

        evidence = Evidence(
            poam_id=poam.id,
            note=form.note.data,
            file_path=file_path,
            file_name=file_name,
            uploaded_by=current_user.id
        )
        db.session.add(evidence)
        db.session.commit()
        flash('Evidence added successfully.', 'success')

    return redirect(url_for('poam_detail', poam_id=poam.id))


@app.route('/evidence/<int:evidence_id>/delete', methods=['POST'])
@login_required
@admin_required
def evidence_delete(evidence_id):
    evidence = Evidence.query.get_or_404(evidence_id)
    poam_id = evidence.poam_id

    if evidence.file_path and os.path.exists(evidence.file_path):
        try:
            os.remove(evidence.file_path)
        except OSError:
            pass

    db.session.delete(evidence)
    db.session.commit()
    flash('Evidence deleted.', 'info')
    return redirect(url_for('poam_detail', poam_id=poam_id))


@app.route('/uploads/<filename>')
@login_required
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


# ---------------------------------------------------------------------------
# Updates
# ---------------------------------------------------------------------------

@app.route('/poam/<int:poam_id>/update', methods=['POST'])
@login_required
@edit_required
def poam_add_update(poam_id):
    poam = POAM.query.get_or_404(poam_id)
    form = UpdateForm()

    if form.validate_on_submit():
        update = Update(
            poam_id=poam.id,
            update_text=form.update_text.data,
            created_by=current_user.id
        )
        db.session.add(update)
        db.session.commit()
        flash('Update added successfully.', 'success')

    return redirect(url_for('poam_detail', poam_id=poam.id))


@app.route('/update/<int:update_id>/delete', methods=['POST'])
@login_required
@admin_required
def update_delete(update_id):
    update = Update.query.get_or_404(update_id)
    poam_id = update.poam_id
    db.session.delete(update)
    db.session.commit()
    flash('Update deleted.', 'info')
    return redirect(url_for('poam_detail', poam_id=poam_id))


# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------

@app.route('/users')
@login_required
@admin_required
def users():
    all_users = User.query.all()
    return render_template('users.html', users=all_users)


@app.route('/users/new', methods=['GET', 'POST'])
@login_required
@admin_required
def user_new():
    form = UserForm()
    if form.validate_on_submit():
        if User.query.filter_by(username=form.username.data).first():
            flash('Username already exists.', 'danger')
        else:
            user = User(
                username=form.username.data,
                role=form.role.data,
                active=True
            )
            user.set_password(form.password.data)
            db.session.add(user)
            db.session.commit()
            flash(f'User {user.username} created.', 'success')
            return redirect(url_for('users'))

    return render_template('user_form.html', form=form, title='New User')


@app.route('/users/<int:user_id>/toggle', methods=['POST'])
@login_required
@admin_required
def user_toggle(user_id):
    user = User.query.get_or_404(user_id)
    if user.id == current_user.id:
        flash('You cannot disable your own account.', 'danger')
    else:
        user.active = not user.active
        db.session.commit()
        status = 'enabled' if user.active else 'disabled'
        flash(f'User {user.username} {status}.', 'success')
    return redirect(url_for('users'))


@app.route('/users/<int:user_id>/reset-password', methods=['POST'])
@login_required
@admin_required
def user_reset_password(user_id):
    user = User.query.get_or_404(user_id)
    new_password = request.form.get('new_password', '').strip()
    if not new_password or len(new_password) < 6:
        flash('Password must be at least 6 characters.', 'danger')
    else:
        user.set_password(new_password)
        db.session.commit()
        flash(f'Password for {user.username} has been reset.', 'success')
    return redirect(url_for('users'))


# ---------------------------------------------------------------------------
# Health Check
# ---------------------------------------------------------------------------

@app.route('/health')
def health():
    return {'status': 'ok', 'timestamp': datetime.datetime.utcnow().isoformat()}


# ---------------------------------------------------------------------------
# Error Handlers
# ---------------------------------------------------------------------------

@app.errorhandler(403)
def forbidden(error):
    return render_template('error.html', code=403, message='Access Denied'), 403


@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', code=404, message='Page Not Found'), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
