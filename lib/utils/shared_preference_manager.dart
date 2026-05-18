import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceManager {
  SharedPreferenceManager({required this.sharedPreferences});
  final SharedPreferences sharedPreferences;

  /// Reads a value from persistent storage, throwing an exception if it's not a String.
  String? getString(String key, {String? defaultValue}) {
    try {
      if (containsKey(key)) {
        return sharedPreferences.getString(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        if (kDebugMode) {
          print(exception);
        }
      }
    }
    return defaultValue;
  }

  /// Saves a string [value] to persistent storage in the background.
  Future<bool> setString(String key, String value) async {
    try {
      return await sharedPreferences.setString(key, value);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return false;
  }

  /// Reads a set of string values from persistent storage, throwing an exception if it's not a string set.
  List<String>? getStringList(String key, {List<String>? defaultValue}) {
    try {
      if (containsKey(key)) {
        return sharedPreferences.getStringList(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return defaultValue;
  }

  /// Saves a list of strings [value] to persistent storage in the background
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      return await sharedPreferences.setStringList(key, value);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return false;
  }

  /// Reads a value from persistent storage, throwing an exception if it's not an int.
  int? getInt(String key, {int? defaultValue}) {
    try {
      if (containsKey(key)) {
        return sharedPreferences.getInt(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return defaultValue;
  }

  /// Saves an integer [value] to persistent storage in the background.
  Future<bool> setInt(String key, int value) async {
    try {
      return await sharedPreferences.setInt(key, value);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return false;
  }

  /// Reads a value from persistent storage, throwing an exception if it's not a
  /// double.
  double? getDouble(String key, {double? defaultValue}) {
    try {
      if (containsKey(key)) {
        return sharedPreferences.getDouble(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return defaultValue;
  }

  /// Saves a double [value] to persistent storage in the background.
  Future<bool> setDouble(String key, double value) async {
    try {
      return await sharedPreferences.setDouble(key, value);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return false;
  }

  /// Reads a value from persistent storage with the given [key], throwing an
  /// exception if it's not a bool.
  bool? getBool(String key, {bool? defaultValue}) {
    try {
      if (containsKey(key)) {
        return sharedPreferences.getBool(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return defaultValue;
  }

  /// Saves a boolean [value] to persistent storage in the background.
  Future<bool> setBool(String key, {required bool value}) async {
    try {
      return await sharedPreferences.setBool(key, value);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return false;
  }

  /// Removes an entry from persistent storage with the given [key].
  Future<bool> remove(String key) async {
    try {
      if (containsKey(key)) {
        return await sharedPreferences.remove(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return false;
  }

  /// Reads a value of any type from persistent storage with the given [key].
  Object? get(String key) {
    try {
      if (containsKey(key)) {
        return sharedPreferences.get(key);
      }
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
    return null;
  }

  /// Returns true if persistent storage contains the given [key].
  bool containsKey(String key) {
    if (sharedPreferences.containsKey(key)) {
      return true;
    }
    return false;
  }

  /// Fetches the latest values from the host platform.
  Future<void> reload() async {
    await sharedPreferences.reload();
  }

  /// Completes with true once the user preferences for the app has been cleared.
  Future<bool> clear() {
    return sharedPreferences.clear();
  }
}
