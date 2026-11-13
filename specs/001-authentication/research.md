# Research & Architectural Spikes: FG1 - Authentication

**Feature**: `001-fg1-authentication`  
**Lead Researcher**: Le Tat Nam (Backend) & Luong Hoang Nam (Mobile)  
**Date**: 08/11/2026  

---

## 1. Cryptographic Password Hashing Decision

* **Context:** NutriViet stores sensitive user dietary health profiles. Storing plaintext or unsalted hashes violates Principle II & Security Standard 2 of the Constitution.
* **Option A: Plain MD5 / SHA-256 (Rejected):** Vulnerable to rainbow table attacks and GPU precomputation.
* **Option B: bcrypt / Argon2 (Considered):** Industry standard, but requires native C-extension compilation dependencies which complicates evaluation on student machines.
* **Option C: PBKDF2 with HMAC-SHA256 & 100,000 rounds (Selected):**
  * *Rationale:* Built directly into Python's native `hashlib` standard library (zero external pip packages required). NIST SP 800-132 compliant, resistant to brute-force attacks via work-factor stretching, and 100% portable.
  * *Salt generation:* 16 bytes of OS entropy (`os.urandom(16).hex()`).

---

## 2. Cross-Platform Android Emulator Networking Spike

* **Context:** When running the Flutter client inside the Android Virtual Device (AVD), requests to `http://localhost:8000` or `http://127.0.0.1:8000` resolve to the emulator's internal loopback interface, failing to connect to the host computer's backend.
* **Investigation Findings:**
  * Android Studio QEMU router maps the host loopback interface to IP `10.0.2.2`.
  * Android 9+ (API 28+) enforces network security configs blocking plaintext HTTP unless explicitly authorized.
* **Implemented Solution:**
  1. Set `android:usesCleartextTraffic="true"` in `AndroidManifest.xml`.
  2. Implement dynamic host resolution in `auth_service.dart`:
     ```dart
     if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1/auth';
     return 'http://127.0.0.1:8000/api/v1/auth';
     ```

---

## 3. Session Persistence Strategy

* **Context:** Consumers should remain authenticated across app restarts without re-entering credentials unless they explicitly log out.
* **Evaluated Options:**
  * Secure Storage (`flutter_secure_storage`): Best for keychain, but requires platform-specific encryption keystore setup.
  * Shared Preferences (`shared_preferences`): Light, reliable, stores session bearer token and user metadata in Android SharedPreferences XML.
* **Decision:** `shared_preferences` chosen for PA3 scope to guarantee instantaneous cold start restoration and zero-error initialization.
