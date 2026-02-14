import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;

  Future<bool> initialize() async {
    // Initialize TTS
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);

    // Initialize STT
    return await _speechToText.initialize(
      onError: (val) {
        if (kDebugMode) debugPrint('STT onError: $val');
      },
      onStatus: (val) {
        if (kDebugMode) debugPrint('STT onStatus: $val');
      },
    );
  }

  Future<void> startListening({required Function(String) onResult}) async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        _isListening = true;
        _speechToText.listen(
          onResult: (val) {
            onResult(val.recognizedWords);
          },
        );
      }
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      await _speechToText.stop();
    }
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }
}
