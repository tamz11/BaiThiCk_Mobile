# Huong Dan Cau Hinh Dich Vu Thu 3 (Firebase + FlutterFire)

Tai lieu nay giup thanh vien moi co the setup nhanh de chay app.

Noi dung gom:
- Dang nhap Firebase
- Cau hinh FlutterFire
- Bat Email/Password Auth
- Bat Google Auth
- Setup Google Calendar tren Google Cloud
- Cau hinh domain OAuth/Firebase cho web
- Bien moi truong cho mode client-only va mode server-side
- Tao Firestore
- Tao Realtime Database
- Cap nhat URL Realtime Database trong code
- Chay app va checklist kiem tra

---

## 1) Cai dat cong cu can thiet

Kiem tra phien ban:

```bash
flutter --version
dart --version
firebase --version
```

Neu chua co Firebase CLI:

```bash
npm install -g firebase-tools
```

Cai FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

---

## 2) Chuan bi project

Tu thu muc goc cua project:

```bash
flutter pub get
```

---

## 3) Dang nhap Firebase

```bash
firebase login
```

---

## 4) Cau hinh FlutterFire cho app

Chay lenh trong thu muc goc:

```bash
flutterfire configure
```

Khuyen nghi:
- Dung mot Firebase project cho tat ca nen tang (android, ios, macos, web).
- Khong tron file cau hinh giua nhieu project khac nhau.

---

## 5) Kiem tra khoi tao Firebase trong app

Dam bao app khoi tao Firebase voi options da generate:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

---

## 6) Setup Firebase Authentication

Vao Firebase Console -> Authentication -> Sign-in method.

### 6.1 Email/Password (bat buoc)
Bat:
- Email/Password

App hien tai dang dang ky/dang nhap bang Email/Password.

### 6.2 Google Sign-In (khuyen nghi)
Bat:
- Google

Neu su dung Google Sign-In tren Android/iOS, can cau hinh them SHA va bundle settings theo huong dan Firebase.

### 6.3 Authorized domains cho web
Vao Firebase Console -> Authentication -> Settings -> Authorized domains.

Them cac domain:
- localhost
- 127.0.0.1
- `<your-project-id>.firebaseapp.com`
- `<your-project-id>.web.app`

Neu thieu domain, popup Google co the mo duoc nhung callback auth se loi.

---

## 7) Setup Cloud Firestore

Vao Firebase Console -> Firestore Database -> Create database.

De chay local nhanh:
- Chon Test mode
- Chon region gan nhat (vi du Singapore)

### 7.1 Du lieu toi thieu
Tao collection:
- diseases

Moi document co field:
- name (string)
- description (string)

Vi du:

```json
{
  "name": "Tang huyet ap",
  "description": "Can theo doi huyet ap thuong xuyen, giam muoi, han che chat kich thich va tai kham dinh ky."
}
```

```json
{
  "name": "Dai thao duong type 2",
  "description": "Kiem soat duong huyet bang che do an, van dong, thuoc theo don va theo doi bien chung."
}
```

```json
{
  "name": "Viem xoang",
  "description": "Gay nghet mui, dau dau, chay mui. Nen giu am co the, ve sinh mui va kham chuyen khoa khi tai phat."
}
```

---

## 8) Setup Realtime Database (du lieu bac si)

Vao Firebase Console -> Realtime Database -> Create database.

Luu y:
- App nay doc danh sach bac si tu Realtime Database, khong phai Firestore.

### 8.1 Them du lieu bac si
Import JSON vao root cua Realtime Database.

Field bac si can co:
- name
- type
- email
- phone
- address
- specification
- openHour
- closeHour
- rating
- image

Tao file `doctor.json` voi noi dung mau:

```json
{
  "doctor_001": {
    "name": "BS. Nguyen Van Minh",
    "type": "Cardiologist",
    "email": "minh.timmach@doctor.vn",
    "phone": "0903123456",
    "address": "Benh vien Tim Ha Noi, 89 Tran Hung Dao, Hoan Kiem, Ha Noi",
    "specification": "Chuyen khoa tim mach, tang huyet ap, roi loan nhip tim, theo doi benh tim man tinh.",
    "openHour": "08:00",
    "closeHour": "16:30",
    "rating": 5,
    "image": ""
  },
  "doctor_002": {
    "name": "BS. Tran Thi Lan",
    "type": "Dentist",
    "email": "lan.nhakhoa@doctor.vn",
    "phone": "0911222333",
    "address": "Nha khoa Sai Gon Smile, 120 Nguyen Thi Minh Khai, Quan 3, TP HCM",
    "specification": "Kham rang tong quat, dieu tri sau rang, nho rang khon, tham my rang su.",
    "openHour": "09:00",
    "closeHour": "19:00",
    "rating": 4,
    "image": ""
  },
  "doctor_003": {
    "name": "BS. Le Quoc Anh",
    "type": "Eye Special",
    "email": "anh.mat@doctor.vn",
    "phone": "0939888777",
    "address": "Benh vien Mat Trung Uong, 85 Ba Trieu, Hai Ba Trung, Ha Noi",
    "specification": "Dieu tri can thi, viem ket mac, theo doi glaucoma va benh ly day mat.",
    "openHour": "07:30",
    "closeHour": "16:00",
    "rating": 5,
    "image": ""
  },
  "doctor_004": {
    "name": "BS. Pham Duc Khoa",
    "type": "Orthopaedic",
    "email": "khoa.coxuongkhop@doctor.vn",
    "phone": "0977555666",
    "address": "Trung tam Chan thuong Chinh hinh, 201B Nguyen Chi Thanh, Dong Da, Ha Noi",
    "specification": "Chan thuong the thao, dau cot song, thoai hoa khop, phuc hoi chuc nang van dong.",
    "openHour": "08:30",
    "closeHour": "17:00",
    "rating": 4,
    "image": ""
  },
  "doctor_005": {
    "name": "BS. Vo Thi Huong",
    "type": "Paediatrician",
    "email": "huong.nhi@doctor.vn",
    "phone": "0909777888",
    "address": "Benh vien Nhi Dong 2, 14 Ly Tu Trong, Quan 1, TP HCM",
    "specification": "Theo doi tang truong, tiem chung, benh ho hap va tieu hoa o tre em.",
    "openHour": "08:00",
    "closeHour": "17:30",
    "rating": 5,
    "image": ""
  }
}
```

Sau do import file nay vao Realtime Database.

---

## 9) Cap nhat URL Realtime Database trong code

Mo file:
- lib/data/realtime_doctors_repository.dart

Cap nhat bien sau theo project cua ban:

```dart
static const String _databaseUrl = 'https://<your-project-id>-default-rtdb.firebaseio.com';
```

Vi du (project id `cccc-7a7d6`):

```dart
static const String _databaseUrl = 'https://cccc-7a7d6-default-rtdb.firebaseio.com';
```

Neu URL nay khac project voi `firebase_options.dart`, danh sach bac si co the khong hien thi.

---

## 10) Chay app

```bash
flutter pub get
flutter run
```

---

## 11) Checklist kiem tra nhanh

Sau khi app chay, kiem tra:

1. Dang ky bang Email/Password thanh cong.
2. Dang nhap thanh cong.
3. Danh sach bac si hien thi (Realtime Database da ket noi).
4. Trang chi tiet bac si hien thi dung thong tin.
5. Dat lich tao du lieu appointment.
6. My Appointments hien thi danh sach pending.
7. Cap nhat profile luu vao collection users.
8. Man hinh Disease doc du lieu tu collection diseases.
9. Dang nhap Google mo popup thanh cong.
10. Settings co the lien ket Google Calendar va hien "Da lien ket voi Calendar".
11. Dat/huy lich hen cap nhat event tren Google Calendar.

---

## 12) Setup Google Calendar service (web first)

Phan nay mo ta mode hien tai cua project: **client-only** (khong can Firebase Blaze).

### 12.1 Google Cloud: bat API va OAuth
Vao Google Cloud Console, chon dung project dang dung cho Firebase.

1. APIs & Services -> Library -> bat:
- Google Calendar API

2. APIs & Services -> OAuth consent screen:
- Chon External (neu app cho user ben ngoai) hoac Internal (neu Workspace noi bo).
- Dien app name, support email, developer contact.
- Them scope:
  - `https://www.googleapis.com/auth/calendar.events`
- Neu dang o trang thai Testing, them email vao Test users.

3. APIs & Services -> Credentials -> Create OAuth Client ID:
- Application type: Web application
- Authorized JavaScript origins (vi du):
  - `http://localhost:3000`
  - `http://127.0.0.1:3000`
  - `https://<your-project-id>.web.app`
  - `https://<your-project-id>.firebaseapp.com`
- Authorized redirect URIs:
  - `https://<your-project-id>.firebaseapp.com/__/auth/handler`

Luu y: app Flutter web dang auth qua Firebase popup, nen domain va redirect URI phai khop.

### 12.2 Bien moi truong (mode hien tai client-only)
Mode hien tai **khong dung exchange token tren Cloud Functions**, vi vay:
- Khong can `GCAL_CLIENT_ID`
- Khong can `GCAL_CLIENT_SECRET`
- Khong can `CALENDAR_TOKEN_SECRET`

App se dung access token tu Google popup credential o phia client de goi Google Calendar REST API.

### 12.3 Neu muon quay lai mode server-side (tuy chon)
Neu doi sang mode server-side (Cloud Functions doi auth code -> refresh token):

1. Project Firebase phai o goi Blaze.
2. Set secrets cho Functions:

```bash
firebase functions:secrets:set GCAL_CLIENT_ID
firebase functions:secrets:set GCAL_CLIENT_SECRET
firebase functions:secrets:set CALENDAR_TOKEN_SECRET
```

3. Deploy lai Functions.

Khuyen nghi: khong hardcode secret trong source code, khong commit secret vao git.

### 12.4 Kiem tra sau khi setup Calendar
1. Dang xuat va dang nhap lai bang Google.
2. Vao Settings -> bam "Lien ket voi Google Calendar".
3. Xac nhan trang thai doi sang "Da lien ket voi Calendar".
4. Tao lich hen moi, kiem tra event xuat hien trong Google Calendar.

### 12.5 Loi thuong gap
- `403 insufficient authentication scopes`:
  - Nguyen nhan: token khong co scope calendar.events.
  - Cach xu ly: dang xuat, dang nhap lai, popup consent lai scope; dam bao OAuth consent screen da them scope.
- Popup khong mo:
  - Trinh duyet chan popup, hoac domain chua co trong Authorized domains.