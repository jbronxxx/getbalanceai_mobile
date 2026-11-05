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
  String get dark_mode => 'Tungi rejim';

  @override
  String get theme_mode => 'Mavzu';

  @override
  String get theme_system => 'Tizim';

  @override
  String get theme_light => 'Yorug\'';

  @override
  String get theme_dark => 'To\'q';

  @override
  String get soon => 'Yaqinda qo\'shiladi';

  @override
  String get notifications => 'Bildirishnomalar';

  @override
  String get limits_and_budgets => 'Limit va budjetlar';

  @override
  String get cloud => 'Bulut';

  @override
  String get sync_status => 'Sinxronizatsiya holati';

  @override
  String get cloud_not_connected => 'Hisobga kirgandan so\'ng mavjud';

  @override
  String get guest_mode => 'Mehmon rejimi';

  @override
  String get login_cloud_hint => 'Ma\'lumotlarni bulutda saqlash uchun kiring';

  @override
  String get logout => 'Hisobdan chiqish';

  @override
  String get login_or_register => 'Kirish yoki ro\'yxatdan o\'tish';

  @override
  String get login_btn_short => 'Kirish';

  @override
  String get local_profile => 'Mahalliy profil';

  @override
  String get offline_storage_desc => 'Ma\'lumotlar ushbu qurilmada saqlanadi';

  @override
  String get local_storage_warning =>
      'Ma\'lumotlar faqat qurilmangizda saqlanadi va ilova o\'chirilganda o\'chib ketadi';

  @override
  String get cloud_backup_prompt => 'Zaxira nusxalashni yoqish uchun kiring';

  @override
  String get user => 'Foydalanuvchi';

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
  String get sync_no_internet_alert =>
      'Sinxronizatsiya uchun tarmoqqa ulanish zarur';

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
  String get currency_rate_hint => 'kurs bo\'yicha';

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
  String get all_months => 'Barcha oylar';

  @override
  String get swipe_hint_text => 'O\'chirish uchun yozuvni chapga suring';

  @override
  String get delete_confirm_title => 'O\'chirish';

  @override
  String get delete_confirm_desc => 'Ushbu yozuvni o\'chirmoqchimisiz?';

  @override
  String get delete_btn => 'O\'chirish';

  @override
  String get today_prefix => 'Bugun';

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
  String get alert_valid_amount => 'To\'g\'ri summani kiriting';

  @override
  String get alert_amount_too_large => 'Summa juda katta, valyuta:';

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
  String get budget_amount_hint => 'Limit summasi';

  @override
  String get save_btn => 'Saqlash';

  @override
  String get budget_exceeded => 'Ortiqcha xarajat:';

  @override
  String get budget_out_of => 'dan';

  @override
  String get no_budgets_title => 'Budjetlar belgilanmagan';

  @override
  String get no_budgets_subtitle =>
      'Mablag\'larni nazorat qilish uchun kategoriyalar bo\'yicha limitlar belgilang.';

  @override
  String get alert_enter_budget_amount => 'Limit summasi kiriting';

  @override
  String get insights_screen_title => 'Tahlil va maslahatlar';

  @override
  String get insights_subtitle => 'Moliyangizning aqlli tahlili';

  @override
  String get insight_advice_title => 'Moliyaviy maslahat';

  @override
  String get insight_advice_desc =>
      'Daromad olgan kuningiz darhol kamida 10-15% qismini xavfsizlik yostig\'i uchun olib qo\'yishga harakat qiling.';

  @override
  String get insight_structure_title => 'Bir oylik xarajatlar tarkibi';

  @override
  String get insight_structure_empty =>
      'Xarajatlar tahlili uchun ma\'lumot yetarli emas. Yozuvlar qo\'shing.';

  @override
  String get insight_saving_title => 'Jamg\'arma darajasi';

  @override
  String get insight_saving_desc_positive =>
      'Ajoyib natija! Siz pul jamg\'armoqdasiz. Uzoq muddatli maqsadlarga erishish uchun shu tarzda davom eting.';

  @override
  String get insight_saving_desc_negative =>
      'Ushbu oyda xarajatlaringiz daromaddan oshib ketdi. Ixtiyoriy kategoriyalar limitlarini qayta ko\'rib chiqishni tavsiya etamiz.';

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
  String get personal_recs_title => 'Shaxsiy tavsiyalar';

  @override
  String get insights_updated_prefix => 'Yangilangan';

  @override
  String get insights_cache_hint =>
      'Maslahatlar yangi xarajatlar qo\'shilganda avtomatik ravishda yangilanadi';

  @override
  String get insights_assistants_busy => 'Aqlli yordamchilarimiz band';

  @override
  String get insights_assistants_busy_desc =>
      'Iltimos, qayta urinib ko\'ring yoki birozdan so\'ng kiring';

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
  String get select_period => 'Davrni tanlang';

  @override
  String get month_label => 'Oy';

  @override
  String get year_label => 'Yil';

  @override
  String get no_description => 'Tavsifsiz';

  @override
  String get today => 'Bugun';

  @override
  String get welcome_back => 'Qaytganingiz bilan!';

  @override
  String get create_account => 'Hisob yaratish';

  @override
  String get login_subtitle =>
      'Ma\'lumotlarni server bilan sinxronlash uchun kiring';

  @override
  String get register_subtitle =>
      'Bulutli xotiraga kirish uchun ro\'yxatdan o\'ting';

  @override
  String get name_label => 'Ism';

  @override
  String get email_label => 'Email';

  @override
  String get password_label => 'Parol';

  @override
  String get login_btn => 'Kirish';

  @override
  String get register_btn => 'Ro\'yxatdan o\'tish';

  @override
  String get no_account_prompt => 'Hisobingiz yo\'qmi? Ro\'yxatdan o\'ting';

  @override
  String get have_account_prompt => 'Sizda hisob bormi? Kiring';

  @override
  String get fill_all_fields => 'Barcha maydonlarni to\'ldiring';

  @override
  String get enter_name_alert => 'Ismingizni kiriting';

  @override
  String get auth_network_required =>
      'Kirish yoki ro\'yxatdan o\'tish uchun tarmoqqa ulanish zarur';

  @override
  String get login_error_title => 'Kirishda xatolik';

  @override
  String get register_error_title => 'Ro\'yxatdan o\'tishda xatolik';

  @override
  String get password_validation_error =>
      'Parol kamida bitta harf va bitta raqamdan iborat kamida 6 belgidan iborat bo\'lishi kerak';

  @override
  String get password_requirements_hint => 'Kamida 6 belgi (1 harf va 1 raqam)';

  @override
  String get password_too_long_bytes => 'Parol juda uzun (maks. 72 bayt)';

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
  String get rate_limit_countdown_prefix => 'Qayta urinish vaqti:';

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
  String get sync_network_required =>
      'Sinxronizatsiya uchun tarmoqqa ulanish zarur';

  @override
  String get sync_synced => 'Ma\'lumotlar sinxronlangan';

  @override
  String sync_pending(int count) {
    return 'Yuborilmagan: $count. Yuborish uchun bosing';
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
  String get report_period_month => 'Oy';

  @override
  String get report_period_year => 'Yil';

  @override
  String get report_period_custom => 'Oraliq tanlash';

  @override
  String get report_format_label => 'Format';

  @override
  String get report_exporting => 'Hisobot tayyorlanmoqda...';

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
  String debug_tap_hint(int count) {
    return 'Nosozliklarni tuzatish menyusini ochish uchun yana $count marta bosing';
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
  String get category_search_empty => 'Hech narsa topilmadi';

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
  String get budget_limits_total => 'Limitlar';

  @override
  String get budget_spent => 'Sarflandi';

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
  String budget_spent_of(String spent, String limit) {
    return 'Sarflandi: $limit dan $spent';
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
}
