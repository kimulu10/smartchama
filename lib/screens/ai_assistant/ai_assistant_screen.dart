import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/ai_chat_model.dart';
import 'package:smartchama/services/ai_assistant_service.dart';

class AIAssistantScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const AIAssistantScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final AIAssistantService _aiService = AIAssistantService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AIChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasLoadedHistory = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final history = await _aiService.getChatHistory(widget.chamaId, user.uid);
    if (mounted) {
      setState(() {
        _messages = history.reversed.toList();
        _hasLoadedHistory = true;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final userMessage = AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chamaId: widget.chamaId,
      userId: user.uid,
      message: message.trim(),
      isUserMessage: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    await _aiService.saveChatMessage(userMessage);

    final response = await _aiService.getResponse(message, widget.chamaId, user.uid);

    final aiMessage = AIChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      chamaId: widget.chamaId,
      userId: user.uid,
      message: response,
      isUserMessage: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(aiMessage);
      _isLoading = false;
    });
    _scrollToBottom();

    await _aiService.saveChatMessage(aiMessage);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final history = await _aiService.getChatHistory(widget.chamaId, user.uid);
    for (var msg in history) {
      await _firestore.collection('ai_chats').doc(msg.id).delete();
    }

    setState(() {
      _messages = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _aiService.getDefaultSuggestions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Financial Assistant'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (!_hasLoadedHistory)
            _buildSuggestionsChips(suggestions)
          else
            _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIChatMessage message) {
    final isUser = message.isUserMessage;
    final time = DateFormat.jm().format(message.timestamp);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 150)),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSuggestionsChips(List<AISuggestion> suggestions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(suggestion.text),
                onPressed: () => _sendMessage(suggestion.text),
                backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                labelStyle: const TextStyle(color: Color(0xFF2E7D32)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about savings, loans, investments...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF2E7D32),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
