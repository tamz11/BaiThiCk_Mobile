import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showNow({
    required String title,
    required String body,
    String? appointmentId,
  }) async {
    await init();
    final id = appointmentId == null
        ? DateTime.now().millisecondsSinceEpoch.remainder(100000)
        : _notificationIdFor(appointmentId, salt: 7);

    await _plugin.show(id, title, body, _details());
  }

  Future<void> scheduleReminder30MinBefore({
    required String appointmentId,
    required String doctorName,
    required DateTime appointmentTime,
  }) async {
    await init();

    final now = DateTime.now();
    final reminderAt = appointmentTime.subtract(const Duration(minutes: 30));
    if (appointmentTime.isBefore(now)) {
      return;
    }

    final reminderId = _notificationIdFor(appointmentId, salt: 13);
    await _plugin.cancel(reminderId);

    if (!reminderAt.isAfter(now)) {
      await showNow(
        title: 'Sắp đến lịch khám',
        body:
            'Lịch với $doctorName sẽ bắt đầu lúc ${_formatHm(appointmentTime)}.',
        appointmentId: appointmentId,
      );
      return;
    }

    await _plugin.zonedSchedule(
      reminderId,
      'Sắp đến lịch khám',
      'Còn 30 phút nữa bạn có lịch khám với $doctorName.',
      tz.TZDateTime.from(reminderAt, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
      payload: appointmentId,
    );
  }

  Future<void> cancelReminder({required String appointmentId}) async {
    await init();
    await _plugin.cancel(_notificationIdFor(appointmentId, salt: 13));
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'appointment_channel',
      'Appointment Notifications',
      channelDescription: 'Thông báo lịch khám và nhắc lịch',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }

  int _notificationIdFor(String raw, {int salt = 0}) {
    final value = raw.trim();
    final hash = Object.hash(value, salt);
    return hash.abs() % 2147483646;
  }

  String _formatHm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
