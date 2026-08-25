import 'package:flutter/material.dart';

const kAppName = 'DailySpur';

class DailySpurApp extends StatelessWidget {
  const DailySpurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Demo')),
        body: const Center(child: Text('Hello World')),
      ),
    );
  }
}
