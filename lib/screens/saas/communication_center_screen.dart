import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/communication_model.dart';
import 'package:smartchama/services/communication_service.dart';

/// Communication Center: announcements, push, SMS, email, in-app chat and
/// meeting invitations, centralised per tenant.
class CommunicationCenterScreen extends StatefulWidget {
  final String organizationId;
  const CommunicationCenterScreen({super.key, required this.organizationId});

  @override
  State<CommunicationCenterScreen> createState() =>
      _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState
    extends State<CommunicationCenterScreen> {
  final CommunicationService _service = CommunicationService();
  List<CommunicationMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _messages = await _service.getMessages(widget.organizationId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Communication Center')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context),
        label: const Text('Compose'),
        icon: const Icon(Icons.edit),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(child: Text('No messages sent yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _MessageCard(_messages[i]),
                ),
    );
  }

  Future<void> _compose(BuildContext context) async {
    final recipients = await _service.getRecipients(widget.organizationId);
    if (!mounted) return;
    final channel = await showDialog<MessageChannel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select channel'),
        children: MessageChannel.values.map((c) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c),
            child: Row(children: [
              Icon(c.icon, size: 20),
              const SizedBox(width: 10),
              Text(c.displayName),
            ]),
          );
        }).toList(),
      ),
    );
    if (channel == null) return;

    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${channel.displayName} message'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 8),
              TextField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 4),
              const SizedBox(height: 8),
              Text('Recipients: ${recipients.length}',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _service.send(
                organizationId: widget.organizationId,
                channel: channel,
                subject: subjectCtrl.text,
                body: bodyCtrl.text,
                recipientIds: recipients.map((r) => r['userId'] as String? ?? '').toList(),
              );
              Navigator.pop(ctx, true);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent == true) _load();
  }
}

class _MessageCard extends StatelessWidget {
  final CommunicationMessage message;
  const _MessageCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(message.channel.icon, color: Colors.green),
        ),
        title: Text(message.subject),
        subtitle: Text(
            '${message.channel.displayName} • ${message.recipientCount} recipients • ${DateFormat('dd MMM').format(message.createdAt)}'),
        trailing: Chip(
          label: Text(message.status.displayName),
          backgroundColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}
