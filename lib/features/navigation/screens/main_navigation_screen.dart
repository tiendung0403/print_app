import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../free_print/screens/home_screen.dart';
import '../../inventory/screens/shift_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/storage/storage_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final StorageService storageService;

  const MainNavigationScreen({Key? key, required this.storageService}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ShiftListScreen(storageService: widget.storageService),
      HomeScreen(storageService: widget.storageService),
      SettingsScreen(storageService: widget.storageService),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.package),
            selectedIcon: Icon(LucideIcons.packageCheck),
            label: 'Hàng Hóa',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.printer),
            selectedIcon: Icon(LucideIcons.printer),
            label: 'In Tự Do',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            selectedIcon: Icon(LucideIcons.settings),
            label: 'Cài Đặt',
          ),
        ],
      ),
    );
  }
}
