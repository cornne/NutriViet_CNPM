# Feature Specification: FG1 - Authentication & Authorization

**Feature Branch**: `001-fg1-authentication`  
**Date**: 10/11/2026 (Updated per Customer & Course Directive)  
**Status**: Approved & Active  
**Target Delivery**: PA3-2026 (Section E Deliverable)  
**Lead Engineer (Assignee)**: Luong Hoang Nam (Flutter) & Le Tat Nam (Backend)  
**Reviewer**: Ngo Tien Binh  

---

## 1. Feature Overview & Business Value

The **Authentication & Authorization** functional group (`FG1`) provides secure, compliant identity management and session control for the NutriViet allergen-safe dietary platform.

In response to the latest security policies and user experience requirements:
1. **Zero Pre-filled Credentials & No Demo Accounts**: Production security posture mandates empty input fields on launch. Demo shortcut buttons are removed.
2. **Elimination of Third-Party SSO**: Google Sign-In is decommissioned to prioritize strict medical data privacy and sovereign credential ownership.
3. **Mandatory Email Verification Gate**: Users are strictly barred from entering the application until their email address is confirmed via cryptographic token link (`is_verified == 1`).
4. **Integrated Password Recovery (Forgot Password)**: Users can initiate password recovery via verified email dispatch.
5. **Direct Onboarding Profile Redirection**: Immediately upon successful login or verification, the application bypasses generic screens and redirects directly into the **Personal Allergy Profile Setup (`FG2`)** to establish life-saving food restrictions prior to accessing any scanning features.

---

## 2. User Stories & Gherkin Scenarios

### User Story 1 - Consumer Account Registration (Priority: P1)
**As a** consumer with dietary restrictions or food allergies,  
**I want to** register an account using my clean personal email and a strong password,  
**So that** an activation email is dispatched and my unique medical record profile can be safely established.

* **Why this priority**: Required foundational step before storing any clinical or dietary profile.
* **Independent Test**: Validated by submitting valid name, email, password; verifying HTTP 201 Created response; checking `is_verified = 0` in SQLite; and confirming verification email delivery.

**Acceptance Scenarios**:
1. **Scenario 1.1 (Successful Registration & Email Gate Trigger):**
   - **Given** the user opens the Registration screen with all fields empty,
   - **When** the user enters their full name, valid email, and password $\ge 8$ characters,
   - **And** agrees to medical terms and taps *"Hoàn tất & Cài đặt Hồ sơ"*,
   - **Then** the backend persists the user record with `is_verified = 0` and generates a 32-byte cryptographic token,
   - **And** the app immediately transitions to the `VerifyEmailScreen` prompting the user to check their mailbox.

2. **Scenario 1.2 (Duplicate Email Prevention):**
   - **Given** an account already exists with email `user@example.com`,
   - **When** another registration attempts using the same email,
   - **Then** the server responds with HTTP 409 Conflict (`EMAIL_ALREADY_EXISTS`),
   - **And** the mobile app displays an accessible red alert banner: *"Email này đã được đăng ký. Vui lòng đăng nhập hoặc khôi phục mật khẩu."*

---

### User Story 2 - Consumer Authentication with Mandatory Verification Gate (Priority: P1)
**As a** registered consumer,  
**I want to** log in with my verified email and password on a clean, empty form,  
**So that** my identity is verified and I can access my dietary safety tools.

* **Why this priority**: Critical path for daily application access.
* **Independent Test**: Validated with unverified vs verified accounts. Unverified accounts must be rejected with HTTP 403 Forbidden.

**Acceptance Scenarios**:
1. **Scenario 2.1 (Login with Unverified Account - Strict Gate):**
   - **Given** a user registered an account but has not clicked the email activation link (`is_verified = 0`),
   - **When** the user enters correct email and password and taps *"Đăng Nhập An Toàn"*,
   - **Then** the backend rejects authentication with HTTP `403 Forbidden` and error code `EMAIL_NOT_VERIFIED`,
   - **And** the mobile app blocks access to the application, displaying a prompt with a direct action to resend or navigate to `VerifyEmailScreen`.

2. **Scenario 2.2 (Successful Login & Immediate Redirection to FG2 Profile):**
   - **Given** a consumer with a verified account (`is_verified = 1`),
   - **When** the consumer enters valid credentials into the empty email and password fields,
   - **Then** the backend returns HTTP `200 OK` with an active JWT session token,
   - **And** the mobile client saves the session token,
   - **And** the app **immediately redirects to `AllergyProfileScreen` (FG2)** so the user can verify or set up their allergen constraints.

3. **Scenario 2.3 (Clean UI - No Demo / No Google SSO):**
   - **Given** the login screen is loaded,
   - **Then** email and password fields MUST be completely blank,
   - **And** no Google Sign-In button shall be displayed,
   - **And** no Demo auto-fill credentials button shall exist.

---

### User Story 3 - Password Recovery & Reset Flow (Priority: P2)
**As a** consumer who forgot their password,  
**I want to** request a password recovery email from the login screen,  
**So that** I can securely regain access to my account without creating a duplicate identity.

**Acceptance Scenarios**:
1. **Scenario 3.1 (Request Password Recovery):**
   - **Given** the user is on the Login screen,
   - **When** the user taps *"Quên mật khẩu?"*,
   - **Then** a clean recovery modal appears prompting for the registered email address,
   - **When** the user submits a valid email,
   - **Then** the backend generates a reset token and sends recovery instructions,
   - **And** the app displays a confirmation banner: *"Đã gửi liên kết khôi phục mật khẩu vào hộp thư của bạn."*

---

### User Story 4 - Post-Login Onboarding Redirection to Health Profile (Priority: P1)
**As a** user accessing NutriViet,  
**I want to** be guided directly to the Allergy Profile configuration screen immediately upon authentication,  
**So that** I do not inadvertently consume dangerous foods before configuring my allergen sensitivity shield.

**Acceptance Scenarios**:
1. **Scenario 4.1 (Immediate Transition to FG2):**
   - **Given** successful authentication or completed email verification,
   - **When** the session initializes,
   - **Then** the app navigates immediately to `AllergyProfileScreen`,
   - **And** displays the user's name and active allergen groups (Peanuts, Seafood, Milk, Gluten, etc.),
   - **When** the user confirms/saves their profile,
   - **Then** the app transitions into the main Home dashboard.

---

### User Story 5 - Settings, Change Password & Body Nutrition Metrics (Priority: P1)
**As a** verified user,  
**I want to** change my temporary or existing password in a dedicated Settings section and customize my physical body metrics (Age, Gender, Height, Weight),  
**So that** I can secure my account after password recovery and receive standard, personalized BMI and caloric intake recommendations.

**Acceptance Scenarios**:
1. **Scenario 5.1 (Change Password in Settings):**
   - **Given** the user is logged in (including users who logged in with temporary password `Nutri@XXXXXX`),
   - **When** the user accesses Settings and inputs their current password and new password ($\ge 6$ chars),
   - **Then** the backend validates the current password, updates the password hash, and confirms success.

2. **Scenario 5.2 (Input Age, Height, Weight & Live BMI Calculation):**
   - **Given** the user is on the Health Profile or Settings screen,
   - **When** the user enters their Age, Height (cm), Weight (kg), and selects Gender,
   - **Then** the app immediately calculates and displays their WHO/Asian BMI status (Underweight, Normal, Overweight, Obese) and estimated daily caloric requirement (TDEE).

---

## 3. Data Requirements & Schema Updates

### Table: `users` (SQLite)
* `id`: Integer Primary Key Autoincrement
* `full_name`: Text Not Null
* `email`: Text Unique Not Null (Collate NOCASE)
* `password_hash`: Text Not Null (PBKDF2 HMAC-SHA256, 100,000 iterations)
* `salt`: Text Not Null (32-byte hex salt)
* `is_verified`: Integer Not Null Default 0 (0 = Pending verification, 1 = Verified)
* `verification_token`: Text Nullable (URL-safe activation token)
* `reset_token`: Text Nullable (Password reset token)
* `created_at`: ISO-8601 Timestamp

### Table: `user_metrics` (SQLite)
* `user_id`: Integer Primary Key References `users(id)` On Delete Cascade
* `age`: Integer Default 22
* `gender`: Text Default 'male'
* `height`: Real Default 170.0 (cm)
* `weight`: Real Default 65.0 (kg)
* `activity_level`: Text Default 'moderate'
* `target_calories`: Integer Default 2100 (kcal)
* `updated_at`: ISO-8601 Timestamp

---

## 4. Non-Functional & Security Constraints
* **Zero Pre-fill**: Inputs initialize with empty strings (`""`) to prevent unauthorized access on shared devices.
* **Dual-Coding Compliance (WCAG 2.1 AA)**: All error states feature both chromatic indication (Red `#EF4444`) and explicit iconography (Icons `error_outline_rounded`).
* **Session Persistence**: Validated session tokens are stored in private local device storage (`SharedPreferences`).
* **Performance**: Authentication and profile loading latency $\le 500\,\text{ms}$ under 4G/WiFi conditions.
