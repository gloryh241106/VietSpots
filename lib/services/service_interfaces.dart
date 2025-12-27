// Minimal service interfaces to satisfy implementations.
// Kept intentionally small to avoid circular imports.

abstract class IChatService {
  Future<dynamic> chat(dynamic request);

  Future<Map<String, dynamic>> getChatConfig();

  Future<dynamic> saveItinerary(dynamic request);

  Future<List<Map<String, dynamic>>> listItineraries(String sessionId);

  Future<dynamic> saveMessage(dynamic request);

  Future<List<Map<String, dynamic>>> loadMessages(String sessionId);
}
