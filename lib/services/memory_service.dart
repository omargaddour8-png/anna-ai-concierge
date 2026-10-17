import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_memory.dart';

class MemoryService {
  static const String key = 'user_memory';

  Future<UserMemory> loadMemory() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(key);

    if (data == null) {
      return UserMemory();
    }

    return UserMemory.fromJson(
      jsonDecode(data),
    );
  }

  Future<void> saveMemory(UserMemory memory) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      key,
      jsonEncode(memory.toJson()),
    );
  }
  Future<void> clearMemory() async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.remove('user_memory');
}
}