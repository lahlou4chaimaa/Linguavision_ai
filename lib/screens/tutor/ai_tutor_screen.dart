import 'package:flutter/material.dart';

import '../../services/ai_tutor_service.dart';
import '../../services/tutor_history_service.dart';
import '../../services/speech_service.dart';
import 'video_tutor_screen.dart';
import 'history/tutor_history_screen.dart';

class TutorMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  TutorMessage({required this.text, required this.isUser, DateTime? time})
    : time = time ?? DateTime.now();
}

class AiTutorScreen extends StatefulWidget {
  final String? conversationId;

  const AiTutorScreen({super.key, this.conversationId});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  // CONTROLLERS

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  // SERVICES

  final AiTutorService _aiTutorService = AiTutorService();

  final TutorHistoryService _historyService = TutorHistoryService();

  final SpeechService _speechService = SpeechService();

  // MESSAGES

  final List<TutorMessage> _messages = [
    TutorMessage(
      text: "Hello! I'm your language tutor. What would you like to practice today?",
      isUser: false,
    ),
  ];

  // STATE

  String? _conversationId;

  bool _isTyping = false;
  bool _isSaving = false;
  bool _isLoadingHistory = false;

  bool _isListening = false;
  String _speechText = '';

  final String _speechLocale = 'en-US';

  @override
  void initState() {
    super.initState();

    _conversationId = widget.conversationId;

    _initializeSpeech();

    if (_conversationId != null) {
      _loadConversation();
    }
  }

  // INITIALIZE SPEECH

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speechService.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');

          if (!mounted) return;

          if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');

          if (!mounted) return;

          setState(() {
            _isListening = false;
          });
        },
      );

      if (!available) {
        debugPrint('Speech recognition is not available.');
        return;
      }

      final locales = await _speechService.getLocales();

      debugPrint(
        'Available speech locales: '
        '${locales.map((e) => e.localeId).join(', ')}',
      );
    } catch (error) {
      debugPrint('Speech initialization error: $error');
    }
  }

  // SPEECH RECOGNITION

  Future<void> _toggleSpeechRecognition() async {
    if (_isTyping) return;

    if (_isListening) {
      await _speechService.stopListening();

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      return;
    }

    try {
      final available = await _speechService.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');

          if (!mounted) return;

          if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');

          if (!mounted) return;

          setState(() {
            _isListening = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech recognition error: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );

      if (!available) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Speech recognition is not available on this device.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      setState(() {
        _isListening = true;
        _speechText = '';
      });

      await _speechService.startListening(
        localeId: _speechLocale,
        onResult: (text, isFinal) {
          debugPrint('Recognized: $text | Final: $isFinal');

          if (!mounted) return;

          setState(() {
            _speechText = text;
            _messageController.text = text;

            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );

            if (isFinal) {
              _isListening = false;
            }
          });
        },
      );
    } catch (error) {
      debugPrint('Unable to start speech recognition: $error');

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone error: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // DISPOSE

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // LOAD CONVERSATION

  Future<void> _loadConversation() async {
    final id = _conversationId;

    if (id == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final savedMessages = await _historyService.getMessages(id);

      if (!mounted) return;

      setState(() {
        _messages.clear();

        for (final item in savedMessages) {
          _messages.add(
            TutorMessage(
              text: item['content'] as String,
              isUser: item['role'] == 'user',
              time:
                  DateTime.tryParse(item['created_at']?.toString() ?? '')
                      ?.toLocal() ??
                  DateTime.now(),
            ),
          );
        }

        _isLoadingHistory = false;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingHistory = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load conversation: $error')),
      );
    }
  }

  // CREATE CONVERSATION

  Future<String> _ensureConversation(String firstMessage) async {
    if (_conversationId != null) {
      return _conversationId!;
    }

    final title = firstMessage.length > 45
        ? '${firstMessage.substring(0, 45)}...'
        : firstMessage;

    final id = await _historyService.createConversation(title: title);

    _conversationId = id;

    return id;
  }

  // SAVE MESSAGE

  Future<void> _saveMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    await _historyService.saveMessage(
      conversationId: conversationId,
      role: role,
      content: content,
    );
  }

  // SEND MESSAGE

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isTyping) return;

    final history = _messages.map((message) {
      return {
        'role': message.isUser ? 'user' : 'assistant',
        'content': message.text,
      };
    }).toList();

    setState(() {
      _messages.add(TutorMessage(text: text, isUser: true));

      _messageController.clear();
      _speechText = '';

      _isTyping = true;
      _isSaving = true;
    });

    _scrollToBottom();

    String? conversationId;

    // CREATE / GET CONVERSATION

    try {
      conversationId = await _ensureConversation(text);

      await _saveMessage(
        conversationId: conversationId,
        role: 'user',
        content: text,
      );
    } catch (error) {
      debugPrint('Supabase user message save error: $error');

      if (mounted) {
        _showPersistenceError();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    // SEND TO FASTAPI / OLLAMA

    try {
      final reply = await _aiTutorService.sendMessage(
        message: text,
        history: history,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(TutorMessage(text: reply, isUser: false));
      });

      _scrollToBottom();

      // SAVE AI RESPONSE

      if (conversationId != null) {
        try {
          await _saveMessage(
            conversationId: conversationId,
            role: 'assistant',
            content: reply,
          );
        } catch (error) {
          debugPrint('Supabase AI response save error: $error');

          if (mounted) {
            _showPersistenceError();
          }
        }
      }
    } catch (error) {
      debugPrint('AI Tutor error: $error');

      if (!mounted) return;

      setState(() {
        _messages.add(
          TutorMessage(
            text:
                "I'm sorry, I couldn't connect to the AI tutor. "
                "Please check your connection and try again.",
            isUser: false,
          ),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI connection error: $error',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });

        _scrollToBottom();
      }
    }
  }

  // ERROR MESSAGE

  void _showPersistenceError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Message not saved. Check your Supabase connection and permissions.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // SCROLL

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // VIDEO TUTOR NAVIGATION

  void _openVideoTutor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VideoTutorScreen()),
    );
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF172B4D),
        title: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFFE8F0FF),
              child: Icon(Icons.smart_toy_outlined, color: Color(0xFF3478F6)),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Tutor',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Your personal language partner',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Conversation history',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TutorHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Video conversation',
            onPressed: _openVideoTutor,
            icon: const Icon(Icons.videocam_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildLanguageHeader(),
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3478F6)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }

                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // LANGUAGE HEADER

  Widget _buildLanguageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      color: Colors.white,
      child: const Row(
        children: [
          Icon(Icons.language, color: Color(0xFF3478F6), size: 20),
          SizedBox(width: 8),
          Text(
            'Personalized language practice',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF253858),
            ),
          ),
          Spacer(),
          Icon(Icons.auto_awesome, color: Color(0xFF3478F6), size: 18),
        ],
      ),
    );
  }

  // MESSAGE

  Widget _buildMessage(TutorMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF3478F6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(message.isUser ? 17 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 17),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : const Color(0xFF253858),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${message.time.hour.toString().padLeft(2, '0')}:'
              '${message.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: message.isUser ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TYPING INDICATOR

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE8F0FF),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 17,
                color: Color(0xFF3478F6),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _isSaving ? 'Saving your message...' : 'Tutor is thinking...',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // INPUT AREA

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAEFF5))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isListening)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _speechText.isEmpty ? 'Listening...' : _speechText,
                        style: const TextStyle(
                          color: Color(0xFF7A2525),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: _isListening ? 'Stop listening' : 'Voice input',
                  onPressed: _isTyping ? null : _toggleSpeechRecognition,
                  icon: Icon(
                    _isListening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    color: _isListening ? Colors.red : const Color(0xFF3478F6),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Write your message...',
                      filled: true,
                      fillColor: const Color(0xFFF3F6FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF3478F6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isTyping ? null : _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
