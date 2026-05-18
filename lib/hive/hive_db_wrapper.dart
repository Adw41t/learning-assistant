import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:on_device_ai/secure_storage.dart';

class HiveDBWrapper {
  HiveDBWrapper({required this.hive, required this.secureStorageManager});
  final HiveInterface hive;
  final SecureStorage secureStorageManager;

  Future<LazyBox?> tryOpenBox(String boxName) async {
    try {
      return await _retryOperation(boxName);
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
      await deleteBox(boxName);

      try {
        return await _openBox(boxName);
      } catch (exception, stacktrace) {
        if (kDebugMode) {
          print(stacktrace);
        }

        return null;
      }
    }
  }

  Future<LazyBox?> _retryOperation(String boxName) async {
    const int retries = 2;
    for (var i = 0; i < retries; i++) {
      try {
        return await _openBox(boxName);
      } catch (e) {
        if (i == retries - 1) {
          rethrow; // Rethrow after all retries fail
        }
      }
    }
    return null;
  }

  Future<LazyBox> _openBox(String boxName) async {
    final key = await getDBSecureKey();

    return hive.openLazyBox(
      boxName,
      encryptionCipher: HiveAesCipher(key),
      crashRecovery: false,
    );
  }

  Future<List<int>> getDBSecureKey() async {
    final String? encryptionKey = await secureStorageManager.read(
      "ENCRYPTION_KEY",
    );
    if (encryptionKey != null) {
      return base64Decode(encryptionKey);
    } else {
      final key = hive.generateSecureKey();
      final String boxKeyEncoded = base64Encode(key);
      await secureStorageManager.write("ENCRYPTION_KEY", boxKeyEncoded);
      return key;
    }
  }

  Future<void> deleteBox(String boxName) async {
    try {
      if (await hive.boxExists(boxName)) {
        await hive.deleteBoxFromDisk(boxName);
      }
    } catch (exception, stacktrace) {
      if (kDebugMode) {
        print(stacktrace);
      }
    }
  }

  Future<bool> boxExists(String boxName) {
    if (boxName.isNotEmpty) {
      return hive.boxExists(boxName);
    }
    return Future<bool>.value(false);
  }
}
