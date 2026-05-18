import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:on_device_ai/hive/hive_db_wrapper.dart';
import 'package:on_device_ai/hive/hive_registrar.g.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/hive/lock.dart';
import 'package:on_device_ai/secure_storage.dart';
import 'package:on_device_ai/services/performance_monitor.dart';
import 'package:on_device_ai/utils/shared_preference_manager.dart';
import 'package:on_device_ai/utils/student_data.dart';
import 'package:on_device_ai/utils/subject_data.dart';
import 'package:on_device_ai/viewlogic/view_logic.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';

final di = GetIt.instance;

Future<bool> initEssentials() async {
  di.registerLazySingleton<SubjectData>(() => SubjectData());
  di.registerLazySingleton<StudentData>(() => StudentData());
  di.registerLazySingleton<PerformanceMonitor>(() => PerformanceMonitor());
  final sharedPreferences = await SharedPreferences.getInstance();

  di.registerLazySingleton<SharedPreferenceManager>(
    () => SharedPreferenceManager(sharedPreferences: sharedPreferences),
  );
  try {
    final appDocumentDir = await path_provider
        .getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    Hive.registerAdapters();

    di.registerLazySingleton<SecureStorage>(
      () => SecureStorage(
        secureStorage: FlutterSecureStorage(
          aOptions: AndroidOptions.defaultOptions,
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
      ),
    );
    di.registerLazySingleton<HiveDBWrapper>(
      () => HiveDBWrapper(hive: Hive, secureStorageManager: di()),
    );
    di.registerFactory<LocalDataSource>(
      () => LocalDataSource(hive: di(), hiveDBLock: Lock()),
    );

    di.registerLazySingleton<ViewLogic>(() => ViewLogic(subjectData: di()));
    return true;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return false;
  }
}
