import 'package:flutter/material.dart';

import 'home.dart';
import 'theme.dart';

void main() {
  runApp(const CrocellApp());
}

class CrocellApp extends StatelessWidget {
  const CrocellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crocell',
      debugShowCheckedModeBanner: false,
      theme: crocellTheme(Brightness.light),
      darkTheme: crocellTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
