import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {

  Future<void> saveMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'anna_messages',
      jsonEncode(messages),
    );
  }

  Future<List<Map<String, dynamic>>> loadMessages() async {
    final prefs =
        await SharedPreferences.getInstance();

    final saved =
        prefs.getString('anna_messages');

    if (saved == null) {
      return [];
    }

    final decoded =
        jsonDecode(saved) as List;

    return decoded
        .map(
          (e) => Map<String, dynamic>.from(e),
        )
        .toList();
  }

  Future<void> saveConversationId(
    String id,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'anna_conversation_id',
      id,
    );
  }

  Future<String?> loadConversationId() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
      'anna_conversation_id',
    );
  }
}