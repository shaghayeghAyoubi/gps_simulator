import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../services/location_service.dart';
import '../services/mqtt_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LocationService locationService = Get.find<LocationService>();
    final MqttService mqttService = Get.find<MqttService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('صفحه اصلی'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              locationService.getCurrentLocation();
            },
            tooltip: 'دریافت موقعیت فعلی',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // کارت وضعیت ردیابی
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'وضعیت ردیابی',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Obx(() => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: locationService.isTracking
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              locationService.isTracking ? 'فعال' : 'غیرفعال',
                              style: const TextStyle(color: Colors.white),
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Obx(() => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: locationService.isTracking
                                  ? null
                                  : () => locationService.startForegroundService(),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('شروع ردیابی'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: locationService.isTracking
                                  ? () => locationService.stopForegroundService()
                                  : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('توقف ردیابی'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // کارت وضعیت MQTT
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'وضعیت MQTT',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Obx(() => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: mqttService.isConnected.value
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              mqttService.isConnected.value ? 'متصل' : 'قطع',
                              style: const TextStyle(color: Colors.white),
                            ),
                          )),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                mqttService.requestReconnect();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('اتصال مجدد MQTT'),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Obx(() => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('آخرین وضعیت: ${mqttService.connectionStatus}'),
                          if (mqttService.lastError != null)
                            Text(
                              'خطا: ${mqttService.lastError}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          Text('تعداد پیام‌های ارسال شده: ${mqttService.messagesSent}'),
                          if (mqttService.lastMessageTime != null)
                            Text(
                              'آخرین ارسال: ${DateFormat('HH:mm:ss').format(mqttService.lastMessageTime!)}',
                            ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // کارت آخرین موقعیت
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'آخرین موقعیت دریافت شده',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() => locationService.currentPosition == null
                          ? const Text('هنوز موقعیتی دریافت نشده است.')
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'عرض جغرافیایی: ${locationService.currentPosition!.latitude.toStringAsFixed(6)}'),
                          Text(
                              'طول جغرافیایی: ${locationService.currentPosition!.longitude.toStringAsFixed(6)}'),
                          if (locationService.currentPosition!.accuracy != null)
                            Text(
                                'دقت: ${locationService.currentPosition!.accuracy!.toStringAsFixed(2)} متر'),
                          if (locationService.currentPosition!.speed != null)
                            Text(
                                'سرعت: ${(locationService.currentPosition!.speed! * 3.6).toStringAsFixed(2)} کیلومتر بر ساعت'),
                          if (locationService.lastUpdateTime != null)
                            Text(
                                'زمان: ${DateFormat('HH:mm:ss').format(locationService.lastUpdateTime!)}'),
                        ],
                      )),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => locationService.getCurrentLocation(),
                          icon: const Icon(Icons.location_on),
                          label: const Text('دریافت موقعیت فعلی'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // کارت آمار
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'آمار',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('موقعیت‌های ثبت شده'),
                              Text(
                                locationService.totalLocations.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('پیام‌های MQTT'),
                              Text(
                                mqttService.messagesSent.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )),
                      const SizedBox(height: 12),
                      Obx(() => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('GPS'),
                              Icon(
                                locationService.gpsEnabled
                                    ? Icons.gps_fixed
                                    : Icons.gps_off,
                                color: locationService.gpsEnabled
                                    ? Colors.green
                                    : Colors.red,
                                size: 32,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('آخرین به‌روزرسانی'),
                              Text(
                                locationService.lastUpdateTime != null
                                    ? DateFormat('HH:mm:ss')
                                    .format(locationService.lastUpdateTime!)
                                    : '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}