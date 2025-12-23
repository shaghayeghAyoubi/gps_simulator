import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/mqtt_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService locationService = Get.find<LocationService>();
  final MqttService mqttService = Get.find<MqttService>();

  // کنترلرهای فرم
  final _brokerController = TextEditingController();
  final _portController = TextEditingController();
  final _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // مقداردهی اولیه کنترلرها با مقادیر فعلی
    _brokerController.text = mqttService.broker;
    _portController.text = mqttService.port.toString();
    _topicController.text = mqttService.topic;
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _updateMqttSettings() async {
    // اعتبارسنجی
    final broker = _brokerController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final topic = _topicController.text.trim();

    if (broker.isEmpty) {
      Get.snackbar(
        'خطا',
        'آدرس بروکر نمی‌تواند خالی باشد.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (port == null || port <= 0 || port > 65535) {
      Get.snackbar(
        'خطا',
        'پورت معتبر نیست.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (topic.isEmpty) {
      Get.snackbar(
        'خطا',
        'توپیک نمی‌تواند خالی باشد.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // ارسال تنظیمات جدید به foreground task
    try {
       FlutterForegroundTask.sendDataToTask({
        'action': 'update_mqtt_settings',
        'broker': broker,
        'port': port,
        'topic': topic,
      });

      Get.snackbar(
        'موفقیت',
        'تنظیمات MQTT ارسال شدند.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'خطا',
        'خطا در ارسال تنظیمات: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // تنظیمات MQTT
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تنظیمات MQTT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brokerController,
                      decoration: const InputDecoration(
                        labelText: 'آدرس بروکر',
                        hintText: 'مثال: test.mosquitto.org',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cloud),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'پورت',
                        hintText: 'مثال: 1883',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        labelText: 'توپیک',
                        hintText: 'مثال: location/tracking',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.topic),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _updateMqttSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('ذخیره تنظیمات MQTT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    // در SettingsScreen، بعد از دکمه ذخیره تنظیمات
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // درخواست تنظیمات فعلی از foreground task
                          FlutterForegroundTask.sendDataToTask({
                            'action': 'get_current_settings',
                          });

                          // گوش دادن برای پاسخ
                          // این نیاز به اضافه کردن listener در MainScreen دارد
                          Get.snackbar(
                            'درخواست تنظیمات',
                            'درخواست تنظیمات فعلی ارسال شد',
                            backgroundColor: Colors.blue,
                            colorText: Colors.white,
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('دریافت تنظیمات فعلی'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // تنظیمات موقعیت‌یابی
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تنظیمات موقعیت‌یابی',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(() => SwitchListTile(
                      title: const Text('GPS فعال'),
                      subtitle: Text(
                        locationService.gpsEnabled ? 'GPS روشن است' : 'GPS خاموش است',
                      ),
                      value: locationService.gpsEnabled,
                      onChanged: (value) {
                        Get.defaultDialog(
                          title: 'تغییر وضعیت GPS',
                          middleText:
                          'برای تغییر وضعیت GPS باید به تنظیمات دستگاه بروید.',
                          textConfirm: 'باز کردن تنظیمات',
                          textCancel: 'انصراف',
                          confirmTextColor: Colors.white,
                          onConfirm: () async {
                            Get.back();
                            await Geolocator.openLocationSettings();
                          },
                        );
                      },
                    )),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.location_history),
                      title: const Text('تاریخچه موقعیت‌ها'),
                      subtitle: Obx(() => Text(
                          '${locationService.totalLocations} موقعیت ذخیره شده')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: locationService.totalLocations > 0
                            ? () {
                          Get.defaultDialog(
                            title: 'پاک کردن تاریخچه',
                            middleText:
                            'آیا از پاک کردن تمام تاریخچه موقعیت‌ها مطمئن هستید؟',
                            textConfirm: 'بله',
                            textCancel: 'خیر',
                            confirmTextColor: Colors.white,
                            onConfirm: () {
                              locationService.clearHistory();
                              Get.back();
                            },
                          );
                        }
                            : null,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: const Text('مجوزها'),
                      subtitle: const Text('مدیریت مجوزهای دسترسی'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await locationService.checkPermissions();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // اطلاعات برنامه
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اطلاعات برنامه',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('نام برنامه'),
                      subtitle: Text('ردیاب موقعیت MQTT'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.code),
                      title: Text('نسخه'),
                      subtitle: Text('1.0.0'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.description),
                      title: Text('توضیحات'),
                      subtitle: Text('ردیابی موقعیت و ارسال به سرور MQTT'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('بازنشانی آمار'),
                      subtitle: const Text('پاک کردن تمام آمار و تاریخچه'),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () {
                          Get.defaultDialog(
                            title: 'بازنشانی آمار',
                            middleText:
                            'آیا از بازنشانی تمام آمار و تاریخچه مطمئن هستید؟',
                            textConfirm: 'بله',
                            textCancel: 'خیر',
                            confirmTextColor: Colors.white,
                            onConfirm: () {
                              locationService.clearHistory();
                              mqttService.resetStats();
                              Get.back();
                              Get.snackbar(
                                'موفقیت',
                                'آمار بازنشانی شد.',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text('لاگ‌های دیباگ'),
                      subtitle: const Text('مشاهده لاگ‌های برنامه'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // می‌توانید صفحه لاگ‌ها را اینجا اضافه کنید
                        Get.snackbar(
                          'لاگ‌ها',
                          'این ویژگی در نسخه بعدی اضافه خواهد شد.',
                          backgroundColor: Colors.blue,
                          colorText: Colors.white,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // دکمه تست اتصال MQTT
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  FlutterForegroundTask.sendDataToTask({
                    'action': 'test_mqtt',
                  });
                  Get.snackbar(
                    'تست اتصال',
                    'درخواست تست اتصال ارسال شد.',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                  );
                },
                icon: const Icon(Icons.wifi),
                label: const Text('تست اتصال MQTT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // دکمه راهنمایی
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Get.defaultDialog(
                    title: 'راهنمای استفاده',
                    content: const SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('1. ابتدا مجوزهای لازم را از صفحه تنظیمات فعال کنید'),
                          SizedBox(height: 8),
                          Text('2. دکمه "شروع ردیابی" را بزنید'),
                          SizedBox(height: 8),
                          Text('3. برنامه حتی در پس‌زمینه موقعیت‌ها را ارسال می‌کند'),
                          SizedBox(height: 8),
                          Text('4. برای توقف، از نوتیفیکیشن یا دکمه توقف استفاده کنید'),
                          SizedBox(height: 8),
                          Text('5. تاریخچه موقعیت‌ها در صفحه تاریخچه قابل مشاهده است'),
                        ],
                      ),
                    ),
                    textConfirm: 'متوجه شدم',
                    onConfirm: () => Get.back(),
                  );
                },
                icon: const Icon(Icons.help),
                label: const Text('راهنمای استفاده'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}