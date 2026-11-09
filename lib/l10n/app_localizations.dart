import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
    Locale('uz')
  ];

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @finances.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get finances;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get insights;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @interface.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get interface;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get language;

  /// No description provided for @select_language.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get select_language;

  /// No description provided for @theme_mode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme_mode;

  /// No description provided for @theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get theme_system;

  /// No description provided for @theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// No description provided for @theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @sync_status.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get sync_status;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @login_or_register.
  ///
  /// In en, this message translates to:
  /// **'Log In or Register'**
  String get login_or_register;

  /// No description provided for @login_btn_short.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login_btn_short;

  /// No description provided for @local_profile.
  ///
  /// In en, this message translates to:
  /// **'Local Profile'**
  String get local_profile;

  /// No description provided for @local_storage_warning.
  ///
  /// In en, this message translates to:
  /// **'Data is stored only on your device and is deleted when the app is uninstalled'**
  String get local_storage_warning;

  /// No description provided for @cloud_backup_prompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to enable cloud backup'**
  String get cloud_backup_prompt;

  /// No description provided for @select_currency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get select_currency;

  /// No description provided for @uzs_name.
  ///
  /// In en, this message translates to:
  /// **'Uzbek Som'**
  String get uzs_name;

  /// No description provided for @kzt_name.
  ///
  /// In en, this message translates to:
  /// **'Kazakhstani Tenge'**
  String get kzt_name;

  /// No description provided for @eur_name.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get eur_name;

  /// No description provided for @usd_name.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get usd_name;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @logout_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout_confirm_title;

  /// No description provided for @logout_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logout_confirm_desc;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @sync_success.
  ///
  /// In en, this message translates to:
  /// **'Data synced successfully'**
  String get sync_success;

  /// No description provided for @sync_updated_just_now.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get sync_updated_just_now;

  /// No description provided for @sync_no_internet.
  ///
  /// In en, this message translates to:
  /// **'No Network'**
  String get sync_no_internet;

  /// No description provided for @no_internet_connection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get no_internet_connection;

  /// No description provided for @sync_error.
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get sync_error;

  /// No description provided for @logout_info.
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get logout_info;

  /// No description provided for @transaction_deleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transaction_deleted;

  /// No description provided for @undo_action.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo_action;

  /// No description provided for @welcome_lang_title.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get welcome_lang_title;

  /// No description provided for @welcome_lang_subtitle.
  ///
  /// In en, this message translates to:
  /// **'For a comfortable experience with the app'**
  String get welcome_lang_subtitle;

  /// No description provided for @welcome_currency_title.
  ///
  /// In en, this message translates to:
  /// **'Main Currency'**
  String get welcome_currency_title;

  /// No description provided for @welcome_currency_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Total balance and budgets are calculated in this currency'**
  String get welcome_currency_subtitle;

  /// No description provided for @continue_btn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_btn;

  /// No description provided for @month_total.
  ///
  /// In en, this message translates to:
  /// **'Month total'**
  String get month_total;

  /// No description provided for @expense_title.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense_title;

  /// No description provided for @income_title.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income_title;

  /// No description provided for @no_transactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this month'**
  String get no_transactions;

  /// No description provided for @delete_btn.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete_btn;

  /// No description provided for @new_transaction.
  ///
  /// In en, this message translates to:
  /// **'New Transaction'**
  String get new_transaction;

  /// No description provided for @edit_transaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get edit_transaction;

  /// No description provided for @amount_label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount_label;

  /// No description provided for @category_label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category_label;

  /// No description provided for @description_label.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get description_label;

  /// No description provided for @add_btn.
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get add_btn;

  /// No description provided for @save_changes_btn.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get save_changes_btn;

  /// No description provided for @amount_requirement_enter.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get amount_requirement_enter;

  /// No description provided for @amount_requirement_positive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than 0'**
  String get amount_requirement_positive;

  /// No description provided for @amount_requirement_max.
  ///
  /// In en, this message translates to:
  /// **'Max: {max} {currency}'**
  String amount_requirement_max(String max, String currency);

  /// No description provided for @budgets_title.
  ///
  /// In en, this message translates to:
  /// **'Expense Budgets'**
  String get budgets_title;

  /// No description provided for @add_budget_title.
  ///
  /// In en, this message translates to:
  /// **'Set Budget Limit'**
  String get add_budget_title;

  /// No description provided for @edit_budget_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Budget Limit'**
  String get edit_budget_title;

  /// No description provided for @save_btn.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_btn;

  /// No description provided for @budget_exceeded.
  ///
  /// In en, this message translates to:
  /// **'Exceeded by'**
  String get budget_exceeded;

  /// No description provided for @no_budgets_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Set limits by category to avoid overspending.'**
  String get no_budgets_subtitle;

  /// No description provided for @insight_login_hint.
  ///
  /// In en, this message translates to:
  /// **'Log in to get personalized recommendations based on your data.'**
  String get insight_login_hint;

  /// No description provided for @insight_no_data.
  ///
  /// In en, this message translates to:
  /// **'Not enough data for analysis yet. Keep recording expenses!'**
  String get insight_no_data;

  /// No description provided for @no_network_title.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get no_network_title;

  /// No description provided for @no_network_desc.
  ///
  /// In en, this message translates to:
  /// **'Updating analytics requires internet. Check your connection and pull down to retry.'**
  String get no_network_desc;

  /// No description provided for @insights_header_title.
  ///
  /// In en, this message translates to:
  /// **'AI Analytics'**
  String get insights_header_title;

  /// No description provided for @insights_assistants_busy_msg1.
  ///
  /// In en, this message translates to:
  /// **'Unfortunately, our smart assistants are currently very busy and cannot analyze the data.'**
  String get insights_assistants_busy_msg1;

  /// No description provided for @insights_assistants_busy_msg2.
  ///
  /// In en, this message translates to:
  /// **'Please check back for tips a little later.'**
  String get insights_assistants_busy_msg2;

  /// No description provided for @month_1.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get month_1;

  /// No description provided for @month_2.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get month_2;

  /// No description provided for @month_3.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get month_3;

  /// No description provided for @month_4.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get month_4;

  /// No description provided for @month_5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get month_5;

  /// No description provided for @month_6.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get month_6;

  /// No description provided for @month_7.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get month_7;

  /// No description provided for @month_8.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get month_8;

  /// No description provided for @month_9.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get month_9;

  /// No description provided for @month_10.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get month_10;

  /// No description provided for @month_11.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get month_11;

  /// No description provided for @month_12.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get month_12;

  /// No description provided for @month_label.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month_label;

  /// No description provided for @no_description.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get no_description;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @login_error_title.
  ///
  /// In en, this message translates to:
  /// **'Login Error'**
  String get login_error_title;

  /// No description provided for @sync_login_required.
  ///
  /// In en, this message translates to:
  /// **'Log in to sync'**
  String get sync_login_required;

  /// No description provided for @uzs_symbol.
  ///
  /// In en, this message translates to:
  /// **'UZS'**
  String get uzs_symbol;

  /// No description provided for @category_food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get category_food;

  /// No description provided for @category_transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get category_transport;

  /// No description provided for @category_entertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get category_entertainment;

  /// No description provided for @category_health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get category_health;

  /// No description provided for @category_subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get category_subscriptions;

  /// No description provided for @category_shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get category_shopping;

  /// No description provided for @category_salary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get category_salary;

  /// No description provided for @category_freelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get category_freelance;

  /// No description provided for @category_investments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get category_investments;

  /// No description provided for @category_transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get category_transfers;

  /// No description provided for @category_cashback.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get category_cashback;

  /// No description provided for @category_sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get category_sales;

  /// No description provided for @category_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get category_other;

  /// No description provided for @type_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get type_income;

  /// No description provided for @type_expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get type_expense;

  /// No description provided for @dialog_ok.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get dialog_ok;

  /// No description provided for @session_expired_title.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get session_expired_title;

  /// No description provided for @session_expired_desc.
  ///
  /// In en, this message translates to:
  /// **'Please log in to your account again to continue.'**
  String get session_expired_desc;

  /// No description provided for @server_error_general.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while communicating with the server'**
  String get server_error_general;

  /// No description provided for @http_400.
  ///
  /// In en, this message translates to:
  /// **'Bad request'**
  String get http_400;

  /// No description provided for @http_401.
  ///
  /// In en, this message translates to:
  /// **'Authorization required'**
  String get http_401;

  /// No description provided for @http_403.
  ///
  /// In en, this message translates to:
  /// **'Access forbidden'**
  String get http_403;

  /// No description provided for @http_404.
  ///
  /// In en, this message translates to:
  /// **'Resource not found'**
  String get http_404;

  /// No description provided for @http_429.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get http_429;

  /// No description provided for @rate_limit_exceeded_title.
  ///
  /// In en, this message translates to:
  /// **'Rate Limit Exceeded'**
  String get rate_limit_exceeded_title;

  /// No description provided for @rate_limit_countdown.
  ///
  /// In en, this message translates to:
  /// **'Retry in: {seconds} sec'**
  String rate_limit_countdown(int seconds);

  /// No description provided for @rate_limit_ready.
  ///
  /// In en, this message translates to:
  /// **'You can retry now'**
  String get rate_limit_ready;

  /// No description provided for @http_500.
  ///
  /// In en, this message translates to:
  /// **'Internal server error'**
  String get http_500;

  /// No description provided for @http_503.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Maintenance in progress'**
  String get http_503;

  /// No description provided for @service_unavailable_title.
  ///
  /// In en, this message translates to:
  /// **'Service Unavailable'**
  String get service_unavailable_title;

  /// No description provided for @service_unavailable_desc.
  ///
  /// In en, this message translates to:
  /// **'Technical maintenance in progress. Please try again later.'**
  String get service_unavailable_desc;

  /// No description provided for @service_unavailable_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get service_unavailable_retry;

  /// No description provided for @startup_error_title.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the app'**
  String get startup_error_title;

  /// No description provided for @startup_error_desc.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t prepare the data on your device. Please try again.'**
  String get startup_error_desc;

  /// No description provided for @err_unexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get err_unexpected;

  /// No description provided for @server_error_code.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get server_error_code;

  /// No description provided for @err_connection_timeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout'**
  String get err_connection_timeout;

  /// No description provided for @err_send_timeout.
  ///
  /// In en, this message translates to:
  /// **'Send timeout'**
  String get err_send_timeout;

  /// No description provided for @err_receive_timeout.
  ///
  /// In en, this message translates to:
  /// **'Receive timeout'**
  String get err_receive_timeout;

  /// No description provided for @err_connection_error.
  ///
  /// In en, this message translates to:
  /// **'No internet connection or server unavailable'**
  String get err_connection_error;

  /// No description provided for @err_network_default.
  ///
  /// In en, this message translates to:
  /// **'Network error: check your connection'**
  String get err_network_default;

  /// No description provided for @pull_to_refresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pull_to_refresh;

  /// No description provided for @release_to_refresh.
  ///
  /// In en, this message translates to:
  /// **'Release to refresh'**
  String get release_to_refresh;

  /// No description provided for @refreshing_data.
  ///
  /// In en, this message translates to:
  /// **'Updating data...'**
  String get refreshing_data;

  /// No description provided for @budget_deleted.
  ///
  /// In en, this message translates to:
  /// **'Budget limit deleted'**
  String get budget_deleted;

  /// No description provided for @sync_synced.
  ///
  /// In en, this message translates to:
  /// **'Data synced'**
  String get sync_synced;

  /// Profile sync card: changes not yet uploaded to the server
  ///
  /// In en, this message translates to:
  /// **'Not uploaded: {count}. Tap to upload'**
  String sync_pending(int count);

  /// Profile sync card: records the server rejected, opens their list
  ///
  /// In en, this message translates to:
  /// **'Not accepted by server: {count}'**
  String sync_rejected_count(int count);

  /// Title of the sheet with records the server rejected
  ///
  /// In en, this message translates to:
  /// **'Not accepted by server'**
  String get sync_rejected_title;

  /// Hint under the title of the rejected records sheet
  ///
  /// In en, this message translates to:
  /// **'Tap a record to fix it. It will be uploaded again after you save it.'**
  String get sync_rejected_hint;

  /// Rejection reason: the server could not get the exchange rate for the record currency
  ///
  /// In en, this message translates to:
  /// **'The server could not get the exchange rate'**
  String get sync_reject_invalid_currency;

  /// Rejection reason: amount converted to the main currency is too large
  ///
  /// In en, this message translates to:
  /// **'The amount in the main currency is too large'**
  String get sync_reject_invalid_amount;

  /// Rejection reason the app does not recognize
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this record'**
  String get sync_reject_unknown;

  /// Toast after a sync in which the server rejected some records
  ///
  /// In en, this message translates to:
  /// **'Synced, but the server did not accept: {count}'**
  String sync_done_with_rejected(int count);

  /// No description provided for @enter_amount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enter_amount;

  /// No description provided for @invalid_amount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get invalid_amount;

  /// No description provided for @max_amount_prefix.
  ///
  /// In en, this message translates to:
  /// **'Max amount'**
  String get max_amount_prefix;

  /// No description provided for @month_gen_1.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get month_gen_1;

  /// No description provided for @month_gen_2.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get month_gen_2;

  /// No description provided for @month_gen_3.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get month_gen_3;

  /// No description provided for @month_gen_4.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get month_gen_4;

  /// No description provided for @month_gen_5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get month_gen_5;

  /// No description provided for @month_gen_6.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get month_gen_6;

  /// No description provided for @month_gen_7.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get month_gen_7;

  /// No description provided for @month_gen_8.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get month_gen_8;

  /// No description provided for @month_gen_9.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get month_gen_9;

  /// No description provided for @month_gen_10.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get month_gen_10;

  /// No description provided for @month_gen_11.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get month_gen_11;

  /// No description provided for @month_gen_12.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get month_gen_12;

  /// No description provided for @terms_of_use_prefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the '**
  String get terms_of_use_prefix;

  /// No description provided for @terms_of_use_link.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get terms_of_use_link;

  /// No description provided for @terms_of_use_and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get terms_of_use_and;

  /// No description provided for @privacy_policy_link.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy_link;

  /// No description provided for @terms_of_use_suffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get terms_of_use_suffix;

  /// No description provided for @login_with_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get login_with_google;

  /// No description provided for @login_with_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get login_with_apple;

  /// No description provided for @continue_with_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google.'**
  String get continue_with_google;

  /// No description provided for @continue_with_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple ID.'**
  String get continue_with_apple;

  /// No description provided for @auth_social_error.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed or was cancelled. Please try again.'**
  String get auth_social_error;

  /// No description provided for @delete_account_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account_title;

  /// No description provided for @delete_account_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account and all associated data? This action cannot be undone.'**
  String get delete_account_confirm;

  /// No description provided for @delete_account_confirm_btn.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get delete_account_confirm_btn;

  /// No description provided for @delete_account_btn.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account_btn;

  /// No description provided for @delete_account_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get delete_account_error;

  /// No description provided for @profile_data_section.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get profile_data_section;

  /// No description provided for @delete_account_info_title.
  ///
  /// In en, this message translates to:
  /// **'Account and data deletion'**
  String get delete_account_info_title;

  /// No description provided for @delete_account_info_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Help page: how to delete your account and what data is erased'**
  String get delete_account_info_subtitle;

  /// No description provided for @open_link_error.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get open_link_error;

  /// No description provided for @report_export_title.
  ///
  /// In en, this message translates to:
  /// **'Export report'**
  String get report_export_title;

  /// No description provided for @report_period_label.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get report_period_label;

  /// No description provided for @report_period_year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get report_period_year;

  /// No description provided for @report_period_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get report_period_custom;

  /// No description provided for @report_format_label.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get report_format_label;

  /// No description provided for @report_save_action.
  ///
  /// In en, this message translates to:
  /// **'Download report'**
  String get report_save_action;

  /// No description provided for @report_share_action.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get report_share_action;

  /// No description provided for @report_saved.
  ///
  /// In en, this message translates to:
  /// **'Report saved'**
  String get report_saved;

  /// No description provided for @report_export_error.
  ///
  /// In en, this message translates to:
  /// **'Could not create the report'**
  String get report_export_error;

  /// No description provided for @report_empty_period.
  ///
  /// In en, this message translates to:
  /// **'No transactions for the selected period'**
  String get report_empty_period;

  /// No description provided for @report_feature_locked.
  ///
  /// In en, this message translates to:
  /// **'Report export is available with a subscription'**
  String get report_feature_locked;

  /// No description provided for @report_title.
  ///
  /// In en, this message translates to:
  /// **'Financial report'**
  String get report_title;

  /// No description provided for @report_generated_at.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get report_generated_at;

  /// No description provided for @report_summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get report_summary;

  /// No description provided for @report_total_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get report_total_income;

  /// No description provided for @report_total_expense.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get report_total_expense;

  /// No description provided for @report_period_result.
  ///
  /// In en, this message translates to:
  /// **'Net result'**
  String get report_period_result;

  /// No description provided for @report_by_category.
  ///
  /// In en, this message translates to:
  /// **'Expenses by category'**
  String get report_by_category;

  /// No description provided for @report_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get report_share;

  /// No description provided for @report_limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get report_limit;

  /// No description provided for @report_spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get report_spent;

  /// No description provided for @report_transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get report_transactions;

  /// No description provided for @report_col_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get report_col_date;

  /// No description provided for @report_col_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get report_col_type;

  /// No description provided for @report_col_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get report_col_category;

  /// No description provided for @report_col_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get report_col_description;

  /// No description provided for @report_col_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get report_col_amount;

  /// No description provided for @report_col_amount_base.
  ///
  /// In en, this message translates to:
  /// **'Amount in {currency}'**
  String report_col_amount_base(String currency);

  /// No description provided for @logging_out.
  ///
  /// In en, this message translates to:
  /// **'Logging out...'**
  String get logging_out;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @debug_menu_title.
  ///
  /// In en, this message translates to:
  /// **'Debug Menu'**
  String get debug_menu_title;

  /// No description provided for @debug_environment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get debug_environment;

  /// No description provided for @debug_environment_changed.
  ///
  /// In en, this message translates to:
  /// **'Environment changed to {env}. Session reset.'**
  String debug_environment_changed(String env);

  /// No description provided for @debug_environment_not_configured.
  ///
  /// In en, this message translates to:
  /// **'No URL is set for {env}. Run the app with --dart-define-from-file=.env'**
  String debug_environment_not_configured(String env);

  /// No description provided for @debug_app_info.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get debug_app_info;

  /// No description provided for @debug_version.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String debug_version(String version);

  /// No description provided for @debug_base_url.
  ///
  /// In en, this message translates to:
  /// **'Base URL: {url}'**
  String debug_base_url(String url);

  /// No description provided for @debug_tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get debug_tools;

  /// No description provided for @debug_open_logs.
  ///
  /// In en, this message translates to:
  /// **'Open Logs (Talker)'**
  String get debug_open_logs;

  /// No description provided for @debug_clear_cache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache & Tokens'**
  String get debug_clear_cache;

  /// No description provided for @debug_cache_cleared.
  ///
  /// In en, this message translates to:
  /// **'Cache & Tokens cleared'**
  String get debug_cache_cleared;

  /// No description provided for @version_label.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version_label(String version);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @pick_date.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pick_date;

  /// No description provided for @date_label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date_label;

  /// No description provided for @rate_updated_on.
  ///
  /// In en, this message translates to:
  /// **'updated {date}'**
  String rate_updated_on(String date);

  /// No description provided for @rate_approximate.
  ///
  /// In en, this message translates to:
  /// **'approximate rate'**
  String get rate_approximate;

  /// No description provided for @more_categories.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more_categories;

  /// No description provided for @all_categories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get all_categories;

  /// No description provided for @category_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Find a category'**
  String get category_search_hint;

  /// No description provided for @category_search_empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get category_search_empty;

  /// No description provided for @previous_month.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previous_month;

  /// No description provided for @next_month.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get next_month;

  /// No description provided for @select_month.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get select_month;

  /// No description provided for @previous_year.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get previous_year;

  /// No description provided for @next_year.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get next_year;

  /// No description provided for @add_limit_btn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add_limit_btn;

  /// No description provided for @insights_not_generated.
  ///
  /// In en, this message translates to:
  /// **'The AI analysis for this month has not been generated yet.'**
  String get insights_not_generated;

  /// No description provided for @insights_generate_btn.
  ///
  /// In en, this message translates to:
  /// **'Generate analysis'**
  String get insights_generate_btn;

  /// No description provided for @insights_future_month.
  ///
  /// In en, this message translates to:
  /// **'This month has not started yet — there is nothing to analyze.'**
  String get insights_future_month;

  /// No description provided for @insights_no_transactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions this month — there is nothing to analyze yet.'**
  String get insights_no_transactions;

  /// No description provided for @view_by_days.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get view_by_days;

  /// No description provided for @view_by_categories.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get view_by_categories;

  /// No description provided for @edit_btn.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit_btn;

  /// No description provided for @details_original_amount.
  ///
  /// In en, this message translates to:
  /// **'Receipt amount'**
  String get details_original_amount;

  /// No description provided for @details_in_base_currency.
  ///
  /// In en, this message translates to:
  /// **'In main currency'**
  String get details_in_base_currency;

  /// No description provided for @month_budget_title.
  ///
  /// In en, this message translates to:
  /// **'Month budget'**
  String get month_budget_title;

  /// No description provided for @daily_allowance.
  ///
  /// In en, this message translates to:
  /// **'You can spend per day'**
  String get daily_allowance;

  /// No description provided for @days_left.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String days_left(int count);

  /// No description provided for @budget_limits_total.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get budget_limits_total;

  /// No description provided for @budget_spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get budget_spent;

  /// No description provided for @budget_remaining.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get budget_remaining;

  /// No description provided for @budget_overspent.
  ///
  /// In en, this message translates to:
  /// **'Overspent'**
  String get budget_overspent;

  /// No description provided for @budget_month_result.
  ///
  /// In en, this message translates to:
  /// **'Result for limits'**
  String get budget_month_result;

  /// No description provided for @budget_planned.
  ///
  /// In en, this message translates to:
  /// **'Planned limits'**
  String get budget_planned;

  /// No description provided for @budget_all_categories_limited.
  ///
  /// In en, this message translates to:
  /// **'All categories already have a limit this month'**
  String get budget_all_categories_limited;

  /// No description provided for @add_limit_cta.
  ///
  /// In en, this message translates to:
  /// **'Add a limit'**
  String get add_limit_cta;

  /// No description provided for @budget_spent_of.
  ///
  /// In en, this message translates to:
  /// **'Spent: {spent} of {limit}'**
  String budget_spent_of(String spent, String limit);

  /// No description provided for @structure_title.
  ///
  /// In en, this message translates to:
  /// **'Expense structure'**
  String get structure_title;

  /// No description provided for @structure_of_income.
  ///
  /// In en, this message translates to:
  /// **'of income'**
  String get structure_of_income;

  /// No description provided for @structure_total_expenses.
  ///
  /// In en, this message translates to:
  /// **'expenses'**
  String get structure_total_expenses;

  /// No description provided for @structure_no_expenses.
  ///
  /// In en, this message translates to:
  /// **'no expenses'**
  String get structure_no_expenses;

  /// No description provided for @structure_no_expenses_month.
  ///
  /// In en, this message translates to:
  /// **'No expenses this month'**
  String get structure_no_expenses_month;

  /// No description provided for @structure_more_categories.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more category} other{{count} more categories}}'**
  String structure_more_categories(int count);

  /// No description provided for @report_btn_short.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report_btn_short;

  /// No description provided for @insights_outdated_note.
  ///
  /// In en, this message translates to:
  /// **'Your data changed after this report — amounts in the tips may differ from the current ones.'**
  String get insights_outdated_note;

  /// No description provided for @insights_outdated_refresh.
  ///
  /// In en, this message translates to:
  /// **'Update report'**
  String get insights_outdated_refresh;

  /// No description provided for @insights_outdated_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'A new report will be available tomorrow: the daily update limit is reached.'**
  String get insights_outdated_tomorrow;

  /// Logout confirmation when some changes could not be uploaded
  ///
  /// In en, this message translates to:
  /// **'Not uploaded to the server: {count}. These changes will be removed from this device when you log out. Log out anyway?'**
  String logout_unsynced_warning(int count);

  /// Number of transactions in a category group
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String operations_count(int count);

  /// TalkBack/VoiceOver tap hint on a collapsed category group (Double tap to ...)
  ///
  /// In en, this message translates to:
  /// **'show transactions'**
  String get category_group_expand_hint;

  /// TalkBack/VoiceOver tap hint on an expanded category group (Double tap to ...)
  ///
  /// In en, this message translates to:
  /// **'hide transactions'**
  String get category_group_collapse_hint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
