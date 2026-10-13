import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import 'package:geolocator/geolocator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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
  Future<void> saveMessages() async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setString(
    'anna_messages',
    jsonEncode(messages),
  );
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
  void startLeadFlow(String service) {
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
}
Future<void> processLeadFlow(
  String answer,
) async {
  switch (currentLeadStep) {
    case "name":
      leadData["name"] = answer;
      currentLeadStep = "phone";

      addAnnaMessage(
        "What phone number should we contact you on?",
      );
      break;

    case "phone":
      leadData["phone"] = answer;
      currentLeadStep = "city";

      addAnnaMessage(
        "Which city are you located in?",
      );
      break;

    case "city":
      leadData["city"] = answer;
      currentLeadStep = "date";

      addAnnaMessage(
        "What is your preferred appointment date?",
      );
      break;

    case "date":
      leadData["appointment_date"] =
          answer;

      await submitLead();

      collectingLead = false;
      currentLeadStep = "";

      addAnnaMessage(
        "✅ Thank you! Your request has been submitted. We will contact you soon.",
      );
      break;
  }
}
void addAnnaMessage(String text) {
  setState(() {
    messages.add({
      "text": text,
      "isUser": false,
      "time": getCurrentTime(),
    });
  });

  saveMessages();
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
Future<void> loadMessages() async {
  final prefs =
      await SharedPreferences.getInstance();

  final savedMessages =
      prefs.getString('anna_messages');

  if (savedMessages == null) return;

  final decoded =
      jsonDecode(savedMessages) as List;

  setState(() {
    messages
      ..clear()
      ..addAll(
        decoded.map(
          (e) =>
              Map<String, dynamic>.from(e),
        ),
      );
  });
}
Future<void> saveConversationId() async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setString(
    'anna_conversation_id',
    conversationId,
  );
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
            "👋 Welcome back!\n\nHow can I help you today?",
        "isUser": false,
        "time": "",
      });
  });
}
Future<void> initializeChat() async {
  final prefs =
      await SharedPreferences.getInstance();

  final savedId = prefs.getString(
    'anna_conversation_id',
  );

  conversationId =
      savedId ?? const Uuid().v4();

  if (savedId == null) {
    await prefs.setString(
      'anna_conversation_id',
      conversationId,
    );
  }

  await loadMessages();
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

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage() async {
    if (controller.text.trim().isEmpty || annaTyping) {
      return;
    }
    
    final userText = controller.text.trim();
    if (collectingLead) {
  setState(() {
    messages.add({
      "text": userText,
      "isUser": true,
      "time": getCurrentTime(),
    });
  });

  controller.clear();

  await processLeadFlow(userText);

  return;
}
    if (!collectingLead) {
  if (userText.toLowerCase().contains("heating")) {
    startLeadFlow("Heating");
    return;
  }

  if (userText.toLowerCase().contains("plumbing")) {
    startLeadFlow("Plumbing");
    return;
  }

  if (userText.toLowerCase().contains("doctor")) {
    startLeadFlow("Doctor");
    return;
  }

  if (userText.toLowerCase().contains("pharmacy")) {
    startLeadFlow("Pharmacy");
    return;
  }
}

    setState(() {
      messages.add({
        "text": userText,
        "isUser": true,
        "time": getCurrentTime(),
      });

      annaTyping = true;
    });

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
        request.fields['conversation_id'] =
            conversationId;

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
                  "message": userText,
                  "conversation_id":
                      conversationId,

                  // FUTURE GPS SUPPORT
                  // "latitude": position?.latitude,
                  // "longitude": position?.longitude,
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
    }

    scrollToBottom();
  }

  Widget serviceButton(
    String title,
    String prompt,
  ) {
    return ElevatedButton(
      onPressed: () =>
          sendQuickMessage(prompt),
      child: Text(title),
    );
  }

  Widget buildMessage(
    Map<String, dynamic> msg,
  ) {
    final bool isUser =
        msg["isUser"] ?? false;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage(
                "assets/images/anna_avatar.jpg",
              ),
            ),

          if (!isUser)
            const SizedBox(width: 8),

          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(
                        0xFF2563EB)
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(
                        18),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    msg["text"] ?? "",
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    msg["time"] ?? "",
                    style: TextStyle(
                      fontSize: 11,
                      color: isUser
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title:
            const Text("Anna AI Concierge"),
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
                serviceButton(
                    "🏥 Doctor",
                    "I need a doctor."),
                serviceButton(
                    "💊 Pharmacy",
                    "I need a pharmacy."),
                serviceButton(
                    "🔥 Heating",
                    "My heating is broken."),
                serviceButton(
                    "🚿 Plumbing",
                    "I have a plumbing issue."),
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
                    index ==
                        messages.length) {
                  return const Padding(
                    padding:
                        EdgeInsets.all(12),
                    child: Text(
                      "● ● ●",
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return buildMessage(
                  messages[index],
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