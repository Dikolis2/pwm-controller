import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PWM Control',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: const BLEScreen(),
    );
  }
}

class BLEScreen extends StatefulWidget {
  const BLEScreen({super.key});

  @override
  State<BLEScreen> createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> {
  BluetoothDevice? device;
  BluetoothCharacteristic? levelChar;
  BluetoothCharacteristic? timerChar;
  BluetoothCharacteristic? controlChar;

  int level = 1;
  int minutes = 0, seconds = 0;
  bool isConnected = false;

  final serviceUuid = "12345678-1234-5678-9abc-def012345678";
  final levelUuid = "12345678-1234-5678-9abc-def012345679";
  final timerUuid = "12345678-1234-5678-9abc-def01234567a";
  final controlUuid = "12345678-1234-5678-9abc-def01234567b";

  @override
  void initState() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (result.device.name == "ESP32-PWM") {
          FlutterBluePlus.stopScan();
          connectToDevice(result.device);
        }
      }
    });
    super.initState();
  }

  void connectToDevice(BluetoothDevice dev) async {
    device = dev;
    await device!.connect();
    setState(() => isConnected = true);

    var services = await device!.discoverServices();
    var service = services.firstWhere((s) => s.uuid.toString().toLowerCase() == serviceUuid);

    levelChar = service.characteristics.firstWhere((c) => c.uuid.toString().toLowerCase() == levelUuid);
    timerChar = service.characteristics.firstWhere((c) => c.uuid.toString().toLowerCase() == timerUuid);
    controlChar = service.characteristics.firstWhere((c) => c.uuid.toString().toLowerCase() == controlUuid);

    await levelChar!.setNotifyValue(true);
    await timerChar!.setNotifyValue(true);

    levelChar!.lastValueStream.listen((value) {
      setState(() => level = value[0]);
    });

    timerChar!.lastValueStream.listen((value) {
      int totalSec = (value[0] << 8) | value[1];
      setState(() {
        minutes = totalSec ~/ 60;
        seconds = totalSec % 60;
      });
    });
  }

  void sendCommand(int cmd) async {
    await controlChar?.write([cmd], withoutResponse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PWM Controller")),
      body: Center(
        child: isConnected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Уровень: $level", style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 20),
                  Text("${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 28, fontFamily: 'monospace')),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        onPressed: () => sendCommand(0x00),
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 40),
                      FloatingActionButton(
                        onPressed: () => sendCommand(0x01),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text("Индикация ленты", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 60, height: 20, color: level >= 1 ? Colors.green : Colors.grey),
                      Container(width: 90, height: 20, color: level >= 2 ? Colors.yellow : Colors.grey),
                      Container(width: 60, height: 20, color: level >= 4 ? Colors.red : Colors.grey),
                    ],
                  ),
                ],
              )
            : const Text("Подключение..."),
      ),
    );
  }
}
