import 'package:flutter/material.dart';

enum MessageChannel {
  announcement,
  push,
  sms,
  email,
  inAppChat,
  meetingInvite,
}

extension MessageChannelExtension on MessageChannel {
  String get displayName {
    switch (this) {
      case MessageChannel.announcement:
        return 'Announcement';
      case MessageChannel.push:
        return 'Push Notification';
      case MessageChannel.sms:
        return 'SMS';
      case MessageChannel.email:
        return 'Email';
      case MessageChannel.inAppChat:
        return 'In-App Chat';
      case MessageChannel.meetingInvite:
        return 'Meeting Invite';
    }
  }

  IconData get icon {
    switch (this) {
      case MessageChannel.announcement:
        return Icons.campaign;
      case MessageChannel.push:
        return Icons.notifications_active;
      case MessageChannel.sms:
        return Icons.sms;
      case MessageChannel.email:
        return Icons.email;
      case MessageChannel.inAppChat:
        return Icons.chat;
      case MessageChannel.meetingInvite:
        return Icons.event;
    }
  }
}

enum MessageStatus { draft, scheduled, sent, failed, partiallySent }

extension MessageStatusExtension on MessageStatus {
  String get displayName {
    switch (this) {
      case MessageStatus.draft:
        return 'Draft';
      case MessageStatus.scheduled:
        return 'Scheduled';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.failed:
        return 'Failed';
      case MessageStatus.partiallySent:
        return 'Partially Sent';
    }
  }
}

class CommunicationMessage {
  final String id;
  final String organizationId;
  final String? chamaId;
  final MessageChannel channel;
  final String subject;
  final String body;
  final List<String> recipientIds;
  final int recipientCount;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final String? createdBy;

  CommunicationMessage({
    required this.id,
    required this.organizationId,
    this.chamaId,
    required this.channel,
    required this.subject,
    required this.body,
    this.recipientIds = const [],
    this.recipientCount = 0,
    this.status = MessageStatus.draft,
    required this.createdAt,
    this.scheduledAt,
    this.sentAt,
    this.createdBy,
  });

  factory CommunicationMessage.fromMap(Map<String, dynamic> map, String id) {
    return CommunicationMessage(
      id: id,
      organizationId: map['organizationId'] ?? '',
      chamaId: map['chamaId'],
      channel: MessageChannel.values[map['channel'] ?? 0],
      subject: map['subject'] ?? '',
      body: map['body'] ?? '',
      recipientIds: List<String>.from(map['recipientIds'] ?? []),
      recipientCount: map['recipientCount'] ?? 0,
      status: MessageStatus.values[map['status'] ?? 0],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      scheduledAt: map['scheduledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduledAt'])
          : null,
      sentAt: map['sentAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['sentAt'])
          : null,
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'chamaId': chamaId,
      'channel': channel.index,
      'subject': subject,
      'body': body,
      'recipientIds': recipientIds,
      'recipientCount': recipientCount,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'scheduledAt': scheduledAt?.millisecondsSinceEpoch,
      'sentAt': sentAt?.millisecondsSinceEpoch,
      'createdBy': createdBy,
    };
  }
}

class NotificationTemplate {
  final String id;
  final String organizationId;
  final String key;
  final String title;
  final String body;
  final MessageChannel channel;

  NotificationTemplate({
    required this.id,
    required this.organizationId,
    required this.key,
    required this.title,
    required this.body,
    required this.channel,
  });

  factory NotificationTemplate.fromMap(Map<String, dynamic> map, String id) {
    return NotificationTemplate(
      id: id,
      organizationId: map['organizationId'] ?? '',
      key: map['key'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      channel: MessageChannel.values[map['channel'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'key': key,
      'title': title,
      'body': body,
      'channel': channel.index,
    };
  }
}
