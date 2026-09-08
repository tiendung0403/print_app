import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:toastification/toastification.dart';
import 'services/storage_service.dart';
import 'screens/main_navigation_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  
  runApp(MyApp(storageService: storageService));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;

  const MyApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      config: const ToastificationConfig(
        maxToastLimit: 3,
        itemWidth: 350,
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: storageService.themeModeNotifier,
        builder: (context, themeMode, child) {
          return ShadApp(
            title: 'print app',
            themeMode: themeMode,
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadZincColorScheme.light(),
              radius: const BorderRadius.all(Radius.circular(16)),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadZincColorScheme.dark(),
              radius: const BorderRadius.all(Radius.circular(16)),
            ),
            home: MainNavigationScreen(storageService: storageService),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

