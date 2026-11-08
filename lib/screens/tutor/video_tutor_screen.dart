import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';


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

  final AudioPlayer _audioPlayer = AudioPlayer();
  Completer<void>? _audioCompletion;
  int _speechGeneration = 0;

  // Avatar lip-sync simulation
  Timer? _avatarAnimationTimer;
  int _avatarExpressionIndex = 0;

  static const List<String> _avatarExpressions = [
    'assets/avatar/expressions/neutral_smile.jpg',
    'assets/avatar/expressions/slightly_open.jpg',
    'assets/avatar/expressions/open_mouth.jpg',
    'assets/avatar/expressions/rounded_mouth.jpg',
  ];

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final LearningService _learningService = LearningService();

  // Camera

  CameraController? _cameraController;

  bool _cameraEnabled = true;

  bool _isInitializing = true;

  String? _cameraError;

  // Conversation

  late List<Map<String, String>> _history;

  String? _conversationId;

  final TextEditingController _messageController = TextEditingController();

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

  // Detect whether a paragraph is French or English.

  // This is a lightweight heuristic, not a full language detector.

  String _detectTextLocale(String text) {

    final normalized = text.toLowerCase();

    const frenchWords = {

      'le',

      'la',

      'les',

      'des',

      'du',

      'de',

      'un',

      'une',

      'et',

      'est',

      'sont',

      'dans',

      'pour',

      'avec',

      'mais',

      'parce',

      'que',

      'qui',

      'quoi',

      'comment',

      'pourquoi',

      'je',

      'tu',

      'il',

      'elle',

      'nous',

      'vous',

      'ils',

      'elles',

      'mon',

      'ma',

      'mes',

      'ton',

      'ta',

      'tes',

      'hier',

      'aujourd',

      'demain',

      'passé',

      'verbe',

      'conjugaison',

      'irrégulier',

      'irrégulière',

      'phrase',

      'correcte',

      'incorrecte',

      'explication',

      'signifie',

      'utilise',

      'utiliser',

      'être',

      'avoir',

      'aller',

      'faire',

      'très',

      'aussi',

      'cette',

      'ce',

      'c’est',

      'n’est',

      'pas',

      'plus',

      'exemple',

      'supermarché',

      'école',

      'étudiant',

      'apprendre',

    };

const englishWords = {

  'the', 'and', 'is', 'are', 'was', 'were', 'you',

  'your', 'what', 'where', 'when', 'why', 'how',

  'this', 'that', 'these', 'those', 'with', 'from',

  'have', 'has', 'had', 'do', 'does', 'did', 'not',

  'but', 'because', 'for', 'to', 'of', 'in', 'on',

  'at', 'my', 'his', 'her', 'their', 'our',

  'went', 'go', 'going', 'correct', 'sentence',

  'example', 'yesterday', 'today', 'tomorrow',

  'school', 'supermarket', 'teacher', 'student',

  'explanation', 'mistake', 'learn', 'practice',

  'let', 'me', 'know', 'well', 'good', 'great',

  'hello', 'hi', 'thanks', 'thank', 'please',

};

    final words = normalized

        .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ')

        .split(RegExp(r'\s+'))

        .where((word) => word.isNotEmpty)

        .toList();

    int frenchScore = 0;

    int englishScore = 0;

    for (final word in words) {

      if (frenchWords.contains(word)) frenchScore++;

      if (englishWords.contains(word)) englishScore++;

    }

    // French-specific accented characters are useful indicators.

    if (RegExp(

      r'[àâçéèêëîïôùûüÿœ]',

      caseSensitive: false,

    ).hasMatch(normalized)) {

      frenchScore += 2;

    }

    // Explicit French headings.

    if (normalized.contains('explication en français') ||

        normalized.contains('explication en francais') ||

        normalized.contains('en français') ||

        normalized.contains('en francais')) {

      frenchScore += 5;

    }

    // Explicit English headings.

    if (normalized.contains('correct sentence') ||

        normalized.contains('another example') ||

        normalized.contains('your turn')) {

      englishScore += 5;

    }

    if (frenchScore > englishScore) {

      return 'fr-FR';

    }

    if (englishScore > frenchScore) {

      return 'en-US';

    }

    // Default to the student's target language.

    return _speechLocale;

  }

  // Divide the response into paragraphs so each can use

  // its own pronunciation language.

  List<String> _splitIntoSpeechSegments(String text) {

    return text

        .split(RegExp(r'\n+'))

        .map((part) => part.trim())

        .where((part) => part.isNotEmpty)

        .toList();

  }

  // --------------------------------------------------

  // INITIALIZATION

  // --------------------------------------------------

  Future<void> _initializeServices() async {

    try {

      final profile = await _learningService.getLearningProfile();

      final language = profile?['target_language']?.toString() ?? 'English';

      final locale = _getLocale(language);

      if (!mounted) return;

      setState(() {

        _targetLanguage = language;

        _speechLocale = locale;

      });

      // Initialize speech recognition.

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

      // Video Tutor uses the backend Edge TTS endpoint.
      // It selects a real voice for each requested language.

      debugPrint('Target language: $language');

      debugPrint('Speech locale: $locale');

      debugPrint('Speech available: $available');

      debugPrint('TTS initialized.');

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

        (camera) => camera.lensDirection == CameraLensDirection.front,

      );

      final selectedCamera = frontCameras.isNotEmpty

          ? frontCameras.first

          : cameras.first;

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

      await _stopAudio();

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

          if (isFinal && text.trim().isNotEmpty && !_processingSpeechResult) {

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

    final id = await _historyService.createConversation(title: title);

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

    final text = (voiceMessage ?? _messageController.text).trim();

    if (text.isEmpty || _isTyping) return;

    if (_speechService.isListening) {

      await _speechService.stopListening();

    }

    await _stopAudio();

    final previousHistory = _history

        .map((item) => Map<String, String>.from(item))

        .toList();

    setState(() {

      _isTyping = true;

      _isListening = false;

      _isAvatarSpeaking = false;

      _messageController.clear();

      _speechText = '';

      _history.add({'role': 'user', 'content': text});

    });

    String? conversationId;

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

        _history.add({'role': 'assistant', 'content': reply});

        _lastReply = reply;

      });

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
    if (!mounted || text.trim().isEmpty) return;

    final generation = ++_speechGeneration;
    final segments = _splitIntoSpeechSegments(text);

    if (segments.isEmpty) return;

    setState(() {
      _isAvatarSpeaking = true;
      _avatarExpressionIndex = 0;
    });

    _startAvatarAnimation();

    try {
      for (final segment in segments) {
        if (!mounted || generation != _speechGeneration) return;

        final locale = _detectTextLocale(segment);
        final language = locale.startsWith('fr') ? 'French' : 'English';

        debugPrint('Edge TTS segment: $segment');
        debugPrint('Edge TTS language: $language');

        final uri = Uri.parse('$_baseUrl/api/tts');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': segment,
                'language': language,
              }),
            )
            .timeout(const Duration(seconds: 120));

        if (!mounted || generation != _speechGeneration) return;

        if (response.statusCode != 200) {
          var detail = 'Audio generation failed (${response.statusCode}).';
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['detail'] != null) {
              detail = data['detail'].toString();
            }
          } catch (_) {
            // Keep the HTTP status message when the response is not JSON.
          }
          throw Exception(detail);
        }

        if (response.bodyBytes.isEmpty) {
          throw Exception('The audio file returned by Edge TTS is empty.');
        }

        await _playAudioBytes(
          Uint8List.fromList(response.bodyBytes),
          generation,
        );
      }
    } catch (error) {
      debugPrint('Edge TTS error: $error');
      if (mounted && generation == _speechGeneration) {
        _showMessage('Audio error: $error');
      }
    } finally {
      if (generation == _speechGeneration) {
        _stopAvatarAnimation();
      }

      if (mounted && generation == _speechGeneration) {
        setState(() {
          _isAvatarSpeaking = false;
          _avatarExpressionIndex = 0;
        });
      }
    }
  }

  void _startAvatarAnimation() {
    _avatarAnimationTimer?.cancel();

    // Change mouth shape while Edge TTS audio is playing.
    _avatarAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 180),
      (_) {
        if (!mounted || !_isAvatarSpeaking) return;

        setState(() {
          _avatarExpressionIndex =
              (_avatarExpressionIndex + 1) % _avatarExpressions.length;
        });
      },
    );
  }

  void _stopAvatarAnimation() {
    _avatarAnimationTimer?.cancel();
    _avatarAnimationTimer = null;

    if (mounted) {
      setState(() {
        _avatarExpressionIndex = 0;
      });
    }
  }

  Future<void> _playAudioBytes(
    Uint8List bytes,
    int generation,
  ) async {
    final completion = Completer<void>();
    _audioCompletion = completion;

    final subscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completion.isCompleted) {
        completion.complete();
      }
    });

    try {
      await _audioPlayer.play(BytesSource(bytes));

      await completion.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw TimeoutException('Audio playback took too long.');
        },
      );

      if (generation != _speechGeneration) return;
    } finally {
      await subscription.cancel();
      if (identical(_audioCompletion, completion)) {
        _audioCompletion = null;
      }
    }
  }

  Future<void> _stopAudio() async {
    // Invalidates any current or pending TTS request.
    _speechGeneration++;

    try {
      await _audioPlayer.stop();
    } catch (error) {
      debugPrint('Audio stop error: $error');
    }

    final completion = _audioCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }

    _stopAvatarAnimation();

    if (mounted) {
      setState(() {
        _isAvatarSpeaking = false;
        _avatarExpressionIndex = 0;
      });
    }
  }

  Future<void> _toggleSpeaker() async {
    if (_isAvatarSpeaking) {
      await _stopAudio();
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

  void _exitVideoTutor() {

    Navigator.pop(context, <String, dynamic>{

      'conversationId': _conversationId,

      'history': _history,

    });

  }

  void _showMessage(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),

    );

  }

  @override

  void dispose() {

    _cameraController?.dispose();

    _speechService.cancelListening();

    _speechGeneration++;
    _avatarAnimationTimer?.cancel();
    _avatarAnimationTimer = null;
    _audioPlayer.dispose();

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

          Positioned.fill(child: _buildFullScreenAvatar()),

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

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

              child: Row(

                children: [

                  IconButton(

                    onPressed: _exitVideoTutor,

                    icon: const Icon(Icons.arrow_back, color: Colors.white),

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

                          style: TextStyle(color: Colors.white70, fontSize: 11),

                        ),

                      ],

                    ),

                  ),

                  const Icon(Icons.circle, color: Colors.greenAccent, size: 9),

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

          Positioned(right: 16, top: 105, child: _buildCameraPreview()),

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

                  style: const TextStyle(color: Colors.white70, fontSize: 14),

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

                  style: const TextStyle(color: Colors.white70, fontSize: 12),

                ),

                if (_isListening && _speechText.isNotEmpty)

                  Padding(

                    padding: const EdgeInsets.only(top: 8),

                    child: Text(

                      _speechText,

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(color: Colors.white, fontSize: 13),

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

            child: SafeArea(top: false, child: _buildControls()),

          ),

        ],

      ),

    );

  }

  // --------------------------------------------------

  // AVATAR

  // --------------------------------------------------

  Widget _buildFullScreenAvatar() {
    final avatarPath = _isAvatarSpeaking
        ? _avatarExpressions[_avatarExpressionIndex]
        : 'assets/avatar/avatar.jpg';

    return AnimatedScale(
      scale: _isAvatarSpeaking ? 1.015 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: Image.asset(
          avatarPath,
          key: ValueKey(avatarPath),
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

              child: Icon(Icons.videocam_off, color: Colors.white70, size: 30),

            )

          : _isInitializing

          ? const Center(child: CircularProgressIndicator(color: Colors.white))

          : _cameraError != null

          ? Center(

              child: Padding(

                padding: const EdgeInsets.all(8),

                child: Text(

                  _cameraError!,

                  textAlign: TextAlign.center,

                  style: const TextStyle(color: Colors.white70, fontSize: 10),

                ),

              ),

            )

          : _cameraController != null && _cameraController!.value.isInitialized

          ? CameraPreview(_cameraController!)

          : const Center(

              child: Icon(Icons.person, color: Colors.white70, size: 35),

            ),

    );

  }

  // --------------------------------------------------

  // MESSAGE INPUT

  // --------------------------------------------------

  Widget _buildMessageInput() {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),

      decoration: BoxDecoration(

        color: Colors.black.withValues(alpha: 0.55),

        borderRadius: BorderRadius.circular(28),

        border: Border.all(color: Colors.white24),

      ),

      child: Row(

        children: [

          Expanded(

            child: TextField(

              controller: _messageController,

              enabled: !_isTyping,

              style: const TextStyle(color: Colors.white, fontSize: 14),

              decoration: const InputDecoration(

                hintText: 'Write a message...',

                hintStyle: TextStyle(color: Colors.white60, fontSize: 13),

                border: InputBorder.none,

                contentPadding: EdgeInsets.symmetric(horizontal: 8),

              ),

              onSubmitted: (_) => _sendMessage(),

            ),

          ),

          IconButton(

            onPressed: _isTyping ? null : _sendMessage,

            icon: const Icon(Icons.send_rounded, color: Colors.white),

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

          color: _isListening ? Colors.redAccent : const Color(0xFF356AE6),

          onPressed: _toggleMicrophone,

        ),

        const SizedBox(width: 22),

        _controlButton(

          icon: _isAvatarSpeaking ? Icons.pause : Icons.volume_up,

          color: const Color(0xFF356AE6),

          onPressed: _toggleSpeaker,

        ),

        const SizedBox(width: 22),

        _controlButton(

          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,

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
