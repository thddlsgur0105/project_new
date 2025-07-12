import 'package:flutter/material.dart';
import 'package:device_frame/device_frame.dart';
import 'screens/welcome_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DeviceFrame(
        device: Devices.ios.iPhone16Pro,
        isFrameVisible: true,
        screen: MaterialApp(home: WelcomePage()),
      ),
    );
  }
}
