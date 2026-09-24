<p align="center">
  <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#2563eb" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
    <polyline points="14 2 14 8 20 8"></polyline>
    <line x1="16" y1="13" x2="8" y2="13"></line>
    <line x1="16" y1="17" x2="8" y2="17"></line>
    <polyline points="10 9 9 9 8 9"></polyline>
  </svg>
</p>

<h1 align="center">POAM Tracker</h1>
<p align="center">
  A lightweight, professional web application for tracking <b>Plans of Action and Milestones</b>.
  <br>
  Designed to run in minimal-resource environments like <b>Proxmox LXC containers</b>.
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#quick-install">Quick Install</a> ·
  <a href="#manual-setup">Manual Setup</a> ·
  <a href="#screenshots">Screenshots</a>
</p>

---

## Features

- **Automated POAM Numbering** — Auto-generates IDs in format `POAM-YYYY-NNN`
- **Role-Based Access Control** — Three user roles with granular permissions:
  | Role | Create/Edit POAMs | Upload Evidence | Manage Users |
  |------|-------------------|-----------------|--------------|
  | **Administrator** | ✅ | ✅ | ✅ |
  | **Evidence Gatherer** | ❌ | ✅ | ❌ |
  | **Read-Only** | ❌ | ❌ | ❌ |
- **Full POAM Fields** — Finding/CVE/KEV/Control, status, criticality score (0.0–10.0), dates, systems impacted, background, mitigating factors, estimated resolution, and conditional "why no ERD" field
- **Update Timeline** — Running log of status updates per POAM
- **Evidence Uploads** — Attach notes and files (screenshots, scan results, PDFs, etc.)
- **Search & Filter** — Filter by status and search across POAM fields
- **Responsive UI** — Clean, professional design with color-coded status badges and criticality score bars
- **Minimal Footprint** — Python + SQLite, runs comfortably in **512MB RAM**

---

## Quick Install

### Proxmox VE (Recommended)

Copy and paste this into your **Proxmox host shell**:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/michaelkpeters/poam-tracker/master/install/poam-tracker.sh)"
```

The script will:
1. Create a Debian 12 LXC container (1 vCPU, 512MB RAM, 8GB disk)
2. Install Docker inside the container
3. Clone this repository and start the application
4. Print your admin credentials

### Docker

```bash
git clone https://github.com/michaelkpeters/poam-tracker.git
cd poam-tracker
cp .env.example .env
# Edit .env to set SECRET_KEY and admin password
docker compose up -d
```

### Manual (No Docker)

```bash
git clone https://github.com/michaelkpeters/poam-tracker.git
cd poam-tracker
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python init_db.py
python app.py
```

---

## Updating

### Inside the LXC container:

```bash
bash /opt/poam-tracker/install/update.sh
```

### Docker:

```bash
cd poam-tracker
git pull
docker compose down
docker compose up -d --build
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | *(dev fallback)* | Flask session secret — **change in production** |
| `ADMIN_USERNAME` | `admin` | Default admin username |
| `ADMIN_PASSWORD` | `admin123` | Default admin password — **change in production** |
| `DATABASE_URL` | `sqlite:///data/poam.db` | SQLite database path |

---

## Data Persistence

- **SQLite database** — `data/poam.db` (all POAMs, users, updates)
- **Uploaded evidence** — `data/uploads/` (files attached to POAMs)

Mount a host directory to `/app/data` in Docker to persist across container restarts.

---

## Screenshots

*Coming soon — Dashboard, POAM detail, and user management views.*

---

## License

MIT — Use freely for internal security and compliance tracking.
