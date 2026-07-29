import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:my_farmer/screens/auth_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Farmer',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AuthGate(), // Ovo sada mora raditi
    );
  }
}