import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../screens/premium_subscription_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'premium_feature_modal.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TravelAgentChatWidget extends StatefulWidget {
  final String guideId;
  final String guideTitle;

  const TravelAgentChatWidget({
    Key? key,
    required this.guideId,
    required this.guideTitle,
  }) : super(key: key);

  @override
  State<TravelAgentChatWidget> createState() => _TravelAgentChatWidgetState();
}

class _TravelAgentChatWidgetState extends State<TravelAgentChatWidget> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mensaje de introducción automático del agente, con bandera 'intro'
    _messages.add({
      'role': 'assistant',
      'content':
          '¡Hola! ¿En qué te puedo ayudar? Puedo reorganizar tu guía y mucho más.',
      'intro': 'true',
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    try {
      final uri = Uri.parse('$baseUrl/guides/${widget.guideId}/agent-chat');
      final request = http.Request('POST', uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      request.body = json.encode({
        'messages': _messages,
      });

      final client = http.Client();
      final response = await client.send(request);

      final buffer = StringBuffer();
      String agentMessage = '';
      final completer = Completer<void>();
      int? agentMsgIndex;

      print('Enviando mensaje al backend:');
      print(json.encode({'messages': _messages}));

      response.stream.transform(utf8.decoder).listen((chunk) {
        print('Fragmento recibido del stream:');
        print(chunk);
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed == '[DONE]') {
            print('[DONE] recibido. Mensaje final del agente:');
            print(buffer.toString());
            setState(() {
              _isLoading = false;
            });
            completer.complete();
            return;
          }
          try {
            final data = json.decode(trimmed);
            if (data['content'] != null) {
              buffer.write(data['content']);
              agentMessage = buffer.toString();
              print('Mensaje acumulado del agente:');
              print(agentMessage);
              setState(() {
                if (agentMsgIndex != null &&
                    agentMsgIndex! < _messages.length &&
                    _messages[agentMsgIndex!]['role'] == 'assistant') {
                  _messages[agentMsgIndex!] = {
                    'role': 'assistant',
                    'content': agentMessage
                  };
                } else {
                  _messages.add({'role': 'assistant', 'content': agentMessage});
                  agentMsgIndex = _messages.length - 1;
                }
              });
            }
          } catch (e) {
            print('Error al decodificar fragmento: $trimmed');
            print(e);
            // Ignorar líneas que no sean JSON
          }
        }
      }, onError: (e) {
        print('Error en el stream del backend:');
        print(e);
        setState(() {
          _isLoading = false;
        });
        completer.completeError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red: $e')),
        );
      });

      await completer.future;
      client.close();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: $e')),
      );
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Agente de viaje'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isAgent = msg['role'] == 'assistant';
                final content = msg['content'] ?? '';
                final sugiereReorganizar = isAgent &&
                    (content.toLowerCase().contains('reestructurar') ||
                        content.toLowerCase().contains('reorganizar')) &&
                    (msg['intro'] != 'true');
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (isAgent)
                          Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 2),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFF2563EB),
                              radius: 18,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/agent_avatar.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(
                                  left: isUser ? 40 : 0,
                                  right: isUser ? 0 : 40,
                                  bottom: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: isUser
                                      ? const LinearGradient(colors: [
                                          Color(0xFF60A5FA),
                                          Color(0xFF2563EB)
                                        ])
                                      : null,
                                  color: isUser ? null : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft:
                                        Radius.circular(isUser ? 18 : 4),
                                    bottomRight:
                                        Radius.circular(isUser ? 4 : 18),
                                  ),
                                  border: isUser
                                      ? null
                                      : Border.all(
                                          color: const Color(0xFF60A5FA)
                                              .withOpacity(0.18),
                                          width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isAgent
                                    ? MarkdownBody(
                                        data: content,
                                        styleSheet: MarkdownStyleSheet(
                                          p: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87),
                                          strong: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                          listBullet: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87),
                                        ),
                                      )
                                    : Text(
                                        content,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                              if (sugiereReorganizar)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, top: 4, bottom: 2),
                                  child: ElevatedButton.icon(
                                    icon:
                                        const Icon(Icons.auto_fix_high_rounded),
                                    label: const Text('Reorganizar guía'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 1,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            const PremiumFeatureModal(),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2563EB),
                    radius: 14,
                    child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  AnimatedDots(),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                            color: const Color(0xFF60A5FA).withOpacity(0.18)),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Escribe tu mensaje...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                        ),
                        onSubmitted: _sendMessage,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.13),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 26),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget animado para los puntos de "escribiendo..."
class AnimatedDots extends StatefulWidget {
  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotCount = StepTween(begin: 1, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        String dots = '.' * _dotCount.value;
        return Text(
          'El agente está escribiendo$dots',
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
