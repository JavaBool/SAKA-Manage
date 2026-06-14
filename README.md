# Customer Feedback & Reporting Management System

A production-ready enterprise solution for customer feedback and reporting management, consisting of a Flask-based Backend Web Service (with a built-in admin dashboard) and a cross-platform Flutter Client (targeting Android and Windows) designed with modern Material 3 aesthetics, role-based access control, offline caching, and real-time push notifications.

---

## 📂 Project Structure

```text
SAKA-Manage/
├── backend/                  # Flask Web Service & Admin Dashboard
│   ├── config/               # App configuration files
│   ├── models/               # SQLAlchemy DB schema models
│   ├── routes/               # API blueprints (REST endpoints)
│   ├── services/             # Core business logic (FCM, Email, Storage, Auditing)
│   ├── templates/            # Jinja2 templates for Admin dashboard
│   ├── tests/                # Pytest integration tests
│   ├── seed.py               # DB seeding script
│   ├── app.py                # WSGI entry point
│   └── requirements.txt      # Python dependencies
├── client_flutter/           # Cross-Platform Flutter Client
│   ├── android/              # Native Android build configuration
│   ├── windows/              # Native Windows build configuration
│   ├── lib/                  # Dart source code (Riverpod state, SQLite cache, UI features)
│   └── pubspec.yaml          # Flutter dependencies
├── migrations/               # Alembic database migrations
└── instance/                 # Local development SQLite database storage
```

---

## 🚀 Backend Setup & Run Guide

### 1. Prerequisites
- Python 3.10+
- PostgreSQL or SQLite (default for development)

### 2. Environment Setup
From the root directory, navigate to `/backend` and create/activate a virtual environment:
```powershell
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Database Initialization & Seeding
Perform Alembic migrations and seed database with the mock test dataset from the root directory (`d:\Projects\SAKA-Manage`) with `PYTHONPATH` set:

**For PowerShell:**
```powershell
$env:PYTHONPATH="d:\Projects\SAKA-Manage"
flask --app backend.app db upgrade
python backend/seed.py
```

**For Command Prompt (cmd):**
```cmd
set PYTHONPATH=d:\Projects\SAKA-Manage
flask --app backend.app db upgrade
python backend/seed.py
```

### 4. Running the Backend Server
Start the development server from the root directory:

**For PowerShell:**
```powershell
$env:PYTHONPATH="d:\Projects\SAKA-Manage"
python backend/app.py
```

**For Command Prompt (cmd):**
```cmd
set PYTHONPATH=d:\Projects\SAKA-Manage
python backend/app.py
```
- **Interactive REST Swagger Docs**: Access at `http://127.0.0.1:5000/api/v1/docs`
- **Web Admin Dashboard**: Access at `http://127.0.0.1:5000/admin`
  - *Default Admin Email*: `admin@company.com` (Requires password & OTP)

### 5. Running Tests
Run the pytest suite from the root directory:

**For PowerShell:**
```powershell
$env:PYTHONPATH="d:\Projects\SAKA-Manage"
.\backend\venv\Scripts\python.exe -m pytest backend/tests/test_api.py
```

**For Command Prompt (cmd):**
```cmd
set PYTHONPATH=d:\Projects\SAKA-Manage
.\backend\venv\Scripts\python.exe -m pytest backend/tests/test_api.py
```

---

## 📱 Client (Flutter) Setup & Build Guide

### 1. Prerequisites
- Flutter SDK (stable channel, e.g., 3.44.x)
- Android SDK (targeting SDK 36)
- Visual Studio 2022/2026 (for Windows compilation, with C++ Desktop Development workload)

### 2. Get Dependencies
Navigate to `/client_flutter` and fetch pub packages:
```powershell
cd client_flutter
flutter pub get
```

### 3. Running the Client App
Run the client locally:
```powershell
flutter run -d windows
# OR
flutter run -d <android-device-id>
```

---

## 📦 Compiling Production Release Artifacts

The system is configured to output fully optimized production-ready binaries for both Android and Windows:

### 1. Android Release APK
Generate the release APK:
```powershell
cd client_flutter
flutter build apk --release
```
- **Output Artifact**: `client_flutter/build/app/outputs/flutter-apk/app-release.apk`

### 2. Android Release App Bundle (AAB)
Generate the Google Play upload bundle:
```powershell
cd client_flutter
flutter build appbundle --release
```
- **Output Artifact**: `client_flutter/build/app/outputs/bundle/release/app-release.aab`

### 3. Windows Release Executable (EXE)
If multiple Visual Studio instances are present and the default is incomplete, or to override path conflicts, compile the Windows executable using the Visual Studio Community developer command prompt script:
```powershell
cmd.exe /c 'call "D:\Apps\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" && cd d:\Projects\SAKA-Manage\client_flutter && set PUB_CACHE=d:\PubCache && D:\Apps\flutter\bin\flutter.bat build windows --release'
```
- **Output Artifact**: `client_flutter/build/windows/x64/runner/Release/client_flutter.exe`

---

## 🔧 Core Architectural Patches Applied

To enable a successful compile and production grade deployment under Windows and modern Android SDKs, the following patches are implemented:
1. **ATL-free Secure Storage on Windows**: Replaced deprecated Active Template Library (ATL) header `<atlstr.h>` and conversions with standard Win32 API functions (`MultiByteToWideChar`/`WideCharToMultiByte`) to compile cleanly on ATL-free build chains.
2. **Android Gradle Plugin 9+ Kotlin Support**: Configured Gradle to force compile Kotlin code properly in third-party library builds (e.g., `file_picker`), ensuring complete compatibility with Gradle 9+ and Android compile SDK 36.
3. **Offline Caching & Background Sync**: Set up SQLite client caching (`sqflite`) and a dedicated Riverpod sync provider that detects connectivity restoring events to flush queued actions to the backend.
