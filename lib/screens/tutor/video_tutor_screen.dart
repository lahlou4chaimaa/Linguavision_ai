
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../services/ai_tutor_service.dart';
import '../../services/tutor_history_service.dart';
import '../../services/speech_service.dart';
import '../../services/learning_service.dart';

class VideoTutorScreen extends StatefulWidget {
  final String? conversationId;
  final List<Map<String, String>> initialHistory;

  const VideoTutorScreen({
    super.key,
    this.conversationId,
    this.initialHistory = const [],
  });

  @override
  State<VideoTutorScreen> createState() => _VideoTutorScreenState();
}

class _VideoTutorScreenState extends State<VideoTutorScreen> {
  // Services
  final AiTutorService _aiTutorService = AiTutorService();
  final TutorHistoryService _historyService = TutorHistoryService();
  final SpeechService _speechService = SpeechService();
  final FlutterTts _tts = FlutterTts();
  final LearningService _learningService = LearningService();

  // Camera
  CameraController? _cameraController;
  bool _cameraEnabled = true;
  bool _isInitializing = true;
  String? _cameraError;

  // Conversation
  late List<Map<String, String>> _history;
  String? _conversationId;
  final TextEditingController _messageController =
      TextEditingController();

  // States
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isTyping = false;
  bool _isAvatarSpeaking = false;
  bool _ttsEnabled = true;

  String _speechText = '';
  String _speechLocale = 'en-US';
  String _targetLanguage = 'English';
  String _lastReply = '';

  bool _processingSpeechResult = false;

  @override
  void initState() {
    super.initState();

    _conversationId = widget.conversationId;

    _history = widget.initialHistory
        .map((item) => Map<String, String>.from(item))
        .toList();

    _initializeCamera();
    _initializeServices();
  }

  // --------------------------------------------------
  // LANGUAGE
  // --------------------------------------------------

  String _getLocale(String language) {
    final normalized = language.toLowerCase().trim();

    const locales = {
      'english': 'en-US',
      'french': 'fr-FR',
      'arabic': 'ar-SA',
      'spanish': 'es-ES',
      'german': 'de-DE',
      'italian': 'it-IT',
      'portuguese': 'pt-PT',
      'chinese': 'zh-CN',
      'japanese': 'ja-JP',
      'korean': 'ko-KR',
      'turkish': 'tr-TR',
      'russian': 'ru-RU',
      'dutch': 'nl-NL',
    };

    return locales[normalized] ?? 'en-US';
  }

  Future<void> _initializeServices() async {
    try {
      final profile =
          await _learningService.getLearningProfile();

      final language =
          profile?['target_language']?.toString() ?? 'English';

      final locale = _getLocale(language);

      if (!mounted) return;

      setState(() {
        _targetLanguage = language;
        _speechLocale = locale;
      });

      // Initialize speech recognition
      final available = await _speechService.initialize(
        onStatus: (status) {
          debugPrint('Video tutor speech status: $status');

          if (!mounted) return;

          if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Video tutor speech error: $error');

          if (!mounted) return;

          setState(() {
            _isListening = false;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
      });

      // Initialize text-to-speech
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        if (!mounted) return;

        setState(() {
          _isAvatarSpeaking = true;
        });
      });

      _tts.setCompletionHandler(() {
        if (!mounted) return;

        setState(() {
          _isAvatarSpeaking = false;
        });
      });

      _tts.setErrorHandler((message) {
        debugPrint('TTS error: $message');

        if (!mounted) return;

        setState(() {
          _isAvatarSpeaking = false;
        });
      });

      debugPrint('Target language: $language');
      debugPrint('Speech locale: $locale');
      debugPrint('Speech available: $available');
    } catch (error) {
      debugPrint('Video tutor initialization error: $error');
    }
  }

  // --------------------------------------------------
  // CAMERA
  // --------------------------------------------------

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No camera detected.');
      }

      final frontCameras = cameras.where(
        (camera) =>
            camera.lensDirection == CameraLensDirection.front,
      );

      final selectedCamera =
          frontCameras.isNotEmpty ? frontCameras.first : cameras.first;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
        _cameraError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _cameraError = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraEnabled) {
      final controller = _cameraController;

      setState(() {
        _cameraEnabled = false;
        _cameraController = null;
      });

      await controller?.dispose();
    } else {
      setState(() {
        _cameraEnabled = true;
        _isInitializing = true;
        _cameraError = null;
      });

      await _initializeCamera();
    }
  }

  // --------------------------------------------------
  // MICROPHONE
  // --------------------------------------------------

  Future<void> _toggleMicrophone() async {
    if (_isTyping) return;

    if (_isListening) {
      await _speechService.stopListening();

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      final text = _speechText.trim();

      if (text.isNotEmpty) {
        await _sendMessage(text);
      }

      return;
    }

    if (!_speechAvailable) {
      _showMessage(
        'Speech recognition is unavailable. '
        'You can type your message instead.',
      );
      return;
    }

    try {
      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _isAvatarSpeaking = false;
        _speechText = '';
        _processingSpeechResult = false;
        _isListening = true;
      });

      await _speechService.startListening(
        localeId: _speechLocale,
        onResult: (text, isFinal) {
          if (!mounted) return;

          setState(() {
            _speechText = text;
          });

          if (isFinal &&
              text.trim().isNotEmpty &&
              !_processingSpeechResult) {
            _processingSpeechResult = true;

            setState(() {
              _isListening = false;
            });

            _sendMessage(text.trim());
          }
        },
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      _showMessage('Microphone error: $error');
    }
  }

  // --------------------------------------------------
  // CONVERSATION / SUPABASE
  // --------------------------------------------------

  Future<String> _ensureConversation(String firstMessage) async {
    if (_conversationId != null) {
      return _conversationId!;
    }

    final title = firstMessage.length > 45
        ? '${firstMessage.substring(0, 45)}...'
        : firstMessage;

    final id = await _historyService.createConversation(
      title: title,
    );

    _conversationId = id;

    return id;
  }

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

  // --------------------------------------------------
  // SEND MESSAGE TO AI
  // --------------------------------------------------

  Future<void> _sendMessage([String? voiceMessage]) async {
    final text =
        (voiceMessage ?? _messageController.text).trim();

    if (text.isEmpty || _isTyping) return;

    // Stop listening before sending.
    if (_speechService.isListening) {
      await _speechService.stopListening();
    }

    await _tts.stop();

    // Keep previous conversation context.
    final previousHistory = _history
        .map((item) => Map<String, String>.from(item))
        .toList();

    setState(() {
      _isTyping = true;
      _isListening = false;
      _isAvatarSpeaking = false;
      _messageController.clear();
      _speechText = '';

      _history.add({
        'role': 'user',
        'content': text,
      });
    });

    String? conversationId;

    // Save user message.
    try {
      conversationId = await _ensureConversation(text);

      await _saveMessage(
        conversationId: conversationId,
        role: 'user',
        content: text,
      );
    } catch (error) {
      debugPrint('User message persistence error: $error');
    }

    try {
      final reply = await _aiTutorService.sendMessage(
        message: text,
        history: previousHistory.take(12).toList(),
      );

      if (!mounted) return;

      setState(() {
        _history.add({
          'role': 'assistant',
          'content': reply,
        });

        _lastReply = reply;
      });

      // Save AI response.
      if (conversationId != null) {
        try {
          await _saveMessage(
            conversationId: conversationId,
            role: 'assistant',
            content: reply,
          );
        } catch (error) {
          debugPrint('AI response persistence error: $error');
        }
      }

      // Speak the AI response.
      if (_ttsEnabled) {
        await _speak(reply);
      }
    } catch (error) {
      debugPrint('AI Tutor error: $error');

      if (mounted) {
        _showMessage('AI Tutor error: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _isAvatarSpeaking = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // TEXT TO SPEECH
  // --------------------------------------------------

  Future<void> _speak(String text) async {
    try {
      if (!mounted) return;

      setState(() {
        _isAvatarSpeaking = true;
      });

      await _tts.speak(text);
    } catch (error) {
      debugPrint('Text-to-speech error: $error');

      if (mounted) {
        setState(() {
          _isAvatarSpeaking = false;
        });
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    if (_isAvatarSpeaking) {
      await _tts.stop();

      if (mounted) {
        setState(() {
          _isAvatarSpeaking = false;
        });
      }
      return;
    }

    if (_lastReply.isNotEmpty) {
      await _speak(_lastReply);
    } else {
      setState(() {
        _ttsEnabled = !_ttsEnabled;
      });
    }
  }

  // --------------------------------------------------
  // EXIT
  // --------------------------------------------------

  void _exitVideoTutor() {
    Navigator.pop(
      context,
      <String, dynamic>{
        'conversationId': _conversationId,
        'history': _history,
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _speechService.cancelListening();
    _tts.stop();
    _messageController.dispose();

    super.dispose();
  }

  // --------------------------------------------------
  // USER INTERFACE
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildFullScreenAvatar(),
          ),

          // Top gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _exitVideoTutor,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Video Tutor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Your personal AI language partner',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.circle,
                    color: Colors.greenAccent,
                    size: 9,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),

          // User camera
          Positioned(
            right: 16,
            top: 105,
            child: _buildCameraPreview(),
          ),

          // Avatar status
          Positioned(
            left: 24,
            right: 24,
            bottom: 195,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isListening
                      ? 'Listening to you...'
                      : _isTyping
                          ? 'Thinking...'
                          : _isAvatarSpeaking
                              ? 'Speaking...'
                              : 'Ready to talk',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Your AI Tutor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Practicing $_targetLanguage',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (_isListening && _speechText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _speechText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Text input
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: _buildMessageInput(),
          ),

          // Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: _buildControls(),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // AVATAR
  // --------------------------------------------------

  Widget _buildFullScreenAvatar() {
    return AnimatedScale(
      scale: _isAvatarSpeaking ? 1.015 : 1.0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      child: Image.asset(
        'assets/avatar/avatar.jpg',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF172B4D),
            child: const Center(
              child: Icon(
                Icons.person,
                color: Colors.white70,
                size: 140,
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // CAMERA PREVIEW
  // --------------------------------------------------

  Widget _buildCameraPreview() {
    return Container(
      width: 115,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF202B40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: !_cameraEnabled
          ? const Center(
              child: Icon(
                Icons.videocam_off,
                color: Colors.white70,
                size: 30,
              ),
            )
          : _isInitializing
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
              : _cameraError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _cameraError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                  : _cameraController != null &&
                          _cameraController!.value.isInitialized
                      ? CameraPreview(_cameraController!)
                      : const Center(
                          child: Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 35,
                          ),
                        ),
    );
  }

  // --------------------------------------------------
  // MESSAGE INPUT
  // --------------------------------------------------

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white24,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isTyping,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Write a message...',
                hintStyle: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            onPressed: _isTyping ? null : _sendMessage,
            icon: const Icon(
              Icons.send_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // CONTROLS
  // --------------------------------------------------

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          icon: _isListening ? Icons.stop : Icons.mic,
          color: _isListening
              ? Colors.redAccent
              : const Color(0xFF356AE6),
          onPressed: _toggleMicrophone,
        ),

        const SizedBox(width: 22),

        _controlButton(
          icon: _isAvatarSpeaking
              ? Icons.pause
              : Icons.volume_up,
          color: const Color(0xFF356AE6),
          onPressed: _toggleSpeaker,
        ),

        const SizedBox(width: 22),

        _controlButton(
          icon: _cameraEnabled
              ? Icons.videocam
              : Icons.videocam_off,
          color: _cameraEnabled
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.redAccent,
          onPressed: _toggleCamera,
        ),

        const SizedBox(width: 22),

        _controlButton(
          icon: Icons.call_end,
          color: Colors.redAccent,
          onPressed: _exitVideoTutor,
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          fixedSize: const Size(58, 58),
        ),
      ),
    );
  }
}
