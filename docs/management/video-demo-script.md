# NutriViet: Video Demonstration Narration Script (Section E)

**Course:** CS300 - CSC13002 - Introduction to Software Engineering  
**Project Assignment:** PA3-2026 (Section E Deliverable - 20 Points)  
**Functional Groups Demonstrated:**  
* **FG1:** Authentication & Authorization (`specs/001-authentication/`)  
* **FG2:** Personal Allergy Profile Management (`specs/002-allergy-profile/`)  
**Group:** Group 07 - NutriViet Team  
**Live Production Backend:** `https://ngobinh2006.pythonanywhere.com`  
**Target Duration:** 3 – 5 minutes (Planned: 4:00)  

> 🎬 **Official Video Demonstration Link (YouTube):**  
> **[https://www.youtube.com/watch?v=-LUs4PHV20Q](https://www.youtube.com/watch?v=-LUs4PHV20Q)**  
> *(Live Software Demonstration of FG1 Authentication, Security Settings & FG2 Allergy Profile on Flutter Android & Cloud PythonAnywhere)*

---

## 🎬 Video Recording Timeline Overview

| Time | Scene | Focus & Screen Action | Demonstrated Requirements |
|:---:|:---|:---|:---|
| **00:00 – 00:35** | **Scene 1: Introduction & Architecture** | Split screen: VS Code, Terminal & Android Emulator. Introduce team, tech stack, and cloud backend. | Three-tier architecture, Clean Architecture, Cloud PythonAnywhere. |
| **00:35 – 01:10** | **Scene 2: Spec Kit SDD Workflow** | VS Code exploring `specs/001-authentication/` and `specs/002-allergy-profile/` (`spec.md`, `plan.md`, `tasks.md`, `openapi.json`). | Spec-Driven Development (SDD), 22/22 checklist review gates. |
| **01:10 – 01:50** | **Scene 3: Account Registration & Login (FG1)** | Android Emulator: Register new account, demonstrate clean zero-prefill, and authenticate into the app. | UC01 (Registration), UC02 (Authentication), PBKDF2 HMAC-SHA256 crypto. |
| **01:50 – 02:30** | **Scene 4: Dedicated Password Change (FG1)** | Tap top AppBar gear icon ⚙️ (`SettingsScreen`). Enter old password, new password, confirm, and verify success toast. | UC03 (Manage Profile & Security), Password hashing, session token update. |
| **02:30 – 03:20** | **Scene 5: Personal Health Metrics & Allergy Profile (FG2)** | Tap Profile Card on Home Screen. Update Height (170cm), Weight (65kg), Age (16), Activity Level $\to$ Auto BMI (22.5) & TDEE. Select Allergens (Peanuts, Seafood) with severity thresholds. | UC04 (Allergy Profile), UC05 (Sensitivity Levels), BMI & TDEE calculations. |
| **03:20 – 03:45** | **Scene 6: Ecosystem Tour (Taskbar, Scanner, Crowdsource)** | Showcase modern 5-tab taskbar, glowing center QUÉT button, Scan modal, and community crowdsource photo uploader. | UC06 (Camera Scanner preview), UC15 (Crowdsource photo upload), Community feed. |
| **03:45 – 04:00** | **Scene 7: Cloud DB Verification & Conclusion** | Open browser to verify SQLite cloud records on PythonAnywhere. Summary and course sign-off. | Data persistence audit, academic integrity wrap-up. |

---

## 🎙️ Detailed Step-by-Step Narration & Action Script

---

### Scene 1: Introduction, Architecture & Tech Stack (0:00 – 0:35)

* **Screen Setup:** Split-screen displaying the VS Code project workspace on the left and the running Android Emulator on the right.
* **Screen Actions:**
  1. Open the project in VS Code.
  2. Show the Flutter mobile application (`src/mobile/`) launched on the Android emulator with the clean Login screen.
  3. Briefly open the browser showing the live production backend status on PythonAnywhere (`https://ngobinh2006.pythonanywhere.com/api/v1/users`).
* **English Voiceover Narration:**
  > *"Hello professor and teaching assistants. We are Group 07 representing the NutriViet project. Today, we present our end-to-end full-stack demonstration for Project Assignment 3, Section E.*  
  > *Our system is engineered following modern full-stack standards: on the frontend, a responsive Flutter mobile client built with clean architecture; on the backend, a production Python microservice deployed live on Cloud PythonAnywhere; and on the persistence layer, an ACID-compliant relational SQLite database securing user credentials, physical metrics, and allergy profiles."*
* **Lời thoại Tiếng Việt (Gợi ý cho bạn quay video):**
  > *"Xin chào thầy cô và các bạn trợ giảng, nhóm 07 xin đại diện dự án NutriViet trình bày video minh chứng cho Section E của Project Assignment 3.*  
  > *Hệ thống NutriViet được phát triển toàn diện theo mô hình Full-Stack 3 tầng: phía mobile client được xây dựng bằng Flutter chạy trên Android emulator; phía backend là dịch vụ RESTful API viết bằng Python triển khai thực tế trên máy chủ đám mây PythonAnywhere; và tầng lưu trữ dữ liệu sử dụng hệ quản trị SQLite bảo mật thông tin tài khoản và hồ sơ dị ứng."*

---

### Scene 2: Spec Kit Spec-Driven Development Workflow (0:35 – 1:10)

* **Screen Setup:** Focus on VS Code. Navigate to the `specs/` directory in the project explorer.
* **Screen Actions:**
  1. Click to expand `specs/001-authentication/` and `specs/002-allergy-profile/`.
  2. Open `specs/001-authentication/spec.md` — scroll through the User Stories and Gherkin scenarios (`Given... When... Then...`).
  3. Open `specs/002-allergy-profile/plan.md` — highlight the data contracts, `openapi.json`, and database schema.
  4. Open `specs/002-allergy-profile/tasks.md` — show the granular 25-task breakdown across Phase 1 to Phase 8 with 100% completion checkmarks.
* **English Voiceover Narration:**
  > *"Before writing any code, our team strictly followed the GitHub Spec Kit Spec-Driven Development workflow. Here in `specs/001-authentication` and `specs/002-allergy-profile`, we authored formal functional specifications with Gherkin acceptance criteria.*  
  > *In `plan.md`, we established our OpenAPI REST contracts and database entity schemas for user metrics and allergen lists. And in `tasks.md`, all implementation activities were broken down into verified tasks, ensuring that every piece of backend and frontend logic directly traces back to our requirements."*
* **Lời thoại Tiếng Việt:**
  > *"Trước khi viết mã nguồn, nhóm đã áp dụng triệt để quy trình Spec-Driven Development với GitHub Spec Kit. Tại thư mục `specs/001-authentication` và `002-allergy-profile`, nhóm đã xây dựng bản đặc tả chi tiết với các kịch bản kiểm thử Gherkin.*  
  > *Trong file `plan.md` là hợp đồng OpenAPI và thiết kế lược đồ cơ sở dữ liệu. Toàn bộ 25 task kỹ thuật được phân rã chi tiết trong `tasks.md` từ khởi tạo, xây dựng API, giao diện người dùng đến tích hợp kiểm thử."*

---

### Scene 3: Account Registration & Authentication (FG1) (1:10 – 1:50)

* **Screen Setup:** Focus on the Android Emulator running NutriViet.
* **Screen Actions:**
  1. Show the Login screen. Emphasize that form fields are cleanly empty (zero-prefill) for authentic user input.
  2. Tap **"Đăng ký ngay"** at the bottom to navigate to `RegisterScreen`.
  3. Fill in new registration details:
     * Họ và tên: `Nguyễn Văn An`
     * Email: `nguyenvanan@nutriviet.vn`
     * Mật khẩu: `NutriViet@2026`
     * Xác nhận mật khẩu: `NutriViet@2026`
  4. Tap **"Đăng Ký Tài Khoản"**. Show the verification dialog prompting that the account has been registered and activated.
  5. Enter the registered email `nguyenvanan@nutriviet.vn` and password `NutriViet@2026` (or use the test account `tienbinhngo20@gmail.com`).
  6. Tap **"Đăng Nhập"**. The app performs animated transition into `HomeScreen`.
* **English Voiceover Narration:**
  > *"Now, let us demonstrate Functional Group 1 in action: UC01 - Register New Account. We navigate to the registration screen and enter a new user's information.*  
  > *When we submit, the Flutter client encrypts the payload and calls our remote API endpoint `/api/v1/auth/register`. The server validates the format, hashes the password using salted PBKDF2 HMAC-SHA256, and stores the user in SQLite.*  
  > *Now, we authenticate with these credentials. The backend verifies the password hash, generates a secure session token, and seamlessly transitions us into the main NutriViet dashboard."*
* **Lời thoại Tiếng Việt:**
  > *"Tiếp theo là phần thực thi của Functional Group 1: Ca sử dụng UC01 - Đăng ký tài khoản mới. Chúng ta nhập họ tên, email và mật khẩu an toàn.*  
  > *Khi bấm Đăng ký, ứng dụng gửi yêu cầu đến endpoint `/api/v1/auth/register` trên PythonAnywhere. Backend băm mật khẩu bằng thuật toán PBKDF2 HMAC-SHA256 kèm muối và lưu vào SQLite.*  
  > *Khi đăng nhập với tài khoản vừa tạo, backend xác thực thông tin, cấp token phiên làm việc và chuyển mượt mà vào màn hình chính của NutriViet."*

---

### Scene 4: Dedicated Password Change via AppBar Gear Icon ⚙️ (1:50 – 2:30)

* **Screen Setup:** Android Emulator on `HomeScreen`.
* **Screen Actions:**
  1. Point out the top AppBar: NutriViet logo, brand subtitle *"Allergen Safety Shield"*, and the **Gear icon ⚙️** (`Icons.settings_outlined`).
  2. Tap the **Gear icon ⚙️** at the top right of the AppBar. The app opens `SettingsScreen` titled *"Cài Đặt & Đổi Mật Khẩu"*.
  3. In the password form, enter:
     * Mật khẩu hiện tại: `NutriViet@2026`
     * Mật khẩu mới: `NewPassNutri@2026`
     * Xác nhận mật khẩu mới: `NewPassNutri@2026`
  4. Tap **"Cập Nhật Mật Khẩu"**.
  5. Show the green SnackBar notification: *"Đổi mật khẩu thành công!"*.
  6. Tap Back to return to `HomeScreen`.
* **English Voiceover Narration:**
  > *"Next is UC03 - Security Management. As designed in our user experience review, security controls are placed conveniently in the top AppBar gear icon.*  
  > *Tapping the gear icon opens the dedicated password update interface. We enter the current password, a new complex password, and confirm.*  
  > *The backend validates the existing hash, computes the new salted cryptographic hash, updates the database, and returns a 200 OK status code. The client immediately displays a confirmation toast."*
* **Lời thoại Tiếng Việt:**
  > *"Tiếp theo là UC03 - Quản lý bảo mật tài khoản. Theo đúng thiết kế chuẩn UX, nút Đổi mật khẩu được bố trí trực tiếp tại biểu tượng Bánh răng ⚙️ ở góc trên AppBar.*  
  > *Khi nhấn vào bánh răng, giao diện `SettingsScreen` hiện ra. Ta nhập mật khẩu hiện tại và mật khẩu mới.*  
  > *Hệ thống gửi request đến `/api/v1/auth/change-password`, kiểm tra mật khẩu cũ, băm mật khẩu mới và cập nhật tức thì trong cơ sở dữ liệu với thông báo thành công màu xanh."*

---

### Scene 5: Personal Allergy Profile & Physical Metrics (FG2) (2:30 – 3:20)

* **Screen Setup:** Android Emulator on `HomeScreen`.
* **Screen Actions:**
  1. Point out the **User Profile Card** at the top showing the avatar, full name, age, email, and dynamic BMI badge (e.g., `BMI 22.5`).
  2. Tap directly anywhere on the **Profile Card** (or tap the bottom Tab *"Dị ứng (FG2)"*). The app smoothly navigates to `AllergyProfileScreen`.
  3. Scroll down to **"Chỉ Số Thể Chất & Sức Khỏe"**:
     * Chiều cao: Enter `170` (cm)
     * Cân nặng: Enter `65` (kg)
     * Tuổi: Enter `16`
     * Mức độ vận động: Select `Vận động vừa (3-5 buổi/tuần)`
     * Show that the app automatically recalculates: **BMI = 22.5 (Bình thường)** và **TDEE = 2150 kcal/ngày**.
  4. Scroll down to **"Danh Sách Dị Ứng Cần Tránh"**:
     * Check **Đậu phộng (Peanuts 🥜)** $\to$ Select Severity: **Sốc phản vệ (Anaphylaxis)**.
     * Check **Hải sản (Seafood 🦐)** $\to$ Select Severity: **Nghiêm trọng (High)**.
  5. Tap **"Lưu Hồ Sơ Sức Khỏe"**.
  6. Return to `HomeScreen`. Show that the Profile Card now displays the updated metrics, and the *"Nhóm Dị Ứng Cần Tránh"* section instantly shows **2 đã chọn** with emoji tags 🥜 🦐.
* **English Voiceover Narration:**
  > *"Now we move to Functional Group 2: UC04 and UC05 - Personal Allergy & Health Profile Management.*  
  > *Instead of burying settings in complex menus, users simply tap directly on their personal profile card on the home screen.*  
  > *Here, users enter their height, weight, and age. The system computes their Body Mass Index (BMI) and Total Daily Energy Expenditure (TDEE) in real time.*  
  > *Below, users select their allergen sensitivities—such as Peanuts and Seafood—and assign clinical severity levels from Mild to Fatal Anaphylaxis.*  
  > *When we tap Save, the profile payload is sent to `/api/v1/profile/metrics` and `/api/v1/profile/allergens`. Upon returning home, the dashboard dynamically updates with the new BMI badge and allergen safety chips."*
* **Lời thoại Tiếng Việt:**
  > *"Bây giờ chúng ta đến với Functional Group 2: Ca sử dụng UC04 và UC05 - Quản lý hồ sơ sức khỏe và dị ứng cá nhân.*  
  > *Người dùng chỉ cần chạm trực tiếp vào thẻ Hồ sơ cá nhân ở đầu màn hình chính để vào trang cấu hình.*  
  > *Tại đây, chúng ta nhập Chiều cao 170cm, Cân nặng 65kg, Tuổi 16 và mức độ vận động. Ứng dụng tự động tính toán chỉ số BMI 22.5 và năng lượng TDEE tiêu hao mỗi ngày.*  
  > *Phía dưới, người dùng chọn các nhóm dị ứng như Đậu phộng và Hải sản, gán mức độ nghiêm trọng từ Nhẹ đến Sốc phản vệ.*  
  > *Sau khi bấm Lưu, dữ liệu đồng bộ lên cloud và màn hình chính lập tức cập nhật huy hiệu BMI cùng các nhãn dị ứng đã chọn."*

---

### Scene 6: Ecosystem Tour (Taskbar, Scanner Modal & Crowdsourcing) (3:20 – 3:45)

* **Screen Setup:** Android Emulator on `HomeScreen`.
* **Screen Actions:**
  1. Highlight the modern **5-tab bottom navigation bar** with the center glowing **QUÉT** button.
  2. Tap the center **QUÉT** button: show the bottom modal sheet with options *"Chụp Bao Bì"* (Camera OCR preview) and *"Chọn Ảnh"*.
  3. Scroll down on `HomeScreen` to the Ecosystem section and tap **"Đóng Góp Sản Phẩm Cộng Đồng"**:
     * Show `ContributeProductScreen` where users can snap packaging photos, enter brand names, barcodes, and ingredients.
  4. Tap Back and open **"Bảng Tin Sản Phẩm Cộng Đồng"** (`CommunityFeedScreen`) showing the live feed of contributed items.
* **English Voiceover Narration:**
  > *"Beyond FG1 and FG2, NutriViet features a cohesive mobile ecosystem designed for grocery shopping convenience.*  
  > *At the center of our bottom navigation bar is the glowing Scan button, allowing instant access to label OCR capture.*  
  > *Furthermore, our crowdsourcing module allows shoppers to photograph unindexed food packaging, upload ingredient lists, and browse verified community contributions."*
* **Lời thoại Tiếng Việt:**
  > *"Bên cạnh FG1 và FG2, NutriViet được trang bị hệ sinh thái hoàn chỉnh phục vụ người tiêu dùng khi đi siêu thị.*  
  > *Nổi bật ở giữa thanh điều hướng là nút QUÉT phát sáng nổi bật, cho phép mở nhanh tính năng chụp nhãn OCR.*  
  > *Ứng dụng cũng tích hợp sẵn phân hệ Đóng góp sản phẩm cộng đồng, cho phép người dùng chụp ảnh bao bì, tải thành phần và xem bảng tin sản phẩm đã được kiểm định."*

---

### Scene 7: Cloud Database Verification & Conclusion (3:45 – 4:00)

* **Screen Setup:** Web browser showing PythonAnywhere SQLite database or API endpoint, then switch to `README.md`.
* **Screen Actions:**
  1. Refresh `https://ngobinh2006.pythonanywhere.com/api/v1/users` in the browser, showing the newly created user record, hashed password, and allergen relationships persisted in the cloud database.
  2. Switch to the project repository `README.md` showing the project structure and Spec Kit documentation.
* **English Voiceover Narration:**
  > *"To verify true full-stack persistence, we refresh our live production API endpoint on PythonAnywhere. As you can see, the new user record, encrypted credentials, BMI metrics, and allergen links are permanently stored in the cloud database.*  
  > *All source code, Flutter UI screens, and Spec Kit artifacts are organized cleanly in our repository under `src/` and `specs/`.*  
  > *Thank you very much for your time and for evaluating NutriViet's PA3 submission!"*
* **Lời thoại Tiếng Việt:**
  > *"Để kiểm chứng tính toàn vẹn của cơ sở dữ liệu đám mây, chúng ta tải lại endpoint trên PythonAnywhere. Bản ghi người dùng mới, mật khẩu băm bảo mật, chỉ số BMI và danh sách dị ứng đã được lưu trữ vĩnh viễn trên cloud database.*  
  > *Toàn bộ mã nguồn Flutter, Python backend và tài liệu Spec Kit đã được tổ chức quy củ trong repository.*  
  > *Nhóm 07 xin chân thành cảm ơn thầy cô đã theo dõi phần trình bày của nhóm!"*

---

## 💡 Quick Tips for the Recording Member:
1. **Resolution:** Record at **1080p (1920x1080)** or **720p (1280x720)** at 30/60 fps.
2. **Audio:** Use a clear microphone; speak at a steady, confident pace.
3. **Speed:** Keep actions smooth without long pauses. Total video duration should be **between 3 minutes 30 seconds and 4 minutes 30 seconds**.
4. **YouTube Settings:** Uploaded as **Unlisted (Không công khai)** at [https://www.youtube.com/watch?v=-LUs4PHV20Q](https://www.youtube.com/watch?v=-LUs4PHV20Q) and embedded across project documentation and [README.md](file:///d:/NutriViet/README.md).
