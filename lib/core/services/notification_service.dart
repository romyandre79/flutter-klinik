import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:kreatif_pos/data/models/order.dart';


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      _isInitialized = true;
    } catch (e) {
      // Ignore errors (e.g. on Windows if not supported or configured)
      print('Notification init error: $e');
    }
  }

  Future<void> scheduleOrderReminder(Order order) async {
    if (!_isInitialized) return;
    if (order.dueDate == null || order.id == null) return;

    try {
      final dueDate = order.dueDate!;
      final now = DateTime.now();

      // Schedule for 2 days before
      final reminder2Days = dueDate.subtract(const Duration(days: 2));
      if (reminder2Days.isAfter(now)) {
        await _scheduleNotification(
          id: order.id! * 10 + 2, // Unique ID for 2-day reminder
          title: 'Reminder: Order #${order.invoiceNo}',
          body: 'Penjualan for ${order.customerName} is due in 2 days.',
          scheduledDate: reminder2Days,
        );
      }

      // Schedule for 1 day before
      final reminder1Day = dueDate.subtract(const Duration(days: 1));
      if (reminder1Day.isAfter(now)) {
        await _scheduleNotification(
          id: order.id! * 10 + 1, // Unique ID for 1-day reminder
          title: 'Urgent: Order #${order.invoiceNo}',
          body: 'Penjualan for ${order.customerName} is due tomorrow!',
          scheduledDate: reminder1Day,
        );
      }
    } catch (e) {
      print('Schedule notification error: $e');
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isInitialized) return;
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'order_reminders',
            'Penjualan Reminders',
            channelDescription: 'Notifications for upcoming order due dates',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Zone schedule error: $e');
    }
  }

  Future<void> cancelOrderReminders(int orderId) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(orderId * 10 + 2);
      await flutterLocalNotificationsPlugin.cancel(orderId * 10 + 1);
    } catch (_) {
      // Ignore errors
    }
  }
}
