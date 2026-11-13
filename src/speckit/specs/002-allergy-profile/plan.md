# Implementation Plan: FG2 - Personal Allergy Profile Management

**Branch**: `002-fg2-allergy-profile` | **Date**: 08/11/2026 | **Spec**: [spec.md](spec.md)  
**Deliverable**: PA3-2026 Section E Extension (Multi-Tier Full-Stack)  
**Lead Architect**: Le Tat Nam | **Mobile Lead**: Luong Hoang Nam | **Reviewer**: Ngo Tien Binh  

---

## 1. Technical Architecture & Approach

This plan extends the existing NutriViet full-stack infrastructure to support **FG2: Personal Allergy Profile Management**.

```
+-------------------------------------------------------------------------------+
|                            FLUTTER MOBILE CLIENT                             |
|                                                                               |
|   +-----------------------------------------------------------------------+   |
|   |                       AllergyProfileScreen (UI)                       |   |
|   |  - Master Catalog Filter Chips (Peanuts, Milk, Seafood, Gluten...)    |   |
|   |  - Severity Selector Segment (High / Moderate / Mild)                 |   |
|   |  - Dynamic Save & Reset Actions                                       |   |
|   +-----------------------------------+-----------------------------------+   |
|                                       |                                       |
|                                       v                                       |
|   +-----------------------------------------------------------------------+   |
|   |                  ProfileService (HTTP REST Client)                    |   |
|   +-----------------------------------+-----------------------------------+   |
+---------------------------------------|---------------------------------------+
                                        | HTTP JSON (Bearer Token / User ID)
                                        v
+-------------------------------------------------------------------------------+
|                             BACKEND API SERVER                                |
|                                                                               |
|   +-----------------------------------+-----------------------------------+   |
|   | GET  /api/v1/profile/allergens    | Retrieve user configured profile  |   |
|   | POST /api/v1/profile/allergens    | Upsert active allergen list       |   |
|   +-----------------------------------+-----------------------------------+   |
+---------------------------------------|---------------------------------------+
                                        | SQL Transactions (Atomic Delete/Insert)
                                        v
+-------------------------------------------------------------------------------+
|                       DATABASE LAYER (SQLite: nutriviet.db)                   |
|                                                                               |
|   TABLE user_allergens (                                                      |
|       id INTEGER PRIMARY KEY AUTOINCREMENT,                                   |
|       user_id INTEGER NOT NULL REFERENCES users(id),                          |
|       allergen_code TEXT NOT NULL,                                            |
|       allergen_name TEXT NOT NULL,                                            |
|       severity TEXT NOT NULL,                                                 |
|       updated_at TEXT NOT NULL                                                |
|   );                                                                          |
+-------------------------------------------------------------------------------+
```

---

## 2. RESTful API Contracts

### 2.1. Endpoint: `GET /api/v1/profile/allergens`
* **Query Parameters**: `?user_id=1` (or extracted via Bearer token)
* **Success Response (`200 OK`)**:
  ```json
  {
    "status": "success",
    "user_id": 1,
    "allergens": [
      {
        "code": "peanuts",
        "name": "Đậu phộng / Lạc",
        "severity": "high",
        "icon": "shield"
      },
      {
        "code": "seafood",
        "name": "Hải sản (Tôm, Cua, Mực)",
        "severity": "high",
        "icon": "set_meal"
      }
    ],
    "total": 2
  }
  ```

---

### 2.2. Endpoint: `POST /api/v1/profile/allergens`
* **Request Body**:
  ```json
  {
    "user_id": 1,
    "allergens": [
      {
        "code": "peanuts",
        "name": "Đậu phộng / Lạc",
        "severity": "high"
      },
      {
        "code": "milk",
        "name": "Sữa bò & Các sản phẩm từ sữa",
        "severity": "moderate"
      }
    ]
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "status": "success",
    "message": "Hồ sơ dị ứng đã được lưu thành công vào cơ sở dữ liệu.",
    "count": 2
  }
  ```

---

## 3. Physical Code Layout

```text
src/
├── speckit/
│   └── specs/002-allergy-profile/
│       ├── spec.md
│       ├── plan.md
│       ├── data-model.md
│       ├── research.md
│       ├── contracts/openapi.json
│       ├── tasks.md
│       └── checklists/requirements.md
├── backend/
│   ├── database.py       # Updated with user_allergens DDL & CRUD operations
│   └── server.py         # Added GET & POST /api/v1/profile/allergens handlers
└── mobile/
    └── lib/
        ├── screens/
        │   └── allergy_profile_screen.dart # Interactive chips & severity selector
        └── services/
            └── profile_service.dart        # Profile API client
```
