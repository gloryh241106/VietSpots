import 'package:flutter/material.dart';
import 'package:vietspots/models/chat_model.dart';
import 'package:vietspots/utils/mock_data.dart';

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
}

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];

  // In-session history (FACT): project has no local storage dependency
  // (no shared_preferences/hive/etc), so we keep history in memory.
  final List<ChatConversation> _history = [];
  String? _activeConversationId;

  List<ChatMessage> get messages => _messages;
  List<ChatConversation> get history => List.unmodifiable(_history);
  String? get activeConversationId => _activeConversationId;

  ChatConversation? get activeConversation {
    if (_activeConversationId == null) return null;
    return _findConversation(_activeConversationId!);
  }

  String get activeTitle => activeConversation?.title ?? 'VietSpots';

  void deleteConversation(String id) {
    final idx = _history.indexWhere((c) => c.id == id);
    if (idx != -1) {
      // if deleting active, clear messages and active id
      if (_activeConversationId == id) {
        _activeConversationId = null;
        _messages.clear();
      }
      _history.removeAt(idx);
      notifyListeners();
    }
  }

  ChatConversation? _findConversation(String id) {
    for (final conv in _history) {
      if (conv.id == id) return conv;
    }
    return null;
  }

  ChatConversation _ensureActiveConversation({String? seedTitle}) {
    final existingId = _activeConversationId;
    if (existingId != null) {
      final existing = _findConversation(existingId);
      if (existing != null) return existing;
    }

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final title = (seedTitle ?? 'New conversation').trim();
    final conv = ChatConversation(
      id: id,
      title: title.isEmpty ? 'New conversation' : title,
      createdAt: now,
      updatedAt: now,
      messages: <ChatMessage>[],
    );

    _activeConversationId = id;
    _history.insert(0, conv);
    return conv;
  }

  void sendMessage(String text) {
    // Add user message
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Ensure we have an active conversation to append messages into.
    final conv = _ensureActiveConversation(
      seedTitle: trimmed.length <= 28
          ? trimmed
          : '${trimmed.substring(0, 28)}…',
    );
    conv.messages.add(userMsg);
    conv.updatedAt = DateTime.now();

    _messages.add(userMsg);
    notifyListeners();

    // Simulate Bot Response
    Future.delayed(const Duration(seconds: 1), () {
      _generateBotResponse(text);
    });
  }

  void clearMessages() {
    // Start a new conversation; keep existing history in memory.
    _activeConversationId = null;
    _messages.clear();
    notifyListeners();
  }

  void loadConversation(String conversationId) {
    final conv = _findConversation(conversationId);
    if (conv == null) return;

    _activeConversationId = conversationId;
    _messages
      ..clear()
      ..addAll(conv.messages);
    notifyListeners();
  }

  void _generateBotResponse(String userText) {
    String botText = "I'm sorry, I didn't understand that.";
    List<dynamic>? places;

    if (userText.toLowerCase().contains("quận 12")) {
      botText = "Here are some interesting places in District 12 for you:";
      places = MockDataService.district12Places;
    } else {
      botText =
          "I can help you find places to visit. Try asking about 'District 12'.";
    }

    // Fix casting properly
    final botMsgFixed = ChatMessage(
      id: DateTime.now().toString(),
      text: botText,
      isUser: false,
      timestamp: DateTime.now(),
      relatedPlaces: places != null ? List.from(places) : null,
    );

    // Append to active conversation (if exists).
    final activeId = _activeConversationId;
    if (activeId != null) {
      final conv = _findConversation(activeId);
      if (conv != null) {
        conv.messages.add(botMsgFixed);
        conv.updatedAt = DateTime.now();
      }
    }

    _messages.add(botMsgFixed);
    notifyListeners();
  }
}
