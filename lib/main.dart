import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT GPS Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SimpleMqtt(),
    );
  }
}

class SimpleMqtt extends StatefulWidget {
  const SimpleMqtt({super.key});

  @override
  State<SimpleMqtt> createState() => _SimpleMqttState();
}

class _SimpleMqttState extends State<SimpleMqtt> {
  late MqttServerClient client;
  bool isConnected = false;
  String message = "";

  int _locationCount = 0;

  @override
  void initState() {
    super.initState();

    client = MqttServerClient('172.15.0.50', 'flutter_client');
    client.port = 1884;
    client.keepAlivePeriod = 60;
    client.logging(on: true);

    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
  }

  // ================= MQTT =================

  Future<void> connectAndSubscribe() async {
    try {
      setState(() => message = "در حال اتصال...");

      await client.connect();

      client.subscribe('car/gps', MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> msgs) {
        final payload = msgs.first.payload as MqttPublishMessage;
        final receivedMessage =
        String.fromCharCodes(payload.payload.message);

        setState(() {
          message = "📥 پیام دریافتی:\n$receivedMessage";
        });

        print("📥 Received: $receivedMessage");
      });
    } catch (e) {
      setState(() => message = "❌ خطا در اتصال: $e");
      client.disconnect();
    }
  }

  void onConnected() {
    setState(() {
      isConnected = true;
      message = "✅ اتصال برقرار شد";
    });
    print("✅ Connected");
  }

  void onDisconnected() {
    setState(() {
      isConnected = false;
      message = "❌ اتصال قطع شد";
    });
    print("❌ Disconnected");
  }

  void onSubscribed(String topic) {
    print("📝 Subscribed to $topic");
  }

  // ================= GPS MESSAGE =================

  String buildGpsMessage() {
    _locationCount++;

    final payload = {
      "imei": "2828",
      "vehicle_id": "CAR-005",
      "timestamp": DateTime.now().toIso8601String(),
      "position": {
        "latitude": 35.805,
        "longitude": 51.437,
        "location_name": "Vanak Square به Niavaran",
      },
      "status": 12.5 > 1 ? "moving" : "stopped",
      "speed": (12.5 * 3.6).round(),
      "fuel_level": 78,
      "engine_temp": 85,
      "odometer": 125000 + _locationCount,
      "route_progress": "150/300",
      "route_completed": false,
      "eta_minutes": 45.5,
      "alerts": ["none"],
      "route_id": "Vanak Square_Niavaran_CAR-005",
      "start_location": "Vanak Square",
      "end_location": "Niavaran",
      "direction": "normal",
      "action": "1",
    };

    return jsonEncode(payload);
  }

  void sendGpsMessage() {
    if (!isConnected) {
      setState(() => message = "⚠️ ابتدا اتصال را برقرار کنید");
      return;
    }

    final gpsJson = buildGpsMessage();
    final builder = MqttClientPayloadBuilder();
    builder.addString(gpsJson);

    client.publishMessage(
      'car/gps',
      MqttQos.atMostOnce,
      builder.payload!,
    );

    setState(() {
      message = "📤 پیام GPS ارسال شد:\n$gpsJson";
    });

    print("📤 Sent: $gpsJson");
  }

  void disconnect() {
    client.disconnect();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MQTT GPS Simulator"),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _statusCard(),
            const SizedBox(height: 20),
            _buttons(),
            const SizedBox(height: 30),
            _messageBox(),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Text(
            isConnected ? "متصل" : "قطع اتصال",
            style: TextStyle(
              fontSize: 18,
              color: isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons() {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: const Text("اتصال به MQTT"),
          onPressed: connectAndSubscribe,
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.location_on),
          label: const Text("ارسال GPS"),
          onPressed: sendGpsMessage,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 50),
            backgroundColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.link_off),
          label: const Text("قطع اتصال"),
          onPressed: disconnect,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 50),
            backgroundColor: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _messageBox() {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }
}
