import 'package:flutter/foundation.dart';
import 'package:on_device_ai/hive/hive_db_wrapper.dart';
import 'lock.dart' as lock;

class LocalDataSource {
  final HiveDBWrapper hive;
  final lock.Lock hiveDBLock;

  LocalDataSource({required this.hive, required this.hiveDBLock});

  String _getHiveBoxKey(String boxKey) {
    if (boxKey.isNotEmpty) {
      return boxKey;
    }
    return "cache";
  }

  Future<void> addDataToLocalHiveDB(
    String typeId,
    dynamic dataObject, {
    String boxKey = '',
  }) async {
    await hiveDBLock.synchronized(() async {
      final hiveBoxKey = _getHiveBoxKey(boxKey);

      final box = await hive.tryOpenBox(hiveBoxKey);
      if (box == null) {
        return;
      }
      try {
        await box.put(typeId, dataObject);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    });
  }

  Future<T?> getDataFromLocalHiveDB<T>(
    String typeId, {
    String boxKey = '',
  }) async {
    return hiveDBLock.synchronized(() async {
      final hiveBoxKey = _getHiveBoxKey(boxKey);
      final box = await hive.tryOpenBox(hiveBoxKey);
      if (box == null) {
        return null;
      }
      dynamic localData;

      try {
        localData = await box.get(typeId);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      return localData;
    });
  }

  Future<void> removeDataFromDB(String typeId, {String boxKey = ''}) async {
    await hiveDBLock.synchronized(() async {
      final hiveBoxKey = _getHiveBoxKey(boxKey);
      final box = await hive.tryOpenBox(hiveBoxKey);

      if (box != null) {
        try {
          await box.delete(typeId);
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
        }
      }
    });
  }

  Future<void> clear() async {
    await hive.deleteBox('');
  }
}
