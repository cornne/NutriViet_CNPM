# Implementation Plan: FG1 - Authentication & Authorization

**Branch**: `001-fg1-authentication` | **Date**: 08/11/2026 | **Spec**: [spec.md](spec.md)  
**Deliverable**: PA3-2026 Section E (Full-Stack Implementation)  
**Lead Architect**: Le Tat Nam | **Mobile Lead**: Luong Hoang Nam | **Reviewer**: Ngo Tien Binh  

---

## 1. Executive Summary & Technical Approach
This plan formalizes the full-stack engineering workflow for **FG1 (Authentication & Authorization)** adhering to the Spec-Driven Development (SDD) lifecycle. 

The implementation covers three integrated tiers:
1. **Frontend Client (Mobile):** Flutter application (Dart) running on Android, implementing Material Design 3, asynchronous HTTP communication, token persistence, and WCAG-compliant form validation.
2. **Backend Application Server:** Lightweight Python RESTful microservice providing cryptographically salted authentication, error handling, CORS headers, and relational persistence.
3. **Database Layer:** Relational SQLite persistence engine (`nutriviet.db`) with normalized schema, constraints, and audit timestamps.

---

## 2. Technical Context & Stack Decisions

* **Client Framework**: Flutter (Dart 3.x), Material 3, `http` package for REST integration, `shared_preferences` for session management.
* **Backend Runtime**: Python 3.10+ (Lightweight high-performance HTTP server / FastAPI compatible API).
* **Database**: SQLite3 embedded relational engine (Zero external server dependencies, ACID compliant, native SQL schema).
* **Security & Cryptography**: Salted SHA-256 / PBKDF2 cryptographic hashing; Bearer authentication tokens.
* **Android Target**: Android API 26+ (Android 8.0 Oreo up to Android 15), compatible with Android Studio emulator and physical devices.
* **Network Communication**: Android Emulator uses `http://10.0.2.2:8000` bridge to access host machine backend.

---

## 3. Architecture & Data Flow

```
+-------------------------------------------------------------------------------+
|                             FLUTTER MOBILE CLIENT                            |
|                                                                               |
|   +-----------------------+     +-----------------------+     +-----------+   |
|   |  LoginScreen (UI)     |     |  RegisterScreen (UI)  |     | HomeScreen|   |
|   +-----------+-----------+     +-----------+-----------+     +-----+-----+   |
|               |                             |                       ^         |
|               +------------+   +------------+                       |         |
|                            v   v                                    |         |
|                     +-----------------+                             |         |
|                     |   AuthService   | ----------------------------+         |
|                     +--------+--------+                                       |
+------------------------------|------------------------------------------------+
                               | HTTP JSON (via 10.0.2.2:8000)
                               v
+-------------------------------------------------------------------------------+
|                             BACKEND API SERVER                                |
|                                                                               |
|   +--------------------------+          +---------------------------------+   |
|   | POST /api/v1/auth/login  |          | POST /api/v1/auth/register      |   |
|   +------------+-------------+          +----------------+----------------+   |
|                |                                         |                    |
|                v                                         v                    |
|   +-----------------------------------------------------------------------+   |
|   |       Authentication Controller & Password Hasher (Crypto Engine)     |   |
|   +-----------------------------------+-----------------------------------+   |
+---------------------------------------|---------------------------------------+
                                        | SQL Queries (SELECT / INSERT)
                                        v
+-------------------------------------------------------------------------------+
|                       DATABASE LAYER (SQLite: nutriviet.db)                   |
|                                                                               |
|   TABLE users (                                                               |
|       id INTEGER PRIMARY KEY AUTOINCREMENT,                                   |
|       full_name TEXT NOT NULL,                                                |
|       email TEXT UNIQUE NOT NULL,                                             |
|       password_hash TEXT NOT NULL,                                            |
|       created_at TEXT NOT NULL                                                |
|   );                                                                          |
+-------------------------------------------------------------------------------+
```

---

## 4. RESTful API Contracts

### 4.1. Endpoint: `POST /api/v1/auth/register`
* **Request Headers**: `Content-Type: application/json`
* **Request Body**:
  ```json
  {
    "full_name": "Nguyen Van A",
    "email": "nguyenvana@gmail.com",
    "password": "SecurePass123"
  }
  ```
* **Success Response (`201 Created`)**:
  ```json
  {
    "status": "success",
    "message": "User registered successfully",
    "token": "nutriviet_session_eyJhbGciOi...",
    "user": {
      "id": 1,
      "full_name": "Nguyen Van A",
      "email": "nguyenvana@gmail.com"
    }
  }
  ```
* **Error Response (`409 Conflict`)**:
  ```json
  {
    "status": "error",
    "code": "EMAIL_ALREADY_EXISTS",
    "message": "Email is already registered"
  }
  ```

---

### 4.2. Endpoint: `POST /api/v1/auth/login`
* **Request Body**:
  ```json
  {
    "email": "nguyenvana@gmail.com",
    "password": "SecurePass123"
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "status": "success",
    "message": "Authentication successful",
    "token": "nutriviet_session_eyJhbGciOi...",
    "user": {
      "id": 1,
      "full_name": "Nguyen Van A",
      "email": "nguyenvana@gmail.com"
    }
  }
  ```
* **Error Response (`401 Unauthorized`)**:
  ```json
  {
    "status": "error",
    "code": "INVALID_CREDENTIALS",
    "message": "Invalid email or password"
  }
  ```

---

## 5. Physical File Structure

```text
src/
├── speckit/
│   └── specs/001-authentication/
│       ├── spec.md
│       ├── plan.md
│       └── tasks.md
├── backend/
│   ├── server.py                # Standalone REST API with SQLite
│   ├── database.py              # SQLite schema & user DAO
│   ├── requirements.txt         # Optional dependencies
│   └── README.md                # Server execution guide
└── mobile/
    ├── pubspec.yaml             # Flutter metadata & dependencies
    ├── README.md                # Android Studio execution guide
    ├── android/                 # Native Android gradle & manifests
    └── lib/
        ├── main.dart            # Flutter entry point & theme
        ├── screens/
        │   ├── login_screen.dart
        │   ├── register_screen.dart
        │   └── home_screen.dart
        └── services/
            └── auth_service.dart
```

