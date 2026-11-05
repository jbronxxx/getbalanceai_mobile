import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Общее защищённое хранилище приложения (токены, ETag, настройки).
///
/// `resetOnError`: если Keystore не может расшифровать данные (сбой ключа
/// после обновления ОС, восстановления из бэкапа и т. п.), хранилище
/// стирается, иначе каждое чтение падает и приложение не запускается.
/// Цена — выход из аккаунта и сброс настроек; локальная БД не затрагивается.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  ),
);
