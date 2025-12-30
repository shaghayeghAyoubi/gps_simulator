import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';

import '../main.dart';
import 'mqtt_service.dart';

class LocationService extends GetxController {
  static LocationService get instance => Get.find();

  // Reactive variables for UI
  final _position = Rxn<Position>();
  Position? get currentPosition => _position.value;

  final _isTracking = false.obs;
  bool get isTracking => _isTracking.value;

  final _locationHistory = <Position>[].obs;
  List<Position> get locationHistory => _locationHistory;

  final _gpsEnabled = false.obs;
  bool get gpsEnabled => _gpsEnabled.value;

  // آمار
  final _totalLocations = 0.obs;
  int get totalLocations => _totalLocations.value;

  final _mqttConnected = false.obs;
  bool get mqttConnected => _mqttConnected.value;

  final _lastUpdateTime = Rx<DateTime?>(null);
  DateTime? get lastUpdateTime => _lastUpdateTime.value;

  // برای دریافت داده از foreground task
  StreamSubscription? _foregroundDataSubscription;

  @override
  void onInit() {
    super.onInit();
    _checkGpsStatus();
    _setupForegroundTaskListener();
  }

  void _setupForegroundTaskListener() {
    // Listener is now handled in MainScreen
  }

  void updateFromForegroundData(Map<String, dynamic> data) {
    final action = data['action'];

    switch (action) {
      case 'location_update':
        if (data['latitude'] != null && data['longitude'] != null) {
          final position = Position(
            latitude: data['latitude'],
            longitude: data['longitude'],
            timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
            accuracy: data['accuracy'] ?? 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: data['speed'] ?? 0.0,
            speedAccuracy: 0.0, altitudeAccuracy: 0, headingAccuracy: 0,
          );

          _position.value = position;
          _locationHistory.add(position);
          _totalLocations.value = data['count'] ?? _totalLocations.value + 1;
          _lastUpdateTime.value = DateTime.now();
        }
        break;

      case 'mqtt_status':
        _mqttConnected.value = data['connected'] ?? false;
        if (!_mqttConnected.value && data['error'] != null) {
          Get.snackbar(
            'خطای MQTT',
            data['error'],
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
        break;

      case 'service_stopped':
        _isTracking.value = false;
        break;

      case 'heartbeat':
        _isTracking.value = data['service_running'] ?? _isTracking.value;
        break;
    }

    update();
  }

  Future<void> _checkGpsStatus() async {
    _gpsEnabled.value = await Geolocator.isLocationServiceEnabled();

    Geolocator.getServiceStatusStream().listen((status) {
      _gpsEnabled.value = status == ServiceStatus.enabled;
      update();
    });
  }

  Future<bool> checkPermissions() async {
    print('Checking permissions...');

    // 1. ابتدا مجوز نوتیفیکیشن برای اندروید 13+
    if (Platform.isAndroid) {
      try {
        final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
        if (notificationPermission != NotificationPermission.granted) {
          final result = await FlutterForegroundTask.requestNotificationPermission();
          print('Notification permission result: $result');
        }
      } catch (e) {
        print('Error checking notification permission: $e');
      }
    }

    // 2. بررسی مجوزهای موقعیت
    try {
      print('Checking location permissions...');
      LocationPermission permission = await Geolocator.checkPermission();
      print('Current location permission: $permission');

      if (permission == LocationPermission.denied) {
        print('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('After request location permission: $permission');

        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'خطای دسترسی',
            'برای استفاده از ردیاب، باید اجازه دسترسی به موقعیت را بدهید.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'خطای دسترسی',
          'دسترسی به موقعیت دائما رد شده است. لطفا از تنظیمات دستگاه اجازه دهید.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          mainButton: TextButton(
            onPressed: openAppSettings,
            child: const Text('باز کردن تنظیمات', style: TextStyle(color: Colors.white)),
          ),
        );
        return false;
      }

      // 3. برای اندروید: درخواست اجتناب از بهینه‌سازی باتری
      if (Platform.isAndroid) {
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          print('Requesting battery optimization ignore...');
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }

      // 4. بررسی فعال بودن GPS
      bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
      print('GPS enabled: $isGpsEnabled');

      if (!isGpsEnabled) {
        final shouldEnable = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('GPS غیرفعال است'),
            content: const Text('برای ردیابی موقعیت، GPS باید فعال باشد. آیا می‌خواهید GPS را فعال کنید؟'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('خیر'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('بله'),
              ),
            ],
          ),
        );

        if (shouldEnable == true) {
          await Geolocator.openLocationSettings();
          await Future.delayed(const Duration(seconds: 3));

          isGpsEnabled = await Geolocator.isLocationServiceEnabled();
          if (!isGpsEnabled) {
            Get.snackbar(
              'خطا',
              'GPS هنوز غیرفعال است',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return false;
          }
        } else {
          return false;
        }
      }

      print('All permissions granted successfully!');
      return true;

    } catch (e) {
      print('Error in checkPermissions: $e');
      Get.snackbar(
        'خطا',
        'خطا در بررسی مجوزها: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<void> startForegroundService() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return;

      // Check GPS status
      if (!gpsEnabled) {
        final shouldEnable = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('GPS غیرفعال است'),
            content: const Text('برای ردیابی موقعیت، GPS باید فعال باشد. آیا می‌خواهید GPS را فعال کنید؟'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('خیر'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('بله'),
              ),
            ],
          ),
        );

        if (shouldEnable == true) {
          await Geolocator.openLocationSettings();
          await Future.delayed(const Duration(seconds: 2));

          if (!await Geolocator.isLocationServiceEnabled()) {
            Get.snackbar(
              'خطا',
              'GPS هنوز غیرفعال است',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          }
        } else {
          return;
        }
      }


      final result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'ردیاب موقعیت فعال',
        notificationText: 'در حال ردیابی موقعیت شما...',
        notificationButtons: [
          const NotificationButton(
            id: 'stop_button',
            text: 'توقف',
          ),
        ],
        callback: startCallback,
      );

      _isTracking.value = true;
      update();

      Get.snackbar(
        'شروع ردیابی',
        'ردیابی موقعیت با موفقیت شروع شد',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

    } catch (e) {
      print(e);
      Get.snackbar(
        'خطا',
        'خطا در شروع ردیابی: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> stopForegroundService() async {
    try {
      final result = await FlutterForegroundTask.stopService();

      _isTracking.value = false;
      update();

      Get.snackbar(
        'توقف ردیابی',
        'ردیابی موقعیت متوقف شد',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );

    } catch (e) {
      Get.snackbar(
        'خطا',
        'خطا در توقف سرویس: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return;

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      Get.back();

      _position.value = position;
      _locationHistory.add(position);
      _totalLocations.value++;
      update();

    } catch (e) {
      Get.back();
      Get.snackbar(
        'خطا',
        'خطا در دریافت موقعیت: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void clearHistory() {
    _locationHistory.clear();
    _totalLocations.value = 0;
    update();
  }

  String getAccuracyName(LocationAccuracy accuracy) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return 'بسیار کم';
      case LocationAccuracy.low:
        return 'کم';
      case LocationAccuracy.medium:
        return 'متوسط';
      case LocationAccuracy.high:
        return 'بالا';
      case LocationAccuracy.best:
        return 'بهترین';
      case LocationAccuracy.bestForNavigation:
        return 'بهترین برای ناوبری';
      default:
        return 'متوسط';
    }
  }

  @override
  void onClose() {
    _foregroundDataSubscription?.cancel();
    super.onClose();
  }
}