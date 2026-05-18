import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({required this.secureStorage});
  final FlutterSecureStorage secureStorage;

  Future<void> write(String key, String value) async {
    try {
      return await secureStorage.write(key: key, value: value);
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
    }
  }

  Future<String?> read(String key, {String? defaultValue}) async {
    try {
      return await secureStorage.read(key: key);
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
    }
    return defaultValue;
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await secureStorage.readAll();
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
    }
    return {};
  }

  Future<void> deleteAll() async {
    try {
      return await secureStorage.deleteAll();
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
    }
    return;
  }

  Future<void> delete(String key) async {
    try {
      return await secureStorage.delete(key: key);
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
    }
    return;
  }
}
