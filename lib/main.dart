import 'package:flutter/material.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/screens/learning_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'injection_container.dart' as main_di;
import 'services/gemma_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await main_di.initEssentials();
  // Framework init is deferred to SetupScreen so any failure surfaces through
  // the normal retry UI rather than crashing to a black screen pre-runApp.
  runApp(OnDeviceAIApp(gemmaService: GemmaService()));
}

class OnDeviceAIApp extends StatelessWidget {
  final GemmaService gemmaService;

  const OnDeviceAIApp({super.key, required this.gemmaService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On-Device AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: AppShell(gemmaService: gemmaService),
    );
  }
}

/// Root shell that handles the setup -> chat flow.
///
/// On first launch: shows SetupScreen (downloads 2.58 GB model, loads to GPU).
/// On subsequent launches: loads model from local storage, then shows chat.
class AppShell extends StatefulWidget {
  final GemmaService gemmaService;

  const AppShell({super.key, required this.gemmaService});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  LocalDataSource? localDataSource;
  late SharedPreferences sharedPreferences;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setup();
      sharedPreferences = await SharedPreferences.getInstance();
    });
  }

  Future<void> _setup() async {
    setState(() {
      localDataSource = di<LocalDataSource>();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (localDataSource != null) {
      return LearningHome(
        gemmaService: widget.gemmaService,
        localDataSource: localDataSource!,
      );
    }
    return Center(child: SizedBox(child: Text("Loading")));
  }
}
