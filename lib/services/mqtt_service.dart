import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';

class MqttService extends GetxController {
  static MqttService get instance => Get.find();

  final RxBool isConnected = false.obs;


  final RxString _connectionStatus = 'در انتظار شروع سرویس...'.obs;
  String get connectionStatus => _connectionStatus.value;

  final RxInt _messagesSent = 0.obs;
  int get messagesSent => _messagesSent.value;

  final Rx<DateTime?> _lastMessageTime = Rx<DateTime?>(null);
  DateTime? get lastMessageTime => _lastMessageTime.value;

  final RxnString lastError = RxnString();


  @override
  void onInit() {
    super.onInit();
    // _listenToForeground();
  }

  void updateFromForeground(Map<String, dynamic> data) {
    if (data['action'] == 'mqtt_status') {
      isConnected.value = data['connected'] ?? false;
      lastError.value = data['error'] ?? '';
    }
  }
  void requestResetStats() {
    FlutterForegroundTask.sendDataToTask({
      'action': 'reset_stats',
    });
  }



  /// 🔁 درخواست reconnect از Foreground Service
  void requestReconnect() {
    FlutterForegroundTask.sendDataToTask({
      'action': 'reconnect_mqtt',
    });

    _connectionStatus.value = 'در حال اتصال مجدد...';
  }
}
