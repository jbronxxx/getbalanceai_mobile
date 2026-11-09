import 'package:flutter/widgets.dart';

/// Навигатор приложения — для переходов вне дерева виджетов (например,
/// из обработчика ошибок на экран входа).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
