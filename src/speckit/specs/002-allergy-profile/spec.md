# Feature Specification: FG2 - Personal Allergy Profile Management

**Feature Branch**: `002-fg2-allergy-profile`  
**Date**: 08/11/2026  
**Status**: Approved  
**Target Delivery**: PA3-2026 (Extended Section E Deliverable)  
**Lead Engineer (Assignee)**: Luong Hoang Nam (Flutter) & Le Tat Nam (Backend)  
**Reviewer**: Ngo Tien Binh (PM & AI Lead)  

---

## 1. Feature Overview & Business Value

The **Personal Allergy Profile Management** functional group (`FG2`) is the central health safety intelligence module of NutriViet. It empowers consumers managing fatal food allergies or chronic dietary restrictions to customize, inspect, and update their personal allergen sensitivities.

This specification maps directly to the system requirements defined in the [Vision Document](../../../docs/requirements/vision.md) and [Use-Case Model](../../../docs/requirements/use-cases.md):
- **`UC04: Configure Allergy & Health Profile`** (Critical Priority)
- **`UC05: Set Allergen Sensitivity Thresholds`** (High Priority)

---

## 2. Supported Master Allergen Catalog

In accordance with Vietnamese food safety regulations and international FAO/WHO standards, the system recognizes the **Top 8 Standard Allergen Classes**:

| Allergen Code | Display Name (Tiếng Việt) | Common Food Triggers | Default Risk Profile |
|:---|:---|:---|:---:|
| `peanuts` | Đậu phộng / Lạc | Bánh kẹo bơ đậu phộng, dầu phụng, sốt satay | Severe (High) |
| `seafood` | Hải sản (Tôm, Cua, Mực) | Nước mắm, bột ngọt chiết xuất, chả cá | Severe (High) |
| `milk` | Sữa bò & Các sản phẩm từ sữa | Casein, whey, phô mai, bơ thực vật | High / Moderate |
| `gluten` | Gluten / Lúa mì | Bánh mì, mì tôm, bột mì, bia, mạch nha | High / Moderate |
| `eggs` | Trứng | Mayonnaise, bánh nướng, chất kết dính albumin | Moderate |
| `soy` | Đậu nành | Nước tương, đậu phụ, lecithin đậu nành | Moderate |
| `fish` | Cá các loại | Dầu cá, bột cá gia vị | Severe (High) |
| `tree_nuts` | Hạt cây (Hạt điều, Hạnh nhân, Óc chó) | Sữa hạt, ngũ cốc granola | Severe (High) |

---

## 3. User Stories & Gherkin Scenarios

### User Story 1 - Configure Personal Allergens (Priority: P1)
**As an** authenticated consumer with dietary restrictions,  
**I want to** select my specific allergen triggers from the master catalog,  
**So that** NutriViet can automatically cross-reference packaging ingredients during scanner workflows (`FG3` & `FG4`).

* **Why this priority**: Core safety pillar of NutriViet. Without an allergen profile, no personalized hazard analysis is possible.
* **Independent Test**: Validated by toggling allergen chips on the mobile client, saving the profile, and querying `GET /api/v1/profile/allergens` to confirm persistence.

**Acceptance Scenarios**:
1. **Scenario 1.1 (Successful Profile Save - Main Flow):**
   - **Given** an authenticated consumer is on the Allergy Profile Configuration screen,
   - **When** the consumer selects *"Đậu phộng"* and *"Hải sản"*,
   - **And** clicks the *"Lưu Hồ Sơ Dị Ứng"* button,
   - **Then** the client sends a `POST /api/v1/profile/allergens` payload containing the allergen codes,
   - **And** the server updates the `user_allergens` SQLite table,
   - **And** returns HTTP `200 OK` with confirmation message,
   - **And** the mobile app displays an emerald confirmation toast and updates the active safety badge.

2. **Scenario 1.2 (Clear / Empty Allergen Profile):**
   - **Given** a consumer with previously configured allergens,
   - **When** the consumer unchecks all allergens and saves,
   - **Then** the backend clears records for that user,
   - **And** updates the profile status to *"Không có hạn chế dị ứng (Chế độ ăn phổ thông)"*.

---

### User Story 2 - Set Severity Levels & Sensitivity Thresholds (Priority: P1)
**As a** consumer with varying degrees of allergy sensitivity,  
**I want to** designate the severity level (`Nghiêm trọng - High`, `Trung bình - Moderate`, `Nhẹ - Mild`) for each chosen allergen,  
**So that** the hazard detection algorithm can trigger distinct visual alarm levels (RED for High vs YELLOW for Mild).

* **Why this priority**: Necessary to prevent alarm fatigue and accurately differentiate life-threatening anaphylaxis risks from mild intolerance.

**Acceptance Scenarios**:
1. **Scenario 2.1 (Configuring Severity Thresholds):**
   - **Given** the consumer has selected *"Đậu phộng"*,
   - **When** the consumer assigns the severity level to *"Nghiêm trọng (High - Có thể sốc phản vệ)"*,
   - **And** selects *"Sữa bò"* with severity *"Nhẹ (Mild - Không dung nạp lactose)"*,
   - **Then** the server persists the exact severity enum alongside each allergen code.

---

### User Story 3 - Persistent Profile Restoration (Priority: P1)
**As a** returning consumer reopening the app,  
**I want** my previously configured allergen profile to load automatically from the server,  
**So that** I don't have to reconfigure my medical data every session.

**Acceptance Scenarios**:
1. **Scenario 3.1 (Automatic Profile Sync):**
   - **Given** an authenticated user opens the Allergy Profile screen,
   - **When** the screen initializes,
   - **Then** the client sends `GET /api/v1/profile/allergens`,
   - **And** pre-populates all previously selected allergen chips and severity settings.

---

## 4. Non-Functional Constraints
* **Latency**: Profile save and fetch response round-trip must be $\le 300$ ms.
* **WCAG 2.1 AA Compliance**: Every allergen chip must display a high-contrast icon + color indicator (Red border for High severity, Yellow for Moderate, Green for Safe).
* **Data Privacy**: Allergen profile data belongs strictly to the authenticated user ID and cannot be viewed or altered by unauthorized users.
