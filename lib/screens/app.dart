import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_simulator/screens/settings_screen.dart';

import '../services/location_service.dart';
import '../services/mqtt_service.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'main_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize services
    Get.lazyPut(() => LocationService());
    Get.lazyPut(() => MqttService());

    return GetMaterialApp(
      title: 'ردیاب موقعیت MQTT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Vazir',
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
      getPages: [
        GetPage(name: '/home', page: () => const HomeScreen()),
        GetPage(name: '/settings', page: () => const SettingsScreen()),
        GetPage(name: '/history', page: () => const HistoryScreen()),
      ],
    );
  }
}