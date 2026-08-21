# FINCALC PRO

A production-grade financial calculator application built with Flutter.

## Features

- 26+ Financial Calculators (EMI, FD, RD, SIP, PPF, Tax, and more)
- Bank Rate Comparison Engine (18+ Indian banks)
- Combined FD Tenure Input (Year + Month + Day)
- Variable/Step-up Deposit Support (Sukanya Samriddhi)
- Stock/Equity Investment Calculators (CAGR, Stock Returns, Dividend Yield)
- Comparison Dashboard (Top banks by duration)
- Real-time Rate Engine with admin approval workflow
- Cloud Sync across devices
- PDF/CSV Export
- Premium UI with Dark/Light themes
- Firebase Authentication (Google, Email, Phone, Guest)
- Google AdMob monetization
- Subscription management (Monthly/Yearly/Lifetime)

## Tech Stack

- **Frontend**: Flutter 3.x with BLoC pattern
- **Backend**: Node.js + Express.js
- **Database**: MongoDB Atlas
- **Auth**: Firebase Authentication
- **Analytics**: Firebase Analytics
- **Notifications**: Firebase Cloud Messaging
- **Charts**: fl_chart
- **State Management**: flutter_bloc

## Getting Started

### Prerequisites

- Flutter SDK 3.16+
- Dart SDK 3.2+
- Android Studio / Xcode
- Node.js 18+
- MongoDB Atlas account
- Firebase project

### Setup

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   cd fincalc_pro
   flutter pub get
   ```

3. Setup Firebase:
   - Create a Firebase project
   - Add Android/iOS apps
   - Download google-services.json (Android) and GoogleService-Info.plist (iOS)
   - Place in respective platform directories

4. Setup Backend:
   ```bash
   cd fincalc_pro_backend
   npm install
   cp .env.example .env
   # Edit .env with your MongoDB URI and other configs
   npm run seed
   npm run dev
   ```

5. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
fincalc_pro/           # Flutter mobile app
fincalc_pro_backend/   # Node.js backend API
fincalc_pro_admin/     # Admin panel (Flutter Web)
```

## License

Proprietary - All rights reserved.
