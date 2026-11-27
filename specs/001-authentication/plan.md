# Implementation Plan: FG1 - Authentication & Authorization

**Branch**: `001-fg1-authentication` | **Date**: 08/11/2026 | **Spec**: [spec.md](spec.md)  
**Deliverable**: PA3-2026 Section E (Full-Stack Implementation)  
**Lead Architect**: Le Tat Nam | **Mobile Lead**: Luong Hoang Nam | **Reviewer**: Ngo Tien Binh  

---

## 1. Executive Summary & Technical Approach
This plan formalizes the full-stack engineering workflow for **FG1 (Authentication & Authorization)** adhering to the Spec-Driven Development (SDD) lifecycle. 

The implementation covers three integrated tiers:
1. **Frontend Client (Mobile):** Flutter application (Dart) running on Android, implementing Material Design 3, asynchronous HTTP communication, token persistence, and WCAG-compliant form validation.
2. **Backend Application Server:** Cloudflare Workers + Hono TypeScript serverless API (`src/cloudflare-worker/src/auth_profile.ts`) providing Web Crypto PBKDF2-HMAC-SHA256 authentication, per-IP rate limiting, CORS headers, and relational persistence.
3. **Database Layer:** Cloudflare D1 (SQLite APAC — `nutriviet-app`) with normalized schema, constraints, and audit timestamps.

---

## 2. Technical Context & Stack Decisions

* **Client Framework**: Flutter (Dart 3.x), Material 3, `http` package for REST integration, `shared_preferences` for session management.
* **Backend Runtime**: Cloudflare Workers + Hono (`^4.7.4`) + TypeScript (`^5.7.3`) deployed at `https://nutriviet.nutriviet-api.workers.dev`.
* **Database**: Cloudflare D1 (`nutriviet-app` SQLite engine with Smart Placement in APAC).
* **Security & Cryptography**: Web Crypto PBKDF2-HMAC-SHA256 (100,000 iterations); 32-byte Bearer authentication tokens (`user_sessions`); Brevo/Resend HTTP email verification & 6-digit OTP reset.
* **Android Target**: Android API 26+ (Android 8.0 Oreo up to Android 15), compatible with Android Studio emulator and physical devices.
* **Network Communication**: All builds communicate directly with `https://nutriviet.nutriviet-api.workers.dev/api/v1` over HTTPS (zero localhost probes).

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
                               | HTTPS JSON (workers.dev)
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
|                       DATABASE LAYER (Cloudflare D1: nutriviet-app)             |
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
├── cloudflare-worker/
│   ├── cloudflare.config.ts     # Worker & D1 bindings
│   ├── package.json             # Hono, esbuild, Vitest
│   └── src/
│       ├── index.ts             # Hono router & rate limiter
│       ├── auth_profile.ts      # Auth, OTP reset & profile handlers
│       ├── crypto.ts            # Web Crypto PBKDF2 & OTP
│       └── email.ts             # Brevo / Resend HTTP email dispatch
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

