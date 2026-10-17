import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/memory_service.dart';
import 'models/user_memory.dart';
import 'widgets/message_bubble.dart';
import 'services/storage_service.dart';
import 'widgets/service_card.dart';
import 'widgets/typing_indicator.dart';
import 'services/chat_service.dart';

// import 'package:geolocator/geolocator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final StorageService _storageService = StorageService();
  final MemoryService _memoryService = MemoryService();
  late ChatService _chatService;
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final SpeechToText speech = SpeechToText();
  final ImagePicker picker = ImagePicker();

  bool isListening = false;
  bool annaTyping = false;
  File? selectedImage;
  final String webhookUrl =
      'https://hook.eu1.make.com/scmnfgpddnq2cud1vfligm5h0n3fpklr';
  late String conversationId;
  Map<String, dynamic> leadData = {};
  bool collectingLead = false;
  String currentLeadStep = "";
  final List<Map<String, dynamic>> messages = [
    {
      "text":
          "👋 Welcome!\n\n"
          "I'm Anna, your AI Concierge.\n\n"
          "🏥 Doctors & Hospitals\n"
          "💊 Pharmacies\n"
          "🔥 Heating Services\n"
          "🚿 Plumbing Services\n"
          "⚡ Electrical Services\n"
          "🌿 Gardening Services\n"
          "🛞 Tire & Auto Experts\n"
          "📅 Appointments\n"
          "🚨 Emergency Support\n\n"
          "How can I help you today?",
      "isUser": false,
      "time": "",
    }
  ];

@override
void initState() {
  super.initState();

  conversationId = const Uuid().v4();

  _chatService = ChatService(
    webhookUrl: webhookUrl,
  );

  initializeChat();
}
  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  String getCurrentTime() {
    final now = DateTime.now();

    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  int getMemoryCount(UserMemory memory) {
  int count = 0;

  if (memory.name != null && memory.name!.isNotEmpty) {
    count++;
  }

  if (memory.city != null && memory.city!.isNotEmpty) {
    count++;
  }

  if (memory.vehicle != null &&
      memory.vehicle!.isNotEmpty) {
    count++;
  }

  if (memory.phone != null &&
      memory.phone!.isNotEmpty) {
    count++;
  }

  return count;
}

  // =========================================================
  // FUTURE GPS SUPPORT (COMMENTED OUT)
  // =========================================================

  // Future<Position?> getLocation() async {
  //   try {
  //     LocationPermission permission =
  //         await Geolocator.checkPermission();
  //
  //     if (permission == LocationPermission.denied) {
  //       permission =
  //           await Geolocator.requestPermission();
  //     }
  //
  //     if (permission == LocationPermission.denied ||
  //         permission == LocationPermission.deniedForever) {
  //       return null;
  //     }
  //
  //     return await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.high,
  //     );
  //   } catch (_) {
  //     return null;
  //   }
  // }
  Future<void> startLeadFlow(String service) async {
  leadData.clear();

  leadData["service"] = service;

  collectingLead = true;
  currentLeadStep = "name";

  setState(() {
    messages.add({
      "text":
          "I'll help you with your $service request.\n\nWhat is your name?",
      "isUser": false,
      "time": getCurrentTime(),
    });
  });
  await _storageService.saveMessages(
  messages,);
}
Future<void> processLeadFlow(
  String answer,
) async {
 final userText = controller.text.trim();

await updateMemory(userText);

final memory =
    await _memoryService.loadMemory();


  switch (currentLeadStep) {
    case "name":
      leadData["name"] = answer;

      memory.name = answer;
      await _memoryService.saveMemory(memory);

      currentLeadStep = "phone";

      await addAnnaMessage(
        "What phone number should we contact you on?",
      );
      break;

    case "phone":
      leadData["phone"] = answer;

      memory.phone = answer;
      await _memoryService.saveMemory(memory);

      currentLeadStep = "city";

      await addAnnaMessage(
        "Which city are you located in?",
      );
      break;

    case "city":
      leadData["city"] = answer;

      memory.city = answer;
      await _memoryService.saveMemory(memory);

      currentLeadStep = "date";

      await addAnnaMessage(
        "What is your preferred appointment date?",
      );
      break;

    case "date":
      leadData["appointment_date"] = answer;

      await submitLead();

      collectingLead = false;
      currentLeadStep = "";

      await addAnnaMessage(
        "✅ Thank you! Your request has been submitted. We will contact you soon.",
      );
      break;
  }
}
Future<void> addAnnaMessage(String text) async {
  setState(() {
    messages.add({
      "text": text,
      "isUser": false,
      "time": getCurrentTime(),
    });
  });
  await _storageService.saveMessages(messages,);
  scrollToBottom();
}
Future<void> submitLead() async {
  try {
    await http.post(
      Uri.parse(webhookUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "type": "lead",
        ...leadData,
      }),
    );
  } catch (_) {}
}

Future<void> clearChat() async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.remove('anna_messages');

  setState(() {
    messages
      ..clear()
      ..add({
        "text":
            "👋 Welcome!\n\n"
            "I'm Anna, your AI Concierge.\n\n"
            "How can I help you today?",
        "isUser": false,
        "time": "",
      });

    annaTyping = false;
    selectedImage = null;
  });

  await _storageService.saveMessages(
    messages,
  );

  scrollToBottom();
}
Future<void> initializeChat() async {
  final savedId =
      await _storageService.loadConversationId();

  conversationId =
      savedId ?? const Uuid().v4();

  if (savedId == null) {
    await _storageService.saveConversationId(
      conversationId,
    );
  }

  final loadedMessages =
      await _storageService.loadMessages();

  if (loadedMessages.isNotEmpty) {
    setState(() {
      messages
        ..clear()
        ..addAll(loadedMessages);
    });
  }
}
  // =========================================================
  // VOICE INPUT
  // =========================================================

  Future<void> startListening() async {
    final available = await speech.initialize();

    if (!available) return;

    setState(() {
      isListening = true;
    });

    speech.listen(
      onResult: (result) {
        setState(() {
          controller.text = result.recognizedWords;
        });
      },
    );
  }

  Future<void> stopListening() async {
    await speech.stop();

    setState(() {
      isListening = false;
    });
  }

  // =========================================================
  // IMAGE PICKER
  // =========================================================

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
    });
  }

  Future<void> takePhoto() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
    });
  }

  Future<void> showImagePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take Photo"),
                onTap: () {
                  Navigator.pop(context);
                  takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose From Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // UI HELPERS
  // =========================================================

  void scrollToBottom() {
    Future.delayed(
      const Duration(milliseconds: 150),
      () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
    );
  }

  Future<void> sendQuickMessage(String text) async {
    controller.text = text;
    await sendMessage();
  }
bool containsAny(
  String text,
  List<String> keywords,
) {
  return keywords.any(
    (keyword) => text.contains(keyword),
  );
}
Future<bool> detectServiceLead(
  String lower,
) async {
  final services = {
    "Heating": [
      "heating",
      "boiler",
      "radiator",
      "heater",
      "hot water",
    ],
    "Plumbing": [
      "plumber",
      "plumbing",
      "pipe",
      "leak",
      "sink",
      "toilet",
    ],
    "Doctor": [
      "doctor",
      "hospital",
      "clinic",
      "medical",
      "health",
    ],
    "Pharmacy": [
      "pharmacy",
      "medicine",
      "medication",
      "prescription",
    ],
    "Electrical": [
      "electrician",
      "electrical",
      "socket",
      "power",
      "fuse",
    ],
    "Gardening": [
      "garden",
      "gardening",
      "lawn",
      "tree",
      "hedge",
    ],
    "Auto": [
      "car",
      "vehicle",
      "mechanic",
      "engine",
      "battery",
    ],
    "Locksmith": [
      "locksmith",
      "locked out",
      "key",
      "lock",
    ],
  };

  for (final entry in services.entries) {
    if (containsAny(lower, entry.value)) {
      await startLeadFlow(entry.key);
      return true;
    }
  }

  return false;
}
Future<void> updateMemory(String message) async {
  final memory = await _memoryService.loadMemory();

  final text = message.toLowerCase();

  if (text.contains("my name is")) {
    final index = text.indexOf("my name is");
    memory.name =
        message.substring(index + 10).trim();
  }

  if (text.contains("i live in")) {
    final index = text.indexOf("i live in");
    memory.city =
        message.substring(index + 9).trim();
  }

  if (text.contains("i drive")) {
    final index = text.indexOf("i drive");
    memory.vehicle =
        message.substring(index + 7).trim();
  }

  if (text.contains("my phone number is")) {
    final index =
        text.indexOf("my phone number is");

    memory.phone =
        message.substring(index + 18).trim();
  }

  await _memoryService.saveMemory(memory);
}
  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage() async {
  if (controller.text.trim().isEmpty || annaTyping) {
    return;
  }

  final userText = controller.text.trim();
  await updateMemory(userText);

  final memory = await _memoryService.loadMemory();

  final memoryContext = """
User Information:

Name: ${memory.name ?? "Unknown"}
Vehicle: ${memory.vehicle ?? "Unknown"}
City: ${memory.city ?? "Unknown"}
Phone: ${memory.phone ?? "Unknown"}

Use this information naturally during the conversation.
""";
final lower = userText.toLowerCase();

if (!collectingLead) {

  // Memory Questions
  if (lower == "who am i" ||
      lower.contains("what do you know about me") ||
      lower.contains("what do you remember about me")) {

    String reply = "";

    if (memory.name != null &&
        memory.name!.isNotEmpty) {
      reply += "👤 Name: ${memory.name}\n";
    }

    if (memory.city != null &&
        memory.city!.isNotEmpty) {
      reply += "📍 City: ${memory.city}\n";
    }

    if (memory.vehicle != null &&
        memory.vehicle!.isNotEmpty) {
      reply += "🚗 Vehicle: ${memory.vehicle}\n";
    }

    if (memory.phone != null &&
        memory.phone!.isNotEmpty) {
      reply += "📞 Phone: ${memory.phone}\n";
    }

    if (reply.isEmpty) {
      reply =
          "I don't know much about you yet.";
    }

    await addAnnaMessage(reply);

    return;
  }

  // Service detection
  if (await detectServiceLead(lower)) {
    return;
  }
}
  if (collectingLead) {
    setState(() {
      messages.add({
        "text": userText,
        "isUser": true,
        "time": getCurrentTime(),
      });
    });

    await _storageService.saveMessages(messages,);

    controller.clear();

    await processLeadFlow(userText);

    return;
  }

      setState(() {
        messages.add({
          "text": userText,
          "isUser": true,
          "time": getCurrentTime(),
        });

        annaTyping = true;
      });

      await _storageService.saveMessages(messages,);

      controller.clear();

      scrollToBottom();

      try {
        // =====================================================
        // IMAGE MESSAGE
        // =====================================================

        if (selectedImage != null) {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse(webhookUrl),
          );

          request.fields['message'] = userText;
          request.fields['conversation_id'] = conversationId;

          request.files.add(
            await http.MultipartFile.fromPath(
              'image',
              selectedImage!.path,
            ),
          );

        final streamedResponse =
            await request.send();

        final response =
            await http.Response.fromStream(
          streamedResponse,
        );

        String reply = response.body;

        try {
          final data =
              jsonDecode(response.body);

          reply =
              data["reply"] ??
              response.body;
        } catch (_) {}

                  setState(() {
            annaTyping = false;

            messages.add({
              "text": reply,
              "isUser": false,
              "time": getCurrentTime(),
            });
            selectedImage = null;
          });
        await _storageService.saveMessages(messages,);
        scrollToBottom();
        return;
      }

      // =====================================================
      // TEXT MESSAGE
      // =====================================================

      const maxRetries = 3;
      int attempt = 0;

      while (attempt < maxRetries) {
        try {
          final response = await http
              .post(
                Uri.parse(webhookUrl),
                headers: {
                  "Content-Type":
                      "application/json",
                },
                body: jsonEncode({
                  "message": "$memoryContext\n\nUser: $userText",
                  "conversation_id": conversationId,
                }),
              )
              .timeout(
                const Duration(seconds: 15),
              );

          if (response.statusCode >= 200 &&
              response.statusCode < 300) {
            String reply;

            try {
              final data =
                  jsonDecode(response.body);

              reply =
                  data["reply"] ??
                  "No reply received.";
            } catch (_) {
              reply = response.body;
            }

            setState(() {
              annaTyping = false;

              messages.add({
                "text": reply,
                "isUser": false,
                "time": getCurrentTime(),
              });
            });
            await _storageService.saveMessages(messages,);

            scrollToBottom();
            return;
          }

          throw Exception(
              "Server returned ${response.statusCode}");
        } catch (_) {
          attempt++;

          if (attempt >= maxRetries) {
            rethrow;
          }

          await Future.delayed(
            Duration(seconds: attempt),
          );
        }
      }
    } on TimeoutException {
      setState(() {
        annaTyping = false;

        messages.add({
          "text":
              "⏱️ Anna is taking longer than expected. Please try again.",
          "isUser": false,
          "time": getCurrentTime(),
        });
      });
      await _storageService.saveMessages(messages,);
    } catch (_) {
      setState(() {
        annaTyping = false;

        messages.add({
          "text":
              "⚠️ Unable to contact Anna right now.\nPlease check your connection and try again.",
          "isUser": false,
          "time": getCurrentTime(),
        });
      });
      await _storageService.saveMessages(messages,);
    }

    scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),
          appBar: AppBar(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          title: const Text("Anna AI Concierge"),
          actions: [
            IconButton(
                icon: const Icon(Icons.psychology),
                onPressed: () async {
                  final memory =
                      await _memoryService.loadMemory();

                  if (!mounted) return;

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        'Anna Memory (${getMemoryCount(memory)} facts)',
                      ),
                      content: Text(
                        '''
              Name: ${memory.name ?? "Unknown"}
              Vehicle: ${memory.vehicle ?? "Unknown"}
              City: ${memory.city ?? "Unknown"}
              Phone: ${memory.phone ?? "Unknown"}
              ''',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final confirmed =
                    await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Chat?'),
                    content: const Text(
                      'This will remove all messages but keep Anna\'s memory.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await clearChat();
                }
              },
            ),

            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final confirmed =
                    await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text(
                      'Clear Memory?',
                    ),
                    content: const Text(
                      'Anna will forget all saved information.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;

                await _memoryService.clearMemory();

                if (!mounted) return;

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Memory cleared',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ServiceCard(
                  title: "🏥 Doctor",
                  onTap: () => sendQuickMessage(
                    "I need a doctor.",
                  ),
                ),

                ServiceCard(
                  title: "💊 Pharmacy",
                  onTap: () => sendQuickMessage(
                    "I need a pharmacy.",
                  ),
                ),

                ServiceCard(
                  title: "🔥 Heating",
                  onTap: () => sendQuickMessage(
                    "My heating is broken.",
                  ),
                ),

                ServiceCard(
                  title: "🚿 Plumbing",
                  onTap: () => sendQuickMessage(
                    "I have a plumbing issue.",
                  ),
                ),
                ServiceCard(
                  title: "⚡ Electrical",
                  onTap: () => sendQuickMessage(
                    "I need an electrician.",
                  ),
                ),

                ServiceCard(
                  title: "🌿 Gardening",
                  onTap: () => sendQuickMessage(
                    "I need a gardener.",
                  ),
                ),

                ServiceCard(
                  title: "🚗 Auto",
                  onTap: () => sendQuickMessage(
                    "I need a mechanic.",
                  ),
                ),

                ServiceCard(
                  title: "🔑 Locksmith",
                  onTap: () => sendQuickMessage(
                    "I am locked out.",
                  ),
                ),
              ],
            ),
          ),

          if (selectedImage != null)
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                            12),
                    child: Image.file(
                      selectedImage!,
                      height: 180,
                      width:
                          double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(
                      Icons.delete),
                  label:
                      const Text("Remove"),
                  onPressed: () {
                    setState(() {
                      selectedImage = null;
                    });
                  },
                )
              ],
            ),

          if (isListening)
            Padding(
              padding:
                  const EdgeInsets.all(8),
              child: Text(
                "🎤 Listening...",
                style: TextStyle(
                  color:
                      Colors.red.shade600,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller:
                  scrollController,
              padding:
                  const EdgeInsets.all(12),
              itemCount:
                  messages.length +
                      (annaTyping ? 1 : 0),
              itemBuilder:
                  (context, index) {
                if (annaTyping &&
                   index == messages.length) {
                 return const TypingIndicator();
               }

                return MessageBubble(
                msg: messages[index],
                );
              },
            ),
          ),

          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_photo_alternate,
                  ),
                  onPressed:
                      showImagePicker,
                ),
                Expanded(
                  child: TextField(
                    controller:
                        controller,
                    maxLines: null,
                    onSubmitted:
                        (_) =>
                            sendMessage(),
                    decoration:
                        const InputDecoration(
                      hintText:
                          "Describe your issue...",
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isListening
                        ? Icons.mic_off
                        : Icons.mic,
                  ),
                  onPressed: () {
                    if (isListening) {
                      stopListening();
                    } else {
                      startListening();
                    }
                  },
                ),
                IconButton(
                  icon:
                      const Icon(Icons.send),
                  onPressed:
                      sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}