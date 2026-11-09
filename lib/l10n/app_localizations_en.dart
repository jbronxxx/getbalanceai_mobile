// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get balance => 'Balance';

  @override
  String get finances => 'Budget';

  @override
  String get insights => 'Analytics';

  @override
  String get profile => 'Profile';

  @override
  String get interface => 'Interface';

  @override
  String get currency => 'Currency';

  @override
  String get language => 'App Language';

  @override
  String get select_language => 'Select Language';

  @override
  String get theme_mode => 'Theme';

  @override
  String get theme_system => 'System';

  @override
  String get theme_light => 'Light';

  @override
  String get theme_dark => 'Dark';

  @override
  String get cloud => 'Cloud';

  @override
  String get sync_status => 'Sync Status';

  @override
  String get logout => 'Log Out';

  @override
  String get login_or_register => 'Log In or Register';

  @override
  String get login_btn_short => 'Log In';

  @override
  String get local_profile => 'Local Profile';

  @override
  String get local_storage_warning =>
      'Data is stored only on your device and is deleted when the app is uninstalled';

  @override
  String get cloud_backup_prompt => 'Sign in to enable cloud backup';

  @override
  String get select_currency => 'Select Currency';

  @override
  String get uzs_name => 'Uzbek Som';

  @override
  String get kzt_name => 'Kazakhstani Tenge';

  @override
  String get eur_name => 'Euro';

  @override
  String get usd_name => 'US Dollar';

  @override
  String get cancel => 'Cancel';

  @override
  String get logout_confirm_title => 'Log Out';

  @override
  String get logout_confirm_desc => 'Are you sure you want to log out?';

  @override
  String get syncing => 'Syncing...';

  @override
  String get sync_success => 'Data synced successfully';

  @override
  String get sync_updated_just_now => 'Updated just now';

  @override
  String get sync_no_internet => 'No Network';

  @override
  String get no_internet_connection =>
      'No internet connection. Please check your network and try again.';

  @override
  String get sync_error => 'Sync Error';

  @override
  String get logout_info => 'Logged out successfully';

  @override
  String get transaction_deleted => 'Transaction deleted';

  @override
  String get undo_action => 'Undo';

  @override
  String get welcome_lang_title => 'Choose language';

  @override
  String get welcome_lang_subtitle =>
      'For a comfortable experience with the app';

  @override
  String get welcome_currency_title => 'Main Currency';

  @override
  String get welcome_currency_subtitle =>
      'Total balance and budgets are calculated in this currency';

  @override
  String get continue_btn => 'Continue';

  @override
  String get month_total => 'Month total';

  @override
  String get expense_title => 'Expense';

  @override
  String get income_title => 'Income';

  @override
  String get no_transactions => 'No transactions for this month';

  @override
  String get delete_btn => 'Delete';

  @override
  String get new_transaction => 'New Transaction';

  @override
  String get edit_transaction => 'Edit Transaction';

  @override
  String get amount_label => 'Amount';

  @override
  String get category_label => 'Category';

  @override
  String get description_label => 'Description (optional)';

  @override
  String get add_btn => 'Add Transaction';

  @override
  String get save_changes_btn => 'Save Changes';

  @override
  String get amount_requirement_enter => 'Enter amount';

  @override
  String get amount_requirement_positive => 'Amount must be greater than 0';

  @override
  String amount_requirement_max(String max, String currency) {
    return 'Max: $max $currency';
  }

  @override
  String get budgets_title => 'Expense Budgets';

  @override
  String get add_budget_title => 'Set Budget Limit';

  @override
  String get edit_budget_title => 'Edit Budget Limit';

  @override
  String get save_btn => 'Save';

  @override
  String get budget_exceeded => 'Exceeded by';

  @override
  String get no_budgets_subtitle =>
      'Set limits by category to avoid overspending.';

  @override
  String get insight_login_hint =>
      'Log in to get personalized recommendations based on your data.';

  @override
  String get insight_no_data =>
      'Not enough data for analysis yet. Keep recording expenses!';

  @override
  String get no_network_title => 'No internet connection';

  @override
  String get no_network_desc =>
      'Updating analytics requires internet. Check your connection and pull down to retry.';

  @override
  String get insights_header_title => 'AI Analytics';

  @override
  String get insights_assistants_busy_msg1 =>
      'Unfortunately, our smart assistants are currently very busy and cannot analyze the data.';

  @override
  String get insights_assistants_busy_msg2 =>
      'Please check back for tips a little later.';

  @override
  String get month_1 => 'January';

  @override
  String get month_2 => 'February';

  @override
  String get month_3 => 'March';

  @override
  String get month_4 => 'April';

  @override
  String get month_5 => 'May';

  @override
  String get month_6 => 'June';

  @override
  String get month_7 => 'July';

  @override
  String get month_8 => 'August';

  @override
  String get month_9 => 'September';

  @override
  String get month_10 => 'October';

  @override
  String get month_11 => 'November';

  @override
  String get month_12 => 'December';

  @override
  String get month_label => 'Month';

  @override
  String get no_description => 'No description';

  @override
  String get today => 'Today';

  @override
  String get login_error_title => 'Login Error';

  @override
  String get sync_login_required => 'Log in to sync';

  @override
  String get uzs_symbol => 'UZS';

  @override
  String get category_food => 'Food';

  @override
  String get category_transport => 'Transport';

  @override
  String get category_entertainment => 'Entertainment';

  @override
  String get category_health => 'Health';

  @override
  String get category_subscriptions => 'Subscriptions';

  @override
  String get category_shopping => 'Shopping';

  @override
  String get category_salary => 'Salary';

  @override
  String get category_freelance => 'Freelance';

  @override
  String get category_investments => 'Investments';

  @override
  String get category_transfers => 'Transfers';

  @override
  String get category_cashback => 'Cashback';

  @override
  String get category_sales => 'Sales';

  @override
  String get category_other => 'Other';

  @override
  String get type_income => 'Income';

  @override
  String get type_expense => 'Expense';

  @override
  String get dialog_ok => 'Got it';

  @override
  String get session_expired_title => 'Session Expired';

  @override
  String get session_expired_desc =>
      'Please log in to your account again to continue.';

  @override
  String get server_error_general =>
      'An error occurred while communicating with the server';

  @override
  String get http_400 => 'Bad request';

  @override
  String get http_401 => 'Authorization required';

  @override
  String get http_403 => 'Access forbidden';

  @override
  String get http_404 => 'Resource not found';

  @override
  String get http_429 => 'Too many requests. Please try again later.';

  @override
  String get rate_limit_exceeded_title => 'Rate Limit Exceeded';

  @override
  String rate_limit_countdown(int seconds) {
    return 'Retry in: $seconds sec';
  }

  @override
  String get rate_limit_ready => 'You can retry now';

  @override
  String get http_500 => 'Internal server error';

  @override
  String get http_503 =>
      'Service temporarily unavailable. Maintenance in progress';

  @override
  String get service_unavailable_title => 'Service Unavailable';

  @override
  String get service_unavailable_desc =>
      'Technical maintenance in progress. Please try again later.';

  @override
  String get service_unavailable_retry => 'Try Again';

  @override
  String get startup_error_title => 'Couldn\'t start the app';

  @override
  String get startup_error_desc =>
      'We couldn\'t prepare the data on your device. Please try again.';

  @override
  String get err_unexpected => 'Something went wrong. Please try again.';

  @override
  String get server_error_code => 'Server error';

  @override
  String get err_connection_timeout => 'Connection timeout';

  @override
  String get err_send_timeout => 'Send timeout';

  @override
  String get err_receive_timeout => 'Receive timeout';

  @override
  String get err_connection_error =>
      'No internet connection or server unavailable';

  @override
  String get err_network_default => 'Network error: check your connection';

  @override
  String get pull_to_refresh => 'Pull to refresh';

  @override
  String get release_to_refresh => 'Release to refresh';

  @override
  String get refreshing_data => 'Updating data...';

  @override
  String get budget_deleted => 'Budget limit deleted';

  @override
  String get sync_synced => 'Data synced';

  @override
  String sync_pending(int count) {
    return 'Not uploaded: $count. Tap to upload';
  }

  @override
  String get enter_amount => 'Enter amount';

  @override
  String get invalid_amount => 'Invalid amount';

  @override
  String get max_amount_prefix => 'Max amount';

  @override
  String get month_gen_1 => 'January';

  @override
  String get month_gen_2 => 'February';

  @override
  String get month_gen_3 => 'March';

  @override
  String get month_gen_4 => 'April';

  @override
  String get month_gen_5 => 'May';

  @override
  String get month_gen_6 => 'June';

  @override
  String get month_gen_7 => 'July';

  @override
  String get month_gen_8 => 'August';

  @override
  String get month_gen_9 => 'September';

  @override
  String get month_gen_10 => 'October';

  @override
  String get month_gen_11 => 'November';

  @override
  String get month_gen_12 => 'December';

  @override
  String get terms_of_use_prefix => 'By continuing, you agree to the ';

  @override
  String get terms_of_use_link => 'Terms of Use';

  @override
  String get terms_of_use_and => ' and ';

  @override
  String get privacy_policy_link => 'Privacy Policy';

  @override
  String get terms_of_use_suffix => '.';

  @override
  String get login_with_google => 'Continue with Google';

  @override
  String get login_with_apple => 'Continue with Apple';

  @override
  String get continue_with_google => 'Continue with Google.';

  @override
  String get continue_with_apple => 'Continue with Apple ID.';

  @override
  String get auth_social_error =>
      'Authentication failed or was cancelled. Please try again.';

  @override
  String get delete_account_title => 'Delete Account';

  @override
  String get delete_account_confirm =>
      'Are you sure you want to permanently delete your account and all associated data? This action cannot be undone.';

  @override
  String get delete_account_confirm_btn => 'Delete Permanently';

  @override
  String get delete_account_btn => 'Delete Account';

  @override
  String get delete_account_error => 'Failed to delete account';

  @override
  String get profile_data_section => 'Data';

  @override
  String get delete_account_info_title => 'Account and data deletion';

  @override
  String get delete_account_info_subtitle =>
      'Help page: how to delete your account and what data is erased';

  @override
  String get open_link_error => 'Could not open the link';

  @override
  String get report_export_title => 'Export report';

  @override
  String get report_period_label => 'Period';

  @override
  String get report_period_year => 'Year';

  @override
  String get report_period_custom => 'Custom range';

  @override
  String get report_format_label => 'Format';

  @override
  String get report_save_action => 'Download report';

  @override
  String get report_share_action => 'Share';

  @override
  String get report_saved => 'Report saved';

  @override
  String get report_export_error => 'Could not create the report';

  @override
  String get report_empty_period => 'No transactions for the selected period';

  @override
  String get report_feature_locked =>
      'Report export is available with a subscription';

  @override
  String get report_title => 'Financial report';

  @override
  String get report_generated_at => 'Generated';

  @override
  String get report_summary => 'Summary';

  @override
  String get report_total_income => 'Income';

  @override
  String get report_total_expense => 'Expenses';

  @override
  String get report_period_result => 'Net result';

  @override
  String get report_by_category => 'Expenses by category';

  @override
  String get report_share => 'Share';

  @override
  String get report_limit => 'Limit';

  @override
  String get report_spent => 'Spent';

  @override
  String get report_transactions => 'Transactions';

  @override
  String get report_col_date => 'Date';

  @override
  String get report_col_type => 'Type';

  @override
  String get report_col_category => 'Category';

  @override
  String get report_col_description => 'Description';

  @override
  String get report_col_amount => 'Amount';

  @override
  String report_col_amount_base(String currency) {
    return 'Amount in $currency';
  }

  @override
  String get logging_out => 'Logging out...';

  @override
  String get deleting => 'Deleting...';

  @override
  String get debug_menu_title => 'Debug Menu';

  @override
  String get debug_environment => 'Environment';

  @override
  String debug_environment_changed(String env) {
    return 'Environment changed to $env. Session reset.';
  }

  @override
  String debug_environment_not_configured(String env) {
    return 'No URL is set for $env. Run the app with --dart-define-from-file=.env';
  }

  @override
  String get debug_app_info => 'App Info';

  @override
  String debug_version(String version) {
    return 'Version: $version';
  }

  @override
  String debug_base_url(String url) {
    return 'Base URL: $url';
  }

  @override
  String get debug_tools => 'Tools';

  @override
  String get debug_open_logs => 'Open Logs (Talker)';

  @override
  String get debug_clear_cache => 'Clear Cache & Tokens';

  @override
  String get debug_cache_cleared => 'Cache & Tokens cleared';

  @override
  String version_label(String version) {
    return 'Version $version';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get pick_date => 'Pick a date';

  @override
  String get date_label => 'Date';

  @override
  String rate_updated_on(String date) {
    return 'updated $date';
  }

  @override
  String get rate_approximate => 'approximate rate';

  @override
  String get more_categories => 'More';

  @override
  String get all_categories => 'All categories';

  @override
  String get category_search_hint => 'Find a category';

  @override
  String get category_search_empty => 'Nothing found';

  @override
  String get previous_month => 'Previous month';

  @override
  String get next_month => 'Next month';

  @override
  String get select_month => 'Select month';

  @override
  String get previous_year => 'Previous year';

  @override
  String get next_year => 'Next year';

  @override
  String get add_limit_btn => 'Add';

  @override
  String get insights_not_generated =>
      'The AI analysis for this month has not been generated yet.';

  @override
  String get insights_generate_btn => 'Generate analysis';

  @override
  String get insights_future_month =>
      'This month has not started yet — there is nothing to analyze.';

  @override
  String get insights_no_transactions =>
      'No transactions this month — there is nothing to analyze yet.';

  @override
  String get view_by_days => 'By day';

  @override
  String get view_by_categories => 'By category';

  @override
  String get edit_btn => 'Edit';

  @override
  String get details_original_amount => 'Receipt amount';

  @override
  String get details_in_base_currency => 'In main currency';

  @override
  String get month_budget_title => 'Month budget';

  @override
  String get daily_allowance => 'You can spend per day';

  @override
  String days_left(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get budget_limits_total => 'Limits';

  @override
  String get budget_spent => 'Spent';

  @override
  String get budget_remaining => 'Left';

  @override
  String get budget_overspent => 'Overspent';

  @override
  String get budget_month_result => 'Result for limits';

  @override
  String get budget_planned => 'Planned limits';

  @override
  String get budget_all_categories_limited =>
      'All categories already have a limit this month';

  @override
  String get add_limit_cta => 'Add a limit';

  @override
  String budget_spent_of(String spent, String limit) {
    return 'Spent: $spent of $limit';
  }

  @override
  String get structure_title => 'Expense structure';

  @override
  String get structure_of_income => 'of income';

  @override
  String get structure_total_expenses => 'expenses';

  @override
  String get structure_no_expenses => 'no expenses';

  @override
  String get structure_no_expenses_month => 'No expenses this month';

  @override
  String structure_more_categories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more categories',
      one: '1 more category',
    );
    return '$_temp0';
  }

  @override
  String get report_btn_short => 'Report';

  @override
  String get insights_outdated_note =>
      'Your data changed after this report — amounts in the tips may differ from the current ones.';

  @override
  String get insights_outdated_refresh => 'Update report';

  @override
  String get insights_outdated_tomorrow =>
      'A new report will be available tomorrow: the daily update limit is reached.';

  @override
  String logout_unsynced_warning(int count) {
    return 'Not uploaded to the server: $count. These changes will be removed from this device when you log out. Log out anyway?';
  }

  @override
  String operations_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }
}
