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
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController agendaController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedStatus = 'scheduled';
  List<Map<String, dynamic>> agendaItems = [];
  List<String> selectedAttendees = [];
  List<Map<String, dynamic>> members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final snapshot = await firestore
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('chamas')
        .doc(widget.chamaId)
        .collection('members')
        .get();
    setState(() {
      members = snapshot.docs.map((d) => {
        'id': d.id,
        'name': d['name'] ?? d['email'] ?? 'Member',
        'email': d['email'] ?? '',
      }).toList();
    });
  }

  Future<void> createMeeting() async {
    if (titleController.text.trim().isEmpty) return;

    await firestore.collection("meetings").add({
      "chamaId": widget.chamaId,
      "organizationId": widget.organizationId,
      "title": titleController.text.trim(),
      "description": descriptionController.text.trim(),
      "location": locationController.text.trim(),
      "date": selectedDate.millisecondsSinceEpoch,
      "time": '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}',
      "status": selectedStatus,
      "attendees": selectedAttendees,
      "agenda": agendaItems,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting created successfully')),
    );
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

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  void _addAgendaItem() {
    if (agendaController.text.trim().isEmpty) return;
    setState(() {
      agendaItems.add({'item': agendaController.text.trim(), 'done': false});
      agendaController.clear();
    });
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
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Meeting Title"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: "Location / Venue"),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickDate,
                    child: Text("Date: ${selectedDate.toLocal()}".split(' ')[0]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickTime,
                    child: Text("Time: ${selectedTime.format(context)}"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(labelText: "Status"),
              items: const [
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (v) => setState(() => selectedStatus = v!),
            ),
            const SizedBox(height: 10),
            const Text("Attendees", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: selectedAttendees.map((a) {
                final member = members.firstWhere((m) => m['id'] == a, orElse: () => {'name': a});
                return Chip(
                  label: Text(member['name']),
                  onDeleted: () => setState(() => selectedAttendees.remove(a)),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            DropdownButton<String>(
              hint: const Text('Add Attendee'),
              isExpanded: true,
              items: members.map((m) {
                return DropdownMenuItem(
                  value: m['id'] as String,
                  child: Text(m['name'] ?? m['email'] ?? ''),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null && !selectedAttendees.contains(v)) {
                  setState(() => selectedAttendees.add(v));
                }
              },
            ),
            const SizedBox(height: 10),
            const Text("Agenda", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...agendaItems.map((item) => ListTile(
              dense: true,
              leading: Checkbox(
                value: item['done'],
                onChanged: (v) {
                  setState(() => item['done'] = v ?? false);
                },
              ),
              title: Text(item['item'], style: TextStyle(decoration: item['done'] ? TextDecoration.lineThrough : null)),
            )),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: agendaController,
                    decoration: const InputDecoration(labelText: "Add agenda item"),
                  ),
                ),
                IconButton(
                  onPressed: _addAgendaItem,
                  icon: const Icon(Icons.add),
                ),
              ],
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
