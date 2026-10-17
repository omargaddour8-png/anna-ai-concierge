import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String webhookUrl;

  ChatService({
    required this.webhookUrl,
  });

  Future<String> sendTextMessage({
    required String message,
    required String conversationId,
  }) async {
    final response = await http.post(
      Uri.parse(webhookUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "message": message,
        "conversation_id": conversationId,
      }),
    );

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      try {
        final data =
            jsonDecode(response.body);

        return data["reply"] ??
            "No reply received.";
      } catch (_) {
        return response.body;
      }
    }

    throw Exception(
      "Server returned ${response.statusCode}",
    );
  }
}