import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'dart:math';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const List<String> motivationMessages = [
  'Телефон подождёт. Твои цели — нет. 🎯',
  'Каждая минута в ленте — это минута не на себя. ⚡',
  'Встань. Подвигайся. Сделай хоть что-нибудь. 💪',
  'Думскроллинг не сделает тебя богаче. Действие — да. 💰',
  'Ты листаешь чужую жизнь. Когда займёшься своей? 🔥',
  'Через год ты скажешь спасибо себе сегодняшнему. Или нет. 🌅',
  'Выключи телефон. Сделай одно дело. Вернись победителем. ✅',
  'Успешные люди не листают ленту часами. Факт. 📈',
  'Твой конкурент прямо сейчас работает. А ты? 👀',
  'Сегодняшние действия — завтрашние результаты. 🎯',
  'Хватит готовиться. Начни делать. 💡',
  'Маленький шаг каждый день = огромный результат через год. 🌱',
  'Дисциплина — это мост между целями и достижениями.',
  'Не желай чтобы было легче — желай чтобы ты был лучше.',
  'Если тебе не нравится где ты находишься — двигайся. Ты не дерево.',
];

// Сообщения по дням без записи
String _getReturnMessage(int daysMissed, String goal) {
  if (daysMissed == 1) {
    return 'Вчера не было записи. Сегодня — другой день. Modo ждёт. 📝';
  } else if (daysMissed == 2) {
    return '2 дня без дневника. Маленький шаг сегодня? Займёт 3 минуты. ⏱️';
  } else if (daysMissed == 3) {
    return '3 дня тишины. Стрик потерян. Но всё можно начать заново — прямо сейчас. 🔥';
  } else if (daysMissed == 4) {
    return '4 дня. Твоя цель "$goal" никуда не делась. Она ждёт пока ты листаешь. 👀';
  } else if (daysMissed == 5) {
    return '5 дней без записи. Именно сейчас важно не останавливаться. Открой Modo. 💪';
  } else if (daysMissed == 7) {
    return 'Неделя прошла. Ты доволен? Если нет — время что-то менять. Modo поможет. 📊';
  } else if (daysMissed == 10) {
    return '10 дней. Цель "$goal" стала дальше. Вернись — пока не стало ещё дальше. 🎯';
  } else {
    return '$daysMissed дней без записи. "$goal" — это всё ещё твоя цель? Докажи. 🔥';
  }
}

Future<void> initNotifications() async {
  tz.initializeTimeZones();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await notifications.initialize(settings: initSettings);

  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.requestNotificationsPermission();
}

Future<void> scheduleNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  final goal = prefs.getString('goal') ?? 'твоя цель';
  final entriesRaw = prefs.getString('entries') ?? '{}';
  final entries = jsonDecode(entriesRaw) as Map;

  await notifications.cancelAll();

  final now = tz.TZDateTime.now(tz.local);
  final random = Random();

  // Считаем сколько дней без записи
  int daysMissed = 0;
  DateTime checkDay = DateTime.now().subtract(const Duration(days: 1));
  for (int i = 0; i < 30; i++) {
    final key =
        '${checkDay.year}-${checkDay.month.toString().padLeft(2, '0')}-${checkDay.day.toString().padLeft(2, '0')}';
    if (entries.containsKey(key)) break;
    daysMissed++;
    checkDay = checkDay.subtract(const Duration(days: 1));
  }

  // ── Утреннее уведомление ~8:30 ──
  var morning = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 30);
  if (morning.isBefore(now)) morning = morning.add(const Duration(days: 1));

  final morningBody = daysMissed == 0
      ? 'Не забудь записать день — займёт меньше 3 минут. Не теряй стрик! 🔥'
      : _getReturnMessage(daysMissed, goal);

  await notifications.zonedSchedule(
    id: 1,
    title: daysMissed == 0 ? '🔥 Modo' : '👀 Modo скучает',
    body: morningBody,
    scheduledDate: morning,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'streak_channel',
        'Стрик',
        channelDescription: 'Напоминание о дневнике',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );

  // ── Вечернее уведомление ~20:00 ──
  var evening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
  if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));

  final eveningBody = daysMissed >= 3
      ? _getReturnMessage(daysMissed, goal)
      : motivationMessages[random.nextInt(motivationMessages.length)];

  await notifications.zonedSchedule(
    id: 2,
    title: daysMissed >= 3 ? '⚡ Modo' : 'Modo',
    body: eveningBody,
    scheduledDate: evening,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'motivation_channel',
        'Мотивация',
        channelDescription: 'Мотивационные сообщения',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );

  // ── Дополнительное уведомление в 13:00 если 3+ дней без записи ──
  if (daysMissed >= 3) {
    var afternoon =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 13, 0);
    if (afternoon.isBefore(now))
      afternoon = afternoon.add(const Duration(days: 1));

    await notifications.zonedSchedule(
      id: 3,
      title: '💪 Modo',
      body: _getReturnMessage(daysMissed, goal),
      scheduledDate: afternoon,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'return_channel',
          'Возврат',
          channelDescription: 'Уведомления о возврате',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

Future<void> schedulePlanReminder(String id, String text, DateTime when) async {
  if (when.isBefore(DateTime.now())) return;
  await notifications.zonedSchedule(
    id: id.hashCode,
    title: '📋 Modo',
    body: text,
    scheduledDate: tz.TZDateTime.from(when, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'plans_channel', 'Планы',
        channelDescription: 'Напоминания о планах',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}