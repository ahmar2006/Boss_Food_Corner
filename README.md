# 🍔 Boss Food Corner — POS System

A **full-featured, real-time Point of Sale (POS) system** built with Flutter Web and Firebase. Designed for restaurant operations with distinct role-based dashboards for the **Manager**, **Cashier**, and **Kitchen/Expediter** staff.

> Developed by **Voryent Solution** — 0329 7600120

---

## 📸 Overview

The Boss Food Corner POS system streamlines restaurant operations from order placement to kitchen fulfillment and daily financial closing. It supports real-time multi-device synchronization, thermal receipt printing, and comprehensive sales analytics — all running in the browser.

---

## ✨ Features

### 👔 Manager Dashboard
| Feature | Description |
|---|---|
| **Menu Management** | Create and manage categories, menu items with prices and images |
| **Deals & Promotions** | Define time-limited combo deals with custom pricing |
| **Discounts** | Configure percentage or flat discounts applied at checkout |
| **Employee Management** | Add/remove cashiers and expediters; assign passwords |
| **Rider Management** | Register delivery riders with contact info and active status |
| **Sales Analytics** | Date-range reports with revenue, order counts, charts (powered by fl_chart) |
| **Activity Logs** | Full audit trail of order status changes across all staff |
| **POS Settings** | Set cashier report password, release daily closings |
| **Daily Closing Release** | Manager authority to release a cashier's submitted closing for correction |

### 🧾 Cashier Dashboard
| Feature | Description |
|---|---|
| **Order Placement** | Browse categories, add items/deals, apply discounts to cart |
| **Dine-in / Delivery / Takeaway** | Configurable order types with optional table/delivery info |
| **Smart Token System** | Auto-incremented human-readable token IDs (e.g., `000006`) |
| **My Orders** | Live view of active orders with real-time status updates; search by token |
| **Order Search** | Search by short token ID (strips leading zeros automatically) |
| **Pay Bill Dialog** | Enter cash received → auto-calculates change; validates insufficient funds |
| **Thermal Receipt Printing** | Prints order receipts with logo, items, tax, discount, cash/change breakdown |
| **Daily Closing** | Submit end-of-day cash/online/card totals; print daily closing receipt |
| **Reports (Password Protected)** | View shift sales, revenue, and order breakdowns (optional password) |

### 🍳 Expediter / Kitchen Dashboard
| Feature | Description |
|---|---|
| **Pending Queue (Grid View)** | Incoming orders displayed as kitchen tickets in a responsive grid |
| **Start Preparation** | One tap to begin cooking; ticket stays visible with "Mark Ready" action |
| **Ready Tab** | Orders marked ready for pickup/delivery |
| **Completed Tab** | Full order history for the shift |
| **Real-time Sync** | All status changes instantly reflected across all logged-in devices |

### 🖨️ Receipt Printing
- **Order Receipt**: Logo, store address/phone, order details, tax (hidden if 0%), discount (hidden if not applied), Grand Total, Cash received, Change returned.
- **Daily Closing Receipt**: Logo, store info, Total Punch Orders, Total Confirmed Orders, Cancelled Orders, Total Today Revenue, Cash/Online/Card breakdown, Total Received Amount, developer signature.

---

## 🏗️ Architecture

The project follows a **feature-first clean architecture** with Riverpod for state management:

```
lib/
├── core/
│   ├── models/         # Shared data models (OrderModel, MenuItemModel, DailyClosingModel, ...)
│   ├── repositories/   # Abstract interfaces + Firebase & Mock implementations
│   ├── routing/        # GoRouter navigation with role-based guards
│   ├── theme/          # App-wide design tokens (AppTheme)
│   └── widgets/        # Shared widgets & thermal receipt print engine
└── features/
    ├── auth/           # Login, registration, role routing
    ├── manager/        # Manager views & providers
    ├── cashier/        # Cashier views, cart, search, reports & closing
    └── expediter/      # Kitchen queue views & providers
```

### Key Patterns
- **Repository Pattern**: `OrderRepository`, `MenuRepository`, `SettingsRepository` etc. are abstract interfaces. `FirebaseOrderRepository` and `MockOrderRepository` provide concrete implementations — toggled automatically based on whether a `firebase_options.dart` project is connected.
- **Riverpod Providers**: All state (orders, settings, auth) is managed via `StreamProvider` and `StateNotifierProvider` — fully reactive.
- **Logical Business Day**: Day resets at **5:00 AM** — all reports and daily closings use this offset for consistent daily metrics.

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter 3.x** | Cross-platform UI framework (deployed as Flutter Web) |
| **Dart 3.10** | Programming language |
| **Firebase Auth** | Email/password authentication |
| **Cloud Firestore** | Real-time NoSQL database |
| **Riverpod** | Reactive state management |
| **GoRouter** | Declarative navigation & route guards |
| **fl_chart** | Sales analytics bar/line charts |
| **intl** | Date formatting & localization |
| **shared_preferences** | Persist local demo/mock state |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.10.1`
- [Node.js](https://nodejs.org/) (for Firebase CLI)
- A [Firebase](https://console.firebase.google.com/) account

### 1. Clone the repository
```bash
git clone https://github.com/your-username/boss_food_corner.git
cd boss_food_corner
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run in Demo Mode (no Firebase required)
The app ships with a full in-memory mock backend. Simply run:
```bash
flutter run -d chrome
```
A **"Demo Mode"** banner will appear. All features work with simulated data.

---

## 🔥 Firebase Setup (Production Mode)

### Step 1 — Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/) → **Add Project**.
2. Enable **Cloud Firestore** and **Email/Password Authentication**.

### Step 2 — Firestore Security Rules
In the Firestore **Rules** tab, paste and publish the following:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuth() { return request.auth != null; }
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    function hasRole(role) { return isAuth() && getUserData().role == role; }
    function isManager() { return hasRole('manager'); }

    match /users/{userId} {
      allow create: if true;
      allow read: if isAuth() || (resource.data.role == 'manager');
      allow update, delete: if isAuth() && (request.auth.uid == userId || isManager());
    }
    match /categories/{id}       { allow read: if isAuth(); allow write: if isManager(); }
    match /menu_items/{id}       { allow read: if isAuth(); allow write: if isManager(); }
    match /deals/{id}            { allow read: if isAuth(); allow write: if isManager(); }
    match /discounts/{id}        { allow read: if isAuth(); allow write: if isManager(); }
    match /restaurant_settings/{id} { allow read: if isAuth(); allow write: if isManager(); }
    match /waiters/{id}          { allow read: if isAuth(); allow write: if isManager(); }
    match /riders/{id}           { allow read: if isAuth(); allow write: if isManager(); }
    match /orders/{orderId}      { allow read: if isAuth(); allow create, update: if isAuth(); allow delete: if isManager(); }
    match /activity_logs/{logId} { allow read: if isAuth(); allow create: if isAuth(); allow update, delete: if isManager(); }
    match /counters/{id}         { allow read, write: if isAuth(); }
    match /daily_closings/{date} { allow read: if isAuth(); allow create, update: if isAuth(); allow delete: if isManager(); }
  }
}
```

### Step 3 — Connect Flutter to Firebase
Install the FlutterFire CLI and link your project:
```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```
Select your project and the **web** platform. This auto-generates `lib/firebase_options.dart`.

### Step 4 — Run in Production Mode
```bash
flutter run -d chrome
```
On first launch with an empty Firestore, the app redirects to the **Manager Registration** screen. Create your manager account to begin.

### Step 5 — Build for Deployment
```bash
flutter build web --release
```
Output is in `build/web/`. Deploy to any static host (Firebase Hosting, Vercel, Netlify, etc.).

---

## 👤 Role-Based Access

| Role | Access |
|---|---|
| **Manager** | Full access — menu, employees, reports, settings, daily closing release |
| **Cashier** | Order placement, payment, search, my orders, reports (optional password), daily closing |
| **Expediter** | Kitchen queue only — view incoming orders, update prep status, mark ready |

---

## 📁 Collections (Firestore)

| Collection | Description |
|---|---|
| `users` | Staff accounts with roles |
| `categories` | Menu categories |
| `menu_items` | Individual food/drink items |
| `deals` | Combo deal bundles |
| `discounts` | Discount configurations |
| `restaurant_settings` | Global POS settings (tax rate, delivery charges, report password, etc.) |
| `riders` | Delivery riders |
| `waiters` | Dine-in waiters |
| `orders` | All orders with full history & status |
| `activity_logs` | Audit trail of every order status change |
| `counters` | Auto-incrementing human-readable order ID counter |
| `daily_closings` | Daily financial closing records (keyed by logical date `YYYY-MM-DD`) |

---

## 🔐 Daily Closing Logic
- The **logical business day** resets at **5:00 AM daily**.
- Cashiers submit end-of-day totals for Cash, Online Banking, and Card payments.
- Once submitted, the closing **locks** — cashier sees "View Closing" instead of "Add Daily Closing".
- The manager can **release** any submitted closing from the POS Settings tab, allowing the cashier to edit and resubmit.

---

## 📄 License

This project is proprietary software developed for **Boss Food Corner**, Okara.  
POS system developed by **Voryent Solution** — 0329 7600120.

---

> Built with ❤️ using Flutter & Firebase
