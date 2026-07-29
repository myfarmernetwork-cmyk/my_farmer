import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/admin/admin_orders_screen.dart';
import '../features/buyer/farmer_storefront_screen.dart';
import '../features/chat/chat_screen.dart';
import '../firebase_options.dart';
import '../models/animal_record.dart';
import '../models/veterinary_request.dart';
import '../screens/my_animals_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const _channelId = 'high_importance_channel';
  static const _channelName = 'Važna obavještenja';

  static const _weatherChannelId = 'weather_alerts_channel';
  static const _weatherChannelName = 'Vremenski alarmi';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  bool _tokenRefreshListenerSet = false;
  String? _pendingPayload;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> initNotifications() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _createAndroidChannel();
    await _createWeatherChannel();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    await _requestPlatformNotificationPermission();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    if (!_tokenRefreshListenerSet) {
      _messaging.onTokenRefresh.listen((newToken) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        await _saveToken(uid, newToken);
      });
      _tokenRefreshListenerSet = true;
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _queuePayload(_buildPayload(initialMessage.data));
    }

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        syncTokenForUser(user.uid);
        flushPendingNavigation();
      }
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await syncTokenForUser(currentUser.uid);
    }

    _initialized = true;
  }

  Future<void> _requestPlatformNotificationPermission() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> syncTokenForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _saveToken(uid, token);
    } catch (_) {
      // Token sync ne smije blokirati app.
    }
  }

  Future<void> clearTokenForUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _messaging.deleteToken();
    } catch (_) {
      // Odjava ne smije blokirati app.
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void flushPendingNavigation() {
    final payload = _pendingPayload;
    if (payload == null) return;
    if (_navigatorKey?.currentState == null) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    _pendingPayload = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPayload(payload);
    });
  }

  void _queuePayload(String? payload) {
    if (payload == null) return;
    _pendingPayload = payload;
    flushPendingNavigation();
  }

  Future<void> showNewOrderAlert({
    required String buyerName,
    required String summary,
    required double total,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Nova narudžba!',
      '$buyerName je naručio: $summary (${total.toStringAsFixed(2)} KM)',
      platformDetails,
      payload: 'new_order',
    );
  }

  Future<void> showLowStockAlert({
    required String productName,
    required double stock,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000) + 1,
      'Niska zaliha',
      '$productName — ostalo ${stock.toStringAsFixed(0)} kom',
      platformDetails,
      payload: 'low_stock',
    );
  }

  Future<void> showWeatherAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _weatherChannelId,
      _weatherChannelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.alarm,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000) + 50000,
      title,
      body,
      platformDetails,
      payload: payload ?? 'weather_alert',
    );
  }

  Future<void> _createWeatherChannel() async {
    const channel = AndroidNotificationChannel(
      _weatherChannelId,
      _weatherChannelName,
      description: 'Hitna upozorenja o vremenu za Premium farmere',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Obavještenja o narudžbama, porukama, kartonima i više',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] as String?;
    final isWeather = type == 'weather_alert';

    final androidDetails = AndroidNotificationDetails(
      isWeather ? _weatherChannelId : _channelId,
      isWeather ? _weatherChannelName : _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      category: isWeather ? AndroidNotificationCategory.alarm : null,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'My Farmer',
      message.notification?.body ??
          'Imate novo obavještenje u My Farmer aplikaciji.',
      platformDetails,
      payload: _buildPayload(message.data),
    );
  }

  String? _buildPayload(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return null;

    switch (type) {
      case 'new_product':
        final farmerId = data['farmerId'] as String?;
        if (farmerId == null) return type;
        return '$type|$farmerId';
      case 'vet_response':
        final animalId = data['animalId'] as String? ?? '';
        return '$type|$animalId';
      case 'chat_message':
        final senderId = data['senderId'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? 'Korisnik';
        return '$type|$senderId|$senderName';
      case 'vet_intake':
        final requestId = data['requestId'] as String? ?? '';
        return '$type|$requestId';
      default:
        return type;
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  void _handleMessageOpened(RemoteMessage message) {
    _handleNotificationPayload(_buildPayload(message.data));
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null) return;

    if (payload == 'new_order') {
      _openOrdersScreen();
      return;
    }

    if (payload == 'low_stock' || payload == 'weather_alert') {
      // Korisnik je već u appu — samo otvori home.
      return;
    }

    if (payload.startsWith('new_product|')) {
      final farmerId = payload.split('|').last;
      _openFarmerStorefront(farmerId);
      return;
    }

    if (payload.startsWith('vet_response|')) {
      final animalId = payload.split('|').last;
      if (animalId.isNotEmpty) {
        _openAnimalDetail(animalId);
      }
      return;
    }

    if (payload.startsWith('chat_message|')) {
      final parts = payload.split('|');
      if (parts.length >= 3) {
        _openChat(parts[1], parts.sublist(2).join('|'));
      }
      return;
    }

    if (payload.startsWith('vet_intake|')) {
      final requestId = payload.split('|').last;
      if (requestId.isNotEmpty) {
        _openVetRequest(requestId);
      }
      return;
    }
  }

  Future<void> _openAnimalDetail(String animalId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('animals')
          .doc(animalId)
          .get();
      if (!doc.exists) return;

      final animal = AnimalRecord.fromFirestore(doc);
      if (animal.userId != uid) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => AnimalDetailScreen(animal: animal),
        ),
      );
    } catch (_) {
      // Navigacija ne smije blokirati app.
    }
  }

  Future<void> _openVetRequest(String requestId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('veterinary_requests')
          .doc(requestId)
          .get();
      if (!doc.exists) return;

      final request = VeterinaryRequest.fromFirestore(doc);
      if (request.vetId != uid) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => VetPatientRequestDetailScreen(request: request),
        ),
      );
    } catch (_) {
      // Navigacija ne smije blokirati app.
    }
  }

  void _openChat(String senderId, String senderName) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: senderId,
          receiverName: senderName,
        ),
      ),
    );
  }

  void _openFarmerStorefront(String farmerId) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => FarmerStorefrontScreen(sellerId: farmerId),
      ),
    );
  }

  void _openOrdersScreen() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
    );
  }
}
