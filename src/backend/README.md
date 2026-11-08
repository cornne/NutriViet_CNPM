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

