import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// صفحات
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

// مدیریت سرویس‌ها
import 'services/location_service.dart';
import 'services/mqtt_service.dart';

void main() {
  // Initialize port for communication between TaskHandler and UI.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
}

// The callback function should always be a top-level or static function.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  MqttServerClient? _mqttClient;
  int _locationCount = 0;
  bool _isMqttConnected = false;

  // MQTT Configuration
  // ❌ تغییر از final به var
  String _mqttBroker = '172.15.0.50';
  int _mqttPort = 1884;
  String _mqttTopic = 'car/#';

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.

  Future<void> _initMqtt() async {
    try {
      final clientId = 'flutter_fg_${DateTime.now().millisecondsSinceEpoch}';

      _mqttClient = MqttServerClient(_mqttBroker, clientId)
        ..port = _mqttPort
        ..logging(on: true) // ✅ VERY IMPORTANT
        ..keepAlivePeriod = 30
        ..connectTimeoutPeriod = 5000 // ⏱ timeout
        ..autoReconnect = false
        ..onDisconnected = _onMqttDisconnected
        ..onConnected = () {
          print('MQTT onConnected callback fired');
        }
        ..onSubscribed = (topic) {
          print('Subscribed to $topic');
        };

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean() // ⚠️ مهم
          .withWillQos(MqttQos.atLeastOnce);

      _mqttClient!.connectionMessage = connMess;

      print('================ MQTT CONNECT ATTEMPT ================');
      print('Broker: $_mqttBroker');
      print('Port  : $_mqttPort');
      print('Client: $clientId');

      await _mqttClient!.connect();

      final status = _mqttClient!.connectionStatus;
      print('MQTT connection status: $status');

      if (status?.state == MqttConnectionState.connected) {
        _isMqttConnected = true;
        print('✅ MQTT CONNECTED');
        _sendMqttStatusToUI(true);
      } else {
        _isMqttConnected = false;
        print('❌ MQTT FAILED: ${status?.state}');
        _sendMqttStatusToUI(
          false,
          error: 'MQTT state: ${status?.state}',
        );
      }
    } on NoConnectionException catch (e) {
      print('❌ NoConnectionException: $e');
      _sendMqttStatusToUI(false, error: e.toString());
    } on SocketException catch (e) {
      print('❌ SocketException: $e');
      _sendMqttStatusToUI(false, error: 'Socket error: ${e.message}');
    } on Exception catch (e) {
      print('❌ General MQTT Exception: $e');
      _sendMqttStatusToUI(false, error: e.toString());
    }
  }


  void _onMqttDisconnected() {
    final status = _mqttClient?.connectionStatus;
    print('❌ MQTT DISCONNECTED');
    print('State: ${status?.state}');
    print('Return code: ${status?.returnCode}');
    _isMqttConnected = false;

    _sendMqttStatusToUI(
      false,
      error: 'Disconnected: ${status?.returnCode}',
    );
  }

  // Start location tracking in foreground task
  Future<void> _startLocationTracking() async {
    try {
      print('Starting location tracking...');

      // ابتدا مجوزها را چک کن
      print('Checking permissions in foreground task...');
      LocationPermission permission = await Geolocator.checkPermission();
      print('Foreground task permission: $permission');

      if (permission == LocationPermission.denied) {
        print('Requesting permission in foreground task...');
        permission = await Geolocator.requestPermission();
        print('After request in foreground task: $permission');
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        print(
          'Location permission granted in foreground task, starting tracking...',
        );

        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        );

        _positionStream =
            Geolocator.getPositionStream(
              locationSettings: locationSettings,
            ).listen(
              (Position position) {
                print(
                  'New position received: ${position.latitude}, ${position.longitude}',
                );
                _locationCount++;

                // 1. Send to MQTT
                _sendToMqtt(position);

                // 2. Send to UI for display
                _sendToMainIsolate(position);

                // 3. Update notification
                _updateNotification(position);
              },
              onError: (error) {
                print('Location stream error: $error');
                _sendErrorToUI('Location error: $error');
              },
            );
      } else {
        print('Location permission denied in foreground task');
        _sendErrorToUI('Location permission denied in foreground task');
      }
    } catch (e) {
      print('Location Tracking Error: $e');
      _sendErrorToUI('Tracking error: $e');
    }
  }

  Future<void> _sendToMqtt(Position position) async {
    print('MQTT state before publish: '
        '${_mqttClient?.connectionStatus?.state}');
    if (_mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      print('❌ MQTT NOT CONNECTED - SKIP SEND');
      return;
    }
    if (_isMqttConnected &&
        _mqttClient?.connectionStatus?.state == MqttConnectionState.connected) {
      try {
        final payload =
            '''
{
  "device_id": "${_mqttClient?.clientIdentifier}",
  "latitude": ${position.latitude},
  "longitude": ${position.longitude},
  "accuracy": ${position.accuracy},
  "altitude": ${position.altitude},
  "speed": ${position.speed},
  "heading": ${position.heading},
  "timestamp": "${position.timestamp?.toIso8601String()}",
  "speed_accuracy": ${position.speedAccuracy},
  "broker": "$_mqttBroker",
  "topic": "$_mqttTopic",
  "count": $_locationCount
}
''';

        final builder = MqttClientPayloadBuilder();
        builder.addString(payload);

        _mqttClient!.publishMessage(
          _mqttTopic, // استفاده از متغیر
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        print(
          'Sent location #$_locationCount to MQTT (Broker: $_mqttBroker, Topic: $_mqttTopic)',
        );
      } catch (e) {
        print('Error sending to MQTT: $e');
        _isMqttConnected = false;
      }
    } else {
      print('MQTT not connected, cannot send location');
    }
  }

  void _sendToMainIsolate(Position position) {
    final data = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'count': _locationCount,
      'timestamp': position.timestamp?.toIso8601String(),
      'accuracy': position.accuracy,
      'speed': position.speed,
      'action': 'location_update',
    };
    FlutterForegroundTask.sendDataToMain(data);
  }

  void _sendMqttStatusToUI(bool connected, {String? error}) {
    final data = {
      'action': 'mqtt_status',
      'connected': connected,
      'error': error,
    };
    FlutterForegroundTask.sendDataToMain(data);
  }

  void _sendErrorToUI(String error) {
    final data = {'action': 'error', 'message': error};
    FlutterForegroundTask.sendDataToMain(data);
  }

  void _updateNotification(Position position) {
    FlutterForegroundTask.updateService(
      notificationTitle: '📍 موقعیت فعال',
      notificationText:
          'موقعیت‌ها: $_locationCount | آخرین: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
    );
  }

  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Foreground Task Started at $timestamp');

    // Initialize MQTT
    await _initMqtt();

    // Start location tracking
    await _startLocationTracking();

    _updateNotification(
      Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ),
    );
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Optional: Periodic checks
    print('Foreground Task Periodic Check at $timestamp');

    // Send heartbeat to UI
    FlutterForegroundTask.sendDataToMain({
      'action': 'heartbeat',
      'timestamp': timestamp.toIso8601String(),
      'count': _locationCount,
      'mqtt_connected': _isMqttConnected,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('Foreground Task Destroyed at $timestamp (isTimeout: $isTimeout)');

    // 1. توقف stream موقعیت
    await _positionStream?.cancel();
    _positionStream = null;

    // 2. قطع MQTT (بدون await اگر خطا داد)
    if (_mqttClient != null) {
      try {
        // فقط disconnect را فراخوانی کن، نتیجه را نادیده بگیر
        _mqttClient!.disconnect();
      } on Error catch (e) {
        print('Error calling disconnect: $e');
      } catch (e) {
        print('Exception calling disconnect: $e');
      }

      // منابع را آزاد کن
      _mqttClient = null;
    }

    // 3. به‌روزرسانی وضعیت
    _isMqttConnected = false;

    // 4. اطلاع به UI
    FlutterForegroundTask.sendDataToMain({
      'action': 'service_stopped',
      'total_locations': _locationCount,
    });
  }

  // و متد onReceiveData را به روز کنید:
  @override
  void onReceiveData(Object data) {
    print('LocationTaskHandler: Received data from UI: $data');

    if (data is Map<String, dynamic>) {
      final action = data['action'];

      switch (action) {
        case 'update_mqtt_settings':
          // دریافت تنظیمات جدید MQTT
          final newBroker = data['broker'] ?? _mqttBroker;
          final newPort = data['port'] ?? _mqttPort;
          final newTopic = data['topic'] ?? _mqttTopic;

          print('Updating MQTT settings to: $newBroker:$newPort - $newTopic');

          // اگر تنظیمات تغییر نکرده، کاری نکن
          if (newBroker == _mqttBroker &&
              newPort == _mqttPort &&
              newTopic == _mqttTopic) {
            print('Settings unchanged, skipping reconnection');
            return;
          }

          // قطع اتصال قبلی
          if (_mqttClient != null) {
            try {
              _mqttClient!.disconnect();
            } catch (e) {
              print('Error disconnecting old client: $e');
            }
            _mqttClient = null;
            _isMqttConnected = false;
          }

          // به‌روزرسانی تنظیمات
          _mqttBroker = newBroker;
          _mqttPort = newPort;
          _mqttTopic = newTopic;

          // اتصال مجدد با تنظیمات جدید
          _initMqtt();

          // اطلاع به UI
          _sendMqttStatusToUI(false, error: 'در حال اتصال با تنظیمات جدید...');
          break;

        case 'test_mqtt':
          // تست اتصال
          _sendMqttStatusToUI(_isMqttConnected);
          break;

        case 'get_current_settings':
          // ارسال تنظیمات فعلی به UI
          FlutterForegroundTask.sendDataToMain({
            'action': 'current_settings',
            'broker': _mqttBroker,
            'port': _mqttPort,
            'topic': _mqttTopic,
          });
          break;
      }
    }
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('LocationTaskHandler: Notification button pressed: $id');

    if (id == 'stop_button') {
      FlutterForegroundTask.sendDataToMain({
        'action': 'stop_service_request',
        'source': 'notification_button',
      });
    }
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    print('LocationTaskHandler: Notification pressed');
    FlutterForegroundTask.sendDataToMain({'action': 'notification_pressed'});
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    print('LocationTaskHandler: Notification dismissed');
  }
}

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
      }

      // Update UI through GetX if needed
      final locationService = Get.find<LocationService>();
      locationService.updateFromForegroundData(data);
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
