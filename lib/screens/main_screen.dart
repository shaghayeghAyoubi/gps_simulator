import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/models/notification_permission.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:gps_simulator/screens/settings_screen.dart';

import '../services/location_service.dart';
import '../services/mqtt_service.dart';
import 'history_screen.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ValueNotifier<Map<String, dynamic>?> _taskDataListenable =
  ValueNotifier(null);
  int _selectedIndex = 0;

  // برای ذخیره آخرین موقعیت
  Position? _lastPosition;
  int _locationCount = 0;
  bool _mqttConnected = false;
  String _mqttError = '';

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  Future<void> _requestPermissions() async {
    // For Android 13+, you need to allow notification permission
    if (Platform.isAndroid) {
      final NotificationPermission notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Android 12+, there are restrictions on starting a foreground service
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracking',
        channelName: 'ردیابی موقعیت',
        channelDescription:
        'این نوتیفیکیشن هنگام فعال بودن سرویس ردیابی موقعیت نمایش داده می‌شود',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
        showWhen: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        // Custom notification icon
        // iconData: const AndroidResource(
        //   name: 'ic_stat_location_on',
        //   resType: ResourceType.mipmap,
        // ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        // Every 30 seconds
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  void _onReceiveTaskData(Object data) {
    print('MainScreen: Received task data: $data');

    if (data is Map<String, dynamic>) {
      final action = data['action'];

      switch (action) {
        case 'current_settings':
          print('Current MQTT settings received: $data');
          // می‌توانید این اطلاعات را در SharedPreferences ذخیره کنید
          // یا در UI نمایش دهید
          Get.snackbar(
            'تنظیمات فعلی',
            'بروکر: ${data['broker']}\nپورت: ${data['port']}\nتوپیک: ${data['topic']}',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          break;
        case 'location_update':
          _taskDataListenable.value = data;
          _locationCount = data['count'] ?? _locationCount;

          // Update position
          if (data['latitude'] != null && data['longitude'] != null) {
            _lastPosition = Position(
              latitude: data['latitude'],
              longitude: data['longitude'],
              timestamp:
              DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
              accuracy: data['accuracy'] ?? 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: data['speed'] ?? 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          }
          break;

        case 'mqtt_status':
          _mqttConnected = data['connected'] ?? false;
          _mqttError = data['error'] ?? '';
          print('MQTT Status: Connected=$_mqttConnected, Error=$_mqttError');
          break;

        case 'error':
          print('Error from foreground task: ${data['message']}');
          Get.snackbar(
            'خطا در سرویس',
            data['message'] ?? 'خطای ناشناخته',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          break;

        case 'service_stopped':
          print('Service stopped. Total locations: ${data['total_locations']}');
          Get.snackbar(
            'سرویس متوقف شد',
            'تعداد موقعیت‌های ارسال شده: ${data['total_locations']}',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          break;

        case 'stop_service_request':
          _handleStopServiceRequest();
          break;

        case 'heartbeat':
        // Just for debugging
          print(
            'Heartbeat: ${data['timestamp']}, Count: ${data['count']}, MQTT: ${data['mqtt_connected']}',
          );
          break;

        case 'mqtt_message_sent':
          final mqttService = Get.find<MqttService>();
          mqttService.onMessageSent(
            DateTime.tryParse(data['timestamp'] ?? ''),
          );
          break;
      }

      // Update UI through GetX if needed
      final locationService = Get.find<LocationService>();
      locationService.updateFromForegroundData(data);

      final mqttService = Get.find<MqttService>();
      mqttService.updateFromForeground(data);
    }
  }

  void _handleStopServiceRequest() {
    Get.defaultDialog(
      title: 'درخواست توقف',
      middleText: 'آیا می‌خواهید سرویس ردیابی را متوقف کنید؟',
      textConfirm: 'بله',
      textCancel: 'خیر',
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back();
        await FlutterForegroundTask.stopService();
      },
      onCancel: () {
        // Do nothing
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // Add a callback to receive data sent from the TaskHandler
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Request permissions and initialize the service
      _requestPermissions();
      _initService();
    });
  }

  @override
  void dispose() {
    // Remove the callback
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _taskDataListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'خانه'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'تاریخچه',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'تنظیمات',
            ),
          ],
        ),
      ),
    );
  }
}