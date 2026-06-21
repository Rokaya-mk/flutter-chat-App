

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatAI',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  final ChatUser _chatAI = ChatUser(id: '1', firstName: 'Chat', lastName: 'AI');
  final ChatUser _currentUser = ChatUser(id: '2', firstName: 'Toi');

  List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatUser> _typingUsers = <ChatUser>[];

  Future<void> _getChatAIResponse(ChatMessage userMessage) async {
    if (_apiKey.isEmpty) {
      _showError(
        "Clé API manquante. Vérifie que le fichier .env contient bien :\n"
        "GROQ_API_KEY=ta_cle",
      );
      return;
    }

  
    setState(() {
      _messages.insert(0, userMessage);
      _typingUsers.add(_chatAI);
    });

  
    final List<Map<String, String>> history = _messages.reversed.map((m) {
      return {
        'role': m.user.id == _currentUser.id ? 'user' : 'assistant',
        'content': m.text,
      };
    }).toList();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', 
          'messages': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String reply = data['choices'][0]['message']['content'];

        setState(() {
          _messages.insert(
            0,
            ChatMessage(
              user: _chatAI,
              createdAt: DateTime.now(),
              text: reply,
            ),
          );
        });
      } else {
        _showError('Erreur API (${response.statusCode}) : ${response.body}');
      }
    } catch (e) {
      _showError('Erreur réseau : $e');
    } finally {
     
      setState(() {
        _typingUsers.remove(_chatAI);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: const Text('ChatAI', style: TextStyle(color: Colors.white)),
      ),
      body: DashChat(
        currentUser: _currentUser,
        typingUsers: _typingUsers,
        onSend: _getChatAIResponse,
        messages: _messages,
        messageOptions: MessageOptions(
          containerColor: const Color.fromARGB(255, 205, 192, 227),
          currentUserContainerColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}