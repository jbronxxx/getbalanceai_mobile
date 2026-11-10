import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import '../utils/utils.dart';
import 'local_db_service.dart';
import 'recurring_payment_service.dart';

/// Напоминание о регулярном платеже в день платежа.
class RecurringReminder {
  /// Номер уведомления в системе — одинаковый для платежа и месяца.
  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// `uid` платежа и месяц (`uid|2026-11`) — по нему тап открывает платёж.
  final String payload;

  const RecurringReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });
}

/// Системные уведомления: планирование, отмена, разрешение, тап.
/// Отдельный интерфейс — чтобы тесты не трогали платформу.
abstract interface class ReminderScheduler {
  /// [onTap] получает payload нажатого уведомления.
  Future<void> initialize(void Function(String payload) onTap);

  /// Payload уведомления, которым приложение было запущено, или `null`.
  Future<String?> launchPayload();

  Future<void> cancelAll();

  Future<void> schedule(RecurringReminder reminder, AppLocalizations l10n);

  /// Показать уведомление сейчас (проверка из меню отладки).
  Future<void> showNow(RecurringReminder reminder, AppLocalizations l10n);

  /// Разрешение на уведомления (Android 13+, iOS); `false` — отказано.
  Future<bool> requestPermission();
}

/// Напоминания в день регулярного платежа или дохода.
///
/// Расписание пересобирается целиком при любом изменении платежей и записей
/// (оплата снимает напоминание), при смене языка и при возвращении в
/// приложение: напоминаний единицы, а так не нужно следить за каждым
/// отдельно. Уведомление планирует система — оно придёт и при закрытом
/// приложении и переживает перезагрузку телефона.
class RecurringReminderService {
  RecurringReminderService({ReminderScheduler? scheduler})
      : _scheduler = scheduler ?? LocalNotificationsScheduler();

  static RecurringReminderService instance = RecurringReminderService();

  /// Во сколько напоминать в день платежа (по местному времени).
  static const reminderHour = 10;

  /// На сколько месяцев вперёд планировать (текущий и следующие).
  static const monthsAhead = 3;

  final ReminderScheduler _scheduler;
  void Function(RecurringOccurrence occurrence)? _onOpen;
  Timer? _debounce;
  AppLifecycleListener? _lifecycle;
  bool _started = false;

  /// Напоминания для [occurrences]: только ожидающие оплаты и только те,
  /// чьё время ещё не прошло.
  static List<RecurringReminder> plan(
    Iterable<RecurringOccurrence> occurrences, {
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final reminders = <RecurringReminder>[];
    for (final o in occurrences) {
      if (!o.isPending) continue;
      final due = o.dueDate;
      final at = DateTime(due.year, due.month, due.day, reminderHour);
      if (!at.isAfter(now)) continue;
      final payment = o.payment;
      final name = payment.displayName();
      final amount =
          CurrencyFormatter.format(payment.amount, currency: payment.currency);
      final isIncome = payment.type == TransactionType.income;
      final key = RecurringSchedule.periodKey(o.period);
      reminders.add(RecurringReminder(
        id: _stableId('${payment.uid}|$key'),
        at: at,
        title: isIncome
            ? l10n.reminder_income_title(name)
            : l10n.reminder_payment_title(name),
        body: isIncome
            ? l10n.reminder_income_body(amount)
            : l10n.reminder_payment_body(amount),
        payload: '${payment.uid}|$key',
      ));
    }
    return reminders;
  }

  /// Положительный 31-битный FNV-1a: `String.hashCode` не обязан совпадать
  /// между запусками.
  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// Платёж месяца по payload уведомления или `null` (платёж удалён).
  @visibleForTesting
  static RecurringOccurrence? occurrenceFor(String payload) {
    final parts = payload.split('|');
    if (parts.length != 2) return null;
    final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(parts[1]);
    if (month == null) return null;
    final period =
        MonthPeriod(int.parse(month.group(1)!), int.parse(month.group(2)!));
    for (final o in RecurringPaymentService.instance.occurrencesIn(period)) {
      if (o.payment.uid == parts[0]) return o;
    }
    return null;
  }

  /// Запускает напоминания. [onOpen] открывает платёж по тапу на
  /// уведомление (в том числе если приложение им и запущено).
  Future<void> start({
    required void Function(RecurringOccurrence occurrence) onOpen,
  }) async {
    _onOpen = onOpen;
    if (_started) return;
    _started = true;
    try {
      await _scheduler.initialize(_handleTap);
      final launch = await _scheduler.launchPayload();
      if (launch != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(launch));
      }
    } catch (e, s) {
      AppLogger.w('[Reminders] Init failed', e, s);
      return;
    }
    LocalDbService.recurringPaymentsChanged.addListener(_scheduleSoon);
    LocalDbService.transactionsChanged.addListener(_scheduleSoon);
    LanguageManager.languageNotifier.addListener(_scheduleSoon);
    _lifecycle = AppLifecycleListener(onResume: _scheduleSoon);
    _scheduleSoon();
  }

  /// Просит разрешение на уведомления — при создании регулярного платежа,
  /// а не при запуске приложения.
  Future<void> requestPermission() async {
    try {
      await _scheduler.requestPermission();
    } catch (e, s) {
      AppLogger.w('[Reminders] Permission request failed', e, s);
    }
  }

  /// Для проверки на телефоне (меню отладки): через [delay] показывает
  /// напоминание о ближайшем ожидающем платеже. Показывается сразу, а не
  /// планируется: пересборка расписания отменила бы его. `false` — ожидающих
  /// платежей нет.
  Future<bool> debugRemindSoon(
      {Duration delay = const Duration(seconds: 10)}) async {
    final now = DateTime.now();
    var period = MonthPeriod.current(now);
    for (var i = 0; i < monthsAhead; i++) {
      for (final o in RecurringPaymentService.instance.occurrencesIn(period)) {
        if (!o.isPending) continue;
        final l10n = LanguageManager.l10n;
        final reminder = plan([o], now: DateTime(1970), l10n: l10n).single;
        unawaited(Future<void>.delayed(
            delay, () => _scheduler.showNow(reminder, l10n)));
        return true;
      }
      period = period.next;
    }
    return false;
  }

  void _handleTap(String payload) {
    final occurrence = occurrenceFor(payload);
    if (occurrence != null) _onOpen?.call(occurrence);
  }

  /// Пересборка не на каждое изменение: сохранение платежа и записи идут
  /// подряд.
  void _scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), reschedule);
  }

  /// Отменяет все напоминания и планирует заново на [monthsAhead] месяцев.
  Future<void> reschedule([DateTime? now]) async {
    if (!LocalDbService.isInitialized) return;
    final moment = now ?? DateTime.now();
    final occurrences = <RecurringOccurrence>[];
    var period = MonthPeriod.current(moment);
    for (var i = 0; i < monthsAhead; i++) {
      occurrences
          .addAll(RecurringPaymentService.instance.occurrencesIn(period));
      period = period.next;
    }
    final l10n = LanguageManager.l10n;
    final reminders = plan(occurrences, now: moment, l10n: l10n);
    try {
      await _scheduler.cancelAll();
      for (final reminder in reminders) {
        await _scheduler.schedule(reminder, l10n);
      }
    } catch (e, s) {
      AppLogger.w('[Reminders] Scheduling failed', e, s);
    }
  }

  @visibleForTesting
  void stop() {
    _debounce?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    LocalDbService.recurringPaymentsChanged.removeListener(_scheduleSoon);
    LocalDbService.transactionsChanged.removeListener(_scheduleSoon);
    LanguageManager.languageNotifier.removeListener(_scheduleSoon);
    _started = false;
  }
}

/// [ReminderScheduler] на `flutter_local_notifications`.
class LocalNotificationsScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Канал Android: пользователь может отключить именно напоминания.
  static const _channelId = 'recurring_payments';

  /// Вид уведомления: канал «Регулярные платежи» с обычной важностью.
  static NotificationDetails _details(AppLocalizations l10n) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.reminder_channel_name,
          channelDescription: l10n.reminder_channel_description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  @override
  Future<void> initialize(void Function(String payload) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Разрешение спрашивается при создании платежа, не при запуске
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap(payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(
      RecurringReminder reminder, AppLocalizations l10n) async {
    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      payload: reminder.payload,
      // Момент времени, а не «10:00 в поясе»: местное время уже учтено
      scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
      notificationDetails: _details(l10n),
      // Точное время не нужно: разрешение на точные будильники не требуется
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> showNow(RecurringReminder reminder, AppLocalizations l10n) =>
      _plugin.show(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        payload: reminder.payload,
        notificationDetails: _details(l10n),
      );

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }
}
