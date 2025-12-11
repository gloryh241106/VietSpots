import 'package:flutter/material.dart';
import 'package:vietspots/models/chat_model.dart';
import 'package:vietspots/utils/mock_data.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => _messages;

  void sendMessage(String text) {
    // Add user message
    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    notifyListeners();

    // Simulate Bot Response
    Future.delayed(const Duration(seconds: 1), () {
      _generateBotResponse(text);
    });
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

    _messages.add(botMsgFixed);
    notifyListeners();
  }
}
