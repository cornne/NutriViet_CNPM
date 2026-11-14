# NutriViet Backend: Authentication Microservice

**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA3-2026 (Section E Deliverable)  
**Functional Group:** FG1 - Authentication & Authorization  

---

## 🚀 How to Run the Backend Server

This backend is designed with Python standard libraries (`sqlite3`, `http.server`, `hashlib`), so it runs immediately **without requiring external package installation**:

```bash
# 1. Navigate to the backend directory
cd src/backend

# 2. Start the server
python server.py
```

---

## 📡 Endpoints Provided

| Method | Endpoint | Description |
|:---:|:---|:---|
| **GET** | `/health` | Check service health & available routes |
| **POST** | `/api/v1/auth/register` | Register new user account (hashes password, persists to SQLite) |
| **POST** | `/api/v1/auth/login` | Authenticate user credentials & issue session token |
| **GET** | `/api/v1/users` | View persistent registered users in SQLite (for demo inspection) |

---

## 💾 Database Persistence
The SQLite database is saved persistently in `nutriviet.db`. A default demo account is seeded automatically:
* **Email:** `demo@nutriviet.vn`
* **Password:** `NutriPass123!`

---

## ☁️ Deploying / Updating on PythonAnywhere (Production WSGI)

The unified production WSGI entrypoint is `wsgi_app.py` (which serves Auth, Profile, Scan History, and the FoodOn + Kala Hybrid Engine backed by `data/nutriviet_hybrid.db` using pure Python standard library at runtime — no `pip install` needed).

1. **Pull latest code on PythonAnywhere Bash console:**
   ```bash
   cd ~/NutriViet_CNPM
   git pull origin Better-F-and-Update-B
   ```
   *(Ensure `src/backend/data/nutriviet_hybrid.db` is present.)*

2. **Configure the Web tab WSGI file** using [`pythonanywhere_wsgi_template.py`](./pythonanywhere_wsgi_template.py):
   - Point `sys.path` to `/home/ngobinh2006/NutriViet_CNPM/src/backend`
   - Import `from wsgi_app import application`
   - Optional environment overrides (`NUTRIVIET_GMAIL_USER`, `NUTRIVIET_GMAIL_PASS`, `NUTRIVIET_DB_PATH`, `NUTRIVIET_PUBLIC_BASE_URL`) can also be placed in `src/backend/.env`.

3. **Reload & verify:**
   - Click **Reload** in the PythonAnywhere Web tab.
   - Check `/health` returns `{"status": "healthy", "service": "NutriViet", "version": "2.0.0", "foodon_hybrid": true}`.


