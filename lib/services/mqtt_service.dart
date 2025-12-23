import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MqttService extends GetxController {
  static MqttService get instance => Get.find();

  // این سرویس فقط برای نمایش وضعیت در UI استفاده می‌شود
  // اتصال واقعی در foreground task انجام می‌شود

  final _isConnected = false.obs;
  bool get isConnected => _isConnected.value;

  final _connectionStatus = 'در حال بررسی...'.obs;
  String get connectionStatus => _connectionStatus.value;

  final _messagesSent = 0.obs;
  int get messagesSent => _messagesSent.value;

  final _lastMessageTime = Rx<DateTime?>(null);
  DateTime? get lastMessageTime => _lastMessageTime.value;

  final _lastError = Rx<String?>(null);
  String? get lastError => _lastError.value;

  // تنظیمات MQTT (فقط برای نمایش)
  final String broker = '172.15.0.50';
  final int port = 1884;
  final String topic = 'car/#';

  // آمار
  final _totalBytesSent = 0.obs;
  int get totalBytesSent => _totalBytesSent.value;

  @override
  void onInit() {
    super.onInit();
    // وضعیت اولیه
    _connectionStatus.value = 'در انتظار شروع سرویس...';
  }

  // برای به روزرسانی وضعیت از foreground task
  void updateStatus(bool connected, {int? messageCount, String? error}) {
    _isConnected.value = connected;
    _connectionStatus.value = connected ? 'متصل' : 'قطع';
    _lastError.value = error;

    if (messageCount != null) {
      _messagesSent.value = messageCount;
    }

    if (connected) {
      _lastMessageTime.value = DateTime.now();
    }

    update();
  }

  void incrementMessageCount() {
    _messagesSent.value++;
    update();
  }

  void addBytesSent(int bytes) {
    _totalBytesSent.value += bytes;
    update();
  }

  void resetStats() {
    _messagesSent.value = 0;
    _totalBytesSent.value = 0;
    _lastError.value = null;
    update();
  }

  // Map<String, dynamic> getConnectionInfo() {
  //   return {
  //     'broker': broker,
  //     'port': port,
  //     'topic': topic,
  //     'connected': isConnected,
  //     'messagesSent': messagesSent,
  //     'totalBytesSent': totalBytesSent,
  //     'lastError': lastError,
  //     'lastMessageTime': lastMessageTime?.toIso8601String(),
  //   };
  // }

  // String getStatusColor() {
  //   if (isConnected) return 'green';
  //   if (_lastError.value != null) return 'red';
  //   return 'orange';
  // }

  // String getStatusIcon() {
  //   if (isConnected) return '✅';
  //   if (_lastError.value != null) return '❌';
  //   return '⏳';
  // }

  Widget buildStatusWidget() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            color: isConnected ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? 'متصل به MQTT' : 'قطع از MQTT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.green : Colors.orange,
                ),
              ),
              if (!isConnected && _lastError.value != null)
                Text(
                  _lastError.value!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              Text(
                'پیام‌های ارسال شده: $messagesSent',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    // Cleanup
    super.onClose();
  }
}