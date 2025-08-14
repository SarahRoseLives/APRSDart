import 'package:flutter/material.dart';
import 'ui/homescreen/homescreen.dart';

void main() {
  runApp(const APRSDartApp());
}

class APRSDartApp extends StatelessWidget {
  const APRSDartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APRSDart',
      debugShowCheckedModeBanner: false, // <--- Added this line
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}