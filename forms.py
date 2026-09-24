from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, SelectField, DecimalField, DateField, FileField, PasswordField, SubmitField, HiddenField
from wtforms.validators import DataRequired, Optional, NumberRange, ValidationError
from wtforms.widgets import TextArea
from flask_login import current_user


class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
    submit = SubmitField('Sign In')


class UserForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
    role = SelectField('Role', choices=[
        ('read_only', 'Read-Only'),
        ('evidence_gatherer', 'Evidence Gatherer'),
        ('administrator', 'Administrator')
    ], validators=[DataRequired()])
    submit = SubmitField('Save User')


class POAMForm(FlaskForm):
    finding_cve_kev_control = TextAreaField('Finding / CVE / KEV / Control', validators=[DataRequired()])
    status = SelectField('Status', choices=[
        ('new', 'New'),
        ('inprocess', 'In Process'),
        ('resolved', 'Resolved')
    ], validators=[DataRequired()])
    criticality_score = DecimalField('Criticality Score (0.0 - 10.0)', places=1, validators=[
        DataRequired(),
        NumberRange(min=0.0, max=10.0, message='Score must be between 0.0 and 10.0')
    ])
    date_made_aware = DateField('Date Made Aware', validators=[DataRequired()])
    date_resolved = DateField('Date Resolved', validators=[Optional()])
    systems_impacted = TextAreaField('System(s) Impacted', validators=[DataRequired()])
    background = TextAreaField('Background of the Finding', validators=[DataRequired()])
    mitigating_factors = TextAreaField('Mitigating Factors', validators=[Optional()])
    estimated_resolution_date = DateField('Estimated Resolution Date', validators=[Optional()])
    why_no_estimated_resolution = TextAreaField('Why No Estimated Resolution Date?', validators=[Optional()])
    submit = SubmitField('Save POAM')

    def validate_date_resolved(self, field):
        if self.status.data == 'resolved' and not field.data:
            raise ValidationError('Date Resolved is required when status is Resolved.')


class EvidenceForm(FlaskForm):
    note = TextAreaField('Notes')
    file = FileField('Attachment')
    submit = SubmitField('Add Evidence')


class UpdateForm(FlaskForm):
    update_text = TextAreaField('Update', validators=[DataRequired()])
    submit = SubmitField('Add Update')
