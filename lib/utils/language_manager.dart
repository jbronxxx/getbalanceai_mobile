import 'package:getbalanceai_mobile/l10n/app_localizations.dart';
export 'package:getbalanceai_mobile/l10n/app_localizations.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';

/// Поддерживаемые языки интерфейса приложения.
enum AppLanguage {
  ru('ru', 'Русский', '🇷🇺'),
  en('en', 'English', '🇬🇧');

  final String code;
  final String displayName;
  final String flag;

  const AppLanguage(this.code, this.displayName, this.flag);
}

/// Менеджер локализации приложения.
/// Обеспечивает хранение текущего языка, реактивное переключение и доступ
/// к сгенерированным строкам [AppLocalizations].
class LanguageManager {
  /// До загрузки сохранённого языка — английский, как и для языка системы,
  /// которого нет в приложении.
  static AppLanguage _currentLanguage = AppLanguage.en;
  static AppLocalizations? _l10n;

  static AppLocalizations get l10n {
    _l10n ??= lookupAppLocalizations(Locale(_currentLanguage.code));
    return _l10n!;
  }

  static set l10n(AppLocalizations value) {
    _l10n = value;
  }

  static final ValueNotifier<AppLanguage> languageNotifier =
      ValueNotifier(AppLanguage.en);

  static void setLanguage(AppLanguage language, {bool save = true}) {
    _currentLanguage = language;
    _l10n = lookupAppLocalizations(Locale(language.code));
    languageNotifier.value = language;
    if (save) {
      PreferencesService.instance.saveLanguage(language.code);
    }
  }

  /// Загружает сохранённый язык. При первом запуске (язык ещё не выбран)
  /// берёт язык системы, если приложение его поддерживает, иначе английский;
  /// сохраняется выбор только в онбординге. [systemLocales] — для тестов.
  static Future<void> loadSavedLanguage({List<Locale>? systemLocales}) async {
    final code = await PreferencesService.instance.getLanguage();
    final language = (code != null
            ? AppLanguage.values.where((l) => l.code == code).firstOrNull
            : languageForLocales(
                systemLocales ?? PlatformDispatcher.instance.locales,
              )) ??
        AppLanguage.en;
    _currentLanguage = language;
    _l10n = lookupAppLocalizations(Locale(language.code));
    languageNotifier.value = language;
  }

  /// Первый из языков системы (в порядке предпочтения), который есть
  /// в приложении; `null` — ни одного.
  static AppLanguage? languageForLocales(List<Locale> locales) {
    for (final locale in locales) {
      final match = AppLanguage.values
          .where((l) => l.code == locale.languageCode.toLowerCase())
          .firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  static AppLanguage get currentLanguage => _currentLanguage;

  static void initFallback() {
    _l10n ??= lookupAppLocalizations(Locale(_currentLanguage.code));
  }

  static String get code => _currentLanguage.code;

  /// Возвращает локализованное название месяца в именительном падеже (1..12).
  ///
  /// [localizations] — явный язык вместо текущего: в фоновом изоляте
  /// (выгрузка отчёта) текущий язык не установлен.
  static String getMonthName(int month, [AppLocalizations? localizations]) {
    final l10n = localizations ?? LanguageManager.l10n;
    switch (month) {
      case 1:
        return l10n.month_1;
      case 2:
        return l10n.month_2;
      case 3:
        return l10n.month_3;
      case 4:
        return l10n.month_4;
      case 5:
        return l10n.month_5;
      case 6:
        return l10n.month_6;
      case 7:
        return l10n.month_7;
      case 8:
        return l10n.month_8;
      case 9:
        return l10n.month_9;
      case 10:
        return l10n.month_10;
      case 11:
        return l10n.month_11;
      case 12:
        return l10n.month_12;
      default:
        return '';
    }
  }

  /// Список названий всех 12 месяцев на текущем языке.
  static List<String> get monthsNames =>
      List.generate(12, (i) => getMonthName(i + 1));

  /// Возвращает название месяца в родительном падеже (1..12).
  static String getMonthGenitive(int month) {
    switch (month) {
      case 1:
        return l10n.month_gen_1;
      case 2:
        return l10n.month_gen_2;
      case 3:
        return l10n.month_gen_3;
      case 4:
        return l10n.month_gen_4;
      case 5:
        return l10n.month_gen_5;
      case 6:
        return l10n.month_gen_6;
      case 7:
        return l10n.month_gen_7;
      case 8:
        return l10n.month_gen_8;
      case 9:
        return l10n.month_gen_9;
      case 10:
        return l10n.month_gen_10;
      case 11:
        return l10n.month_gen_11;
      case 12:
        return l10n.month_gen_12;
      default:
        return '';
    }
  }

  /// Форматирует дату в формат «день месяц».
  static String formatDayMonth(DateTime date) {
    final day = date.day;
    final monthGen = getMonthGenitive(date.month);
    switch (_currentLanguage) {
      case AppLanguage.ru:
        return '$day $monthGen';
      case AppLanguage.en:
        return '$monthGen $day';
    }
  }

  /// Форматирует дату и время в человекочитаемый вид в зависимости от языка.
  static String formatDateTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '${formatDayMonthYear(date)}, $hours:$minutes';
  }

  /// День и месяц, а если год не текущий ([now] — для тестов) — и год:
  /// «5 марта» / «5 марта 2025».
  static String formatDayMonthYear(DateTime date, [DateTime? now]) {
    final dayMonth = formatDayMonth(date);
    if (date.year == (now ?? DateTime.now()).year) return dayMonth;
    switch (_currentLanguage) {
      case AppLanguage.ru:
        return '$dayMonth ${date.year}';
      case AppLanguage.en:
        return '$dayMonth, ${date.year}';
    }
  }

  /// Форматирует дату с опциональным временем.
  static String formatDate(DateTime date, {bool includeTime = true}) {
    if (includeTime) {
      return formatDateTime(date);
    }
    return formatDayMonth(date);
  }
}

/// Удобный доступ к строкам локализации через контекст.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
