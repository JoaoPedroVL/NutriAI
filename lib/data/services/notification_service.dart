import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/user_profile.dart';

/// Serviço de notificações locais.
///
/// - Lembrete de refeições (configurável por refeição)
/// - Lembrete de registrar peso
/// - Lembrete de beber água
/// - Funciona 100% offline
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;

  /// Inicializa o serviço.
  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializa timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    // Configurações Android
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configurações iOS
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicita permissão (Android 13+)
    _permissionsGranted = await _requestPermissions();

    _initialized = true;
  }

  Future<bool> _requestPermissions() async {
    if (await Permission.notification.isGranted) {
      return true;
    }
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  void _onNotificationTap(NotificationResponse response) {
    // TODO: Navegar para tela específica baseado no payload
    // final payload = response.payload;
  }

  /// Agenda lembrete de refeição.
  Future<void> scheduleMealReminder({
    required int id,
    required String mealName,
    required String title,
    required String body,
    required int hour,
    required int minute,
    bool daily = true,
  }) async {
    if (!_permissionsGranted) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminders',
          'Lembretes de Refeições',
          channelDescription: 'Notificações para lembrar de registrar refeições',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      payload: 'meal_reminder:$mealName',
    );
  }

  /// Agenda lembrete de peso.
  Future<void> scheduleWeightReminder({
    required int hour,
    required int minute,
    bool daily = true,
  }) async {
    if (!_permissionsGranted) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      100, // ID fixo para lembrete de peso
      'Hora de se pesar! 📏',
      'Registre seu peso de hoje para acompanhar seu progresso.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weight_reminders',
          'Lembretes de Peso',
          channelDescription: 'Notificações para lembrar de registrar o peso',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      payload: 'weight_reminder',
    );
  }

  /// Agenda lembrete de água.
  Future<void> scheduleWaterReminder({
    required int intervalMinutes,
    required int startHour,
    required int endHour,
  }) async {
    if (!_permissionsGranted) return;

    // Cancela lembretes de água existentes (IDs 200-299)
    for (int i = 200; i < 300; i++) {
      await cancel(i);
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    var notificationId = 200;

    for (int hour = startHour; hour <= endHour; hour++) {
      for (int minute = 0; minute < 60; minute += intervalMinutes) {
        if (notificationId >= 300) break;

        tz.TZDateTime scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          'Hora de beber água! 💧',
          'Beba um copo de água para manter-se hidratado.',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'water_reminders',
              'Lembretes de Água',
              channelDescription: 'Notificações para lembrar de beber água',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: false,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'water_reminder',
        );

        notificationId++;
      }
    }
  }

  /// Cancela uma notificação agendada.
  Future<void> cancel(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancela todas as notificações.
  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Reagenda todos os lembretes baseado nas preferências do usuário.
  Future<void> rescheduleAll({
    required UserProfile profile,
    required NutritionGoals goals,
    required Map<String, MealReminderSettings> mealSettings,
    required WeightReminderSettings weightSettings,
    required WaterReminderSettings waterSettings,
  }) async {
    await cancelAll();

    if (!_permissionsGranted) {
      _permissionsGranted = await _requestPermissions();
      if (!_permissionsGranted) return;
    }

    // Refeições
    for (final entry in mealSettings.entries) {
      final settings = entry.value;
      if (settings.enabled) {
        await scheduleMealReminder(
          id: settings.id,
          mealName: entry.key,
          title: 'Hora do ${entry.key}! 🍽️',
          body: 'Não esqueça de registrar seu ${entry.key.toLowerCase()}.',
          hour: settings.hour,
          minute: settings.minute,
          daily: settings.daily,
        );
      }
    }

    // Peso
    if (weightSettings.enabled) {
      await scheduleWeightReminder(
        hour: weightSettings.hour,
        minute: weightSettings.minute,
        daily: weightSettings.daily,
      );
    }

    // Água
    if (waterSettings.enabled) {
      await scheduleWaterReminder(
        intervalMinutes: waterSettings.intervalMinutes,
        startHour: waterSettings.startHour,
        endHour: waterSettings.endHour,
      );
    }
  }
}

/// Configurações de lembrete de refeição.
class MealReminderSettings {
  final int id;
  final bool enabled;
  final int hour;
  final int minute;
  final bool daily;

  const MealReminderSettings({
    required this.id,
    this.enabled = true,
    this.hour = 12,
    this.minute = 0,
    this.daily = true,
  });

  MealReminderSettings copyWith({
    int? id,
    bool? enabled,
    int? hour,
    int? minute,
    bool? daily,
  }) {
    return MealReminderSettings(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daily: daily ?? this.daily,
    );
  }
}

/// Configurações de lembrete de peso.
class WeightReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final bool daily;

  const WeightReminderSettings({
    this.enabled = true,
    this.hour = 7,
    this.minute = 0,
    this.daily = true,
  });

  WeightReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? daily,
  }) {
    return WeightReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daily: daily ?? this.daily,
    );
  }
}

/// Configurações de lembrete de água.
class WaterReminderSettings {
  final bool enabled;
  final int intervalMinutes;
  final int startHour;
  final int endHour;

  const WaterReminderSettings({
    this.enabled = true,
    this.intervalMinutes = 120, // a cada 2 horas
    this.startHour = 8,
    this.endHour = 20,
  });

  WaterReminderSettings copyWith({
    bool? enabled,
    int? intervalMinutes,
    int? startHour,
    int? endHour,
  }) {
    return WaterReminderSettings(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
    );
  }
}