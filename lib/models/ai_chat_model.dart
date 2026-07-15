class AIChatMessage {
  final String id;
  final String chamaId;
  final String userId;
  final String message;
  final bool isUserMessage;
  final DateTime timestamp;
  final String? category;

  AIChatMessage({
    required this.id,
    required this.chamaId,
    required this.userId,
    required this.message,
    required this.isUserMessage,
    required this.timestamp,
    this.category,
  });

  factory AIChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return AIChatMessage(
      id: id,
      chamaId: map['chamaId'] ?? '',
      userId: map['userId'] ?? '',
      message: map['message'] ?? '',
      isUserMessage: map['isUserMessage'] ?? false,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      category: map['category'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'userId': userId,
      'message': message,
      'isUserMessage': isUserMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (category != null) 'category': category,
    };
  }
}

class AISuggestion {
  final String id;
  final String text;
  final String category;

  AISuggestion({
    required this.id,
    required this.text,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'category': category,
    };
  }

  factory AISuggestion.fromMap(Map<String, dynamic> map) {
    return AISuggestion(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      category: map['category'] ?? 'general',
    );
  }
}
