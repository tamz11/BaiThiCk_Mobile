import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationRepository {
  AppNotificationRepository._();

  static final AppNotificationRepository instance =
      AppNotificationRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid) {
    return _firestore
        .collection('notification_history')
        .doc(uid)
        .collection('messages');
  }

  Future<void> createForUser({
    required String uid,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? extra,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final notificationId = '${uid}_$nowMs';

    final data = <String, dynamic>{
      'id': notificationId,
      'uid': uid,
      'title': title,
      'message': message,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': nowMs,
    };

    if (extra != null && extra.isNotEmpty) {
      data['extra'] = extra;
    }

    await _messagesRef(
      uid,
    ).doc(notificationId).set(data, SetOptions(merge: true));
  }
}
