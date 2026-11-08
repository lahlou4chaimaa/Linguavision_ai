import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;

  bool get isListening => _speech.isListening;

  bool get isAvailable => _speech.isAvailable;

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    if (_initialized) {
      return _speech.isAvailable;
    }

    _initialized = await _speech.initialize(
      onStatus: onStatus,
      onError: (error) {
        onError(error.errorMsg);
      },
      debugLogging: false,
    );

    return _initialized;
  }

  Future<List<LocaleName>> getLocales() async {
    if (!_initialized) {
      return [];
    }

    return _speech.locales();
  }

  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_initialized || !_speech.isAvailable) {
      throw Exception('Speech recognition is not available.');
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: localeId,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
  }
}
