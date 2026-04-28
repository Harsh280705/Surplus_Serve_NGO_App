// ---------- lib/services/notification_service.dart ----------
import 'dart:async';
import 'dart:collection';
import 'dart:math' show cos, sqrt, asin;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import '../models/donation.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  try {
    final FlutterLocalNotificationsPlugin backgroundLocal = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await backgroundLocal.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'donation_channel',
      'Donation Notifications',
      description: 'Notifications for new food donations',
      importance: Importance.high,
    );

    const androidChatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Messages',
      description: 'Notifications for chat messages',
      importance: Importance.high,
    );

    await backgroundLocal
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await backgroundLocal
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChatChannel);

    final idValue = message.data['donationId'] ?? message.messageId ?? message.hashCode.toString();
    final notifId = idValue.hashCode;

    final channel = (message.data['type'] ?? '') == 'chat' ? 'chat_channel' : 'donation_channel';
    final channelName = channel == 'chat_channel' ? 'Chat Messages' : 'Donation Notifications';
    final channelDesc = channel == 'chat_channel' ? 'Incoming chat messages' : 'New donation alerts';

    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    final iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await backgroundLocal.show(
      notifId,
      message.notification?.title ?? (message.data['title'] ?? 'New notification'),
      message.notification?.body ?? (message.data['body'] ?? ''),
      details,
      payload: idValue.toString(),
    );
  } catch (e) {
    if (kDebugMode) print('❌ Background local notification failed: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final _donationStreamController = StreamController<Donation>.broadcast();
  Stream<Donation> get donationStream => _donationStreamController.stream;

  final _chatStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get chatStream => _chatStreamController.stream;

  // ====== ADDED: Notifications Stream ======
  final _notificationsStreamController = StreamController<QuerySnapshot>.broadcast();
  Stream<QuerySnapshot> get notificationsStream => _notificationsStreamController.stream;

  final _prefStreamController = StreamController<bool>.broadcast();
  Stream<bool> get prefStream => _prefStreamController.stream;

  StreamSubscription<QuerySnapshot>? _donationSubscription;
  // ====== ADDED: Notifications Subscription ======
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  final ListQueue<String> _processedDonationIds = ListQueue<String>();
  static const int _maxCacheSize = 100;

  String? _currentUserId;
  bool _notificationsEnabled = true;

  // ======================
  // 🚀 PUBLIC INITIALIZATION
  // ======================
  Future<void> initialize(AuthService authService) async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _requestPermissions();
    await _initializeLocalNotifications();
    await _configureFCM();

    _currentUserId = authService.currentUserId;

    if (_currentUserId != null) {
      await _loadNotificationPreference(_currentUserId!);
      if (_notificationsEnabled) {
        await _saveDeviceToken(authService);
        await _subscribeToUserTopic(_currentUserId!);
      }
      _startListeningToDonations(authService);
      // ====== ADDED ======
      _startListeningToNotifications();
    }

    _authSubscription = authService.authStateChanges.listen((user) async {
      if (user?.uid != _currentUserId) {
        _currentUserId = user?.uid;
        _processedDonationIds.clear();
        await _donationSubscription?.cancel();
        // ====== ADDED ======
        await _notificationsSubscription?.cancel();

        if (user != null) {
          await _loadNotificationPreference(_currentUserId!);
          if (_notificationsEnabled) {
            await _saveDeviceToken(authService);
            await _subscribeToUserTopic(_currentUserId!);
          } else {
            await _unsubscribeFromUserTopic(_currentUserId!);
          }

          _startListeningToDonations(authService);
          // ====== ADDED ======
          _startListeningToNotifications();
        }
      }
    });
  }

  // ======================
  // 🔧 PRIVATE SETUP METHODS
  // ======================
  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (kDebugMode) print('✅ Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      if (kDebugMode) print('❌ Error requesting permissions: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      const androidChannel = AndroidNotificationChannel(
        'donation_channel',
        'Donation Notifications',
        description: 'Notifications for new food donations',
        importance: Importance.high,
      );

      const androidChatChannel = AndroidNotificationChannel(
        'chat_channel',
        'Chat Messages',
        description: 'Notifications for chat messages',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChatChannel);
    } catch (e) {
      if (kDebugMode) print('❌ Error initializing local notifications: $e');
    }
  }

  Future<void> _configureFCM() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('📨 Foreground message received: ${message.messageId}, data: ${message.data}');

      final isChat = (message.data['type'] ?? '') == 'chat';
      if (isChat) _chatStreamController.add(message.data);

      if (_notificationsEnabled) _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) print('📬 Notification opened app (background)');
      _handleNotificationTap(message.data);
    });

    try {
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) print('📬 App launched via notification');
        _handleNotificationTap(initialMessage.data);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error checking initial message: $e');
    }

    _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((newToken) async {
      if (kDebugMode) print('🔁 Token refreshed: $newToken');
      if (_currentUserId != null && _notificationsEnabled) {
        await _db.collection('users').doc(_currentUserId).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> _saveDeviceToken(AuthService authService) async {
    final userId = authService.currentUserId;
    if (userId == null) return;

    if (!_notificationsEnabled) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _db.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });

        // ⭐ ADDED — subscribe all users to a global topic for broadcast notifications
        try {
          await _fcm.subscribeToTopic('all_users');
          if (kDebugMode) print('✅ Subscribed to global topic: all_users');
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to subscribe to all_users: $e');
        }

        if (kDebugMode) print('✅ FCM Token saved: $token');
      } else {
        if (kDebugMode) print('⚠️ FCM token was null');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error saving token: $e');
    }
  }

  void _addProcessedId(String id) {
    if (_processedDonationIds.contains(id)) return;
    if (_processedDonationIds.length >= _maxCacheSize) {
      _processedDonationIds.removeFirst();
    }
    _processedDonationIds.addLast(id);
  }

  bool _hasProcessedId(String id) => _processedDonationIds.contains(id);

  void _startListeningToDonations(AuthService authService) {
    final userId = authService.currentUserId;
    if (userId == null) return;

    _donationSubscription?.cancel();

    bool isFirstLoad = true;

    _donationSubscription = _db
        .collection('donations')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen(
      (snapshot) {
        for (var docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.added) {
            final donation = Donation.fromFirestore(docChange.doc);

            if (isFirstLoad) {
              _addProcessedId(donation.id);
              continue;
            }

            if (donation.createdBy == userId) continue;

            if (_hasProcessedId(donation.id)) continue;

            _addProcessedId(donation.id);

            _donationStreamController.add(donation);

            if (kDebugMode) print('🔔 New donation detected: ${donation.itemName}');
          }
        }
        isFirstLoad = false;
      },
      onError: (error) {
        if (kDebugMode) print('❌ Error in donation listener: $error');
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentUserId != null) _startListeningToDonations(authService);
        });
      },
    );
  }

  // ====== ADDED: Listen to user's notifications ======
  void _startListeningToNotifications() {
    final userId = _currentUserId;
    if (userId == null) return;

    _notificationsSubscription?.cancel();

    _notificationsSubscription = _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        _notificationsStreamController.add(snapshot);
        if (kDebugMode) print('🔔 Notifications updated. Count: ${snapshot.size}');
      },
      onError: (error) {
        if (kDebugMode) print('❌ Error in notifications listener: $error');
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentUserId != null) _startListeningToNotifications();
        });
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final idValue = message.data['donationId'] ?? message.messageId ?? message.hashCode.toString();
      final notifId = idValue.hashCode;

      final isChat = (message.data['type'] ?? '') == 'chat';
      final channel = isChat ? 'chat_channel' : 'donation_channel';

      final androidDetails = AndroidNotificationDetails(
        channel,
        isChat ? 'Chat Messages' : 'Donation Notifications',
        channelDescription: isChat ? 'Incoming chat messages' : 'New donation alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _localNotifications.show(
        notifId,
        message.notification?.title ??
            message.data['title'] ??
            (isChat ? 'New Message' : 'New Donation'),
        message.notification?.body ?? message.data['body'] ?? '',
        details,
        payload: idValue.toString(),
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error showing local notification: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      _handleNotificationTap({'donationId': response.payload!});
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) print('🔔 Notification tapped with data: $data');
  }

  // ======================
  // 📨 NEW: Donation Confirmed Notification
  // ======================
  Future<void> notifyDonationConfirmed({
    required String ngoId,
    required String donationId,
    required String donationName,
  }) async {
    try {
      // Create in-app notification
      await _db.collection('notifications').add({
        'userId': ngoId,
        'type': 'donation_confirmed',
        'title': 'Donation Confirmed! 🎉',
        'body': 'The donation "$donationName" has been confirmed as delivered by the event manager.',
        'donationId': donationId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Get NGO's FCM token
      final ngoDoc = await _db.collection('users').doc(ngoId).get();
      final fcmToken = ngoDoc.data()?['fcmToken'] as String?;

      // Send push if token exists
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendPushNotification(
          token: fcmToken,
          title: 'Donation Confirmed! 🎉',
          body: 'The donation "$donationName" has been confirmed as delivered.',
          data: {
            'type': 'donation_confirmed',
            'donationId': donationId,
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sending confirmation notification: $e');
    }
  }

  // Helper to queue push via Cloud Function
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _db.collection('fcm_queue').add({
        'token': token,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error queuing push notification: $e');
    }
  }

  // Public helper to show local notification (e.g., from foreground handler or manual trigger)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'donation_channel',
      'Donation Notifications',
      channelDescription: 'Notifications for donation updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use a stable but unique ID (millis can collide; using hash of payload or timestamp)
    final id = (payload ?? DateTime.now().toString()).hashCode;

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ======================
  // ✅ Existing Business Logic (Accept/Decline, Utils)
  // ======================
  Future<bool> acceptDonation(String donationId, String ngoId) async {
    try {
      final result = await _db.runTransaction<bool>((transaction) async {
        final docRef = _db.collection('donations').doc(donationId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          if (kDebugMode) print('❌ Donation not found');
          return false;
        }

        final data = snapshot.data();
        if (data?['status'] == 'accepted') {
          if (kDebugMode) print('❌ Donation already accepted');
          return false;
        }

        transaction.update(docRef, {
          'status': 'accepted',
          'acceptedBy': ngoId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      if (result) {
        await _db.collection('notifications').add({
          'donationId': donationId,
          'ngoId': ngoId,
          'action': 'accepted',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) print('✅ Donation accepted: $donationId');
      }

      return result;
    } catch (e) {
      if (kDebugMode) print('❌ Error accepting donation: $e');
      return false;
    }
  }

  Future<bool> declineDonation(String donationId, String ngoId) async {
    try {
      await _db.collection('declined_donations').add({
        'donationId': donationId,
        'ngoId': ngoId,
        'declinedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('✅ Donation declined.');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error declining donation: $e');
      return false;
    }
  }

  Future<void> notifyNgoDeclineInApp({
    required String ngoId,
    required String donationId,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': ngoId,
        'donationId': donationId,
        'type': 'decline',
        'title': 'Donation Declined',
        'message': 'You declined this donation. It will no longer appear for you.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('🔔 In-app decline notification stored for NGO $ngoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to store NGO decline notification: $e');
      }
    }
  }

  Future<bool> isDonationDeclinedByUser(String donationId, String ngoId) async {
    try {
      final query = await _db
          .collection('declined_donations')
          .where('donationId', isEqualTo: donationId)
          .where('ngoId', isEqualTo: ngoId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking declined: $e');
      return false;
    }
  }

  double calculateDistance(GeoPoint from, GeoPoint to) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((to.latitude - from.latitude) * p) / 2 +
        cos(from.latitude * p) *
            cos(to.latitude * p) *
            (1 - cos((to.longitude - from.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // ======================
  // 🔔 Preference & Lifecycle
  // ======================
  Future<void> setNotificationsEnabled(bool enabled, AuthService authService) async {
    final uid = authService.currentUserId;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).set({'notificationsEnabled': enabled}, SetOptions(merge: true));
      _notificationsEnabled = enabled;
      _prefStreamController.add(enabled);

      if (enabled) {
        await _saveDeviceToken(authService);
        await _subscribeToUserTopic(uid);
      } else {
        await _unsubscribeFromUserTopic(uid);
        await _db.collection('users').doc(uid).update({'fcmToken': FieldValue.delete()});
      }

      if (kDebugMode) print('🔔 Notifications ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (kDebugMode) print('❌ Error updating preference: $e');
    }
  }

  Future<void> _loadNotificationPreference(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final enabled = doc.data()?['notificationsEnabled'];
      _notificationsEnabled = enabled is bool ? enabled : true;
      _prefStreamController.add(_notificationsEnabled);
    } catch (e) {
      if (kDebugMode) print('❌ Error loading preference: $e');
      _notificationsEnabled = true;
      _prefStreamController.add(true);
    }
  }

  Future<void> notifyAllNgosAboutDonation({
    required String donationId,
    required String donationTitle,
    required GeoPoint donorLocation,
  }) async {
    try {
      // Get all NGOs
      final ngosSnapshot = await _db
          .collection('users')
          .where('userType', isEqualTo: 'ngo')
          .get();

      for (final ngoDoc in ngosSnapshot.docs) {
        final ngoData = ngoDoc.data();
        final ngoId = ngoDoc.id;
        final ngoLocation = ngoData['location'] as GeoPoint?;

        if (ngoLocation == null) continue;

        // Calculate distance
        final distance = calculateDistance(donorLocation, ngoLocation);
        final distanceStr = distance < 1 ? '<1' : distance.toStringAsFixed(1);

        // Create in-app notification
        await _db.collection('notifications').add({
          'userId': ngoId,
          'type': 'new_donation',
          'title': 'New Donation Available!',
          'body': '"$donationTitle" is available $distanceStr km away from your location',
          'donationId': donationId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send push notification if FCM token exists
        final fcmToken = ngoData['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendPushNotification(
            token: fcmToken,
            title: 'New Donation Available!',
            body: '"$donationTitle" is available $distanceStr km away',
            data: {
              'type': 'new_donation',
              'donationId': donationId,
            },
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error notifying NGOs: $e');
    }
  }

  Future<void> _subscribeToUserTopic(String uid) async {
    try {
      await _fcm.subscribeToTopic('user_$uid');
      if (kDebugMode) print('✅ Subscribed to topic: user_$uid');
    } catch (e) {
      if (kDebugMode) print('❌ Subscribe topic failed: $e');
    }
  }

  Future<void> _unsubscribeFromUserTopic(String uid) async {
    try {
      await _fcm.unsubscribeFromTopic('user_$uid');
      if (kDebugMode) print('✅ Unsubscribed from topic: user_$uid');
    } catch (e) {
      if (kDebugMode) print('❌ Unsubscribe topic failed: $e');
    }
  }

  Future<bool> notificationsEnabled() async => _notificationsEnabled;

  void dispose() {
    _donationSubscription?.cancel();
    // ====== ADDED ======
    _notificationsSubscription?.cancel();
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _donationStreamController.close();
    _chatStreamController.close();
    // ====== ADDED ======
    _notificationsStreamController.close();
    _prefStreamController.close();
  }
}