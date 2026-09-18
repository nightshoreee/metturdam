# Setup Guide

## 1. Install MySQL
Install MySQL 8+ (or MariaDB 10.x, which this project was actually
tested against during development). On Ubuntu/Debian:
```bash
sudo apt update
sudo apt install mysql-server
sudo service mysql start
```

## 2. Create the Database
Run the SQL files **in order** from the `database/` folder:
```bash
cd database
mysql -u root -p < 01_create_database.sql
mysql -u root -p < 02_create_tables.sql
mysql -u root -p < 03_constraints_indexes.sql
mysql -u root -p < 04_seed_data.sql
mysql -u root -p < 05_views.sql
mysql -u root -p < 06_stored_procedures.sql
mysql -u root -p < 07_triggers.sql
```
`08_sample_transactions.sql` and `09_queries.sql` are optional
demonstration files -- run them any time after the above to see the
transaction/rollback behavior and the report queries in the MySQL CLI.
`10_drop_database.sql` completely removes the database if you want to
start over.

## 3. Backend (Flask) Setup
```bash
cd backend
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# edit .env and set DB_PASSWORD (and DB_HOST/DB_USER if different)
```

## 4. Configure `.env`
Open `backend/.env` and fill in your real MySQL credentials:
```
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_real_password
DB_NAME=mettur_dam_irrigation
FLASK_SECRET_KEY=some-random-string
FLASK_DEBUG=True
```
Never commit the real `.env` file -- it is already excluded by
`.gitignore`.

## 5. Start Flask
```bash
cd backend
python3 app.py
```
The API is now live at `http://localhost:5000/api`. Check it with:
```bash
curl http://localhost:5000/api/health
```

## 6. Frontend Setup
The frontend is static HTML/CSS/JS -- no build step. Two ways to run it:

**Option A -- open directly:**
Open `frontend/index.html` in a browser. (Some browsers restrict
`fetch()` from `file://` pages; if you hit CORS/network errors, use
Option B instead.)

**Option B -- serve locally:**
```bash
cd frontend
python3 -m http.server 8000
```
Then visit `http://localhost:8000`.

`frontend/js/api.js` has `API_BASE = "http://localhost:5000/api"` at
the top -- change this if your backend runs somewhere else.

## 7. Test the Application
- Visit the Dashboard -- you should see live stats and 4 charts.
- Go to Water Scheduling, pick a farmer/parcel/canal, and click "Check
  Availability" before submitting.
- Try booking the SAME canal and overlapping time twice from two
  different farmers -- the second one should be rejected with
  "SLOT CONFLICT".
- Go to Water Usage and record a usage reading against an approved
  schedule -- then check the Billing page; a bill should appear
  automatically.

## 8. GitHub Deployment
This project is structured so each piece deploys separately:

- **`frontend/`** -> GitHub Pages (or any static host). GitHub Pages
  can only serve static files; it cannot run Flask or MySQL, so the
  frontend must point (`API_BASE` in `js/api.js`) at wherever the
  backend is actually hosted.
- **`backend/`** -> any Python-compatible host (Render, Railway,
  PythonAnywhere, a VPS, etc.). Set the same environment variables as
  `.env.example` in that host's configuration.
- **`database/`** -> any MySQL-compatible database host (the SQL files
  in `database/` are portable to any managed MySQL/MariaDB service).

The SQL files themselves ARE committed to GitHub (per the project
brief) -- only the real `.env` with live credentials is excluded.

## 9. Push to GitHub
```bash
git init
git add .
git commit -m "Initial commit: Mettur Dam Smart Water & Irrigation Management System"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```
