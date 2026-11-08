import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/learning_service.dart';

class CameraTranslationScreen extends StatefulWidget {
  const CameraTranslationScreen({super.key});

  @override
  State<CameraTranslationScreen> createState() =>
      _CameraTranslationScreenState();
}

class _CameraTranslationScreenState extends State<CameraTranslationScreen> {
  // --------------------------------------------------
  // CONFIGURATION
  // --------------------------------------------------

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Color _primaryBlue = Color(0xFF356AE6);
  static const Color _darkBlue = Color(0xFF172B4D);

  // --------------------------------------------------
  // SERVICES
  // --------------------------------------------------

  final LearningService _learningService = LearningService();
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<void>? _audioCompleteSubscription;

  // --------------------------------------------------
  // IMAGE
  // --------------------------------------------------

  XFile? _selectedImage;
  Uint8List? _imageBytes;

  // --------------------------------------------------
  // OCR
  // --------------------------------------------------

  String _recognizedText = '';

  // --------------------------------------------------
  // TRANSLATION
  // --------------------------------------------------

  String _translatedText = '';
  String _targetLanguage = 'English';

  // --------------------------------------------------
  // STATES
  // --------------------------------------------------

  bool _isProcessing = false;
  bool _isTranslating = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();

    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });
    });
  }

  // --------------------------------------------------
  // IMAGE SELECTION
  // --------------------------------------------------

  Future<void> _selectImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 90);

      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();

      await _stopAudio();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _recognizedText = '';
        _translatedText = '';
      });
    } catch (error) {
      _showMessage('Image selection error: $error');
    }
  }

  Future<void> _takePhoto() async {
    await _selectImage(ImageSource.camera);
  }

  Future<void> _chooseFromGallery() async {
    await _selectImage(ImageSource.gallery);
  }

  // --------------------------------------------------
  // IMAGE MIME TYPE
  // --------------------------------------------------

  MediaType _getImageMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  // --------------------------------------------------
  // OCR THROUGH FASTAPI + EASYOCR
  // --------------------------------------------------

  Future<void> _processImage() async {
    final image = _selectedImage;
    final bytes = _imageBytes;

    if (image == null || bytes == null || _isProcessing) {
      return;
    }

    if (bytes.length > 10 * 1024 * 1024) {
      _showMessage('Image too large. Maximum size is 10 MB.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _recognizedText = '';
      _translatedText = '';
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/ocr');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: image.name,
          contentType: _getImageMimeType(image.name),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 180),
      );

      final response = await http.Response.fromStream(streamedResponse);

      final responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final detail = responseData is Map
            ? responseData['detail']?.toString()
            : null;

        throw Exception(detail ?? 'Server error ${response.statusCode}');
      }

      final recognizedText = responseData['text']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() {
        _recognizedText = recognizedText;
        _isProcessing = false;
      });

      if (recognizedText.isEmpty) {
        _showMessage('No text was detected in this image.');
      }
    } catch (error) {
      debugPrint('EasyOCR error: $error');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage('OCR error: $error');
    }
  }

  // --------------------------------------------------
  // LOAD TARGET LANGUAGE
  // --------------------------------------------------

  Future<String> _loadTargetLanguage() async {
    final profile = await _learningService.getLearningProfile();

    return profile?['target_language']?.toString() ?? 'English';
  }

  // --------------------------------------------------
  // TRANSLATION THROUGH FASTAPI
  // --------------------------------------------------

  Future<void> _translateText() async {
    final text = _recognizedText.trim();

    if (text.isEmpty || _isTranslating) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    try {
      final language = await _loadTargetLanguage();

      if (!mounted) return;

      setState(() {
        _targetLanguage = language;
      });

      final uri = Uri.parse('$_baseUrl/api/translate');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'target_language': language}),
          )
          .timeout(const Duration(seconds: 120));

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final detail = data is Map ? data['detail']?.toString() : null;

        throw Exception(
          detail ?? 'Translation server error ${response.statusCode}',
        );
      }

      final translation = data['translated_text']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() {
        _translatedText = translation;
        _isTranslating = false;
      });

      if (translation.isEmpty) {
        _showMessage('The translation is empty.');
      }
    } catch (error) {
      debugPrint('Translation error: $error');

      if (!mounted) return;

      setState(() {
        _isTranslating = false;
      });

      _showMessage('Translation error: $error');
    }
  }

  // --------------------------------------------------
  // STOP AUDIO
  // --------------------------------------------------

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (error) {
      debugPrint('Audio stop error: $error');
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  // --------------------------------------------------
  // NATURAL TEXT TO SPEECH THROUGH EDGE TTS
  // --------------------------------------------------

  Future<void> _speakTranslation() async {
    final text = _translatedText.trim();

    if (text.isEmpty) return;

    if (_isSpeaking) {
      await _stopAudio();
      return;
    }

    try {
      setState(() {
        _isSpeaking = true;
      });

      final uri = Uri.parse('$_baseUrl/api/tts');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'language': _targetLanguage}),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        String detail = 'Audio generation failed';

        try {
          final data = jsonDecode(response.body);

          if (data is Map && data['detail'] != null) {
            detail = data['detail'].toString();
          }
        } catch (_) {
          detail = 'Audio server error ${response.statusCode}';
        }

        throw Exception(detail);
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('The audio file is empty.');
      }

      if (!mounted) return;

      // Play the MP3 returned by Edge TTS.
      await _audioPlayer.play(BytesSource(response.bodyBytes));
    } catch (error) {
      debugPrint('Edge TTS error: $error');

      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });

      _showMessage('Audio error: $error');
    }
  }

  // --------------------------------------------------
  // CLEAR IMAGE
  // --------------------------------------------------

  Future<void> _clearImage() async {
    await _stopAudio();

    if (!mounted) return;

    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _recognizedText = '';
      _translatedText = '';
      _isProcessing = false;
      _isTranslating = false;
    });
  }

  // --------------------------------------------------
  // MESSAGE
  // --------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _audioCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // MAIN UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Camera Translation'),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _selectedImage == null
            ? _buildEmptyState()
            : _buildImageResult(),
      ),
    );
  }

  // --------------------------------------------------
  // EMPTY STATE
  // --------------------------------------------------

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black12),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 80,
                      color: _primaryBlue,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scan text with your camera',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        'Take a photo or select an existing image.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _chooseFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // IMAGE AND RESULTS
  // --------------------------------------------------

  Widget _buildImageResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SELECTED IMAGE

          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 16),

          // IMAGE ACTIONS
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearImage,
                  icon: const Icon(Icons.close),
                  label: const Text('New Image'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processImage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.document_scanner),
                  label: Text(_isProcessing ? 'Reading...' : 'Detect Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // DETECTED TEXT
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Detected text',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkBlue,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: SelectableText(
                _recognizedText,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            // TRANSLATION BUTTON
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _translateText,
              icon: _isTranslating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.translate),
              label: Text(
                _isTranslating
                    ? 'Translating...'
                    : 'Translate to $_targetLanguage',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],

          // TRANSLATED TEXT
          if (_translatedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Translation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkBlue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _speakTranslation,
                  tooltip: _isSpeaking ? 'Stop audio' : 'Listen',
                  icon: Icon(
                    _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                    color: _primaryBlue,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _primaryBlue.withValues(alpha: 0.25)),
              ),
              child: SelectableText(
                _translatedText,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: _darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Translated into $_targetLanguage',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}
