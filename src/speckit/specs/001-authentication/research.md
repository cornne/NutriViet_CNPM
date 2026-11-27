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
  * *Rationale:* Built natively into the Web Crypto API (`crypto.subtle.deriveBits` in `src/cloudflare-worker/src/crypto.ts`) with zero external runtime dependencies. NIST SP 800-132 compliant, resistant to brute-force attacks via work-factor stretching, and byte-compatible with standard PBKDF2-HMAC-SHA256.
  * *Salt generation:* 16 bytes of CSPRNG entropy (`crypto.getRandomValues`).

---

## 2. Direct HTTPS Cloud Networking Decision

* **Context:** Earlier prototypes probed local loopback addresses (`10.0.2.2:8000` / `localhost:8000`), which caused connection timeouts on physical Android devices and added startup latency.
* **Investigation Findings:**
  * Deploying the backend to **Cloudflare Workers** (`https://nutriviet.nutriviet-api.workers.dev`) with Smart Placement in APAC eliminates local loopback dependencies across both Android emulators and physical devices.
* **Implemented Solution:**
  1. All Flutter builds (debug & release) target `https://nutriviet.nutriviet-api.workers.dev/api/v1` over HTTPS exclusively (configurable via `--dart-define=NUTRIVIET_API_ROOT=...`), with zero localhost probes.

---

## 3. Session Persistence Strategy

* **Context:** Consumers should remain authenticated across app restarts without re-entering credentials unless they explicitly log out.
* **Evaluated Options:**
  * Secure Storage (`flutter_secure_storage`): Best for keychain, but requires platform-specific encryption keystore setup.
  * Shared Preferences (`shared_preferences`): Light, reliable, stores session bearer token and user metadata in Android SharedPreferences XML.
* **Decision:** `shared_preferences` chosen for PA3 scope to guarantee instantaneous cold start restoration and zero-error initialization.
