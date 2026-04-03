import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_calendar_api_client.dart';

class GoogleCalendarSyncRepository {
  GoogleCalendarSyncRepository._();

  static final GoogleCalendarSyncRepository instance =
      GoogleCalendarSyncRepository._();

  static const List<String> calendarScopes = <String>[
    'https://www.googleapis.com/auth/calendar.events',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: calendarScopes);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleCalendarApiClient _calendarApi = GoogleCalendarApiClient.instance;

  String? _cachedAccessToken;

  Stream<Map<String, dynamic>?> watchCurrentUserCalendarStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<Map<String, dynamic>?>.value(null);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data());
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = _buildWebGoogleProvider();
      final userCredential = await _auth.signInWithPopup(provider);
      _cacheAccessTokenFromCredential(userCredential);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'googleEmail': userCredential.user?.email,
        'calendarId': 'primary',
        'googleLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return userCredential;
    }

    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw _mapGoogleSignInPlatformException(e);
    }
    if (account == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'Bạn đã hủy đăng nhập Google.',
      );
    }

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
      _cachedAccessToken = auth.accessToken;
    }

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'googleEmail': account.email,
      'calendarId': 'primary',
      'googleLinkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return userCredential;
  }

  Future<UserCredential> signInWithGoogleAndEnableCalendar() async {
    final userCredential = await signInWithGoogle();

    if (kIsWeb) {
      try {
        await _enableCalendarForUser(
          uid: userCredential.user!.uid,
          email: userCredential.user?.email ?? '',
          accessToken:
              _extractAccessToken(userCredential) ?? _cachedAccessToken,
        );
      } catch (_) {
        // Auto-link should not block successful login.
      }
      return userCredential;
    }

    try {
      final account = await _resolveGoogleAccountForCalendar(
        interactive: false,
      );
      if (account == null) {
        await _markCalendarLinkFailed(
          uid: userCredential.user!.uid,
          reason: 'missing-google-account-for-calendar',
        );
        return userCredential;
      }

      final auth = await account.authentication;
      await _enableCalendarForUser(
        uid: userCredential.user!.uid,
        email: account.email,
        accessToken: auth.accessToken,
      );
    } catch (_) {
      // Auto-link should not block successful login.
    }

    return userCredential;
  }

  Future<void> linkGoogleToCurrentUserForCalendar() async {
    var currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Vui lòng đăng nhập trước khi liên kết Google.',
      );
    }

    if (kIsWeb) {
      final provider = _buildWebGoogleProvider();
      final hasGoogleLinked = currentUser.providerData.any(
        (p) => p.providerId == 'google.com',
      );

      UserCredential credentialResult;
      if (!hasGoogleLinked) {
        try {
          credentialResult = await currentUser.linkWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use') {
            rethrow;
          }
          final switched = await _signInWithGoogleProviderForConflict(
            provider: provider,
          );
          final switchedUser = switched.user;
          if (switchedUser == null) {
            throw FirebaseAuthException(
              code: 'account-switch-failed',
              message:
                  'Không thể chuyển sang tài khoản Google đang liên kết. Vui lòng thử lại.',
            );
          }
          currentUser = switchedUser;
          credentialResult = switched;
        }
      } else {
        credentialResult = await currentUser.reauthenticateWithPopup(provider);
      }

      _cacheAccessTokenFromCredential(credentialResult);
      final token = _extractAccessToken(credentialResult) ?? _cachedAccessToken;
      await _enableCalendarForUser(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        accessToken: token,
      );
      return;
    }

    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw _mapGoogleSignInPlatformException(e);
    }
    if (account == null) {
      throw FirebaseAuthException(
        code: 'google-link-cancelled',
        message: 'Bạn đã hủy liên kết Google.',
      );
    }

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final hasGoogleLinked = currentUser.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (!hasGoogleLinked) {
      try {
        await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          final switched = await _signInWithCredentialForConflict(credential);
          final switchedUser = switched.user;
          if (switchedUser == null) {
            throw FirebaseAuthException(
              code: 'account-switch-failed',
              message:
                  'Không thể chuyển sang tài khoản Google đang liên kết. Vui lòng thử lại.',
            );
          }
          currentUser = switchedUser;
        } else {
          rethrow;
        }
      }
    }

    if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
      _cachedAccessToken = auth.accessToken;
    }
    await _enableCalendarForUser(
      uid: currentUser.uid,
      email: account.email,
      accessToken: auth.accessToken,
    );
  }

  Future<bool> isCalendarLinkedForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    return data?['calendarSyncEnabled'] == true &&
        data?['calendarTokenStatus'] == 'ready';
  }

  Future<String> getCalendarIdForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return 'primary';
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final value = doc.data()?['calendarId']?.toString().trim() ?? '';
    if (value.isEmpty) return 'primary';
    return value;
  }

  Future<String?> getCalendarAccessToken({bool interactive = false}) async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }

    if (kIsWeb) {
      if (!interactive) return null;
      final user = _auth.currentUser;
      if (user == null) return null;
      final provider = _buildWebGoogleProvider();
      final credential = await user.reauthenticateWithPopup(provider);
      _cacheAccessTokenFromCredential(credential);
      return _extractAccessToken(credential) ?? _cachedAccessToken;
    }

    final account = await _resolveGoogleAccountForCalendar(
      interactive: interactive,
    );
    if (account == null) return null;
    final auth = await account.authentication;
    if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
      _cachedAccessToken = auth.accessToken;
    }
    return auth.accessToken;
  }

  Future<void> _enableCalendarForUser({
    required String uid,
    required String email,
    required String? accessToken,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'googleEmail': email,
      'calendarId': 'primary',
      'calendarSyncEnabled': false,
      'calendarSyncError': null,
      'calendarLinkedAt': FieldValue.serverTimestamp(),
      'calendarTokenStatus': 'exchanging',
    }, SetOptions(merge: true));

    final normalizedToken = accessToken?.trim() ?? '';
    if (normalizedToken.isEmpty) {
      await _markCalendarLinkFailed(uid: uid, reason: 'missing-access-token');
      throw Exception(
        'Không lấy được access token từ Google. Vui lòng liên kết lại.',
      );
    }

    try {
      await _calendarApi.validateAccess(accessToken: normalizedToken);
      _cachedAccessToken = normalizedToken;
      await _firestore.collection('users').doc(uid).set({
        'calendarSyncEnabled': true,
        'calendarSyncError': null,
        'calendarTokenStatus': 'ready',
        'calendarId': 'primary',
        'calendarLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      await _markCalendarLinkFailed(uid: uid, reason: error.toString());
      rethrow;
    }
  }

  Future<void> _markCalendarLinkFailed({
    required String uid,
    required String reason,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'calendarSyncEnabled': false,
      'calendarSyncError': reason,
      'calendarTokenStatus': 'failed',
    }, SetOptions(merge: true));
  }

  Future<GoogleSignInAccount?> _resolveGoogleAccountForCalendar({
    required bool interactive,
  }) async {
    final current = _googleSignIn.currentUser;
    if (current != null) {
      return current;
    }

    final silent = await _googleSignIn.signInSilently();
    if (silent != null) {
      return silent;
    }

    if (!interactive) {
      return null;
    }

    try {
      return _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw _mapGoogleSignInPlatformException(e);
    }
  }

  FirebaseAuthException _mapGoogleSignInPlatformException(
    PlatformException e,
  ) {
    final raw = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
    final isApi10 = raw.contains('sign_in_failed') && raw.contains('api: 10');
    if (isApi10) {
      return FirebaseAuthException(
        code: 'google-sign-in-config-error',
        message:
            'Google Sign-In Android chưa cấu hình đúng (ApiException 10). '
            'Hãy thêm SHA-1/SHA-256 của debug keystore vào Firebase Android app '
            '(package com.example.baithick), sau đó tải lại google-services.json.',
      );
    }

    if (raw.contains('network_error')) {
      return FirebaseAuthException(
        code: 'network-error',
        message: 'Lỗi mạng khi đăng nhập Google. Vui lòng kiểm tra kết nối.',
      );
    }

    return FirebaseAuthException(
      code: 'google-sign-in-failed',
      message: 'Không thể đăng nhập Google. ${e.message ?? ''}'.trim(),
    );
  }

  Future<UserCredential> _signInWithCredentialForConflict(
    AuthCredential credential,
  ) async {
    await _auth.signOut();
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> _signInWithGoogleProviderForConflict({
    required GoogleAuthProvider provider,
  }) async {
    await _auth.signOut();
    final result = await _auth.signInWithPopup(provider);
    _cacheAccessTokenFromCredential(result);
    return result;
  }

  String? _extractAccessToken(UserCredential userCredential) {
    final credential = userCredential.credential;
    if (credential is OAuthCredential) {
      final token = credential.accessToken?.trim();
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  void _cacheAccessTokenFromCredential(UserCredential userCredential) {
    final token = _extractAccessToken(userCredential);
    if (token != null && token.isNotEmpty) {
      _cachedAccessToken = token;
    }
  }

  GoogleAuthProvider _buildWebGoogleProvider() {
    final provider = GoogleAuthProvider()..addScope(calendarScopes.first);
    provider.setCustomParameters(<String, String>{
      'prompt': 'consent',
      'include_granted_scopes': 'true',
    });
    return provider;
  }
}
