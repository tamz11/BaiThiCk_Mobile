# Ung dung dat lich kham benh (Flutter)

Ung dung duoc tach theo huong MVVM nhe voi Provider:

- models
- services (Firebase)
- providers (state + loading + error)
- screens
- widgets
- utils

## Tinh nang

- Dang nhap bang Google Sign-In
- Luu thong tin user vao Firestore
- Hien thi danh sach bac si tu Firestore
- Xem chi tiet bac si
- Dat lich kham vao collection appointments
- Xem danh sach lich da dat theo userId
- Huy lich kham
- Hien thi Google Maps marker cac chi nhanh

## Cau truc thu muc

```text
lib/
├── main.dart
├── models/
│   ├── user_model.dart
│   ├── doctor_model.dart
│   ├── appointment_model.dart
│   └── clinic_model.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── map_service.dart
├── providers/
│   ├── auth_provider.dart
│   └── appointment_provider.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── doctor_list_screen.dart
│   ├── doctor_detail_screen.dart
│   ├── booking_screen.dart
│   ├── appointment_screen.dart
│   ├── map_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── doctor_card.dart
│   ├── appointment_card.dart
│   └── custom_button.dart
└── utils/
	├── constants.dart
	└── helpers.dart
```

## Firestore structure

- users: uid, name, email, role
- doctors: id, name, specialty
- appointments: id, userId, doctorId, date, time, status
- clinics: id, name, address, latitude, longitude

## Cai dat

1. Cai package:

```bash
flutter pub get
```

2. Cau hinh Firebase va FlutterFire:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

3. Bat Google Sign-In trong Firebase Authentication.

4. Tao Firestore va import du lieu ban dau cho collections `doctors`, `clinics`.

5. Cau hinh Google Maps API Key:
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/AppDelegate.swift` hoac `Info.plist`

6. Chay app:

```bash
flutter run
```
