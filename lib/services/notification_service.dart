import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/buyer/buyer_orders_screen.dart';
import '../features/buyer/product_details_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/forum/screens/forum_topic_detail_screen.dart';
import '../features/seller/farmer_orders_screen.dart';
import '../firebase_options.dart';
import '../models/animal_record.dart';
import '../models/product.dart';
import '../models/veterinary_request.dart';
import '../providers/notification_navigation_provider.dart';
import '../screens/my_animals_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.showBackgroundMessage(message);
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
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
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

    _initialized = true;
  }

  /// Traži dozvolu (ako treba) i uvijek osvježi FCM token u Firestore.
  /// Poziva se pri svakom ulasku u app — ne samo jednom.
  Future<void> ensurePushReady() async {
    try {
      if (!_initialized) {
        await initNotifications();
      }

      await _requestPlatformNotificationPermission();
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await syncTokenForUser(user.uid);
      }
    } catch (_) {
      // Obavijesti nisu obavezne za rad appa.
    }
  }

  Future<void> requestPermissionsWhenReady() => ensurePushReady();

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
    String? orderId,
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
      'notification_new_order_title'.tr(),
      'notification_new_order_push_body'.tr(
        namedArgs: {
          'buyer': buyerName,
          'summary': summary,
          'total': total.toStringAsFixed(2),
        },
      ),
      platformDetails,
      payload: orderId == null || orderId.isEmpty
          ? 'new_order'
          : 'new_order|$orderId',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.orders,
        orderId: orderId,
        title: 'notification_new_order_title'.tr(),
        body: 'notification_new_order_push_body'.tr(
          namedArgs: {
            'buyer': buyerName,
            'summary': summary,
            'total': total.toStringAsFixed(2),
          },
        ),
        pushOrdersScreen: true,
      ),
    );
  }

  Future<void> showLowStockAlert({
    required String productName,
    required double stock,
    String? productId,
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
      payload: productId == null || productId.isEmpty
          ? 'low_stock'
          : 'low_stock|$productId|$productName',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.lowStock,
        productId: productId,
        productName: productName,
        title: 'Niska zaliha',
        body: '$productName — ostalo ${stock.toStringAsFixed(0)} kom',
      ),
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

  static Future<void> showBackgroundMessage(RemoteMessage message) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Obavještenja o narudžbama, porukama, kartonima i više',
      importance: Importance.max,
    );

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final data = message.data;
    final type = data['type'] as String?;
    final notification = message.notification;
    final title = notification?.title ??
        data['senderName'] as String? ??
        'My Farmer';
    final body = notification?.body ??
        (data['message'] as String?) ??
        'Nova poruka';

    final payload = _buildPayloadStatic(data);
    final isWeather = type == 'weather_alert';
    final channelId = isWeather ? _weatherChannelId : _channelId;
    final channelName = isWeather ? _weatherChannelName : _channelName;

    if (isWeather) {
      const weatherChannel = AndroidNotificationChannel(
        _weatherChannelId,
        _weatherChannelName,
        description: 'Hitna upozorenja o vremenu za Premium farmere',
        importance: Importance.max,
      );
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(weatherChannel);
    }

    await plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          category: isWeather ? AndroidNotificationCategory.alarm : null,
        ),
      ),
      payload: payload,
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

    _dispatchInAppIntent(message.data, message.notification);
  }

  void _dispatchInAppIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final type = data['type'] as String?;
    switch (type) {
      case 'new_product':
        _dispatchNewProductIntent(data, notification);
        break;
      case 'new_order':
        NotificationNavigationBridge.dispatch(
          NotificationNavigationIntent(
            target: NotificationTarget.orders,
            orderId: data['orderId'] as String?,
            title: notification?.title,
            body: notification?.body,
            pushOrdersScreen: true,
          ),
        );
        break;
      case 'order_status':
        NotificationNavigationBridge.dispatch(
          NotificationNavigationIntent(
            target: NotificationTarget.buyerOrders,
            orderId: data['orderId'] as String?,
            orderStatus: data['status'] as String?,
            title: notification?.title,
            body: notification?.body,
          ),
        );
        break;
      case 'low_stock':
        NotificationNavigationBridge.dispatch(
          NotificationNavigationIntent(
            target: NotificationTarget.lowStock,
            productId: data['productId'] as String?,
            productName: data['productName'] as String?,
            title: notification?.title ?? 'Niska zaliha',
            body: notification?.body,
          ),
        );
        break;
      case 'weather_alert':
        NotificationNavigationBridge.dispatch(
          NotificationNavigationIntent(
            target: NotificationTarget.weather,
            weatherAlertKey: data['alertKey'] as String?,
            title: notification?.title ?? '⚠️ Vremensko upozorenje',
            body: notification?.body,
          ),
        );
        break;
      case 'vet_intake':
        _dispatchVetIntakeIntent(data, notification);
        break;
      case 'vet_response':
        _dispatchVetResponseIntent(data, notification);
        break;
      case 'chat_message':
        _dispatchChatMessageIntent(data, notification);
        break;
      case 'forum_new_topic':
        _dispatchForumNewTopicIntent(data, notification);
        break;
      case 'forum_reply':
        _dispatchForumReplyIntent(data, notification);
        break;
    }
  }

  void _dispatchVetIntakeIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final requestId = data['requestId'] as String? ?? '';
    if (requestId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.vetIntake,
        requestId: requestId,
        animalName: data['animalName'] as String?,
        clientName: data['clientName'] as String?,
        title: notification?.title ?? 'Novi digitalni karton',
        body: notification?.body,
      ),
    );
  }

  void _dispatchVetResponseIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final animalId = data['animalId'] as String? ?? '';
    if (animalId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.vetResponse,
        animalId: animalId,
        animalName: data['animalName'] as String?,
        title: notification?.title ?? 'Odgovor veterinara',
        body: notification?.body,
      ),
    );
  }

  void _dispatchChatMessageIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final senderId = data['senderId'] as String? ?? '';
    if (senderId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.chatMessage,
        senderId: senderId,
        senderName: data['senderName'] as String? ?? 'Korisnik',
        body: notification?.body ?? data['message'] as String?,
        title: notification?.title ?? 'Nova poruka',
      ),
    );
  }

  void _dispatchForumNewTopicIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final topicId = data['topicId'] as String? ?? '';
    if (topicId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.forumTopic,
        topicId: topicId,
        topicTitle: data['topicTitle'] as String?,
        authorName: data['authorName'] as String?,
        title: notification?.title,
        body: notification?.body,
      ),
    );
  }

  void _dispatchForumReplyIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final topicId = data['topicId'] as String? ?? '';
    if (topicId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.forumReply,
        topicId: topicId,
        topicTitle: data['topicTitle'] as String?,
        authorName: data['authorName'] as String?,
        body: notification?.body ?? data['preview'] as String?,
        title: notification?.title,
      ),
    );
  }

  Future<void> showVetIntakeAlert({
    required String requestId,
    required String animalName,
    required String clientName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    final body = clientName.trim().isEmpty
        ? animalName.trim()
        : '${clientName.trim()} — ${animalName.trim()}';

    await _localNotifications.show(
      requestId.hashCode,
      'Novi digitalni karton',
      body.isEmpty ? 'Novi karton ljubimca' : body,
      platformDetails,
      payload: 'vet_intake|$requestId',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.vetIntake,
        requestId: requestId,
        animalName: animalName,
        clientName: clientName,
        title: 'Novi digitalni karton',
        body: body.isEmpty ? 'Novi karton ljubimca' : body,
      ),
    );
  }

  Future<void> showVetResponseAlert({
    required String animalId,
    required String animalName,
    required String body,
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
      animalId.hashCode,
      'Odgovor veterinara',
      body,
      platformDetails,
      payload: 'vet_response|$animalId',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.vetResponse,
        animalId: animalId,
        animalName: animalName,
        title: 'Odgovor veterinara',
        body: body,
      ),
    );
  }

  Future<void> showChatMessageAlert({
    required String senderId,
    required String senderName,
    required String messagePreview,
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
      '$senderId$messagePreview'.hashCode,
      'Nova poruka',
      messagePreview.isEmpty ? senderName : messagePreview,
      platformDetails,
      payload: 'chat_message|$senderId|$senderName',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.chatMessage,
        senderId: senderId,
        senderName: senderName,
        title: 'Nova poruka',
        body: messagePreview.isEmpty ? senderName : messagePreview,
      ),
    );
  }

  Future<void> showForumNewTopicAlert({
    required String topicId,
    required String topicTitle,
    required String authorName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    final title = topicTitle.trim().isEmpty ? 'Nova tema na forumu' : topicTitle.trim();
    final body = authorName.trim().isEmpty
        ? 'Netko je objavio novu temu'
        : authorName.trim();

    await _localNotifications.show(
      topicId.hashCode,
      title,
      body,
      platformDetails,
      payload: 'forum_new_topic|$topicId',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.forumTopic,
        topicId: topicId,
        topicTitle: topicTitle,
        authorName: authorName,
        title: title,
        body: body,
      ),
    );
  }

  Future<void> showForumReplyAlert({
    required String topicId,
    required String topicTitle,
    required String authorName,
    required String preview,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    final title = topicTitle.trim().isEmpty
        ? 'Novi odgovor na forumu'
        : topicTitle.trim();
    final body = preview.trim().isNotEmpty
        ? preview.trim()
        : (authorName.trim().isEmpty ? 'Netko je odgovorio' : authorName.trim());

    await _localNotifications.show(
      '$topicId$preview'.hashCode,
      title,
      body,
      platformDetails,
      payload: 'forum_reply|$topicId',
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.forumReply,
        topicId: topicId,
        topicTitle: topicTitle,
        authorName: authorName,
        title: title,
        body: body,
      ),
    );
  }

  Future<void> openVetRequestFromNotification(String requestId) =>
      _openVetRequest(requestId);

  Future<void> openAnimalDetailFromNotification(String animalId) =>
      _openAnimalDetail(animalId);

  void openChatFromNotification(String senderId, String senderName) =>
      _openChat(senderId, senderName);

  Future<void> openForumTopicFromNotification(String topicId) async {
    await _openForumTopic(topicId);
  }

  void _dispatchNewProductIntent(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final productId = data['productId'] as String? ?? '';
    if (productId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.newProduct,
        productId: productId,
        farmerId: data['farmerId'] as String?,
        farmerName: data['farmerName'] as String?,
        productName: data['productName'] as String?,
        title: notification?.title,
        body: notification?.body,
      ),
    );
  }

  /// Otvara ekran proizvoda iz obavijesti (banner, tržnica, push).
  Future<void> openProductFromNotification(String productId) async {
    await _openProductDetails(productId);
  }

  String? _buildPayload(Map<String, dynamic> data) =>
      _buildPayloadStatic(data);

  static String? _buildPayloadStatic(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return null;

    switch (type) {
      case 'new_order':
        final orderId = data['orderId'] as String? ?? '';
        return orderId.isEmpty ? type : '$type|$orderId';
      case 'order_status':
        final orderId = data['orderId'] as String? ?? '';
        final status = data['status'] as String? ?? '';
        if (orderId.isEmpty) return type;
        return status.isEmpty ? '$type|$orderId' : '$type|$orderId|$status';
      case 'weather_alert':
        final alertKey = data['alertKey'] as String? ?? '';
        return alertKey.isEmpty ? type : '$type|$alertKey';
      case 'low_stock':
        final productId = data['productId'] as String? ?? '';
        final productName = data['productName'] as String? ?? '';
        if (productId.isEmpty) return type;
        return productName.isEmpty
            ? '$type|$productId'
            : '$type|$productId|$productName';
      case 'new_product':
        final productId = data['productId'] as String? ?? '';
        final farmerId = data['farmerId'] as String? ?? '';
        if (productId.isEmpty && farmerId.isEmpty) return type;
        if (productId.isEmpty) return '$type||$farmerId';
        if (farmerId.isEmpty) return '$type|$productId';
        return '$type|$productId|$farmerId';
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
      case 'forum_new_topic':
        final topicId = data['topicId'] as String? ?? '';
        return topicId.isEmpty ? type : '$type|$topicId';
      case 'forum_reply':
        final topicId = data['topicId'] as String? ?? '';
        return topicId.isEmpty ? type : '$type|$topicId';
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

    if (payload == 'new_order' || payload.startsWith('new_order|')) {
      final parts = payload.split('|');
      final orderId = parts.length > 1 ? parts[1] : null;
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.orders,
          orderId: orderId,
          pushOrdersScreen: true,
        ),
      );
      _openOrdersScreen(highlightOrderId: orderId);
      return;
    }

    if (payload == 'order_status' || payload.startsWith('order_status|')) {
      final parts = payload.split('|');
      final orderId = parts.length > 1 ? parts[1] : null;
      final status = parts.length > 2 ? parts[2] : null;
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.buyerOrders,
          orderId: orderId,
          orderStatus: status,
        ),
      );
      _openBuyerOrdersScreen();
      return;
    }

    if (payload == 'low_stock' || payload.startsWith('low_stock|')) {
      final parts = payload.split('|');
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.lowStock,
          productId: parts.length > 1 ? parts[1] : null,
          productName: parts.length > 2 ? parts.sublist(2).join('|') : null,
          title: 'Niska zaliha',
        ),
      );
      return;
    }

    if (payload == 'weather_alert' || payload.startsWith('weather_alert|')) {
      final parts = payload.split('|');
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.weather,
          weatherAlertKey: parts.length > 1 ? parts[1] : null,
          title: '⚠️ Vremensko upozorenje',
        ),
      );
      return;
    }

    if (payload.startsWith('new_product|')) {
      final parts = payload.split('|');
      final productId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
      final farmerId = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;

      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.newProduct,
          productId: productId,
          farmerId: farmerId,
        ),
      );

      if (productId != null) {
        _openProductDetails(productId);
      }
      return;
    }

    if (payload.startsWith('vet_response|')) {
      final animalId = payload.split('|').last;
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.vetResponse,
          animalId: animalId.isEmpty ? null : animalId,
        ),
      );
      if (animalId.isNotEmpty) {
        _openAnimalDetail(animalId);
      }
      return;
    }

    if (payload.startsWith('chat_message|')) {
      final parts = payload.split('|');
      if (parts.length >= 3) {
        final senderId = parts[1];
        final senderName = parts.sublist(2).join('|');
        NotificationNavigationBridge.dispatch(
          NotificationNavigationIntent(
            target: NotificationTarget.chatMessage,
            senderId: senderId,
            senderName: senderName,
          ),
        );
        _openChat(senderId, senderName);
      }
      return;
    }

    if (payload.startsWith('vet_intake|')) {
      final requestId = payload.split('|').last;
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.vetIntake,
          requestId: requestId.isEmpty ? null : requestId,
        ),
      );
      if (requestId.isNotEmpty) {
        _openVetRequest(requestId);
      }
      return;
    }

    if (payload.startsWith('forum_new_topic|')) {
      final topicId = payload.split('|').last;
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.forumTopic,
          topicId: topicId.isEmpty ? null : topicId,
        ),
      );
      if (topicId.isNotEmpty) {
        _openForumTopic(topicId);
      }
      return;
    }

    if (payload.startsWith('forum_reply|')) {
      final topicId = payload.split('|').last;
      NotificationNavigationBridge.dispatch(
        NotificationNavigationIntent(
          target: NotificationTarget.forumReply,
          topicId: topicId.isEmpty ? null : topicId,
        ),
      );
      if (topicId.isNotEmpty) {
        _openForumTopic(topicId);
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

  Future<void> _openForumTopic(String topicId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ForumTopicDetailScreen(topicId: topicId),
      ),
    );
  }

  Future<void> _openProductDetails(String productId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (!doc.exists) return;

      final product = Product.fromFirestore(doc);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      );
    } catch (_) {
      // Navigacija ne smije blokirati app.
    }
  }

  void _openBuyerOrdersScreen() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const BuyerOrdersScreen(),
      ),
    );
  }

  void _openOrdersScreen({String? highlightOrderId}) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => FarmerOrdersScreen(highlightOrderId: highlightOrderId),
      ),
    );
  }
}
