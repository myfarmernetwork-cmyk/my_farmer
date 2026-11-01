import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/buyer/farmer_storefront_screen.dart';
import '../features/buyer/buyer_orders_screen.dart';
import '../features/buyer/product_details_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/forum/screens/forum_topic_detail_screen.dart';
import '../features/seller/add_product_screen.dart';
import '../features/seller/farmer_orders_screen.dart';
import '../firebase_options.dart';
import '../models/animal_record.dart';
import '../models/product.dart';
import '../models/veterinary_request.dart';
import '../providers/notification_navigation_provider.dart';
import '../screens/my_animals_screen.dart';
import 'notification_dismissal_store.dart';
import 'notification_event_key.dart';
import 'notification_prefs.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationDismissalStore.recordRemoteMessage(message.data);
  await NotificationService.showBackgroundMessage(message);
}

/// Prati ulazak u app i označava swipe-om obrisane tray obavijesti.
class _NotificationLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationService().syncTrayDismissalsFromSystem());
    }
  }
}

final _notificationLifecycleObserver = _NotificationLifecycleObserver();

class NotificationService {
  static const String _notificationIcon = '@drawable/ic_notification';
  static const String _notificationLargeIcon = '@mipmap/ic_launcher';
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
  bool _lifecycleObserverAttached = false;
  bool _tokenRefreshListenerSet = false;
  String? _pendingPayload;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> syncQuietWhenBackground(bool value) async {
    await NotificationPrefs.setQuietWhenBackground(value);
  }

  static Future<bool> shouldSuppressBackgroundNotification(
    RemoteMessage message,
  ) async {
    final type = message.data['type'] as String?;
    if (type == 'weather_alert') return false;
    if (type == 'forum_new_topic' || type == 'forum_reply') return true;
    final quiet = await NotificationPrefs.quietWhenBackground();
    return quiet;
  }

  Future<void> initNotifications() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _createAndroidChannel();
    await _createWeatherChannel();

    const androidSettings =
        AndroidInitializationSettings(_notificationIcon);
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
      final eventKey = NotificationEventKey.fromData(initialMessage.data);
      if (eventKey != null) {
        unawaited(
          NotificationDismissalStore.markDismissedForCurrentUser(eventKey),
        );
      }
      _queuePayload(_buildPayload(initialMessage.data));
    }

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        syncTokenForUser(user.uid);
        _loadQuietSettingForUser(user.uid);
        flushPendingNavigation();
        unawaited(syncTrayDismissalsFromSystem());
      }
    });

    if (!_lifecycleObserverAttached) {
      WidgetsBinding.instance.addObserver(_notificationLifecycleObserver);
      _lifecycleObserverAttached = true;
    }

    _initialized = true;
  }

  /// Uskladi lokalno stanje s trayom — obrisane obavijesti se više ne vraćaju.
  Future<void> syncTrayDismissalsFromSystem() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      final active = await android.getActiveNotifications();
      final activeIds = active
          .map((notification) => notification.id)
          .whereType<int>()
          .toSet();
      await NotificationDismissalStore.markMissingActiveAsDismissed(activeIds);
    } catch (_) {}
  }

  AndroidNotificationDetails _androidTrayDetails(
    AndroidNotificationDetails base,
  ) {
    return AndroidNotificationDetails(
      base.channelId,
      base.channelName,
      channelDescription: base.channelDescription,
      importance: base.importance,
      priority: base.priority,
      showWhen: base.showWhen,
      category: base.category,
      icon: _notificationIcon,
      largeIcon: const DrawableResourceAndroidBitmap(_notificationLargeIcon),
    );
  }

  Future<bool> _showSystemTrayIfAllowed({
    required String eventKey,
    required String? payload,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (await NotificationDismissalStore.isBlocked(uid, eventKey)) {
      return false;
    }

    final notificationId = NotificationEventKey.notificationIdFor(eventKey);
    await NotificationDismissalStore.linkNotificationId(
      uid,
      notificationId,
      eventKey,
    );
    await NotificationDismissalStore.markTrayShown(uid, eventKey);

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: _androidTrayDetails(androidDetails)),
      payload: payload ?? eventKey,
    );
    return true;
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
        await _loadQuietSettingForUser(user.uid);
        await syncTrayDismissalsFromSystem();
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

  Future<void> _loadQuietSettingForUser(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final quiet = doc.data()?['quietWhenBackground'] as bool? ?? false;
      await syncQuietWhenBackground(quiet);
    } catch (_) {
      await NotificationPrefs.quietWhenBackground();
    }
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
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final payload = orderId == null || orderId.isEmpty
        ? 'new_order'
        : 'new_order|$orderId';
    final eventKey = NotificationEventKey.fromPayload(payload)!;

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

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: 'notification_new_order_title'.tr(),
      body: 'notification_new_order_push_body'.tr(
        namedArgs: {
          'buyer': buyerName,
          'summary': summary,
          'total': total.toStringAsFixed(2),
        },
      ),
      androidDetails: androidDetails,
    );
  }

  Future<void> showLowStockAlert({
    required String productName,
    required double stock,
    String? productId,
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final payload = productId == null || productId.isEmpty
        ? 'low_stock'
        : 'low_stock|$productId|$productName';
    final eventKey = NotificationEventKey.fromPayload(payload)!;
    final title = 'notification_low_stock_title'.tr();
    final body = 'notification_low_stock_body_remaining'.tr(
      namedArgs: {
        'product': productName,
        'count': stock % 1 == 0
            ? stock.toInt().toString()
            : stock.toStringAsFixed(1),
      },
    );

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.lowStock,
        productId: productId,
        productName: productName,
        stockCount: stock,
      ),
    );

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: title,
      body: body,
      androidDetails: androidDetails,
    );
  }

  Future<void> showWeatherAlert({
    required String title,
    required String body,
    String? payload,
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _weatherChannelId,
      _weatherChannelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.alarm,
    );

    final resolvedPayload = payload ?? 'weather_alert';
    final eventKey =
        NotificationEventKey.fromPayload(resolvedPayload) ?? 'weather_alert';

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: resolvedPayload,
      title: title,
      body: body,
      androidDetails: androidDetails,
    );
  }

  static Future<void> showBackgroundMessage(RemoteMessage message) async {
    if (await shouldSuppressBackgroundNotification(message)) return;

    final data = message.data;
    final eventKey = NotificationEventKey.fromData(data);
    if (eventKey != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (await NotificationDismissalStore.isBlocked(uid, eventKey)) return;
    }

    // FCM već prikaže system notification kad payload sadrži `notification`.
    if (message.notification != null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
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

    final type = data['type'] as String?;
    final notification = message.notification;
    final title = notification?.title ??
        data['senderName'] as String? ??
        'My Farmer';
    final body = notification?.body ??
        (data['message'] as String?) ??
        'Nova poruka';

    final payload = NotificationEventKey.fromData(data);
    final isWeather = type == 'weather_alert';
    final channelId = isWeather ? _weatherChannelId : _channelId;
    final channelName = isWeather ? _weatherChannelName : _channelName;

    if (payload == null) return;

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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final notificationId = NotificationEventKey.notificationIdFor(payload);
    await NotificationDismissalStore.linkNotificationId(
      uid,
      notificationId,
      payload,
    );
    await NotificationDismissalStore.markTrayShown(uid, payload);

    await plugin.show(
      notificationId,
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
          icon: '@drawable/ic_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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

    unawaited(NotificationDismissalStore.recordRemoteMessage(message.data));

    // Dok je app otvoren: in-app banner umjesto system traya (osim vremena).
    if (isWeather) {
      final payload = NotificationEventKey.fromData(message.data);
      if (payload != null) {
        await _showSystemTrayIfAllowed(
          eventKey: payload,
          payload: payload,
          title: message.notification?.title ?? 'My Farmer',
          body: message.notification?.body ??
              'Imate novo obavještenje u My Farmer aplikaciji.',
          androidDetails: AndroidNotificationDetails(
            _weatherChannelId,
            _weatherChannelName,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            category: AndroidNotificationCategory.alarm,
          ),
        );
      }
    }

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
            stockCount: _parseStockCount(data['stockCount']),
          ),
        );
        break;
      case 'weather_alert':
        NotificationNavigationBridge.dispatch(
          NotificationNavigationIntent(
            target: NotificationTarget.weather,
            weatherAlertKey: data['alertKey'] as String?,
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
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final body = clientName.trim().isEmpty
        ? animalName.trim()
        : '${clientName.trim()} — ${animalName.trim()}';
    final payload = 'vet_intake|$requestId';
    final eventKey = NotificationEventKey.fromPayload(payload)!;

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

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: 'Novi digitalni karton',
      body: body.isEmpty ? 'Novi karton ljubimca' : body,
      androidDetails: androidDetails,
    );
  }

  Future<void> showVetResponseAlert({
    required String animalId,
    required String animalName,
    required String body,
    String? requestId,
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final payload = requestId != null && requestId.isNotEmpty
        ? 'vet_response|$requestId'
        : 'vet_response|$animalId';
    final eventKey = NotificationEventKey.fromPayload(payload)!;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.vetResponse,
        animalId: animalId,
        animalName: animalName,
        title: 'Odgovor veterinara',
        body: body,
      ),
    );

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: 'Odgovor veterinara',
      body: body,
      androidDetails: androidDetails,
    );
  }

  Future<void> showChatMessageAlert({
    required String senderId,
    required String senderName,
    required String messagePreview,
    String? roomId,
    String? messageId,
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final payload = _chatPayload(
      senderId: senderId,
      senderName: senderName,
      roomId: roomId,
      messageId: messageId,
    );
    final eventKey = NotificationEventKey.fromPayload(payload)!;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.chatMessage,
        senderId: senderId,
        senderName: senderName,
        title: 'Nova poruka',
        body: messagePreview.isEmpty ? senderName : messagePreview,
      ),
    );

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: 'Nova poruka',
      body: messagePreview.isEmpty ? senderName : messagePreview,
      androidDetails: androidDetails,
    );
  }

  String _chatPayload({
    required String senderId,
    required String senderName,
    String? roomId,
    String? messageId,
  }) {
    if (messageId != null &&
        messageId.isNotEmpty &&
        roomId != null &&
        roomId.isNotEmpty) {
      return 'chat_message|$roomId|$messageId';
    }
    return 'chat_message|$senderId|$senderName';
  }

  Future<void> showForumNewTopicAlert({
    required String topicId,
    required String topicTitle,
    required String authorName,
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final title =
        topicTitle.trim().isEmpty ? 'Nova tema na forumu' : topicTitle.trim();
    final body = authorName.trim().isEmpty
        ? 'Netko je objavio novu temu'
        : authorName.trim();
    final payload = 'forum_new_topic|$topicId';
    final eventKey = NotificationEventKey.fromPayload(payload)!;

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

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: title,
      body: body,
      androidDetails: androidDetails,
    );
  }

  Future<void> showForumReplyAlert({
    required String topicId,
    required String topicTitle,
    required String authorName,
    required String preview,
    bool systemTray = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final title = topicTitle.trim().isEmpty
        ? 'Novi odgovor na forumu'
        : topicTitle.trim();
    final body = preview.trim().isNotEmpty
        ? preview.trim()
        : (authorName.trim().isEmpty ? 'Netko je odgovorio' : authorName.trim());
    final payload = 'forum_reply|$topicId';
    final eventKey = NotificationEventKey.fromPayload(payload)!;

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

    if (!systemTray) return;

    await _showSystemTrayIfAllowed(
      eventKey: eventKey,
      payload: payload,
      title: title,
      body: body,
      androidDetails: androidDetails,
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
    final productId = (data['productId'] as String? ?? '').trim();
    final farmerId = (data['farmerId'] as String? ?? '').trim();
    if (productId.isEmpty && farmerId.isEmpty) return;

    NotificationNavigationBridge.dispatch(
      NotificationNavigationIntent(
        target: NotificationTarget.newProduct,
        productId: productId.isEmpty ? null : productId,
        farmerId: farmerId.isEmpty ? null : farmerId,
        farmerName: data['farmerName'] as String?,
        productName: data['productName'] as String?,
        title: notification?.title,
        body: notification?.body,
      ),
    );
  }

  /// Otvara ekran proizvoda iz obavijesti (banner, tržnica, push).
  Future<void> navigateFromIntent(NotificationNavigationIntent intent) async {
    NotificationNavigationBridge.switchToTabFor(intent);

    switch (intent.target) {
      case NotificationTarget.orders:
        _openOrdersScreen(highlightOrderId: intent.orderId);
        break;
      case NotificationTarget.buyerOrders:
        _openBuyerOrdersScreen(
          highlightOrderId: intent.orderId,
          orderStatus: intent.orderStatus,
        );
        break;
      case NotificationTarget.newProduct:
        await _openNewProductFromIntent(intent);
        break;
      case NotificationTarget.lowStock:
        if (intent.productId != null && intent.productId!.isNotEmpty) {
          await _openSellerProductEdit(intent.productId!);
        } else {
          NotificationNavigationBridge.switchToTabFor(
            NotificationNavigationIntent(
              target: NotificationTarget.lowStock,
              productId: intent.productId,
            ),
          );
        }
        break;
      case NotificationTarget.weather:
        break;
      case NotificationTarget.vetIntake:
        if (intent.requestId != null && intent.requestId!.isNotEmpty) {
          await _openVetRequest(intent.requestId!);
        }
        break;
      case NotificationTarget.vetResponse:
        if (intent.animalId != null && intent.animalId!.isNotEmpty) {
          await _openAnimalDetail(intent.animalId!);
        }
        break;
      case NotificationTarget.chatMessage:
        if (intent.senderId != null && intent.senderId!.isNotEmpty) {
          _openChat(
            intent.senderId!,
            intent.senderName ?? 'Korisnik',
          );
        }
        break;
      case NotificationTarget.forumTopic:
      case NotificationTarget.forumReply:
        if (intent.topicId != null && intent.topicId!.isNotEmpty) {
          await _openForumTopic(intent.topicId!);
        }
        break;
    }
  }

  void focusSellerOrderFromIntent(NotificationNavigationIntent intent) {
    if (intent.orderId == null || intent.orderId!.isEmpty) return;
    _openOrdersScreen(highlightOrderId: intent.orderId);
  }

  void focusBuyerOrderFromIntent(NotificationNavigationIntent intent) {
    if (intent.orderId == null || intent.orderId!.isEmpty) return;
    _openBuyerOrdersScreen(
      highlightOrderId: intent.orderId,
      orderStatus: intent.orderStatus,
    );
  }

  Future<void> openProductFromNotification(String productId) async {
    await _openProductDetails(productId);
  }

  String? _buildPayload(Map<String, dynamic> data) =>
      NotificationEventKey.fromData(data);

  void _onLocalNotificationTap(NotificationResponse response) {
    unawaited(_markNotificationHandled(response));
    _handleNotificationPayload(response.payload);
  }

  Future<void> _markNotificationHandled(NotificationResponse response) async {
    final payload = response.payload;
    final eventKey = NotificationEventKey.fromPayload(payload);
    if (eventKey != null) {
      await NotificationDismissalStore.markDismissedForCurrentUser(eventKey);
    }
    final id = response.id;
    if (id != null) {
      await NotificationDismissalStore.markDismissedByNotificationId(id);
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    final eventKey = NotificationEventKey.fromData(message.data);
    if (eventKey != null) {
      unawaited(NotificationDismissalStore.markDismissedForCurrentUser(eventKey));
    }
    _handleNotificationPayload(_buildPayload(message.data));
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null) return;

    if (payload == 'new_order' || payload.startsWith('new_order|')) {
      final parts = payload.split('|');
      final orderId = parts.length > 1 ? parts[1] : null;
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.orders,
        orderId: orderId,
        pushOrdersScreen: true,
      );
      NotificationNavigationBridge.dispatch(intent);
      navigateFromIntent(intent);
      return;
    }

    if (payload == 'order_status' || payload.startsWith('order_status|')) {
      final parts = payload.split('|');
      final orderId = parts.length > 1 ? parts[1] : null;
      final status = parts.length > 2 ? parts[2] : null;
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.buyerOrders,
        orderId: orderId,
        orderStatus: status,
      );
      NotificationNavigationBridge.dispatch(intent);
      navigateFromIntent(intent);
      return;
    }

    if (payload == 'low_stock' || payload.startsWith('low_stock|')) {
      final parts = payload.split('|');
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.lowStock,
        productId: parts.length > 1 ? parts[1] : null,
        productName: parts.length > 2 ? parts.sublist(2).join('|') : null,
      );
      NotificationNavigationBridge.dispatch(intent);
      navigateFromIntent(intent);
      return;
    }

    if (payload == 'weather_alert' || payload.startsWith('weather_alert|')) {
      final parts = payload.split('|');
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.weather,
        weatherAlertKey: parts.length > 1 ? parts[1] : null,
      );
      NotificationNavigationBridge.dispatch(intent);
      navigateFromIntent(intent);
      return;
    }

    if (payload.startsWith('new_product|')) {
      final parts = payload.split('|');
      final productId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
      final farmerId = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;

      final intent = NotificationNavigationIntent(
        target: NotificationTarget.newProduct,
        productId: productId,
        farmerId: farmerId,
      );
      NotificationNavigationBridge.dispatch(intent);

      if ((productId != null && productId.isNotEmpty) ||
          (farmerId != null && farmerId.isNotEmpty)) {
        navigateFromIntent(intent);
      }
      return;
    }

    if (payload.startsWith('vet_response|')) {
      final parts = payload.split('|');
      final animalId = parts.length >= 3 ? parts[2] : parts.last;
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.vetResponse,
        animalId: animalId.isEmpty ? null : animalId,
      );
      NotificationNavigationBridge.dispatch(intent);
      if (animalId.isNotEmpty) {
        navigateFromIntent(intent);
      }
      return;
    }

    if (payload.startsWith('chat_message|')) {
      final parts = payload.split('|');
      if (parts.length >= 3) {
        final second = parts[1];
        final third = parts.sublist(2).join('|');

        String senderId;
        String senderName;

        // FCM: chat_message|roomId|messageId
        if (second.contains('_') && !third.contains(' ')) {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final roomParts = second.split('_');
          if (uid.isNotEmpty && roomParts.length == 2) {
            senderId =
                roomParts.first == uid ? roomParts.last : roomParts.first;
            senderName = 'Korisnik';
          } else {
            return;
          }
        } else {
          senderId = second;
          senderName = third;
        }

        final intent = NotificationNavigationIntent(
          target: NotificationTarget.chatMessage,
          senderId: senderId,
          senderName: senderName,
        );
        NotificationNavigationBridge.dispatch(intent);
        navigateFromIntent(intent);
      }
      return;
    }

    if (payload.startsWith('vet_intake|')) {
      final requestId = payload.split('|').last;
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.vetIntake,
        requestId: requestId.isEmpty ? null : requestId,
      );
      NotificationNavigationBridge.dispatch(intent);
      if (requestId.isNotEmpty) {
        navigateFromIntent(intent);
      }
      return;
    }

    if (payload.startsWith('forum_new_topic|')) {
      final topicId = payload.split('|').last;
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.forumTopic,
        topicId: topicId.isEmpty ? null : topicId,
      );
      NotificationNavigationBridge.dispatch(intent);
      if (topicId.isNotEmpty) {
        navigateFromIntent(intent);
      }
      return;
    }

    if (payload.startsWith('forum_reply|')) {
      final topicId = payload.split('|').last;
      final intent = NotificationNavigationIntent(
        target: NotificationTarget.forumReply,
        topicId: topicId.isEmpty ? null : topicId,
      );
      NotificationNavigationBridge.dispatch(intent);
      if (topicId.isNotEmpty) {
        navigateFromIntent(intent);
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

      if (doc.exists) {
        final request = VeterinaryRequest.fromFirestore(doc);
        final assignedVetId = request.vetId.trim();
        if (assignedVetId.isEmpty || assignedVetId == uid) {
          if (!navigator.mounted) return;
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => VetPatientRequestDetailScreen(request: request),
            ),
          );
          return;
        }
      }

      if (!navigator.mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const VeterinarianAnimalsHubScreen(
            initialTab: VeterinarianAnimalsTab.digitalIntake,
          ),
        ),
      );
    } catch (_) {
      final navigator = _navigatorKey?.currentState;
      if (navigator == null || !navigator.mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const VeterinarianAnimalsHubScreen(
            initialTab: VeterinarianAnimalsTab.digitalIntake,
          ),
        ),
      );
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

  Future<void> _openNewProductFromIntent(
    NotificationNavigationIntent intent,
  ) async {
    final productId = intent.productId?.trim();
    if (productId != null && productId.isNotEmpty) {
      final opened = await _tryOpenProductDetails(productId);
      if (opened) return;
    }

    final farmerId = intent.farmerId?.trim();
    if (farmerId != null && farmerId.isNotEmpty) {
      _openFarmerStorefront(farmerId);
      return;
    }

    _showNavigationUnavailableMessage();
  }

  void _showNavigationUnavailableMessage() {
    final messenger = _navigatorKey?.currentState?.overlay?.context;
    if (messenger == null) return;
    ScaffoldMessenger.maybeOf(messenger)?.showSnackBar(
      SnackBar(content: Text('notification_product_unavailable'.tr())),
    );
  }

  void _openFarmerStorefront(String sellerId) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => FarmerStorefrontScreen(sellerId: sellerId),
      ),
    );
  }

  Future<bool> _tryOpenProductDetails(String productId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (!doc.exists) return false;

      final product = Product.fromFirestore(doc);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openProductDetails(String productId) async {
    final opened = await _tryOpenProductDetails(productId);
    if (!opened) {
      _showNavigationUnavailableMessage();
    }
  }

  void _openBuyerOrdersScreen({
    String? highlightOrderId,
    String? orderStatus,
  }) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => BuyerOrdersScreen(
          highlightOrderId: highlightOrderId,
          orderStatus: orderStatus,
        ),
      ),
    );
  }

  Future<void> _openSellerProductEdit(String productId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (!doc.exists) return;

      final product = Product.fromFirestore(doc);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || product.sellerId != uid) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => AddProductScreen(productToEdit: product),
        ),
      );
    } catch (_) {}
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

  static double? _parseStockCount(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }
}
