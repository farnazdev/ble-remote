import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:http/http.dart' as http;


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const BluetoothScanPage(),
    );
  }
}

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  _BluetoothScanPageState createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  final List<ScanResult> scanResults = [];
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location
    ].request();

    if (statuses[Permission.location]?.isGranted == true) {
      await enableLocation();
    } else {
      Future.delayed(Duration.zero, () {
        if (mounted) showPermissionDeniedMessage();
      });
    }
  }

  Future<void> enableLocation() async {
    if (!(await Permission.location.serviceStatus.isEnabled)) {
      Future.delayed(Duration.zero, () {
        if (mounted) showLocationDisabledMessage();
      });
    }
  }

  void showPermissionDeniedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ Permission Denied! Enable from settings.")),
    );
  }

  void showLocationDisabledMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ Location is turned off! Enable it.")),
    );
  }

  void startScan() async {
    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    await FlutterBluePlus.startScan();
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        for (var result in results) {
          if (!scanResults.any((r) => r.device.remoteId == result.device.remoteId)) {
            scanResults.add(result);
          }
        }
      });
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      isScanning = false;
    });
  }

  void connectToDevice(BluetoothDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DevicePage(device: device)),
    );
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Bluetooth Scan')),
      body: Column(
        children: [
          Expanded(
            child: scanResults.isEmpty
                ? const Center(child: Text('❌ No device found!'))
                : ListView.builder(
                    itemCount: scanResults.length,
                    itemBuilder: (context, index) {
                      final device = scanResults[index].device;
                      return ListTile(
                        leading: const Icon(Icons.bluetooth, color: Colors.blueAccent, size: 30),
                        title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
                        subtitle: Text(device.remoteId.toString()),
                        trailing: ElevatedButton(
                          onPressed: () => connectToDevice(device),
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isScanning ? stopScan : startScan,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: isScanning ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: Text(isScanning ? '⏹ Stop Scan' : '🔍 Start Scan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DevicePage extends StatefulWidget {
  final BluetoothDevice device;
  const DevicePage({super.key, required this.device});

  @override
  _DevicePageState createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool isConnected = false;
  final TextEditingController messageController = TextEditingController();
  final List<String> receivedMessages = [];

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

    Future<void> sendDataToApi(BuildContext context, int inaValue) async {
  final String apiUrl = "https://hivaind.ir/wil/insert81v3.php?id=2027&ina=$inaValue";

  try {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ اتصال ثبت شد: ina=$inaValue")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطا در ارسال اطلاعات! کد: ${response.statusCode}")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ خطا در ارتباط با سرور!")),
    );
  }
}

  void connectToDevice() async {
    try {
      await widget.device.connect();
      if (!mounted) return;
      setState(() {
        isConnected = true;
      });
      // sendDataToApi(context, 1);
      listenForMessages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isConnected = false;
      });
    }
  }

  void listenForMessages() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        characteristic.setNotifyValue(true);
        characteristic.onValueReceived.listen((value) {
          if (!mounted) return;
          setState(() {
            receivedMessages.add(String.fromCharCodes(value));
          });
        });
      }
    }
  }

void sendMessage() async {
  if (!isConnected || messageController.text.isEmpty) return;

  // UUIDهای سرویس و ویژگی مربوطه
  final serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb"); // UUID سرویس
  final characteristicUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb"); // UUID ویژگی

  try {
  List<BluetoothService> services = await widget.device.discoverServices();
  for (var service in services) {
    if (service.uuid == serviceUuid) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicUuid) {
          await characteristic.write(
            messageController.text.codeUnits,
            withoutResponse: false,
          );
          messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Message Sent")),
          );
        }
      }
    }
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Error sending message: $e")),
  );
}
}


  @override
  void dispose() {
    // sendDataToApi(context, 0);
    widget.device.disconnect();
    messageController.dispose();
    super.dispose();
  }
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('Connect to ${widget.device.platformName}')),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.cancel,
                color: isConnected ? Colors.green : Colors.red,
                size: 30,
              ),
              const SizedBox(width: 10),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: receivedMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages received',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: receivedMessages.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            receivedMessages[index],
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  enabled: isConnected,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: isConnected ? Colors.blue : Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: isConnected && messageController.text.isNotEmpty ? sendMessage : null,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}