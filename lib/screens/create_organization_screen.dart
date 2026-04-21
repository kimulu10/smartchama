import 'package:flutter/material.dart';

class CreateOrganizationScreen extends StatelessWidget {
  const CreateOrganizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Organization")),
      body: const Center(
        child: Text(
          "Welcome to SmartChama Dashboard",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}