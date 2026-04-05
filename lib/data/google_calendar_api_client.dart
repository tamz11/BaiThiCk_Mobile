import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleCalendarApiException implements Exception {
  GoogleCalendarApiException({
    required this.context,
    required this.statusCode,
    required this.rawBody,
    required this.userMessage,
  });

  final String context;
  final int statusCode;
  final String rawBody;
  final String userMessage;

  @override
  String toString() {
    return '[$context] $statusCode: $userMessage';
  }
}

class GoogleCalendarApiClient {
  GoogleCalendarApiClient._();

  static final GoogleCalendarApiClient instance = GoogleCalendarApiClient._();

  static const String _base = 'https://www.googleapis.com/calendar/v3';

  Future<void> validateAccess({required String accessToken}) async {
    final uri = Uri.parse(
      '$_base/calendars/primary/events?maxResults=1&singleEvents=true&orderBy=startTime',
    );
    final response = await http.get(uri, headers: _headers(accessToken));
    _throwIfNotSuccess(response, context: 'validate-access');
  }

  Future<String> createEvent({
    required String accessToken,
    required String calendarId,
    required Map<String, dynamic> event,
  }) async {
    final uri = Uri.parse(
      '$_base/calendars/${Uri.encodeComponent(calendarId)}/events',
    );
    final response = await http.post(
      uri,
      headers: _headers(accessToken),
      body: jsonEncode(event),
    );
    _throwIfNotSuccess(response, context: 'create-event');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final eventId = data['id']?.toString() ?? '';
    if (eventId.isEmpty) {
      throw Exception('Không nhận được event id từ Google Calendar.');
    }
    return eventId;
  }

  Future<void> updateEvent({
    required String accessToken,
    required String calendarId,
    required String eventId,
    required Map<String, dynamic> event,
  }) async {
    final uri = Uri.parse(
      '$_base/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(eventId)}',
    );
    final response = await http.patch(
      uri,
      headers: _headers(accessToken),
      body: jsonEncode(event),
    );
    _throwIfNotSuccess(response, context: 'update-event');
  }

  Future<void> deleteEvent({
    required String accessToken,
    required String calendarId,
    required String eventId,
  }) async {
    final uri = Uri.parse(
      '$_base/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(eventId)}',
    );
    final response = await http.delete(uri, headers: _headers(accessToken));
    if (response.statusCode == 404) {
      return;
    }
    _throwIfNotSuccess(response, context: 'delete-event');
  }

  Map<String, String> _headers(String token) => <String, String>{
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  void _throwIfNotSuccess(http.Response response, {required String context}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final userMessage = _buildUserMessage(
      statusCode: response.statusCode,
      responseBody: response.body,
    );

    throw GoogleCalendarApiException(
      context: context,
      statusCode: response.statusCode,
      rawBody: response.body,
      userMessage: userMessage,
    );
  }

  String _buildUserMessage({
    required int statusCode,
    required String responseBody,
  }) {
    final parsed = _extractErrorMeta(responseBody);
    final reason = parsed.reason.toLowerCase();
    final raw = responseBody.toLowerCase();
    final message = parsed.message;

    final serviceDisabled =
        reason == 'accessnotconfigured' ||
        reason == 'service_disabled' ||
        raw.contains('google calendar api has not been used') ||
        raw.contains('service_disabled');
    if (statusCode == 403 && serviceDisabled) {
      return 'Google Calendar API chưa được bật cho Firebase project. '
          'Vào Google Cloud Console -> APIs & Services -> Library -> bật "Google Calendar API", '
          'sau đó chờ 3-5 phút rồi liên kết lại.';
    }

    final missingScope =
        reason == 'insufficientpermissions' ||
        raw.contains('insufficient permission') ||
        raw.contains('insufficientpermissions');
    if (statusCode == 403 && missingScope) {
      return 'Tài khoản Google chưa cấp quyền Calendar. '
          'Vui lòng liên kết lại Google và chấp nhận quyền truy cập lịch.';
    }

    if (statusCode == 401) {
      return 'Phiên đăng nhập Google Calendar đã hết hạn. '
          'Vui lòng liên kết lại Google Calendar.';
    }

    if (message.isNotEmpty) {
      return message;
    }

    return 'Lỗi Google Calendar ($statusCode). Vui lòng thử lại.';
  }

  _CalendarErrorMeta _extractErrorMeta(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        return const _CalendarErrorMeta(message: '', reason: '');
      }

      final error = decoded['error'];
      if (error is! Map<String, dynamic>) {
        return const _CalendarErrorMeta(message: '', reason: '');
      }

      final message = error['message']?.toString().trim() ?? '';
      String reason = error['status']?.toString().trim() ?? '';

      final errors = error['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map<String, dynamic>) {
          final itemReason = first['reason']?.toString().trim() ?? '';
          if (itemReason.isNotEmpty) {
            reason = itemReason;
          }
        }
      }

      final details = error['details'];
      if (details is List) {
        for (final item in details) {
          if (item is! Map<String, dynamic>) continue;
          final itemReason = item['reason']?.toString().trim() ?? '';
          if (itemReason.isNotEmpty) {
            reason = itemReason;
            break;
          }
        }
      }

      return _CalendarErrorMeta(message: message, reason: reason);
    } catch (_) {
      return const _CalendarErrorMeta(message: '', reason: '');
    }
  }
}

class _CalendarErrorMeta {
  const _CalendarErrorMeta({required this.message, required this.reason});

  final String message;
  final String reason;
}
