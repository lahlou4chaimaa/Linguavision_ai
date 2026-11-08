
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_tutor_service.dart';
import '../../services/learning_service.dart';

class CameraTranslationScreen extends StatefulWidget {
  const CameraTranslationScreen({super.key});

  @override
  State<CameraTranslationScreen> createState() =>
      _CameraTranslationScreenState();
}

class _CameraTranslationScreenState extends State<CameraTranslationScreen> {
  // --------------------------------------------------
  // SERVICES
  // --------------------------------------------------

  final AiTutorService _aiTutorService = AiTutorService();
  final LearningService _learningService = LearningService();
  final FlutterTts _tts = FlutterTts();
  final ImagePicker _picker = ImagePicker();

  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

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

  // --------------------------------------------------
  // TAKE PHOTO
  // --------------------------------------------------

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();

      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _recognizedText = '';
        _translatedText = '';
        _isSpeaking = false;
      });
    } catch (error) {
      _showMessage('Camera error: $error');
    }
  }

  // --------------------------------------------------
  // CHOOSE FROM GALLERY
  // --------------------------------------------------

  Future<void> _chooseFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();

      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _recognizedText = '';
        _translatedText = '';
        _isSpeaking = false;
      });
    } catch (error) {
      _showMessage('Gallery error: $error');
    }
  }

  // --------------------------------------------------
  // OCR
  // --------------------------------------------------

  Future<void> _processImage() async {
    final image = _selectedImage;

    if (image == null || _isProcessing) return;

    // Google ML Kit Text Recognition does not support Flutter Web.
    if (kIsWeb) {
      _showMessage(
        'Text recognition is available on Android, not Chrome.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _recognizedText = '';
      _translatedText = '';
    });

    try {
      // On Android/iOS, ML Kit can read the selected image
      // using its local file path.
      final inputImage = InputImage.fromFilePath(image.path);

      final RecognizedText result =
          await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      setState(() {
        _recognizedText = result.text.trim();
        _isProcessing = false;
      });

      if (_recognizedText.isEmpty) {
        _showMessage('No text was detected in this image.');
      }
    } catch (error) {
      debugPrint('OCR error: $error');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage('OCR error: $error');
    }
  }

  // --------------------------------------------------
  // TRANSLATION
  // --------------------------------------------------

  Future<void> _translateText() async {
    final text = _recognizedText.trim();

    if (text.isEmpty || _isTranslating) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    try {
      final profile = await _learningService.getLearningProfile();

      final language =
          profile?['target_language']?.toString() ?? 'English';

      if (!mounted) return;

      setState(() {
        _targetLanguage = language;
      });

      final prompt = '''
You are a professional language translator.

Translate the following text into $language.

Instructions:
- Return only the translated text.
- Do not explain the translation.
- Do not add introductions or conclusions.
- Do not add quotation marks.
- Preserve the original meaning.
- Keep names, numbers and important details unchanged.
- Preserve paragraph structure when possible.

Text to translate:
$text
''';

      final translation = await _aiTutorService.sendMessage(
        message: prompt,
        history: const [],
      );

      if (!mounted) return;

      setState(() {
        _translatedText = translation.trim();
        _isTranslating = false;
      });

      if (_translatedText.isEmpty) {
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
  // TTS LANGUAGE
  // --------------------------------------------------

  String _getTtsLocale(String language) {
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

    return locales[language.toLowerCase().trim()] ?? 'en-US';
  }

  // --------------------------------------------------
  // TEXT TO SPEECH
  // --------------------------------------------------

  Future<void> _speakTranslation() async {
    if (_translatedText.trim().isEmpty) return;

    // Stop current speech
    if (_isSpeaking) {
      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });

      return;
    }

    try {
      await _tts.stop();

      await _tts.setLanguage(
        _getTtsLocale(_targetLanguage),
      );

      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);

      if (!mounted) return;

      setState(() {
        _isSpeaking = true;
      });

      await _tts.speak(_translatedText);

      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });
    } catch (error) {
      debugPrint('TTS error: $error');

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
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _recognizedText = '';
      _translatedText = '';
      _isSpeaking = false;
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _textRecognizer.close();
    _tts.stop();
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
        backgroundColor: const Color(0xFF356AE6),
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
                border: Border.all(
                  color: Colors.black12,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 80,
                      color: Color(0xFF356AE6),
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
                        style: TextStyle(
                          color: Colors.black54,
                        ),
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
                    backgroundColor: const Color(0xFF356AE6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
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
                    foregroundColor: const Color(0xFF356AE6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
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
          // --------------------------------------------------
          // SELECTED IMAGE
          // --------------------------------------------------

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
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),

          const SizedBox(height: 16),

          // --------------------------------------------------
          // IMAGE ACTIONS
          // --------------------------------------------------

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
                  onPressed:
                      _isProcessing ? null : _processImage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.document_scanner,
                        ),
                  label: Text(
                    _isProcessing
                        ? 'Reading...'
                        : 'Detect Text',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF356AE6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // --------------------------------------------------
          // DETECTED TEXT
          // --------------------------------------------------

          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 24),

            const Text(
              'Detected text',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.black12,
                ),
              ),
              child: SelectableText(
                _recognizedText,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // TRANSLATION BUTTON
            // --------------------------------------------------

            ElevatedButton.icon(
              onPressed:
                  _isTranslating ? null : _translateText,
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
                backgroundColor: const Color(0xFF356AE6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
              ),
            ),
          ],

          // --------------------------------------------------
          // TRANSLATED TEXT
          // --------------------------------------------------

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
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _speakTranslation,
                  tooltip:
                      _isSpeaking ? 'Stop audio' : 'Listen',
                  icon: Icon(
                    _isSpeaking
                        ? Icons.stop_circle
                        : Icons.volume_up,
                    color: const Color(0xFF356AE6),
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
                border: Border.all(
                  color: const Color(0xFF356AE6)
                      .withValues(alpha: 0.25),
                ),
              ),
              child: SelectableText(
                _translatedText,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF172B4D),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Translated into $_targetLanguage',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}