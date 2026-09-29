import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _fcmToken;
  bool _isLocalInitialized = false;

  static void initializeTimezone() {
    tz_data.initializeTimeZones();
  }

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _fcmToken = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> initializeLocalNotifications() async {
    if (_isLocalInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    _isLocalInitialized = true;
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened from notification: ${message.data}');
  }

  String? get fcmToken => _fcmToken;

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('Sending to topic $topic: $title - $body');
  }

  Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await initializeLocalNotifications();

    const androidDetails = AndroidNotificationDetails(
      'smartchama_channel',
      'SmartChama Notifications',
      channelDescription: 'Notifications for SmartChama app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initializeLocalNotifications();

    const androidDetails = AndroidNotificationDetails(
      'smartchama_channel',
      'SmartChama Notifications',
      channelDescription: 'Notifications for SmartChama app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> schedulePaymentReminder({
    required String memberId,
    required String chamaId,
    required DateTime dueDate,
    required double amount,
  }) async {
    final reminderDate = dueDate.subtract(const Duration(days: 1));
    await scheduleLocalNotification(
      id: memberId.hashCode,
      title: 'Payment Reminder',
      body:
          'Your contribution of KES ${amount.toStringAsFixed(0)} is due tomorrow',
      scheduledDate: reminderDate,
      payload: 'payment_$chamaId',
    );
  }

  Future<void> scheduleContributionReminder({
    required String chamaId,
    required String chamaName,
    required DateTime deadline,
    required double amount,
  }) async {
    final oneDayBefore = deadline.subtract(const Duration(days: 1));
    final threeDaysBefore = deadline.subtract(const Duration(days: 3));

    if (threeDaysBefore.isAfter(DateTime.now())) {
      await scheduleLocalNotification(
        id: '${chamaId}_3day'.hashCode,
        title: 'Contribution Due Soon',
        body: 'Your $chamaName contribution of KES ${amount.toStringAsFixed(0)} is due in 3 days',
        scheduledDate: threeDaysBefore,
        payload: 'contribution_${chamaId}_3',
      );
    }

    if (oneDayBefore.isAfter(DateTime.now())) {
      await scheduleLocalNotification(
        id: '${chamaId}_1day'.hashCode,
        title: 'Contribution Due Tomorrow',
        body: 'Your $chamaName contribution of KES ${amount.toStringAsFixed(0)} is due tomorrow',
        scheduledDate: oneDayBefore,
        payload: 'contribution_${chamaId}_1',
      );
    }
  }

  Future<void> notifyLoanRequest({
    required String chamaId,
    required String memberName,
    required double amount,
  }) async {
    await showLocalNotification(
      id: '${chamaId}_loan_${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title: 'New Loan Request',
      body: '$memberName has requested a loan of KES ${amount.toStringAsFixed(0)}',
      payload: 'loan_request_$chamaId',
    );
  }

  Future<void> notifyLoanStatus({
    required String chamaId,
    required String status,
    required double amount,
  }) async {
    final title = status == 'approved' ? 'Loan Approved' : 'Loan Rejected';
    final body = status == 'approved'
        ? 'Your loan of KES ${amount.toStringAsFixed(0)} has been approved'
        : 'Your loan of KES ${amount.toStringAsFixed(0)} has been rejected';

    await showLocalNotification(
      id: '${chamaId}_loan_status'.hashCode,
      title: title,
      body: body,
      payload: 'loan_status_$chamaId',
    );
  }

  Future<void> scheduleLoanDeadlineReminder({
    required String chamaId,
    required String loanId,
    required DateTime deadline,
    required double outstandingAmount,
  }) async {
    final reminderDate = deadline.subtract(const Duration(days: 2));
    if (reminderDate.isAfter(DateTime.now())) {
      await scheduleLocalNotification(
        id: '${chamaId}_${loanId}_deadline'.hashCode,
        title: 'Loan Payment Due Soon',
        body: 'Your loan payment of KES ${outstandingAmount.toStringAsFixed(0)} is due in 2 days',
        scheduledDate: reminderDate,
        payload: 'loan_deadline_$chamaId',
      );
    }
  }

  Future<void> notifyNewMember({
    required String chamaId,
    required String memberName,
    required String chamaName,
  }) async {
    await showLocalNotification(
      id: '${chamaId}_new_member'.hashCode,
      title: 'New Member Joined',
      body: '$memberName has joined $chamaName',
      payload: 'new_member_$chamaId',
    );
  }

  Future<void> notifyNewMeeting({
    required String chamaId,
    required String meetingTitle,
    required DateTime meetingDate,
  }) async {
    final reminderDate = meetingDate.subtract(const Duration(hours: 1));
    if (reminderDate.isAfter(DateTime.now())) {
      await scheduleLocalNotification(
        id: '${chamaId}_meeting_${meetingTitle.hashCode}'.hashCode,
        title: 'Meeting Reminder',
        body: 'Meeting "$meetingTitle" starts in 1 hour',
        scheduledDate: reminderDate,
        payload: 'meeting_$chamaId',
      );
    }
  }

  Future<void> scheduleMeetingReminder({
    required String chamaId,
    required DateTime meetingDate,
    required String location,
  }) async {
    final reminderDate = meetingDate.subtract(const Duration(hours: 1));
    await scheduleLocalNotification(
      id: meetingDate.millisecondsSinceEpoch,
      title: 'Meeting Reminder',
      body: 'Meeting at $location starting in 1 hour',
      scheduledDate: reminderDate,
      payload: 'meeting_$chamaId',
    );
  }
}
