# FINCALC PRO — Deployment Guide

## Table of Contents
1. [Firebase Setup](#firebase-setup)
2. [MongoDB Atlas Setup](#mongodb-atlas-setup)
3. [Backend Deployment](#backend-deployment)
4. [Flutter App Setup](#flutter-app-setup)
5. [Play Store Publishing](#play-store-publishing)
6. [App Store Publishing](#app-store-publishing)
7. [Admin Panel Deployment](#admin-panel-deployment)
8. [CI/CD Setup](#cicd-setup)

---

## 1. Firebase Setup

### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project" → Name it "FinCalc Pro"
3. Enable Google Analytics
4. Select your Analytics account

### Add Android App
1. Click "Add App" → Android
2. Package name: `com.fincalcpro.fincalc_pro`
3. App nickname: "FinCalc Pro"
4. Download `google-services.json`
5. Place in `fincalc_pro/android/app/google-services.json`

### Add iOS App
1. Click "Add App" → iOS
2. Bundle ID: `com.fincalcpro.fincalcPro`
3. Download `GoogleService-Info.plist`
4. Place in `fincalc_pro/ios/Runner/GoogleService-Info.plist`

### Enable Authentication
1. Go to Authentication → Sign-in method
2. Enable: Email/Password, Google, Phone
3. Add authorized domains

### Enable Cloud Firestore
1. Go to Firestore Database → Create Database
2. Start in production mode
3. Select nearest region (asia-south1 for India)

### Enable Cloud Messaging
1. Go to Cloud Messaging
2. Note the Server Key for backend
3. Generate Web Push Certificate for admin panel

### Firebase Admin SDK (Backend)
1. Go to Project Settings → Service Accounts
2. Generate new private key
3. Save as `firebase-service-account.json` in backend root
4. Add to `.env`: `FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json`

---

## 2. MongoDB Atlas Setup

### Create Cluster
1. Go to [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Create account / Sign in
3. Create new cluster (M0 free tier for development)
4. Select cloud provider: AWS
5. Select region: Mumbai (ap-south-1)
6. Cluster name: `fincalc-pro`

### Configure Access
1. Database Access → Add Database User
   - Username: `fincalc_admin`
   - Password: Generate secure password
   - Privileges: Atlas Admin
2. Network Access → Add IP Address
   - For development: `0.0.0.0/0` (Allow from anywhere)
   - For production: Add specific server IPs

### Get Connection String
1. Click "Connect" on your cluster
2. Choose "Connect your application"
3. Driver: Node.js, Version: 5.5+
4. Copy connection string
5. Replace `<password>` and `<dbname>` → `fincalc_pro`

### Create Indexes
After seeding, create indexes via Atlas UI or `mongosh`:
```javascript
// Users
db.users.createIndex({ email: 1 }, { unique: true, sparse: true });
db.users.createIndex({ firebaseUid: 1 }, { unique: true });

// Banks
db.banks.createIndex({ shortName: 1 }, { unique: true });
db.banks.createIndex({ isActive: 1 });

// FD Rates
db.fdrates.createIndex({ bankId: 1, isActive: 1 });
db.fdrates.createIndex({ generalRate: -1 });
db.fdrates.createIndex({ seniorCitizenRate: -1 });

// Calculations
db.calculations.createIndex({ userId: 1, createdAt: -1 });

// Comparisons
db.comparisons.createIndex({ userId: 1, createdAt: -1 });

// Notifications
db.notifications.createIndex({ userId: 1, isRead: 1, createdAt: -1 });
```

---

## 3. Backend Deployment

### Option A: Docker (Recommended)
```bash
cd fincalc_pro_backend

# Build and run
docker-compose up -d --build

# Seed database
docker exec -it fincalc-api npm run seed

# View logs
docker-compose logs -f
```

### Option B: Manual
```bash
cd fincalc_pro_backend

# Install dependencies
npm install

# Copy and configure environment
cp .env.example .env
# Edit .env with your MongoDB URI, JWT secrets, etc.

# Seed database
npm run seed

# Start development server
npm run dev

# Start production server
npm start
```

### Option C: Cloud Deployment (Railway/Render/AWS)

#### Railway
1. Connect GitHub repo
2. Set environment variables
3. Deploy automatically
4. Custom domain: `api.fincalcpro.com`

#### AWS (Production)
1. Create EC2 instance (t3.medium recommended)
2. Install Node.js 18+, Docker
3. Clone repo, configure `.env`
4. Use PM2 for process management:
```bash
npm install -g pm2
pm2 start src/server.js --name fincalc-api
pm2 startup
pm2 save
```
5. Setup Nginx reverse proxy:
```nginx
server {
    listen 80;
    server_name api.fincalcpro.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```
6. Setup SSL with Certbot

---

## 4. Flutter App Setup

### Prerequisites
```bash
flutter --version  # Requires 3.16+
dart --version     # Requires 3.2+
```

### Install Dependencies
```bash
cd fincalc_pro
flutter pub get
```

### Configure Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure --project=your-project-id
```

### Configure AdMob
1. Create [AdMob](https://admob.google.com/) account
2. Create Android/iOS apps
3. Create ad units (banner, interstitial, rewarded)
4. Update ad unit IDs in `lib/config/constants/app_constants.dart`
5. Update `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-YOUR_APP_ID"/>
```

### Build & Run
```bash
# Debug
flutter run

# Release (Android)
flutter build appbundle --release

# Release (iOS)
flutter build ios --release
```

---

## 5. Play Store Publishing

### Generate Signing Key
```bash
keytool -genkey -v -keystore fincalc-pro-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fincalc-pro
```

### Configure Signing
Create `android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=fincalc-pro
storeFile=../fincalc-pro-keystore.jks
```

### Build App Bundle
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Play Console Setup
1. Go to [Google Play Console](https://play.google.com/console)
2. Create application → "FinCalc Pro"
3. Fill in:
   - **Title**: FinCalc Pro - Financial Calculator
   - **Short description**: Premium EMI, FD, SIP Calculator & Bank Rate Comparison
   - **Full description**: (See app_store_description.txt)
   - **Category**: Finance
   - **Content rating**: Complete questionnaire
   - **Target audience**: 18+ (financial app)
4. Upload screenshots (phone + tablet)
5. Upload feature graphic (1024×500)
6. Upload app icon (512×512)
7. Upload AAB file
8. Set pricing: Free (with in-app purchases)
9. Submit for review

### Required Assets
- App Icon: 512×512 PNG
- Feature Graphic: 1024×500 PNG
- Phone Screenshots: Min 2, 16:9 or 9:16
- Tablet Screenshots: Min 1 (optional but recommended)
- Privacy Policy URL: Host `privacy_policy.html`

---

## 6. App Store Publishing

### Prerequisites
- Apple Developer Account ($99/year)
- Mac with Xcode 15+
- Valid certificates and provisioning profiles

### Build IPA
```bash
flutter build ios --release
```

### App Store Connect
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Create new app → "FinCalc Pro"
3. Fill in all metadata
4. Upload using Xcode or Transporter
5. Submit for review

### App Review Tips
- Ensure all features work without backend (offline mode)
- Test all in-app purchases in sandbox
- Provide demo account credentials if needed
- Privacy Nutrition Labels must be accurate

---

## 7. Admin Panel Deployment

### Build for Web
```bash
cd fincalc_pro_admin
flutter build web --release
```

### Deploy to Firebase Hosting
```bash
firebase init hosting
# Select build/web as public directory
firebase deploy --only hosting
```

### Or Deploy to Vercel/Netlify
Upload `build/web/` directory.

---

## 8. CI/CD Setup

### GitHub Actions (Android)
Create `.github/workflows/android.yml`:
```yaml
name: Android Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter test
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v3
        with:
          name: app-release
          path: build/app/outputs/bundle/release/
```

### GitHub Actions (Backend)
Create `.github/workflows/backend.yml`:
```yaml
name: Backend CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - working-directory: fincalc_pro_backend
        run: |
          npm install
          npm test
```

---

## Environment Variables Checklist

### Backend (.env)
- [ ] `MONGODB_URI` — MongoDB Atlas connection string
- [ ] `JWT_SECRET` — Random 64-char string
- [ ] `JWT_REFRESH_SECRET` — Different random 64-char string
- [ ] `FIREBASE_SERVICE_ACCOUNT_PATH` — Path to service account JSON
- [ ] `ENCRYPTION_KEY` — 32-byte AES encryption key
- [ ] `PORT` — Server port (default 3000)

### Flutter (.env)
- [ ] `API_BASE_URL` — Backend API URL
- [ ] `FIREBASE_PROJECT_ID` — Firebase project ID
- [ ] AdMob App IDs and Ad Unit IDs
- [ ] Subscription Product IDs

---

## Production Checklist

- [ ] All environment variables configured
- [ ] Firebase project created and configured
- [ ] MongoDB Atlas cluster running with indexes
- [ ] Backend deployed and healthy
- [ ] Database seeded with 18 banks and rates
- [ ] SSL/HTTPS configured for API
- [ ] App signing key generated and secured
- [ ] AdMob production ad units created
- [ ] In-app purchase products created in Play Console / App Store Connect
- [ ] Privacy Policy hosted and accessible
- [ ] Terms & Conditions hosted and accessible
- [ ] App icons and screenshots prepared
- [ ] Crash reporting enabled (Firebase Crashlytics)
- [ ] Analytics tracking verified
- [ ] Push notifications tested
- [ ] All calculators verified for mathematical accuracy
- [ ] Both dark and light themes tested
- [ ] Offline mode tested
- [ ] Data export (PDF/CSV) tested
