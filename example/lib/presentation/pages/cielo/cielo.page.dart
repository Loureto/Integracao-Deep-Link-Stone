import 'package:flutter/material.dart';

class CieloPage extends StatefulWidget {
  const CieloPage({super.key});

  @override
  State<CieloPage> createState() => _CieloPageState();
}

class _CieloPageState extends State<CieloPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      body: SingleChildScrollView(child: Column(children: [])),
    );
  }
}
