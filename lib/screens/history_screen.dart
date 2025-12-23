import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../services/location_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LocationService locationService = Get.find<LocationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تاریخچه موقعیت‌ها'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Get.defaultDialog(
                title: 'پاک کردن تاریخچه',
                middleText: 'آیا از پاک کردن تمام تاریخچه موقعیت‌ها مطمئن هستید؟',
                textConfirm: 'بله',
                textCancel: 'خیر',
                confirmTextColor: Colors.white,
                onConfirm: () {
                  locationService.clearHistory();
                  Get.back();
                },
              );
            },
            icon: const Icon(Icons.delete),
            tooltip: 'پاک کردن تاریخچه',
          ),
        ],
      ),
      body: Obx(() {
        final history = locationService.locationHistory;

        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'هیچ موقعیتی در تاریخچه وجود ندارد',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: history.length,
          reverse: true, // جدیدترین ابتدا
          itemBuilder: (context, index) {
            final position = history[history.length - 1 - index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'موقعیت ${history.length - index}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm:ss').format(position.timestamp!),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (position.accuracy != null)
                      Row(
                        children: [
                           Icon(Icons.currency_bitcoin, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text('دقت: ${position.accuracy!.toStringAsFixed(2)} متر'),
                        ],
                      ),
                    if (position.speed != null && position.speed! > 0)
                      Row(
                        children: [
                          const Icon(Icons.speed, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text('سرعت: ${(position.speed! * 3.6).toStringAsFixed(2)} کیلومتر بر ساعت'),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy/MM/dd - HH:mm:ss').format(position.timestamp!),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: Obx(() {
        if (locationService.locationHistory.isEmpty) {
          return Text("data"); // اینجا می‌توانید null برگردانید
        }

        return FloatingActionButton.extended(
          onPressed: () {
            Get.defaultDialog(
              title: 'پاک کردن تاریخچه',
              middleText: 'آیا از پاک کردن تمام تاریخچه موقعیت‌ها مطمئن هستید؟',
              textConfirm: 'بله',
              textCancel: 'خیر',
              confirmTextColor: Colors.white,
              onConfirm: () {
                locationService.clearHistory();
                Get.back();
              },
            );
          },
          icon: const Icon(Icons.delete),
          label: const Text('پاک کردن تاریخچه'),
          backgroundColor: Colors.red,
        );
      }),
    );
  }
}