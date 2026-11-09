// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get balance => 'Баланс';

  @override
  String get finances => 'Бюджет';

  @override
  String get insights => 'Талдау';

  @override
  String get profile => 'Профиль';

  @override
  String get interface => 'Интерфейс';

  @override
  String get currency => 'Валюта';

  @override
  String get language => 'Қолданба тілі';

  @override
  String get select_language => 'Тілді таңдау';

  @override
  String get theme_mode => 'Безендіру тақырыбы';

  @override
  String get theme_system => 'Жүйелік';

  @override
  String get theme_light => 'Ашық';

  @override
  String get theme_dark => 'Қараңғы';

  @override
  String get cloud => 'Бұлт';

  @override
  String get sync_status => 'Синхрондау күйі';

  @override
  String get logout => 'Тіркелгіден шығу';

  @override
  String get login_or_register => 'Кіру немесе тіркелу';

  @override
  String get login_btn_short => 'Кіру';

  @override
  String get local_profile => 'Жергілікті профиль';

  @override
  String get local_storage_warning =>
      'Деректер тек құрылғыңызда сақталады және қолданбаны өшірген кезде жойылады';

  @override
  String get cloud_backup_prompt => 'Резервтік көшіруді қосу үшін кіріңіз';

  @override
  String get select_currency => 'Валютаны таңдау';

  @override
  String get uzs_name => 'Өзбек сомы';

  @override
  String get kzt_name => 'Қазақстан теңгесі';

  @override
  String get eur_name => 'Еуро';

  @override
  String get usd_name => 'АҚШ доллары';

  @override
  String get cancel => 'Бас тарту';

  @override
  String get logout_confirm_title => 'Шығу';

  @override
  String get logout_confirm_desc =>
      'Тіркелгіден шыққыңыз келетініне сенімдісіз бе?';

  @override
  String get syncing => 'Синхрондау...';

  @override
  String get sync_success => 'Деректер сәтті синхрондалды';

  @override
  String get sync_updated_just_now => 'Жаңа ғана жаңартылды';

  @override
  String get sync_no_internet => 'Желі жоқ';

  @override
  String get no_internet_connection =>
      'Интернетке қосылым жоқ. Желіні тексеріп, әрекетті қайталаңыз.';

  @override
  String get sync_error => 'Синхрондау қатесі';

  @override
  String get logout_info => 'Сіз жүйеден шықтыңыз';

  @override
  String get transaction_deleted => 'Жазба жойылды';

  @override
  String get undo_action => 'Болдырмау';

  @override
  String get welcome_lang_title => 'Тілді таңдаңыз';

  @override
  String get welcome_lang_subtitle => 'Қолданбамен ыңғайлы жұмыс істеу үшін';

  @override
  String get welcome_currency_title => 'Негізгі валюта';

  @override
  String get welcome_currency_subtitle =>
      'Бұл валютада жалпы баланс пен бюджеттер есептеледі';

  @override
  String get continue_btn => 'Жалғастыру';

  @override
  String get month_total => 'Ай қорытындысы';

  @override
  String get expense_title => 'Шығыс';

  @override
  String get income_title => 'Кіріс';

  @override
  String get no_transactions => 'Осы айда жазбалар жоқ';

  @override
  String get delete_btn => 'Жою';

  @override
  String get new_transaction => 'Жаңа жазба';

  @override
  String get edit_transaction => 'Жазбаны өңдеу';

  @override
  String get amount_label => 'Сомасы';

  @override
  String get category_label => 'Санат';

  @override
  String get description_label => 'Сипаттама (міндетті емес)';

  @override
  String get add_btn => 'Жазба қосу';

  @override
  String get save_changes_btn => 'Өзгерістерді сақтау';

  @override
  String get amount_requirement_enter => 'Соманы көрсетіңіз';

  @override
  String get amount_requirement_positive => 'Сома 0-ден үлкен болуы керек';

  @override
  String amount_requirement_max(String max, String currency) {
    return 'Максимум: $max $currency';
  }

  @override
  String get budgets_title => 'Шығыс лимиттері';

  @override
  String get add_budget_title => 'Бюджет лимиті';

  @override
  String get edit_budget_title => 'Лимитті өңдеу';

  @override
  String get save_btn => 'Сақтау';

  @override
  String get budget_exceeded => 'Асып кетті';

  @override
  String get no_budgets_subtitle =>
      'Қаражаттың артық жұмсалуын бақылау үшін санаттар бойынша лимиттерді орнатыңыз.';

  @override
  String get insight_login_hint =>
      'Деректеріңіз негізінде жеке ұсыныстар алу үшін тіркелгіңізге кіріңіз.';

  @override
  String get insight_no_data =>
      'Талдау үшін әзірге деректер жеткіліксіз. Шығыстарды жазуды жалғастырыңыз!';

  @override
  String get no_network_title => 'Желіге қосылым жоқ';

  @override
  String get no_network_desc =>
      'Талдауды жаңарту интернетті қажет етеді. Қосылымды тексеріп, қайталау үшін экранды төмен тартыңыз.';

  @override
  String get insights_header_title => 'AI-Талдау';

  @override
  String get insights_assistants_busy_msg1 =>
      'Өкінішке қарай, біздің ақылды көмекшілеріміз қазір өте бос емес және деректерді талдай алмайды.';

  @override
  String get insights_assistants_busy_msg2 =>
      'Кеңестер алу үшін сәл кейінірек кіріңіз.';

  @override
  String get month_1 => 'Қаңтар';

  @override
  String get month_2 => 'Ақпан';

  @override
  String get month_3 => 'Наурыз';

  @override
  String get month_4 => 'Сәуір';

  @override
  String get month_5 => 'Мамыр';

  @override
  String get month_6 => 'Маусым';

  @override
  String get month_7 => 'Шілде';

  @override
  String get month_8 => 'Тамыз';

  @override
  String get month_9 => 'Қыркүйек';

  @override
  String get month_10 => 'Қазан';

  @override
  String get month_11 => 'Қараша';

  @override
  String get month_12 => 'Желтоқсан';

  @override
  String get month_label => 'Ай';

  @override
  String get no_description => 'Сипаттамасыз';

  @override
  String get today => 'Бүгін';

  @override
  String get login_error_title => 'Кіру қатесі';

  @override
  String get sync_login_required => 'Синхрондау үшін тіркелгіге кіріңіз';

  @override
  String get uzs_symbol => 'сом';

  @override
  String get category_food => 'Тамақтану';

  @override
  String get category_transport => 'Көлік';

  @override
  String get category_entertainment => 'Ойын-сауық';

  @override
  String get category_health => 'Денсаулық';

  @override
  String get category_subscriptions => 'Жазылымдар';

  @override
  String get category_shopping => 'Сатып алулар';

  @override
  String get category_salary => 'Жалақы';

  @override
  String get category_freelance => 'Фриланс';

  @override
  String get category_investments => 'Инвестициялар';

  @override
  String get category_transfers => 'Аударымдар';

  @override
  String get category_cashback => 'Кэшбэк';

  @override
  String get category_sales => 'Сатулар';

  @override
  String get category_other => 'Басқа';

  @override
  String get type_income => 'Кіріс';

  @override
  String get type_expense => 'Шығыс';

  @override
  String get dialog_ok => 'Түсінікті';

  @override
  String get session_expired_title => 'Сессия аяқталды';

  @override
  String get session_expired_desc =>
      'Жұмысты жалғастыру үшін тіркелгіңізге қайта кіріңіз.';

  @override
  String get server_error_general =>
      'Сервермен байланысу кезінде қате орын алды';

  @override
  String get http_400 => 'Қате сұрау';

  @override
  String get http_401 => 'Авторизация қажет';

  @override
  String get http_403 => 'Қолжетімділікке тыйым салынған';

  @override
  String get http_404 => 'Ресурс табылмады';

  @override
  String get http_429 =>
      'Сұраулар шегінен асып кетті. Кейінірек қайталап көріңіз.';

  @override
  String get rate_limit_exceeded_title => 'Сұраулар шегінен асып кетті';

  @override
  String rate_limit_countdown(int seconds) {
    return 'Қайталау уақыты: $seconds сек.';
  }

  @override
  String get rate_limit_ready => 'Қазір қайталап көре аласыз';

  @override
  String get http_500 => 'Сервердің ішкі қатесі';

  @override
  String get http_503 =>
      'Қызмет уақытша қолжетімсіз. Техникалық жұмыстар жүргізілуде';

  @override
  String get service_unavailable_title => 'Қызмет уақытша қолжетімсіз';

  @override
  String get service_unavailable_desc =>
      'Техникалық жұмыстар жүргізілуде. Кейінірек қайталап көріңіз.';

  @override
  String get service_unavailable_retry => 'Қайталау';

  @override
  String get startup_error_title => 'Қолданбаны іске қосу мүмкін болмады';

  @override
  String get startup_error_desc =>
      'Құрылғыдағы деректерді дайындау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get err_unexpected => 'Бірдеңе дұрыс болмады. Қайталап көріңіз.';

  @override
  String get server_error_code => 'Сервер қатесі';

  @override
  String get err_connection_timeout => 'Қосылымның күту уақыты аяқталды';

  @override
  String get err_send_timeout => 'Деректерді жіберу уақыты аяқталды';

  @override
  String get err_receive_timeout => 'Деректерді қабылдау уақыты аяқталды';

  @override
  String get err_connection_error =>
      'Интернет қосылымы жоқ немесе сервер қолжетімсіз';

  @override
  String get err_network_default => 'Желі қатесі: қосылымды тексеріңіз';

  @override
  String get pull_to_refresh => 'Жаңарту үшін төмен тартыңыз';

  @override
  String get release_to_refresh => 'Жаңарту үшін жіберіңіз';

  @override
  String get refreshing_data => 'Деректер жаңартылуда...';

  @override
  String get budget_deleted => 'Лимит жойылды';

  @override
  String get sync_synced => 'Деректер синхрондалды';

  @override
  String sync_pending(int count) {
    return 'Жіберілмеген: $count. Жіберу үшін басыңыз';
  }

  @override
  String sync_rejected_count(int count) {
    return 'Сервер қабылдамады: $count';
  }

  @override
  String get sync_rejected_title => 'Сервер қабылдамаған';

  @override
  String get sync_rejected_hint =>
      'Түзету үшін жазбаны басыңыз. Сақтағаннан кейін ол қайта жіберіледі.';

  @override
  String get sync_reject_invalid_currency =>
      'Сервер бұл валютаны қолдамайды немесе оның бағамын ала алмады';

  @override
  String get sync_reject_invalid_amount => 'Негізгі валютадағы сома тым үлкен';

  @override
  String get sync_reject_invalid_category =>
      'Сервер бұл санатты білмейді — басқасын таңдаңыз немесе қолданбаны жаңартыңыз';

  @override
  String get sync_reject_invalid_amount_range =>
      'Сома рұқсат етілген ауқымнан тыс';

  @override
  String get sync_reject_unknown => 'Сервер бұл жазбаны қабылдамады';

  @override
  String sync_done_with_rejected(int count) {
    return 'Синхрондалды, бірақ сервер қабылдамады: $count';
  }

  @override
  String get enter_amount => 'Соманы енгізіңіз';

  @override
  String get invalid_amount => 'Қате сома';

  @override
  String get max_amount_prefix => 'Ең көп сома';

  @override
  String get month_gen_1 => 'қаңтар';

  @override
  String get month_gen_2 => 'ақпан';

  @override
  String get month_gen_3 => 'наурыз';

  @override
  String get month_gen_4 => 'сәуір';

  @override
  String get month_gen_5 => 'мамыр';

  @override
  String get month_gen_6 => 'маусым';

  @override
  String get month_gen_7 => 'шілде';

  @override
  String get month_gen_8 => 'тамыз';

  @override
  String get month_gen_9 => 'қыркүйек';

  @override
  String get month_gen_10 => 'қазан';

  @override
  String get month_gen_11 => 'қараша';

  @override
  String get month_gen_12 => 'желтоқсан';

  @override
  String get terms_of_use_prefix => 'Жалғастыру арқылы сіз ';

  @override
  String get terms_of_use_link => 'Пайдалану шарттарымен';

  @override
  String get terms_of_use_and => ' және ';

  @override
  String get privacy_policy_link => 'Құпиялылық саясатымен';

  @override
  String get terms_of_use_suffix => ' келісесіз.';

  @override
  String get login_with_google => 'Google арқылы кіру';

  @override
  String get login_with_apple => 'Apple арқылы кіру';

  @override
  String get continue_with_google => 'Google арқылы жалғастырыңыз.';

  @override
  String get continue_with_apple => 'Apple ID арқылы жалғастырыңыз.';

  @override
  String get auth_social_error =>
      'Авторизация үзілді немесе қате орын алды. Қайталап көріңіз.';

  @override
  String get delete_account_title => 'Тіркелгіні жою';

  @override
  String get delete_account_confirm =>
      'Тіркелгіңізді және оған қатысты барлық деректерді біржола жойғыңыз келетініне сенімдісіз бе? Бұл әрекетті қайтару мүмкін емес.';

  @override
  String get delete_account_confirm_btn => 'Біржола жою';

  @override
  String get delete_account_btn => 'Тіркелгіні жою';

  @override
  String get delete_account_error => 'Тіркелгіні жою қатесі';

  @override
  String get profile_data_section => 'Деректер';

  @override
  String get delete_account_info_title => 'Аккаунт пен деректерді жою';

  @override
  String get delete_account_info_subtitle =>
      'Анықтама: аккаунтты қалай жоюға болады және қандай деректер жойылады';

  @override
  String get open_link_error => 'Сілтемені ашу мүмкін болмады';

  @override
  String get report_export_title => 'Есепті жүктеу';

  @override
  String get report_period_label => 'Кезең';

  @override
  String get report_period_year => 'Жыл';

  @override
  String get report_period_custom => 'Өз аралығы';

  @override
  String get report_format_label => 'Формат';

  @override
  String get report_save_action => 'Есепті жүктеу';

  @override
  String get report_share_action => 'Бөлісу';

  @override
  String get report_saved => 'Есеп сақталды';

  @override
  String get report_export_error => 'Есепті қалыптастыру мүмкін болмады';

  @override
  String get report_empty_period => 'Таңдалған кезеңде операциялар жоқ';

  @override
  String get report_feature_locked =>
      'Есептерді жүктеу жазылым арқылы қолжетімді';

  @override
  String get report_title => 'Қаржылық есеп';

  @override
  String get report_generated_at => 'Қалыптастырылған';

  @override
  String get report_summary => 'Қорытынды';

  @override
  String get report_total_income => 'Кірістер';

  @override
  String get report_total_expense => 'Шығыстар';

  @override
  String get report_period_result => 'Кезең нәтижесі';

  @override
  String get report_by_category => 'Санаттар бойынша шығыстар';

  @override
  String get report_share => 'Үлесі';

  @override
  String get report_limit => 'Лимит';

  @override
  String get report_spent => 'Жұмсалған';

  @override
  String get report_transactions => 'Операциялар';

  @override
  String get report_col_date => 'Күні';

  @override
  String get report_col_type => 'Түрі';

  @override
  String get report_col_category => 'Санат';

  @override
  String get report_col_description => 'Сипаттама';

  @override
  String get report_col_amount => 'Сома';

  @override
  String report_col_amount_base(String currency) {
    return '$currency сомасы';
  }

  @override
  String get logging_out => 'Шығу...';

  @override
  String get deleting => 'Жойылуда...';

  @override
  String get debug_menu_title => 'Баптау мәзірі';

  @override
  String get debug_environment => 'Орта';

  @override
  String debug_environment_changed(String env) {
    return 'Орта $env күйіне өзгертілді. Сессия қалпына келтірілді.';
  }

  @override
  String debug_environment_not_configured(String env) {
    return '$env үшін URL берілмеген. Қолданбаны --dart-define-from-file=.env арқылы іске қосыңыз';
  }

  @override
  String get debug_app_info => 'Қолданба туралы ақпарат';

  @override
  String debug_version(String version) {
    return 'Нұсқасы: $version';
  }

  @override
  String debug_base_url(String url) {
    return 'Негізгі URL: $url';
  }

  @override
  String get debug_tools => 'Құралдар';

  @override
  String get debug_open_logs => 'Журналдарды ашу (Talker)';

  @override
  String get debug_clear_cache => 'Кэш пен токендерді тазалау';

  @override
  String get debug_cache_cleared => 'Кэш пен токендер тазартылды';

  @override
  String version_label(String version) {
    return 'Нұсқасы $version';
  }

  @override
  String get yesterday => 'Кеше';

  @override
  String get pick_date => 'Күнді таңдау';

  @override
  String get date_label => 'Күні';

  @override
  String rate_updated_on(String date) {
    return '$date жаңартылды';
  }

  @override
  String get rate_approximate => 'шамамен бағам';

  @override
  String get more_categories => 'Тағы';

  @override
  String get all_categories => 'Барлық санаттар';

  @override
  String get category_search_hint => 'Санатты табу';

  @override
  String get search_nothing_found => 'Ештеңе табылмады';

  @override
  String get transaction_search_title => 'Іздеу';

  @override
  String get transaction_search_hint => 'Сипаттама немесе санат';

  @override
  String get search_clear => 'Тазалау';

  @override
  String get filter_all => 'Барлығы';

  @override
  String get filter_expenses => 'Шығыстар';

  @override
  String get filter_incomes => 'Кірістер';

  @override
  String get previous_month => 'Алдыңғы ай';

  @override
  String get next_month => 'Келесі ай';

  @override
  String get select_month => 'Айды таңдау';

  @override
  String get previous_year => 'Алдыңғы жыл';

  @override
  String get next_year => 'Келесі жыл';

  @override
  String get add_limit_btn => 'Қосу';

  @override
  String get insights_not_generated => 'Осы айдың AI-талдауы әлі жасалмаған.';

  @override
  String get insights_generate_btn => 'Талдау жасау';

  @override
  String get insights_future_month =>
      'Бұл ай әлі басталған жоқ — талдайтын ештеңе жоқ.';

  @override
  String get insights_no_transactions =>
      'Бұл айда операциялар жоқ — әзірге талдайтын ештеңе жоқ.';

  @override
  String get view_by_days => 'Күндер бойынша';

  @override
  String get view_by_categories => 'Санаттар бойынша';

  @override
  String get edit_btn => 'Өңдеу';

  @override
  String get details_original_amount => 'Чек сомасы';

  @override
  String get details_in_base_currency => 'Негізгі валютада';

  @override
  String get month_budget_title => 'Ай бюджеті';

  @override
  String get daily_allowance => 'Күніне жұмсауға болады';

  @override
  String days_left(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count күн қалды',
    );
    return '$_temp0';
  }

  @override
  String get budget_remaining => 'Қалды';

  @override
  String get budget_overspent => 'Асып кетті';

  @override
  String get budget_month_result => 'Лимиттер бойынша қорытынды';

  @override
  String get budget_planned => 'Жоспарланған';

  @override
  String get budget_all_categories_limited =>
      'Бұл айда барлық санаттарға лимит қойылған';

  @override
  String get add_limit_cta => 'Лимит қосу';

  @override
  String copy_limits_cta(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        'm1': 'Қаңтардан көшіру',
        'm2': 'Ақпаннан көшіру',
        'm3': 'Наурыздан көшіру',
        'm4': 'Сәуірден көшіру',
        'm5': 'Мамырдан көшіру',
        'm6': 'Маусымнан көшіру',
        'm7': 'Шілдеден көшіру',
        'm8': 'Тамыздан көшіру',
        'm9': 'Қыркүйектен көшіру',
        'm10': 'Қазаннан көшіру',
        'm11': 'Қарашадан көшіру',
        'm12': 'Желтоқсаннан көшіру',
        'other': 'Өткен айдан көшіру',
      },
    );
    return '$_temp0';
  }

  @override
  String budget_spent_of(String spent, String limit) {
    return '$limit ішінен $spent';
  }

  @override
  String get structure_title => 'Шығыстар құрылымы';

  @override
  String get structure_of_income => 'кірістен';

  @override
  String get structure_total_expenses => 'барлық шығын';

  @override
  String get structure_no_expenses => 'шығын жоқ';

  @override
  String get structure_no_expenses_month => 'Бұл айда шығыс жоқ';

  @override
  String structure_more_categories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'тағы $count санат',
    );
    return '$_temp0';
  }

  @override
  String get report_btn_short => 'Есеп';

  @override
  String get insights_outdated_note =>
      'Бұл есептен кейін деректер өзгерді — кеңестердегі сомалар қазіргімен сәйкес келмеуі мүмкін.';

  @override
  String get insights_outdated_refresh => 'Есепті жаңарту';

  @override
  String get insights_outdated_tomorrow =>
      'Жаңа есеп ертең қолжетімді болады: күндік жаңарту шегі таусылды.';

  @override
  String logout_unsynced_warning(int count) {
    return 'Серверге жіберілмеген: $count. Шыққанда бұл өзгерістер құрылғыдан жойылады. Бәрібір шығасыз ба?';
  }

  @override
  String operations_count(int count) {
    return '$count операция';
  }

  @override
  String get category_group_expand_hint => 'операцияларды көрсету';

  @override
  String get category_group_collapse_hint => 'операцияларды жасыру';

  @override
  String get app_lock_title => 'Қолданба құлпы';

  @override
  String get app_lock_subtitle => 'Саусақ ізі немесе телефонның экран құлпы';

  @override
  String get app_lock_prompt_title => 'GetBalance AI-ға кіру';

  @override
  String get app_lock_reason => 'Бұл сіз екеніңізді растаңыз';

  @override
  String get app_locked => 'Қолданба құлыпталған';

  @override
  String get app_unlock => 'Құлыпты ашу';

  @override
  String get app_lock_no_device_lock =>
      'Алдымен телефон баптауларында экран құлпын қосыңыз';

  @override
  String get app_lock_too_many_attempts =>
      'Әрекет тым көп. Кейінірек қайталаңыз';

  @override
  String get balance_hide => 'Сомаларды жасыру';

  @override
  String get balance_show => 'Сомаларды көрсету';
}
