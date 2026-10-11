# Daylight - Daily Activity & Time Tracker

A modern, minimalist daily time tracking Flutter application designed to help you visualize where your time goes in real time, build habits, and monitor goals.

---

## 📱 Features

- **Real-Time Visual Timeline:** Log and view every activity across a 24-hour day with color-coded categories.
- **Auto-Carry Forward:** Automatically carries ongoing routines (like sleep) across midnight.
- **Smart Goals & Streaks:** Set daily, weekly, or custom day goals with streak tracking and freeze protection.
- **Insights & Analytics:** Live percentage breakdown of your tracked time, weekly summaries, and category trends.
- **Profile & Auth:** Seamless authentication with first name, last name, email, and alphanumeric password requirements.
- **Cloud Sync & Guest Mode:** Backed by **Supabase** for multi-device sync, with offline-first local persistence (`SharedPreferences`) for guest usage.

---

## 🛠️ Tech Stack

- **Frontend:** [Flutter](https://flutter.dev/) (Dart)
- **Backend & Auth:** [Supabase](https://supabase.com/) (PostgreSQL + Auth + Row Level Security)
- **Local Storage:** `shared_preferences`

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- A [Supabase](https://supabase.com) project (for cloud sync & auth)

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/daily_activity_tracker.git
cd daily_activity_tracker
```

### 2. Set up Supabase

1. Open your Supabase Project dashboard.
2. Go to the **SQL Editor** and execute the script found in:
   ```text
   supabase/schema.sql
   ```
   *(This configures tables for profiles, categories, activities, goals, and Row Level Security).*
3. In **Authentication -> Providers -> Email**, disable **Confirm email** for instant sign-ins (or configure Site Redirect URLs for production).

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

Run in debug mode on your connected device or emulator:

```bash
flutter run
```

---

## 📦 Building an APK (Android)

To generate an optimized release APK:

```bash
flutter build apk --release
```

The APK will be located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 📄 License

This project is licensed under the MIT License - feel free to customize and use it!
