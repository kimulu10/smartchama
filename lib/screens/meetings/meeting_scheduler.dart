import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingScheduler extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const MeetingScheduler({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<MeetingScheduler> createState() => _MeetingSchedulerState();
}

class _MeetingSchedulerState extends State<MeetingScheduler> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController titleController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  Future<void> createMeeting() async {
    await firestore.collection("meetings").add({
      "chamaId": widget.chamaId,
      "title": titleController.text,
      "date": selectedDate.millisecondsSinceEpoch,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });

    Navigator.pop(context);
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule Meeting"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Meeting Title"),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickDate,
              child: Text("Pick Date: ${selectedDate.toLocal()}"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: createMeeting,
              child: const Text("Create Meeting"),
            )
          ],
        ),
      ),
    );
  }
}