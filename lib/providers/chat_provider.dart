import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:vietspots/models/chat_model.dart';
import 'package:vietspots/models/place_model.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechAvailable = false;
  String _lastSpeechResult = '';

  // Streaming display state for bot messages (partial reveal like ChatGPT)
  final Map<String, String> _streamingText = {};
  static final MethodChannel _recorderChannel = MethodChannel(
    'vietspots/recorder',
  );

  // Recording state exposed for UI
  bool _isRecording = false;
  DateTime? _recordingStart;

  bool get isRecording => _isRecording;

  /// Duration in seconds since recording started (0 if not recording)
  int get recordingDuration {
    if (!_isRecording || _recordingStart == null) return 0;
    return DateTime.now().difference(_recordingStart!).inSeconds;
  }

  // Storage key for chat history
  static const String _chatHistoryKey = 'chat_history';

  ChatProvider(this._chatService, this._placeService, [dynamic outboundQueue]) {
    _getUserLocation();
    _loadChatHistoryFromLocal();
    // Initialize on-device speech recognizer in background
    _initSpeechRecognizer();
  }

  Future<void> _initSpeechRecognizer() async {
    try {
      _speechAvailable = await _speechToText.initialize();
      notifyListeners();
    } catch (_) {
      _speechAvailable = false;
    }
  }

  /// Start push-to-talk recording. Returns true if recording started.
  Future<bool> startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return false;
      _isRecording = true;
      _recordingStart = DateTime.now();
      notifyListeners();
      // Prefer package-based on-device SpeechRecognizer (speech_to_text)
      try {
        String lang = 'vi-VN';
        try {
          final prefs = await SharedPreferences.getInstance();
          lang = prefs.getString('preferred_stt_language') ?? lang;
        } catch (_) {}

        final localeId = lang.replaceAll('-', '_');

        if (!_speechAvailable) {
          _speechAvailable = await _speechToText.initialize();
        }

        if (_speechAvailable) {
          _lastSpeechResult = '';
          _speechToText.listen(
            onResult: (r) {
              _lastSpeechResult = r.recognizedWords;
              notifyListeners();
            },
            localeId: localeId,
            listenFor: const Duration(minutes: 1),
          );
          return true;
        }
      } catch (e) {
        debugPrint('speech_to_text start failed: $e');
      }

      // Fallback: platform recorder via MethodChannel
      try {
        final started = await _recorderChannel.invokeMethod<bool>(
          'startListening',
        );
        if (started == true) return true;
      } catch (_) {}

      try {
        final path = await _recorderChannel.invokeMethod<String>('start');
        if (path != null && path.isNotEmpty) return true;
      } catch (_) {}

      try {
        final path = await _recorderChannel.invokeMethod<String>('start');
        return path != null && path.isNotEmpty;
      } catch (_) {
        return false;
      }
    } catch (e) {
      debugPrint('Start recording failed: $e');
      _isRecording = false;
      _recordingStart = null;
      notifyListeners();
      return false;
    }
  }

  /// Stop recording and transcribe. Returns the transcript (if any).
  Future<String?> stopRecordingAndTranscribe() async {
    try {
      // stop recording UI state first
      _isRecording = false;
      final startedAt = _recordingStart;
      _recordingStart = null;
      notifyListeners();
      // First try package-based on-device STT (speech_to_text)
      try {
        if (_speechAvailable && _speechToText.isListening) {
          await _speechToText.stop();
          if (_lastSpeechResult.isNotEmpty) return _lastSpeechResult;
        }
      } catch (e) {
        debugPrint('speech_to_text stop failed: $e');
      }

      String? path;
      // Fallback: platform stop which may return a transcript or a file path
      try {
        final transcript = await _recorderChannel.invokeMethod<String>(
          'stopListening',
        );
        if (transcript != null && transcript.isNotEmpty) return transcript;
      } catch (_) {}

      try {
        path = await _recorderChannel.invokeMethod<String>('stop');
      } catch (_) {
        path = null;
      }

      if (path == null || path.isEmpty) return null;
      final file = File(path);

      // Upload to backend STT endpoint
      try {
        // Read preferred STT language if present
        String lang = 'vi-VN';
        try {
          final prefs = await SharedPreferences.getInstance();
          lang = prefs.getString('preferred_stt_language') ?? lang;
        } catch (_) {}

        final resp = await _chatService.transcribeAudioFile(
          file,
          language: lang,
        );
        final transcript = resp['transcript']?.toString() ?? '';
        if (transcript.isNotEmpty) {
          // Log duration if available
          if (startedAt != null) {
            final dur = DateTime.now().difference(startedAt).inSeconds;
            debugPrint('STT transcript received (recording ${dur}s)');
          }
          return transcript;
        }
      } catch (e) {
        debugPrint('Transcription failed: $e');
      }
    } catch (e) {
      debugPrint('Stop recording failed: $e');
    }
    return null;
  }

  /// Play TTS for given text (non-blocking). Errors are logged.
  Future<void> playTts(String text, {String language = 'vi-VN'}) async {
    try {
      final file = await _chatService.synthesizeTextToSpeech(
        text,
        language: language,
      );
      // Use DeviceFileSource on newer audioplayers versions
      if (file.existsSync()) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(file.path));
        return;
      }
      debugPrint('TTS file not found, falling back to platform TTS');
    } catch (e) {
      debugPrint('Play TTS failed: $e');
    }

    // Fallback: try platform TTS (on-device)
    try {
      await _audioPlayer.stop();
      await _flutterTts.setLanguage(language);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Fallback platform TTS failed: $e');
    }
  }

  @override
  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (_) {}
    try {
      _flutterTts.stop();
    } catch (_) {}
    try {
      if (_speechAvailable) {
        _speechToText.stop();
      }
    } catch (_) {}
    super.dispose();
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
                // Rehydrate relatedPlaces if present
                List<Place>? relatedPlaces;
                if (msg is Map<String, dynamic> &&
                    msg['relatedPlaces'] is List) {
                  relatedPlaces = (msg['relatedPlaces'] as List<dynamic>)
                      .map<Place?>((p) {
                        if (p is Map<String, dynamic>) {
                          return Place(
                            id: p['id']?.toString() ?? '',
                            nameLocalized: (p['nameLocalized'] is Map)
                                ? Map<String, String>.from(p['nameLocalized'])
                                : null,
                            imageUrl: p['imageUrl']?.toString() ?? '',
                            rating: (p['rating'] is num)
                                ? (p['rating'] as num).toDouble()
                                : 0.0,
                            location: p['location']?.toString() ?? '',
                            commentCount: (p['commentCount'] is int)
                                ? p['commentCount'] as int
                                : (p['commentCount'] is num)
                                ? (p['commentCount'] as num).toInt()
                                : 0,
                            ratingCount: (p['ratingCount'] is int)
                                ? p['ratingCount'] as int
                                : (p['ratingCount'] is num)
                                ? (p['ratingCount'] as num).toInt()
                                : 0,
                            latitude: (p['latitude'] is num)
                                ? (p['latitude'] as num).toDouble()
                                : 0.0,
                            longitude: (p['longitude'] is num)
                                ? (p['longitude'] as num).toDouble()
                                : 0.0,
                            descriptionLocalized:
                                (p['descriptionLocalized'] is Map)
                                ? Map<String, String>.from(
                                    p['descriptionLocalized'],
                                  )
                                : null,
                            comments: <PlaceComment>[],
                          );
                        }
                        return null;
                      })
                      .whereType<Place>()
                      .toList();
                }

                return ChatMessage(
                  id: msg['id']?.toString() ?? DateTime.now().toString(),
                  text: msg['text']?.toString() ?? '',
                  isUser: msg['isUser'] == true,
                  timestamp: msg['timestamp'] != null
                      ? DateTime.tryParse(msg['timestamp'].toString()) ??
                            DateTime.now()
                      : DateTime.now(),
                  relatedPlaces: relatedPlaces,
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
                      'relatedPlaces': msg.relatedPlaces
                          ?.map(
                            (p) => {
                              'id': p.id,
                              'nameLocalized': p.nameLocalized,
                              'imageUrl': p.imageUrl,
                              'rating': p.rating,
                              'location': p.location,
                              'commentCount': p.commentCount,
                              'ratingCount': p.ratingCount,
                              'latitude': p.latitude,
                              'longitude': p.longitude,
                              'descriptionLocalized': p.descriptionLocalized,
                            },
                          )
                          .toList(),
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

  /// Get current streaming text for a message id (returns null if not streaming)
  String? streamingTextFor(String messageId) => _streamingText[messageId];
  List<ChatConversation> get history => List.unmodifiable(_history);
  String? get activeConversationId => _activeConversationId;

  ChatConversation? get activeConversation {
    if (_activeConversationId == null) return null;
    return _findConversation(_activeConversationId!);
  }

  String get activeTitle => activeConversation?.title ?? 'VietSpots';

  Future<void> deleteConversation(String id) async {
    final idx = _history.indexWhere((c) => c.id == id);
    if (idx != -1) {
      // if deleting active, clear messages and active id
      if (_activeConversationId == id) {
        _activeConversationId = null;
        _messages.clear();
      }
      _history.removeAt(idx);
      await _saveChatHistoryToLocal();
      notifyListeners();
    }
  }

  /// Persist a single conversation (or refresh storage) so it remains after app restarts.
  Future<void> saveConversation(String id) async {
    final conv = _findConversation(id);
    if (conv == null) return;
    conv.updatedAt = DateTime.now();
    await _saveChatHistoryToLocal();
    notifyListeners();
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
    // Prevent sending while a response is being generated
    if (_isLoading) return;

    // Add user message
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Mark loading immediately to avoid duplicate sends while the bot is processing
    _isLoading = true;
    notifyListeners();

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

      // Start progressive reveal for bot message (word-by-word)
      _startStreamingReveal(botMsg.id, botMsg.text);

      // Play TTS for bot reply in background (do not block UI)
      try {
        playTts(botMsg.text);
      } catch (_) {}
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

  /// Reveal `text` for message `messageId` gradually (word-by-word).
  void _startStreamingReveal(String messageId, String text) async {
    final words = text.split(RegExp(r'\s+'));
    _streamingText[messageId] = '';
    notifyListeners();

    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(words[i]);
      _streamingText[messageId] = buffer.toString();
      notifyListeners();
      // Small delay to simulate streaming; tune as needed.
      await Future.delayed(const Duration(milliseconds: 140));
    }

    // Done streaming — remove streaming entry
    _streamingText.remove(messageId);
    notifyListeners();
  }
}
