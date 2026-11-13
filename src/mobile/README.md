# NutriViet Mobile Application (Flutter)

**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA3-2026 (Section E Deliverable)  
**Functional Group:** FG1 - Authentication & Authorization  

---

## 📱 How to Open and Run in Android Studio

### 1. Prerequisite: Start the Backend Server First
Before launching the Flutter app, ensure the backend server is running so that the Android app can communicate with it:
```bash
cd d:\NutriViet\src\backend
python server.py
```
*(The backend will be listening on `http://0.0.0.0:8000`)*

---

### 2. Open Project in Android Studio
1. Open **Android Studio**.
2. Select **Open** (or `File > Open...`).
3. Navigate to `d:\NutriViet\src\mobile` and click **OK**.
4. If prompted to get Flutter dependencies, click **Get dependencies** (or run `flutter pub get` in terminal).

---

### 3. Launch on Android Emulator
1. Open **Device Manager** in Android Studio (icon in top right or `Tools > Device Manager`).
2. Start any Android Virtual Device (e.g., *Pixel 7 Pro*, *Medium Phone API 34*).
3. Select the emulator as target device and click **Run** (`Shift + F10` or the green Play icon).

> [!NOTE]
> In Android Emulator, network requests to `http://10.0.2.2:8000` automatically connect to the host computer's backend on port 8000. This is pre-configured in `auth_service.dart`.

---

## 🧪 Testing the Feature (Full-Stack Verification)

1. **Test Registration (UC01):**
   * Click *"Đăng ký ngay"*
   * Enter full name, your personal email, password
   * Submit ➔ Verify HTTP 201 response and redirect to Home screen
   * Check the backend terminal log and SQLite database to see your new user record!

2. **Test Negative Scenario (UC02 Alternative Flow):**
   * Log out
   * Try entering an incorrect password ➔ Verify the red warning banner appears immediately!

3. **Test Successful Login (UC02 Basic Flow):**
   * Click *"Dùng tài khoản mẫu (Demo)"* to auto-fill `demo@nutriviet.vn`
   * Click *"Đăng nhập"* ➔ Verify HTTP 200 and redirect to Home screen.

