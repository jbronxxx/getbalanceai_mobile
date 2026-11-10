// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get balance => 'Balans';

  @override
  String get finances => 'Byudjet';

  @override
  String get insights => 'Tahlil';

  @override
  String get profile => 'Profil';

  @override
  String get interface => 'Interfeys';

  @override
  String get currency => 'Valyuta';

  @override
  String get language => 'Ilova tili';

  @override
  String get select_language => 'Tilni tanlash';

  @override
  String get theme_mode => 'Mavzu';

  @override
  String get theme_system => 'Tizim';

  @override
  String get theme_light => 'Yorug\'';

  @override
  String get theme_dark => 'To\'q';

  @override
  String get cloud => 'Bulut';

  @override
  String get sync_status => 'Sinxronizatsiya holati';

  @override
  String get logout => 'Hisobdan chiqish';

  @override
  String get login_or_register => 'Kirish yoki ro\'yxatdan o\'tish';

  @override
  String get login_btn_short => 'Kirish';

  @override
  String get local_profile => 'Mahalliy profil';

  @override
  String get local_storage_warning =>
      'Ma\'lumotlar faqat qurilmangizda saqlanadi va ilova o\'chirilganda o\'chib ketadi';

  @override
  String get cloud_backup_prompt => 'Zaxira nusxalashni yoqish uchun kiring';

  @override
  String get select_currency => 'Valyutani tanlash';

  @override
  String get uzs_name => 'O\'zbek so\'mi';

  @override
  String get kzt_name => 'Qozog\'iston tengesi';

  @override
  String get eur_name => 'Evro';

  @override
  String get usd_name => 'AQSh dollari';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get logout_confirm_title => 'Chiqish';

  @override
  String get logout_confirm_desc => 'Hisobingizdan chiqmoqchimisiz?';

  @override
  String get syncing => 'Sinxronizatsiya...';

  @override
  String get sync_success => 'Ma\'lumotlar muvaffaqiyatli sinxronlandi';

  @override
  String get sync_updated_just_now => 'Hozirgina yangilandi';

  @override
  String get sync_no_internet => 'Tarmoq yo\'q';

  @override
  String get no_internet_connection =>
      'Internetga ulanish yo\'q. Tarmoqni tekshirib, qayta urinib ko\'ring.';

  @override
  String get sync_error => 'Sinxronizatsiya xatoligi';

  @override
  String get logout_info => 'Tizimdan chiqdingiz';

  @override
  String get transaction_deleted => 'Yozuv o\'chirildi';

  @override
  String get undo_action => 'Bekor qilish';

  @override
  String get welcome_lang_title => 'Tilni tanlang';

  @override
  String get welcome_lang_subtitle => 'Ilovadan qulay foydalanish uchun';

  @override
  String get welcome_currency_title => 'Asosiy valyuta';

  @override
  String get welcome_currency_subtitle =>
      'Umumiy balans va byudjetlar ushbu valyutada hisoblanadi';

  @override
  String get continue_btn => 'Davom etish';

  @override
  String get month_total => 'Oy yakuni';

  @override
  String get expense_title => 'Xarajat';

  @override
  String get income_title => 'Daromad';

  @override
  String get no_transactions => 'Bu oyda yozuvlar yo\'q';

  @override
  String get delete_btn => 'O\'chirish';

  @override
  String get new_transaction => 'Yangi yozuv';

  @override
  String get edit_transaction => 'Yozuvni tahrirlash';

  @override
  String get amount_label => 'Summa';

  @override
  String get category_label => 'Kategoriya';

  @override
  String get description_label => 'Tavsif (ixtiyoriy)';

  @override
  String get add_btn => 'Yozuvni qo\'shish';

  @override
  String get save_changes_btn => 'O\'zgarishlarni saqlash';

  @override
  String get amount_requirement_enter => 'Summani kiriting';

  @override
  String get amount_requirement_positive => 'Summa 0 dan katta bo\'lishi kerak';

  @override
  String amount_requirement_max(String max, String currency) {
    return 'Maksimal: $max $currency';
  }

  @override
  String get budgets_title => 'Xarajatlar limitlari';

  @override
  String get add_budget_title => 'Budjet limiti';

  @override
  String get edit_budget_title => 'Limitni tahrirlash';

  @override
  String get save_btn => 'Saqlash';

  @override
  String get budget_exceeded => 'Ortiqcha xarajat';

  @override
  String get no_budgets_subtitle =>
      'Mablag\'larni nazorat qilish uchun kategoriyalar bo\'yicha limitlar belgilang.';

  @override
  String get insight_login_hint =>
      'Ma\'lumotlaringiz asosida shaxsiy tavsiyalarni olish uchun hisobga kiring.';

  @override
  String get insight_no_data =>
      'Tahlil uchun hozircha ma\'lumot yetarli emas. Xarajatlarni yozishda davom eting!';

  @override
  String get no_network_title => 'Tarmoqqa ulanish yo\'q';

  @override
  String get no_network_desc =>
      'Tahlillarni yangilash uchun internet zarur. Ulanishni tekshiring va ekranni pastga torting.';

  @override
  String get insights_header_title => 'AI-Tahlil';

  @override
  String get insights_assistants_busy_msg1 =>
      'Afsuski, aqlli yordamchilarimiz hozir juda band va ma\'lumotlarni tahlil qila olmaydilar.';

  @override
  String get insights_assistants_busy_msg2 =>
      'Iltimos, maslahatlar uchun biroz keyinroq qaytib keling.';

  @override
  String get month_1 => 'Yanvar';

  @override
  String get month_2 => 'Fevral';

  @override
  String get month_3 => 'Mart';

  @override
  String get month_4 => 'Aprel';

  @override
  String get month_5 => 'May';

  @override
  String get month_6 => 'Iyun';

  @override
  String get month_7 => 'Iyul';

  @override
  String get month_8 => 'Avgust';

  @override
  String get month_9 => 'Sentabr';

  @override
  String get month_10 => 'Oktabr';

  @override
  String get month_11 => 'Noyabr';

  @override
  String get month_12 => 'Dekabr';

  @override
  String get month_label => 'Oy';

  @override
  String get no_description => 'Tavsifsiz';

  @override
  String get today => 'Bugun';

  @override
  String get login_error_title => 'Kirishda xatolik';

  @override
  String get sync_login_required => 'Sinxronizatsiya uchun hisobga kiring';

  @override
  String get uzs_symbol => 'so\'m';

  @override
  String get category_food => 'Oziq-ovqat';

  @override
  String get category_transport => 'Transport';

  @override
  String get category_entertainment => 'O\'yin-kulgi';

  @override
  String get category_health => 'Sog\'liq';

  @override
  String get category_subscriptions => 'Obunalar';

  @override
  String get category_shopping => 'Xaridlar';

  @override
  String get category_housing => 'Uy-joy, kommunal';

  @override
  String get category_communication => 'Aloqa';

  @override
  String get category_education => 'Ta\'lim';

  @override
  String get category_family => 'Oila';

  @override
  String get category_car => 'Avtomobil';

  @override
  String get category_gifts => 'Sovg\'alar';

  @override
  String get category_travel => 'Sayohat';

  @override
  String get category_beauty => 'Go\'zallik';

  @override
  String get category_salary => 'Maosh';

  @override
  String get category_freelance => 'Frilans';

  @override
  String get category_investments => 'Investitsiyalar';

  @override
  String get category_transfers => 'O\'tkazmalar';

  @override
  String get category_cashback => 'Keshbek';

  @override
  String get category_sales => 'Sotuvlar';

  @override
  String get category_other => 'Boshqa';

  @override
  String get type_income => 'Daromad';

  @override
  String get type_expense => 'Xarajat';

  @override
  String get dialog_ok => 'Tushunarli';

  @override
  String get session_expired_title => 'Sessiya tugadi';

  @override
  String get session_expired_desc =>
      'Davom etish uchun hisobingizga qayta kiring.';

  @override
  String get server_error_general =>
      'Server bilan bog\'lanishda xatolik yuz berdi';

  @override
  String get http_400 => 'Noto\'g\'ri so\'rov';

  @override
  String get http_401 => 'Avtorizatsiya talab qilinadi';

  @override
  String get http_403 => 'Ruxsat berilmagan';

  @override
  String get http_404 => 'Manba topilmadi';

  @override
  String get http_429 =>
      'So‘rovlar chegarasi oshib ketdi. Iltimos, keyinroq qayta urinib ko‘ring.';

  @override
  String get rate_limit_exceeded_title => 'So‘rovlar chegarasi oshib ketdi';

  @override
  String rate_limit_countdown(int seconds) {
    return 'Qayta urinish vaqti: $seconds soniya';
  }

  @override
  String get rate_limit_ready => 'Endi qayta urinib ko‘rishingiz mumkin';

  @override
  String get http_500 => 'Serverning ichki xatoligi';

  @override
  String get http_503 =>
      'Xizmat vaqtincha ishlamayapti. Texnik ishlar olib borilmoqda';

  @override
  String get service_unavailable_title => 'Xizmat vaqtincha ishlamayapti';

  @override
  String get service_unavailable_desc =>
      'Texnik ishlar olib borilmoqda. Iltimos, keyinroq qayta urinib ko‘ring.';

  @override
  String get service_unavailable_retry => 'Qayta urinish';

  @override
  String get startup_error_title => 'Ilovani ishga tushirib bo\'lmadi';

  @override
  String get startup_error_desc =>
      'Qurilmadagi ma\'lumotlarni tayyorlab bo\'lmadi. Qaytadan urinib ko\'ring.';

  @override
  String get err_unexpected => 'Nimadir xato ketdi. Qaytadan urinib ko\'ring.';

  @override
  String get server_error_code => 'Server xatoligi';

  @override
  String get err_connection_timeout => 'Ulanish vaqti tugadi';

  @override
  String get err_send_timeout => 'Ma\'lumot jo\'natish vaqti tugadi';

  @override
  String get err_receive_timeout => 'Ma\'lumot qabul qilish vaqti tugadi';

  @override
  String get err_connection_error => 'Internet ulanishi yo\'q yoki server band';

  @override
  String get err_network_default => 'Tarmoq xatoligi: ulanishni tekshiring';

  @override
  String get pull_to_refresh => 'Yangilash uchun torting';

  @override
  String get release_to_refresh => 'Yangilash uchun qo\'yib yuboring';

  @override
  String get refreshing_data => 'Ma\'lumotlar yangilanmoqda...';

  @override
  String get budget_deleted => 'Limit o\'chirildi';

  @override
  String get sync_synced => 'Ma\'lumotlar sinxronlangan';

  @override
  String sync_pending(int count) {
    return 'Yuborilmagan: $count. Yuborish uchun bosing';
  }

  @override
  String sync_rejected_count(int count) {
    return 'Server qabul qilmadi: $count';
  }

  @override
  String get sync_rejected_title => 'Server qabul qilmagan';

  @override
  String get sync_rejected_hint =>
      'Tuzatish uchun yozuvni bosing. Saqlangandan keyin u qayta yuboriladi.';

  @override
  String get sync_reject_invalid_currency =>
      'Server bu valyutani qo\'llamaydi yoki uning kursini ololmadi';

  @override
  String get sync_reject_invalid_amount =>
      'Asosiy valyutadagi summa juda katta';

  @override
  String get sync_reject_invalid_category =>
      'Server bu kategoriyani bilmaydi — boshqasini tanlang yoki ilovani yangilang';

  @override
  String get sync_reject_invalid_amount_range =>
      'Summa ruxsat etilgan oraliqdan tashqarida';

  @override
  String get sync_reject_unknown => 'Server bu yozuvni qabul qilmadi';

  @override
  String sync_done_with_rejected(int count) {
    return 'Sinxronlandi, lekin server qabul qilmadi: $count';
  }

  @override
  String get enter_amount => 'Summani kiriting';

  @override
  String get invalid_amount => 'Noto\'g\'ri summa';

  @override
  String get max_amount_prefix => 'Maksimal summa';

  @override
  String get month_gen_1 => 'yanvar';

  @override
  String get month_gen_2 => 'fevral';

  @override
  String get month_gen_3 => 'mart';

  @override
  String get month_gen_4 => 'aprel';

  @override
  String get month_gen_5 => 'may';

  @override
  String get month_gen_6 => 'iyun';

  @override
  String get month_gen_7 => 'iyul';

  @override
  String get month_gen_8 => 'avgust';

  @override
  String get month_gen_9 => 'sentabr';

  @override
  String get month_gen_10 => 'oktabr';

  @override
  String get month_gen_11 => 'noyabr';

  @override
  String get month_gen_12 => 'dekabr';

  @override
  String get terms_of_use_prefix => 'Davom etish orqali siz ';

  @override
  String get terms_of_use_link => 'Foydalanish shartlari';

  @override
  String get terms_of_use_and => ' va ';

  @override
  String get privacy_policy_link => 'Maxfiylik siyosati';

  @override
  String get terms_of_use_suffix => 'ga rozilik bildirasiz.';

  @override
  String get login_with_google => 'Google orqali kirish';

  @override
  String get login_with_apple => 'Apple orqali kirish';

  @override
  String get continue_with_google => 'Google orqali davom eting.';

  @override
  String get continue_with_apple => 'Apple ID orqali davom eting.';

  @override
  String get auth_social_error =>
      'Avtorizatsiya bekor qilindi yoki xatolik yuz berdi. Iltimos, qaytadan urinib ko\'ring.';

  @override
  String get delete_account_title => 'Hisobni o\'chirish';

  @override
  String get delete_account_confirm =>
      'Haqiqatan ham hisobingizni va barcha bog\'liq ma\'lumotlarni butunlay o\'chirib tashlamoqchimisiz? Ushbu amalni bekor qilib bo\'lmaydi.';

  @override
  String get delete_account_confirm_btn => 'Butunlay o\'chirish';

  @override
  String get delete_account_btn => 'Hisobni o\'chirish';

  @override
  String get delete_account_error => 'Hisobni o\'chirishda xatolik';

  @override
  String get profile_data_section => 'Ma’lumotlar';

  @override
  String get delete_account_info_title => 'Hisob va ma’lumotlarni o‘chirish';

  @override
  String get delete_account_info_subtitle =>
      'Ma’lumot: hisobni qanday o‘chirish va qaysi ma’lumotlar o‘chiriladi';

  @override
  String get open_link_error => 'Havolani ochib bo‘lmadi';

  @override
  String get report_export_title => 'Hisobotni yuklab olish';

  @override
  String get report_period_label => 'Davr';

  @override
  String get report_period_year => 'Yil';

  @override
  String get report_period_custom => 'Oraliq tanlash';

  @override
  String get report_format_label => 'Format';

  @override
  String get report_save_action => 'Hisobotni yuklab olish';

  @override
  String get report_share_action => 'Ulashish';

  @override
  String get report_saved => 'Hisobot saqlandi';

  @override
  String get report_export_error => 'Hisobotni yaratib bo\'lmadi';

  @override
  String get report_empty_period => 'Tanlangan davrda operatsiyalar yo\'q';

  @override
  String get report_feature_locked =>
      'Hisobotlarni yuklab olish obuna orqali mavjud';

  @override
  String get report_title => 'Moliyaviy hisobot';

  @override
  String get report_generated_at => 'Yaratilgan';

  @override
  String get report_summary => 'Xulosa';

  @override
  String get report_total_income => 'Daromadlar';

  @override
  String get report_total_expense => 'Xarajatlar';

  @override
  String get report_period_result => 'Davr natijasi';

  @override
  String get report_by_category => 'Toifalar bo\'yicha xarajatlar';

  @override
  String get report_share => 'Ulushi';

  @override
  String get report_limit => 'Limit';

  @override
  String get report_spent => 'Sarflangan';

  @override
  String get report_transactions => 'Operatsiyalar';

  @override
  String get report_col_date => 'Sana';

  @override
  String get report_col_type => 'Turi';

  @override
  String get report_col_category => 'Toifa';

  @override
  String get report_col_description => 'Tavsif';

  @override
  String get report_col_amount => 'Summa';

  @override
  String report_col_amount_base(String currency) {
    return 'Summa ($currency)';
  }

  @override
  String get logging_out => 'Chiqilmoqda...';

  @override
  String get deleting => 'O\'chirilmoqda...';

  @override
  String get debug_menu_title => 'Nosozliklarni tuzatish menyusi';

  @override
  String get debug_environment => 'Muhit';

  @override
  String debug_environment_changed(String env) {
    return 'Muhit $env ga o\'zgartirildi. Sessiya qayta tiklandi.';
  }

  @override
  String debug_environment_not_configured(String env) {
    return '$env uchun URL berilmagan. Ilovani --dart-define-from-file=.env bilan ishga tushiring';
  }

  @override
  String get debug_app_info => 'Ilova ma\'lumotlari';

  @override
  String debug_version(String version) {
    return 'Versiya: $version';
  }

  @override
  String debug_base_url(String url) {
    return 'Asosiy URL: $url';
  }

  @override
  String get debug_tools => 'Asboblar';

  @override
  String get debug_open_logs => 'Jurnallarni ochish (Talker)';

  @override
  String get debug_clear_cache => 'Kesh va tokenlarni tozalash';

  @override
  String get debug_cache_cleared => 'Kesh va tokenlar tozalandi';

  @override
  String version_label(String version) {
    return 'Versiya $version';
  }

  @override
  String get yesterday => 'Kecha';

  @override
  String get pick_date => 'Sanani tanlash';

  @override
  String get date_label => 'Sana';

  @override
  String rate_updated_on(String date) {
    return '$date yangilangan';
  }

  @override
  String get rate_approximate => 'taxminiy kurs';

  @override
  String get more_categories => 'Yana';

  @override
  String get all_categories => 'Barcha toifalar';

  @override
  String get category_search_hint => 'Toifani topish';

  @override
  String get search_nothing_found => 'Hech narsa topilmadi';

  @override
  String get transaction_search_title => 'Qidiruv';

  @override
  String get transaction_search_hint => 'Tavsif yoki kategoriya';

  @override
  String get search_clear => 'Tozalash';

  @override
  String get filter_all => 'Barchasi';

  @override
  String get filter_expenses => 'Xarajatlar';

  @override
  String get filter_incomes => 'Daromadlar';

  @override
  String get previous_month => 'Oldingi oy';

  @override
  String get next_month => 'Keyingi oy';

  @override
  String get select_month => 'Oyni tanlash';

  @override
  String get previous_year => 'Oldingi yil';

  @override
  String get next_year => 'Keyingi yil';

  @override
  String get add_limit_btn => 'Qo\'shish';

  @override
  String get insights_not_generated =>
      'Bu oy uchun AI-tahlil hali tayyorlanmagan.';

  @override
  String get insights_generate_btn => 'Tahlil tayyorlash';

  @override
  String get insights_future_month =>
      'Bu oy hali boshlanmagan — tahlil qiladigan narsa yo\'q.';

  @override
  String get insights_no_transactions =>
      'Bu oyda operatsiyalar yo\'q — hozircha tahlil qiladigan narsa yo\'q.';

  @override
  String get view_by_days => 'Kunlar bo\'yicha';

  @override
  String get view_by_categories => 'Toifalar bo\'yicha';

  @override
  String get edit_btn => 'Tahrirlash';

  @override
  String get details_original_amount => 'Chek summasi';

  @override
  String get details_in_base_currency => 'Asosiy valyutada';

  @override
  String get month_budget_title => 'Oy byudjeti';

  @override
  String get daily_allowance => 'Kuniga sarflash mumkin';

  @override
  String days_left(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kun qoldi',
    );
    return '$_temp0';
  }

  @override
  String get budget_remaining => 'Qoldi';

  @override
  String get budget_overspent => 'Ortiqcha sarf';

  @override
  String get budget_month_result => 'Limitlar bo\'yicha yakun';

  @override
  String get budget_planned => 'Rejalashtirilgan';

  @override
  String get budget_all_categories_limited =>
      'Bu oyda barcha toifalarga limit qo\'yilgan';

  @override
  String get add_limit_cta => 'Limit qo\'shish';

  @override
  String copy_limits_cta(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        'm1': 'Yanvardan nusxalash',
        'm2': 'Fevraldan nusxalash',
        'm3': 'Martdan nusxalash',
        'm4': 'Apreldan nusxalash',
        'm5': 'Maydan nusxalash',
        'm6': 'Iyundan nusxalash',
        'm7': 'Iyuldan nusxalash',
        'm8': 'Avgustdan nusxalash',
        'm9': 'Sentabrdan nusxalash',
        'm10': 'Oktabrdan nusxalash',
        'm11': 'Noyabrdan nusxalash',
        'm12': 'Dekabrdan nusxalash',
        'other': 'O\'tgan oydan nusxalash',
      },
    );
    return '$_temp0';
  }

  @override
  String budget_spent_of(String spent, String limit) {
    return '$limit dan $spent';
  }

  @override
  String get structure_title => 'Xarajatlar tarkibi';

  @override
  String get structure_of_income => 'daromaddan';

  @override
  String get structure_total_expenses => 'jami xarajat';

  @override
  String get structure_no_expenses => 'xarajat yo\'q';

  @override
  String get structure_no_expenses_month => 'Bu oyda xarajatlar yo\'q';

  @override
  String structure_more_categories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'yana $count toifa',
    );
    return '$_temp0';
  }

  @override
  String get report_btn_short => 'Hisobot';

  @override
  String get insights_outdated_note =>
      'Ushbu hisobotdan keyin ma\'lumotlar o\'zgardi — maslahatlardagi summalar joriylaridan farq qilishi mumkin.';

  @override
  String get insights_outdated_refresh => 'Hisobotni yangilash';

  @override
  String get insights_outdated_tomorrow =>
      'Yangi hisobot ertaga mavjud bo\'ladi: kunlik yangilash limiti tugadi.';

  @override
  String logout_unsynced_warning(int count) {
    return 'Serverga yuborilmagan: $count. Chiqishda bu o\'zgarishlar qurilmadan o\'chiriladi. Baribir chiqasizmi?';
  }

  @override
  String operations_count(int count) {
    return '$count ta operatsiya';
  }

  @override
  String get category_group_expand_hint => 'operatsiyalarni ko\'rsatish';

  @override
  String get category_group_collapse_hint => 'operatsiyalarni yashirish';

  @override
  String get app_lock_title => 'Ilova qulfi';

  @override
  String get app_lock_subtitle => 'Barmoq izi yoki telefon ekran qulfi';

  @override
  String get app_lock_prompt_title => 'GetBalance AI ga kirish';

  @override
  String get app_lock_reason => 'Bu siz ekanligingizni tasdiqlang';

  @override
  String get app_locked => 'Ilova qulflangan';

  @override
  String get app_unlock => 'Qulfni ochish';

  @override
  String get app_lock_no_device_lock =>
      'Avval telefon sozlamalarida ekran qulfini yoqing';

  @override
  String get app_lock_too_many_attempts =>
      'Urinishlar juda ko\'p. Keyinroq qayta urinib ko\'ring';

  @override
  String get balance_hide => 'Summalarni yashirish';

  @override
  String get balance_show => 'Summalarni ko\'rsatish';

  @override
  String get edit_name_title => 'Ismingiz';

  @override
  String get edit_name_label => 'Ism';

  @override
  String get edit_name_tooltip => 'Ismni o\'zgartirish';

  @override
  String get edit_name_error => 'Ismni saqlab bo\'lmadi';

  @override
  String get recurring_every_month => 'Har oy';

  @override
  String recurring_every_day(int day) {
    return 'Har oy, $day-kun';
  }

  @override
  String get recurring_end_none => 'Muddatsiz';

  @override
  String recurring_end_until(String date) {
    return '$date gacha';
  }

  @override
  String recurring_end_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta to\'lov',
    );
    return '$_temp0';
  }

  @override
  String get recurring_end_title => 'Qancha takrorlash';

  @override
  String get recurring_end_pick_date => 'Tugash sanasini tanlash';

  @override
  String get recurring_add_btn => 'Doimiy qo\'shish';

  @override
  String get recurring_expected => 'Kutilmoqda';

  @override
  String get recurring_not_paid => 'To\'lanmagan';

  @override
  String get recurring_payment_title => 'Doimiy to\'lov';

  @override
  String get recurring_income_title => 'Doimiy daromad';

  @override
  String get recurring_pay_title => 'To\'lovni belgilash';

  @override
  String get recurring_receive_title => 'Olinganini belgilash';

  @override
  String get recurring_paid_btn => 'To\'landi';

  @override
  String get recurring_received_btn => 'Olindi';

  @override
  String get recurring_skip_btn => 'Bu oyni o\'tkazish';

  @override
  String get recurring_stop_btn => 'To\'xtatish';

  @override
  String get recurring_skipped_toast => 'Bu oyda o\'tkazildi';

  @override
  String get recurring_stopped_toast => 'Doimiy to\'lov to\'xtatildi';

  @override
  String get recurring_repeat_label => 'Takrorlash';

  @override
  String get recurring_due_label => 'To\'lov sanasi';

  @override
  String recurring_progress(int number, int total) {
    return '$total tadan $number-to\'lov';
  }

  @override
  String daily_allowance_reserved(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta to\'lov hisobga olingan · $amount',
    );
    return '$_temp0';
  }

  @override
  String get reminder_channel_name => 'Doimiy to\'lovlar';

  @override
  String get reminder_channel_description =>
      'Doimiy to\'lov yoki daromad kunida eslatma';

  @override
  String reminder_payment_title(String name) {
    return 'Bugun to\'lov: $name';
  }

  @override
  String reminder_income_title(String name) {
    return 'Bugun kutilmoqda: $name';
  }

  @override
  String reminder_payment_body(String amount) {
    return '$amount — to\'lovni belgilash uchun bosing';
  }

  @override
  String reminder_income_body(String amount) {
    return '$amount — olinganini belgilash uchun bosing';
  }

  @override
  String get debug_test_reminder => '10 soniyadan keyin eslatma';

  @override
  String get debug_reminder_scheduled =>
      'Eslatma 10 soniyadan keyin keladi — ilovani yopish mumkin';

  @override
  String get debug_reminder_none => 'Kutilayotgan doimiy to\'lovlar yo\'q';
}
