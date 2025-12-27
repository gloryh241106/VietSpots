import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vietspots/models/chat_model.dart';
import 'package:vietspots/services/chat_service.dart';
import 'package:vietspots/services/place_service.dart';
import 'package:geolocator/geolocator.dart';

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
  final ChatService _chatService;
  final PlaceService _placeService;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  Position? _userPosition;

  // In-session history (FACT): project has no local storage dependency
  // (no shared_preferences/hive/etc), so we keep history in memory.
  final List<ChatConversation> _history = [];
  String? _activeConversationId;

  // Storage key for chat history
  static const String _chatHistoryKey = 'chat_history';

  ChatProvider(this._chatService, this._placeService) {
    _getUserLocation();
    _loadChatHistoryFromLocal();
  }

  /// Load chat history from local storage
  Future<void> _loadChatHistoryFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_chatHistoryKey);

      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        debugPrint(
          '📥 Loading ${historyList.length} conversations from local storage',
        );

        for (final convData in historyList) {
          final messages =
              (convData['messages'] as List<dynamic>?)?.map((msg) {
                return ChatMessage(
                  id: msg['id']?.toString() ?? DateTime.now().toString(),
                  text: msg['text']?.toString() ?? '',
                  isUser: msg['isUser'] == true,
                  timestamp: msg['timestamp'] != null
                      ? DateTime.tryParse(msg['timestamp'].toString()) ??
                            DateTime.now()
                      : DateTime.now(),
                );
              }).toList() ??
              [];

          final conv = ChatConversation(
            id: convData['id']?.toString() ?? DateTime.now().toString(),
            title: convData['title']?.toString() ?? 'Chat',
            createdAt: convData['createdAt'] != null
                ? DateTime.tryParse(convData['createdAt'].toString()) ??
                      DateTime.now()
                : DateTime.now(),
            updatedAt: convData['updatedAt'] != null
                ? DateTime.tryParse(convData['updatedAt'].toString()) ??
                      DateTime.now()
                : DateTime.now(),
            messages: messages,
          );

          _history.add(conv);
        }

        // Load the most recent conversation into active messages
        if (_history.isNotEmpty) {
          final lastConv = _history.first;
          _activeConversationId = lastConv.id;
          _messages.addAll(lastConv.messages);
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history from local: $e');
    }
  }

  /// Save chat history to local storage
  Future<void> _saveChatHistoryToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final historyList = _history
          .map(
            (conv) => {
              'id': conv.id,
              'title': conv.title,
              'createdAt': conv.createdAt.toIso8601String(),
              'updatedAt': conv.updatedAt.toIso8601String(),
              'messages': conv.messages
                  .map(
                    (msg) => {
                      'id': msg.id,
                      'text': msg.text,
                      'isUser': msg.isUser,
                      'timestamp': msg.timestamp.toIso8601String(),
                    },
                  )
                  .toList(),
            },
          )
          .toList();

      await prefs.setString(_chatHistoryKey, jsonEncode(historyList));
      debugPrint('💾 Saved ${_history.length} conversations to local storage');
    } catch (e) {
      debugPrint('❌ Error saving chat history to local: $e');
    }
  }

  bool get isLoading => _isLoading;

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      _userPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      // Silently handle location error
    }
  }

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

    // Save message to Supabase (fire and forget)
    _saveChatMessage(userMsg, conv.id);
    try {
      final uid = _chatService.getCurrentUserId() ?? 'anonymous';
      _chatService.saveMessage(
        ChatMessageSaveRequest(
          sessionId: conv.id,
          userId: uid,
          message: userMsg.text,
          isUser: true,
          timestamp: userMsg.timestamp,
        ),
      );
    } catch (e) {
      debugPrint('Failed to send user message to Supabase: $e');
    }

    // Call real backend API
    _generateBotResponse(text);
  }

  /// Save chat message to local storage
  Future<void> _saveChatMessage(
    ChatMessage message,
    String conversationId,
  ) async {
    // Save the entire chat history to local storage
    await _saveChatHistoryToLocal();
    debugPrint('💾 Chat message saved to local storage');
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

  Future<void> _generateBotResponse(String userText) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Call backend chat API (timeout handled in service layer)
      final response = await _chatService.chat(
        ChatRequest(
          message: userText,
          sessionId: _activeConversationId ?? 'default-session',
          userLat: _userPosition?.latitude,
          userLon: _userPosition?.longitude,
        ),
      );

      // Convert PlaceDTO to Place for display
      final places = response.places.map((dto) => dto.toPlace()).toList();

      // Debug: Print the actual text received
      debugPrint('📝 Response text length: ${response.answer.length}');
      debugPrint(
        '📝 Response text (first 500 chars): ${response.answer.substring(0, response.answer.length > 500 ? 500 : response.answer.length)}',
      );
      debugPrint('📝 Contains \\n: ${response.answer.contains('\n')}');
      debugPrint('📝 Contains \\r\\n: ${response.answer.contains('\r\n')}');

      // Fix markdown formatting: ensure proper spacing for list items
      // Replace single newlines between numbered items with double newlines
      String formattedText = response.answer;

      // Add blank line before numbered list items (except at the start)
      formattedText = formattedText.replaceAllMapped(
        RegExp(r'([^\n])\n(\d+\.\s+\*\*)', multiLine: true),
        (match) => '${match.group(1)}\n\n${match.group(2)}',
      );

      // Also handle regular numbered items without bold
      formattedText = formattedText.replaceAllMapped(
        RegExp(r'([^\n])\n(\d+\.\s+[^\*\n])', multiLine: true),
        (match) => '${match.group(1)}\n\n${match.group(2)}',
      );

      debugPrint(
        '📝 Formatted text (first 500 chars): ${formattedText.substring(0, formattedText.length > 500 ? 500 : formattedText.length)}',
      );

      // Create bot message with response
      final botMsg = ChatMessage(
        id: DateTime.now().toString(),
        text: formattedText,
        isUser: false,
        timestamp: DateTime.now(),
        relatedPlaces: places.isNotEmpty ? places : null,
      );

      // Append to active conversation
      final activeId = _activeConversationId;
      if (activeId != null) {
        final conv = _findConversation(activeId);
        if (conv != null) {
          conv.messages.add(botMsg);
          conv.updatedAt = DateTime.now();
        }
      }

      _messages.add(botMsg);

      // Save bot response to local storage and Supabase (fire and forget)
      _saveChatMessage(botMsg, _activeConversationId ?? 'default-session');
      try {
        final uid = _chatService.getCurrentUserId() ?? 'anonymous';
        _chatService.saveMessage(
          ChatMessageSaveRequest(
            sessionId: _activeConversationId ?? 'default-session',
            userId: uid,
            message: botMsg.text,
            isUser: false,
            timestamp: botMsg.timestamp,
          ),
        );
      } catch (e) {
        debugPrint('Failed to send bot message to Supabase: $e');
      }
    } catch (e) {
      // Debug: Log the actual error
      debugPrint('❌ Chat API Error: $e');
      debugPrint('Error type: ${e.runtimeType}');

      // Try graceful fallback: suggest nearby top-rated places
      try {
        final dtos = await _placeService.getPlaces(
          limit: 5,
          lat: _userPosition?.latitude,
          lon: _userPosition?.longitude,
          maxDistance: 50,
          sortBy: 'rating',
          minRating: 0.1,
        );
        final places = dtos.map((d) => d.toPlace()).toList();
        final fallbackMsg = ChatMessage(
          id: DateTime.now().toString(),
          text: 'Kết nối chậm nên tạm gợi ý nhanh một số địa điểm gần bạn nhé:',
          isUser: false,
          timestamp: DateTime.now(),
          relatedPlaces: places,
        );
        final activeId = _activeConversationId;
        if (activeId != null) {
          final conv = _findConversation(activeId);
          if (conv != null) {
            conv.messages.add(fallbackMsg);
            conv.updatedAt = DateTime.now();
          }
        }
        _messages.add(fallbackMsg);
      } catch (e2) {
        // Fallback to error message
        String errorText = 'Xin lỗi, tôi gặp vấn đề khi xử lý yêu cầu của bạn.';

        if (e.toString().contains('Backend đang quá tải') ||
            e.toString().contains('TimeoutException')) {
          errorText =
              'Kết nối với server quá lâu. Vui lòng kiểm tra mạng và thử lại. 📡';
        } else if (e.toString().contains('SocketException')) {
          errorText =
              'Không có kết nối internet. Vui lòng kiểm tra mạng của bạn. 📶';
        }

        final errorMsg = ChatMessage(
          id: DateTime.now().toString(),
          text: errorText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        final activeId = _activeConversationId;
        if (activeId != null) {
          final conv = _findConversation(activeId);
          if (conv != null) {
            conv.messages.add(errorMsg);
            conv.updatedAt = DateTime.now();
          }
        }

        _messages.add(errorMsg);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
