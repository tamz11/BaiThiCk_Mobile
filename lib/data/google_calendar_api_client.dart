import 'dart:convert';

import 'package:http/http.dart' as http;

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
    throw Exception('[$context] ${response.statusCode}: ${response.body}');
  }
}
