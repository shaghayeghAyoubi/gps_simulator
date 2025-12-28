import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_simulator/screens/app.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../local/app_storage.dart';

// صفحات


class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  MqttServerClient? _mqttClient;
  int _locationCount = 0;
  bool _isMqttConnected = false;

  // MQTT Configuration
  // ❌ تغییر از final به var
  String _mqttBroker = '172.15.0.50';
  int _mqttPort = 1884;
  String _mqttTopic = 'car/gps';

  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  int _reconnectAttempt = 0;

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.

  Future<void> _loadMqttSettingsFromStorage() async {
    try {
      final ip = await AppStorage.getIp();
      final portString = await AppStorage.getPort();
      final topic = await AppStorage.getTopic();

      _mqttBroker = ip;
      _mqttPort = int.tryParse(portString) ?? _mqttPort;
      _mqttTopic = topic;

      print('📦 MQTT settings loaded from storage');
      print('Broker: $_mqttBroker');
      print('Port  : $_mqttPort');
      print('Topic : $_mqttTopic');
    } catch (e) {
      print('❌ Failed to load MQTT settings from storage: $e');
    }
  }
  void onConnected() {
    print("✅ اتصال برقرار شد");
  }
  Future<void> _initMqtt() async {
    final clientId = 'flutter_fg_${DateTime.now().microsecondsSinceEpoch}';

    _mqttClient = MqttServerClient(_mqttBroker, clientId);
    _mqttClient?.port = _mqttPort;
    try {



      // تنظیمات اتصال
      _mqttClient?.keepAlivePeriod = 60;
      _mqttClient?.onDisconnected = _onMqttDisconnected;
      _mqttClient?.onConnected = onConnected;
      await _mqttClient?.connect();

      // تنظیم پیام اتصال






      if (_mqttClient!.connectionStatus!.state == MqttConnectionState.connected) {
        _isMqttConnected = true;

        print('✅ اتصال MQTT برقرار شد');

        // مشترک شدن در تاپیک

      } else {

      }
    } on NoConnectionException catch (e) {

      print('❌ Broker did not respond: $e');
    } catch (e) {

      print('❌ خطا: $e');
    }
  }






  void _onMqttDisconnected() {
    if (_isReconnecting) return;

    _isMqttConnected = false;
    _sendMqttStatusToUI(false, error: 'Disconnected');

    _safeReconnect();
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
    if (_mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    final payload = {
      "imei": "2828",
      "vehicle_id": "CAR-005",
      "timestamp": DateTime.now().toIso8601String(),
      "position": {
        "latitude": position.latitude,
        "longitude": position.longitude,
        "location_name": "Vanak Square به Niavaran"
      },
      "status": position.speed > 1 ? "moving" : "stopped",
      "speed": (position.speed * 3.6).round(),
      "action": "1"
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));

    _mqttClient!.publishMessage(
      _mqttTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print('📤 Location sent');
  }

  void _sendToMainIsolate(Position position) {
    final data = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'count': _locationCount,
      'timestamp': position.timestamp?.toIso8601String(),
      'accuracy': position.accuracy,
      'speed': position.speed,
      'mqtt_connected': _isMqttConnected,
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

    await _loadMqttSettingsFromStorage();
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


    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;

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
        case 'reconnect_mqtt':
          print('🔁 Reconnecting MQTT by UI request');

          if (_mqttClient != null) {
            try {
              _mqttClient!.disconnect();
            } catch (_) {}
            _mqttClient = null;
          }

          _isMqttConnected = false;
          _sendMqttStatusToUI(false, error: 'در حال اتصال مجدد...');

          _safeReconnect();
          break;

        case 'reset_stats':
          _resetStats();
          break;

      }
    }
  }
  Future<void> _safeReconnect() async {
    if (_isReconnecting) {
      print('⏳ Reconnect already in progress, skip');
      return;
    }

    _isReconnecting = true;

    try {
      if (_mqttClient != null) {
        try {
          _mqttClient!.disconnect();
        } catch (_) {}
        _mqttClient = null;
      }

      _isMqttConnected = false;
      _sendMqttStatusToUI(false, error: 'در حال اتصال مجدد...');

      // ⏱ صبر کن شبکه stabilize شود
      await Future.delayed(const Duration(seconds: 3));

      await _initMqtt();
    } finally {
      _isReconnecting = false;
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

  void _resetStats() {
    print('🔄 Resetting foreground stats');

    _locationCount = 0;

    FlutterForegroundTask.sendDataToMain({
      'action': 'stats_reset',
      'location_count': _locationCount,
    });
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