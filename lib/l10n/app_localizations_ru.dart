// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get balance => 'Баланс';

  @override
  String get finances => 'Бюджет';

  @override
  String get insights => 'Аналитика';

  @override
  String get profile => 'Профиль';

  @override
  String get interface => 'Интерфейс';

  @override
  String get currency => 'Валюта';

  @override
  String get language => 'Язык приложения';

  @override
  String get select_language => 'Выбор языка';

  @override
  String get theme_mode => 'Тема оформления';

  @override
  String get theme_system => 'Системная';

  @override
  String get theme_light => 'Светлая';

  @override
  String get theme_dark => 'Темная';

  @override
  String get cloud => 'Облако';

  @override
  String get sync_status => 'Статус синхронизации';

  @override
  String get logout => 'Выйти из аккаунта';

  @override
  String get login_or_register => 'Войти или создать аккаунт';

  @override
  String get login_btn_short => 'Войти';

  @override
  String get local_profile => 'Локальный профиль';

  @override
  String get local_storage_warning =>
      'Данные хранятся только на вашем устройстве и удаляются при удалении приложения';

  @override
  String get cloud_backup_prompt => 'Войдите для включения резервной копии';

  @override
  String get select_currency => 'Выбор валюты';

  @override
  String get uzs_name => 'Узбекский сум';

  @override
  String get kzt_name => 'Казахстанский тенге';

  @override
  String get eur_name => 'Евро';

  @override
  String get usd_name => 'Доллар США';

  @override
  String get cancel => 'Отмена';

  @override
  String get logout_confirm_title => 'Выход';

  @override
  String get logout_confirm_desc => 'Вы уверены, что хотите выйти из аккаунта?';

  @override
  String get syncing => 'Синхронизация...';

  @override
  String get sync_success => 'Данные успешно синхронизированы';

  @override
  String get sync_updated_just_now => 'Обновлено только что';

  @override
  String get sync_no_internet => 'Нет сети';

  @override
  String get no_internet_connection =>
      'Нет подключения к интернету. Проверьте сеть и повторите попытку.';

  @override
  String get sync_error => 'Ошибка синхронизации';

  @override
  String get logout_info => 'Вы вышли из системы';

  @override
  String get transaction_deleted => 'Запись удалена';

  @override
  String get undo_action => 'Отменить';

  @override
  String get welcome_lang_title => 'Выберите язык';

  @override
  String get welcome_lang_subtitle => 'Для комфортной работы с приложением';

  @override
  String get welcome_currency_title => 'Основная валюта';

  @override
  String get welcome_currency_subtitle =>
      'В этой валюте рассчитывается общий баланс и бюджеты';

  @override
  String get continue_btn => 'Продолжить';

  @override
  String get month_total => 'Итог месяца';

  @override
  String get expense_title => 'Расход';

  @override
  String get income_title => 'Доход';

  @override
  String get no_transactions => 'Нет записей за этот месяц';

  @override
  String get delete_btn => 'Удалить';

  @override
  String get new_transaction => 'Новая запись';

  @override
  String get edit_transaction => 'Редактировать запись';

  @override
  String get amount_label => 'Сумма';

  @override
  String get category_label => 'Категория';

  @override
  String get description_label => 'Описание (необязательно)';

  @override
  String get add_btn => 'Добавить запись';

  @override
  String get save_changes_btn => 'Сохранить изменения';

  @override
  String get amount_requirement_enter => 'Укажите сумму';

  @override
  String get amount_requirement_positive => 'Сумма должна быть больше 0';

  @override
  String amount_requirement_max(String max, String currency) {
    return 'Максимум: $max $currency';
  }

  @override
  String get budgets_title => 'Лимиты расходов';

  @override
  String get add_budget_title => 'Лимит на бюджет';

  @override
  String get edit_budget_title => 'Редактировать лимит';

  @override
  String get save_btn => 'Сохранить';

  @override
  String get budget_exceeded => 'Превышен на';

  @override
  String get no_budgets_subtitle =>
      'Установите лимиты по категориям, чтобы контролировать перерасход средств.';

  @override
  String get insight_login_hint =>
      'Войдите в аккаунт, чтобы получить персональные рекомендации на основе ваших данных.';

  @override
  String get insight_no_data =>
      'Пока недостаточно данных для анализа. Продолжайте записывать расходы!';

  @override
  String get no_network_title => 'Нет подключения к сети';

  @override
  String get no_network_desc =>
      'Обновление аналитики требует интернета. Проверьте соединение и потяните экран вниз для повтора.';

  @override
  String get insights_header_title => 'AI-Аналитика';

  @override
  String get insights_assistants_busy_msg1 =>
      'К сожалению, наши умные помощники сейчас очень заняты и не могут проанализировать данные.';

  @override
  String get insights_assistants_busy_msg2 =>
      'Пожалуйста, загляните за советами немного позже.';

  @override
  String get month_1 => 'Январь';

  @override
  String get month_2 => 'Февраль';

  @override
  String get month_3 => 'Март';

  @override
  String get month_4 => 'Апрель';

  @override
  String get month_5 => 'Май';

  @override
  String get month_6 => 'Июнь';

  @override
  String get month_7 => 'Июль';

  @override
  String get month_8 => 'Август';

  @override
  String get month_9 => 'Сентябрь';

  @override
  String get month_10 => 'Октябрь';

  @override
  String get month_11 => 'Ноябрь';

  @override
  String get month_12 => 'Декабрь';

  @override
  String get month_label => 'Месяц';

  @override
  String get no_description => 'Без описания';

  @override
  String get today => 'Сегодня';

  @override
  String get login_error_title => 'Ошибка входа';

  @override
  String get sync_login_required => 'Войдите в аккаунт для синхронизации';

  @override
  String get uzs_symbol => 'сум';

  @override
  String get category_food => 'Питание';

  @override
  String get category_transport => 'Транспорт';

  @override
  String get category_entertainment => 'Развлечения';

  @override
  String get category_health => 'Здоровье';

  @override
  String get category_subscriptions => 'Подписки';

  @override
  String get category_shopping => 'Покупки';

  @override
  String get category_salary => 'Зарплата';

  @override
  String get category_freelance => 'Фриланс';

  @override
  String get category_investments => 'Инвестиции';

  @override
  String get category_transfers => 'Переводы';

  @override
  String get category_cashback => 'Кэшбэк';

  @override
  String get category_sales => 'Продажи';

  @override
  String get category_other => 'Другое';

  @override
  String get type_income => 'Доход';

  @override
  String get type_expense => 'Расход';

  @override
  String get dialog_ok => 'Понятно';

  @override
  String get session_expired_title => 'Сессия истекла';

  @override
  String get session_expired_desc =>
      'Пожалуйста, войдите в аккаунт снова для продолжения работы.';

  @override
  String get server_error_general => 'Произошла ошибка при связи с сервером';

  @override
  String get http_400 => 'Некорректный запрос';

  @override
  String get http_401 => 'Необходима авторизация';

  @override
  String get http_403 => 'Доступ запрещен';

  @override
  String get http_404 => 'Ресурс не найден';

  @override
  String get http_429 =>
      'Превышен лимит запросов. Пожалуйста, повторите попытку позже.';

  @override
  String get rate_limit_exceeded_title => 'Превышен лимит запросов';

  @override
  String rate_limit_countdown(int seconds) {
    return 'Повторите попытку через: $seconds сек.';
  }

  @override
  String get rate_limit_ready => 'Вы можете повторить попытку прямо сейчас';

  @override
  String get http_500 => 'Внутренняя ошибка сервера';

  @override
  String get http_503 =>
      'Сервис временно недоступен. Ведутся технические работы';

  @override
  String get service_unavailable_title => 'Сервис временно недоступен';

  @override
  String get service_unavailable_desc =>
      'Ведутся технические работы. Пожалуйста, повторите попытку позже.';

  @override
  String get service_unavailable_retry => 'Повторить попытку';

  @override
  String get startup_error_title => 'Не удалось запустить приложение';

  @override
  String get startup_error_desc =>
      'Не получилось подготовить данные на устройстве. Попробуйте ещё раз.';

  @override
  String get err_unexpected => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get server_error_code => 'Ошибка сервера';

  @override
  String get err_connection_timeout => 'Превышено время ожидания соединения';

  @override
  String get err_send_timeout => 'Превышено время отправки данных';

  @override
  String get err_receive_timeout => 'Превышено время получения данных';

  @override
  String get err_connection_error =>
      'Отсутствует интернет-соединение или сервер недоступен';

  @override
  String get err_network_default => 'Ошибка сети: проверьте подключение';

  @override
  String get pull_to_refresh => 'Потяните для обновления';

  @override
  String get release_to_refresh => 'Отпустите для обновления';

  @override
  String get refreshing_data => 'Обновление данных...';

  @override
  String get budget_deleted => 'Лимит удален';

  @override
  String get sync_synced => 'Данные синхронизированы';

  @override
  String sync_pending(int count) {
    return 'Не отправлено: $count. Нажмите, чтобы отправить';
  }

  @override
  String sync_rejected_count(int count) {
    return 'Сервер не принял: $count';
  }

  @override
  String get sync_rejected_title => 'Не принято сервером';

  @override
  String get sync_rejected_hint =>
      'Нажмите на запись, чтобы исправить её. После сохранения она отправится снова.';

  @override
  String get sync_reject_invalid_currency =>
      'Сервер не смог получить курс валюты';

  @override
  String get sync_reject_invalid_amount =>
      'Сумма в основной валюте слишком большая';

  @override
  String get sync_reject_unknown => 'Сервер не принял эту запись';

  @override
  String sync_done_with_rejected(int count) {
    return 'Синхронизировано, но сервер не принял: $count';
  }

  @override
  String get enter_amount => 'Введите сумму';

  @override
  String get invalid_amount => 'Некорректная сумма';

  @override
  String get max_amount_prefix => 'Макс. сумма';

  @override
  String get month_gen_1 => 'января';

  @override
  String get month_gen_2 => 'февраля';

  @override
  String get month_gen_3 => 'марта';

  @override
  String get month_gen_4 => 'апреля';

  @override
  String get month_gen_5 => 'мая';

  @override
  String get month_gen_6 => 'июня';

  @override
  String get month_gen_7 => 'июля';

  @override
  String get month_gen_8 => 'августа';

  @override
  String get month_gen_9 => 'сентября';

  @override
  String get month_gen_10 => 'октября';

  @override
  String get month_gen_11 => 'ноября';

  @override
  String get month_gen_12 => 'декабря';

  @override
  String get terms_of_use_prefix => 'Продолжая, вы соглашаетесь с ';

  @override
  String get terms_of_use_link => 'Условиями использования';

  @override
  String get terms_of_use_and => ' и ';

  @override
  String get privacy_policy_link => 'Политикой конфиденциальности';

  @override
  String get terms_of_use_suffix => '.';

  @override
  String get login_with_google => 'Войти с помощью Google';

  @override
  String get login_with_apple => 'Войти с помощью Apple';

  @override
  String get continue_with_google => 'Продолжите с помощью Google.';

  @override
  String get continue_with_apple => 'Продолжите с помощью Apple ID.';

  @override
  String get auth_social_error =>
      'Авторизация прервана или произошла ошибка. Пожалуйста, попробуйте снова.';

  @override
  String get delete_account_title => 'Удаление аккаунта';

  @override
  String get delete_account_confirm =>
      'Вы уверены, что хотите навсегда удалить свой аккаунт и все связанные с ним данные? Это действие невозможно отменить.';

  @override
  String get delete_account_confirm_btn => 'Удалить навсегда';

  @override
  String get delete_account_btn => 'Удалить аккаунт';

  @override
  String get delete_account_error => 'Ошибка удаления аккаунта';

  @override
  String get profile_data_section => 'Данные';

  @override
  String get delete_account_info_title => 'Удаление аккаунта и данных';

  @override
  String get delete_account_info_subtitle =>
      'Справка: как удалить аккаунт и какие данные удаляются';

  @override
  String get open_link_error => 'Не удалось открыть ссылку';

  @override
  String get report_export_title => 'Выгрузка отчёта';

  @override
  String get report_period_label => 'Период';

  @override
  String get report_period_year => 'Год';

  @override
  String get report_period_custom => 'Свой диапазон';

  @override
  String get report_format_label => 'Формат';

  @override
  String get report_save_action => 'Скачать отчёт';

  @override
  String get report_share_action => 'Поделиться';

  @override
  String get report_saved => 'Отчёт сохранён';

  @override
  String get report_export_error => 'Не удалось сформировать отчёт';

  @override
  String get report_empty_period => 'Нет операций за выбранный период';

  @override
  String get report_feature_locked => 'Выгрузка отчётов доступна по подписке';

  @override
  String get report_title => 'Финансовый отчёт';

  @override
  String get report_generated_at => 'Сформирован';

  @override
  String get report_summary => 'Сводка';

  @override
  String get report_total_income => 'Доходы';

  @override
  String get report_total_expense => 'Расходы';

  @override
  String get report_period_result => 'Итог периода';

  @override
  String get report_by_category => 'Расходы по категориям';

  @override
  String get report_share => 'Доля';

  @override
  String get report_limit => 'Лимит';

  @override
  String get report_spent => 'Потрачено';

  @override
  String get report_transactions => 'Операции';

  @override
  String get report_col_date => 'Дата';

  @override
  String get report_col_type => 'Тип';

  @override
  String get report_col_category => 'Категория';

  @override
  String get report_col_description => 'Описание';

  @override
  String get report_col_amount => 'Сумма';

  @override
  String report_col_amount_base(String currency) {
    return 'Сумма в $currency';
  }

  @override
  String get logging_out => 'Выход...';

  @override
  String get deleting => 'Удаление...';

  @override
  String get debug_menu_title => 'Меню отладки';

  @override
  String get debug_environment => 'Окружение';

  @override
  String debug_environment_changed(String env) {
    return 'Окружение изменено на $env. Сессия сброшена.';
  }

  @override
  String debug_environment_not_configured(String env) {
    return 'Для $env не задан URL. Запустите приложение с --dart-define-from-file=.env';
  }

  @override
  String get debug_app_info => 'Информация о приложении';

  @override
  String debug_version(String version) {
    return 'Версия: $version';
  }

  @override
  String debug_base_url(String url) {
    return 'Базовый URL: $url';
  }

  @override
  String get debug_tools => 'Инструменты';

  @override
  String get debug_open_logs => 'Открыть логи (Talker)';

  @override
  String get debug_clear_cache => 'Очистить кеш и токены';

  @override
  String get debug_cache_cleared => 'Кеш и токены очищены';

  @override
  String version_label(String version) {
    return 'Версия $version';
  }

  @override
  String get yesterday => 'Вчера';

  @override
  String get pick_date => 'Выбрать дату';

  @override
  String get date_label => 'Дата';

  @override
  String rate_updated_on(String date) {
    return 'обновлён $date';
  }

  @override
  String get rate_approximate => 'курс приблизительный';

  @override
  String get more_categories => 'Ещё';

  @override
  String get all_categories => 'Все категории';

  @override
  String get category_search_hint => 'Найти категорию';

  @override
  String get category_search_empty => 'Ничего не найдено';

  @override
  String get previous_month => 'Предыдущий месяц';

  @override
  String get next_month => 'Следующий месяц';

  @override
  String get select_month => 'Выбрать месяц';

  @override
  String get previous_year => 'Предыдущий год';

  @override
  String get next_year => 'Следующий год';

  @override
  String get add_limit_btn => 'Добавить';

  @override
  String get insights_not_generated =>
      'AI-анализ за этот месяц ещё не сформирован.';

  @override
  String get insights_generate_btn => 'Сформировать анализ';

  @override
  String get insights_future_month =>
      'Этот месяц ещё не наступил — анализировать пока нечего.';

  @override
  String get insights_no_transactions =>
      'За этот месяц нет операций — анализировать пока нечего.';

  @override
  String get view_by_days => 'По дням';

  @override
  String get view_by_categories => 'По категориям';

  @override
  String get edit_btn => 'Редактировать';

  @override
  String get details_original_amount => 'Сумма чека';

  @override
  String get details_in_base_currency => 'В основной валюте';

  @override
  String get month_budget_title => 'Бюджет месяца';

  @override
  String get daily_allowance => 'Можно тратить в день';

  @override
  String days_left(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count дня',
      many: 'Осталось $count дней',
      few: 'Осталось $count дня',
      one: 'Остался $count день',
    );
    return '$_temp0';
  }

  @override
  String get budget_limits_total => 'Лимиты';

  @override
  String get budget_spent => 'Траты';

  @override
  String get budget_remaining => 'Осталось';

  @override
  String get budget_overspent => 'Перерасход';

  @override
  String get budget_month_result => 'Итог по лимитам';

  @override
  String get budget_planned => 'Запланировано';

  @override
  String get budget_all_categories_limited =>
      'На все категории в этом месяце уже есть лимиты';

  @override
  String get add_limit_cta => 'Добавить лимит';

  @override
  String copy_limits_cta(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        'm1': 'Скопировать из января',
        'm2': 'Скопировать из февраля',
        'm3': 'Скопировать из марта',
        'm4': 'Скопировать из апреля',
        'm5': 'Скопировать из мая',
        'm6': 'Скопировать из июня',
        'm7': 'Скопировать из июля',
        'm8': 'Скопировать из августа',
        'm9': 'Скопировать из сентября',
        'm10': 'Скопировать из октября',
        'm11': 'Скопировать из ноября',
        'm12': 'Скопировать из декабря',
        'other': 'Скопировать из прошлого месяца',
      },
    );
    return '$_temp0';
  }

  @override
  String budget_spent_of(String spent, String limit) {
    return 'Потрачено: $spent из $limit';
  }

  @override
  String get structure_title => 'Структура расходов';

  @override
  String get structure_of_income => 'от дохода';

  @override
  String get structure_total_expenses => 'всего трат';

  @override
  String get structure_no_expenses => 'нет трат';

  @override
  String get structure_no_expenses_month => 'Расходов в этом месяце нет';

  @override
  String structure_more_categories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ещё $count категории',
      many: 'ещё $count категорий',
      few: 'ещё $count категории',
      one: 'ещё $count категория',
    );
    return '$_temp0';
  }

  @override
  String get report_btn_short => 'Отчёт';

  @override
  String get insights_outdated_note =>
      'Данные изменились после этого отчёта — суммы в советах могут не совпадать с текущими.';

  @override
  String get insights_outdated_refresh => 'Обновить отчёт';

  @override
  String get insights_outdated_tomorrow =>
      'Новый отчёт будет доступен завтра: дневной лимит обновлений исчерпан.';

  @override
  String logout_unsynced_warning(int count) {
    return 'Не отправлено на сервер: $count. При выходе эти изменения будут удалены с устройства. Всё равно выйти?';
  }

  @override
  String operations_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count операции',
      many: '$count операций',
      few: '$count операции',
      one: '$count операция',
    );
    return '$_temp0';
  }

  @override
  String get category_group_expand_hint => 'показать операции';

  @override
  String get category_group_collapse_hint => 'скрыть операции';
}
