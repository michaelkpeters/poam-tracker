document.addEventListener('DOMContentLoaded', function() {
    // POAM Form conditional fields
    const statusSelect = document.getElementById('status');
    const dateResolvedGroup = document.getElementById('date_resolved_group');
    const estimatedResolutionDate = document.getElementById('estimated_resolution_date');
    const whyNoErdGroup = document.getElementById('why_no_estimated_resolution_group');

    if (statusSelect && dateResolvedGroup) {
        function toggleDateResolved() {
            if (statusSelect.value === 'resolved') {
                dateResolvedGroup.classList.remove('hidden');
                dateResolvedGroup.querySelector('input').setAttribute('required', 'required');
            } else {
                dateResolvedGroup.classList.add('hidden');
                dateResolvedGroup.querySelector('input').removeAttribute('required');
                dateResolvedGroup.querySelector('input').value = '';
            }
        }
        statusSelect.addEventListener('change', toggleDateResolved);
        toggleDateResolved();
    }

    if (estimatedResolutionDate && whyNoErdGroup) {
        function toggleWhyNoErd() {
            if (!estimatedResolutionDate.value) {
                whyNoErdGroup.classList.remove('hidden');
            } else {
                whyNoErdGroup.classList.add('hidden');
                whyNoErdGroup.querySelector('textarea').value = '';
            }
        }
        estimatedResolutionDate.addEventListener('change', toggleWhyNoErd);
        // Also check on load
        toggleWhyNoErd();
    }

    // Auto-dismiss alerts after 5 seconds
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(function(alert) {
        setTimeout(function() {
            alert.style.transition = 'opacity 0.5s, transform 0.5s';
            alert.style.opacity = '0';
            alert.style.transform = 'translateY(-10px)';
            setTimeout(function() {
                alert.remove();
            }, 500);
        }, 5000);
    });

    // Confirm delete actions
    const deleteForms = document.querySelectorAll('.delete-form');
    deleteForms.forEach(function(form) {
        form.addEventListener('submit', function(e) {
            if (!confirm('Are you sure? This action cannot be undone.')) {
                e.preventDefault();
            }
        });
    });
});
