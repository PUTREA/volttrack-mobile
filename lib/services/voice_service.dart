import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Layanan suara AURA — SEMUA on-device (gratis, tanpa API eksternal):
///  - STT: Apple Speech Recognition lewat paket speech_to_text.
///  - TTS: suara bawaan iOS lewat flutter_tts (Bahasa Indonesia).
///
/// Dipakai untuk V1 (push-to-talk) & V2 (listening mode "Hi AURA").
/// Mengirim HANYA teks hasil transkripsi ke pipeline AURA yang sudah ada,
/// jadi tidak menambah konsumsi token Gemini sama sekali.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  bool _listening = false;
  bool _speaking = false;

  bool get isListening => _listening;
  bool get isSpeaking => _speaking;
  bool get sttAvailable => _sttReady;

  /// Level suara mic 0..1 (dari onSoundLevel) — dipakai orb reaktif ala Siri.
  final ValueNotifier<double> soundLevel = ValueNotifier<double>(0.0);

  /// Variasi wake word yang diterima (dinormalisasi lowercase).
  static const List<String> wakeWords = [
    'hi aura',
    'hai aura',
    'hey aura',
    'halo aura',
  ];

  Completer<void>? _speakCompleter;

  // Pelacakan satu sesi listen: apakah sudah ada hasil final + callback akhir.
  bool _gotFinalThisSession = false;
  void Function()? _onListenEnd;

  /// Inisialisasi STT + TTS. Aman dipanggil berkali-kali (idempoten).
  /// Mengembalikan true bila STT siap (mic+speech diizinkan).
  Future<bool> init() async {
    if (!_ttsReady) {
      try {
        await _tts.awaitSpeakCompletion(true);
        // iOS: pakai kategori playAndRecord agar TTS & mic (STT) berbagi
        // AVAudioSession yang sama tanpa saling merusak (penyebab EXC_BAD_ACCESS).
        try {
          await _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playAndRecord,
            [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
            IosTextToSpeechAudioMode.spokenAudio,
          );
        } catch (_) {
          /* non-iOS atau tidak didukung → abaikan */
        }
        // Utamakan Bahasa Indonesia; fallback ke en-US bila tak tersedia.
        try {
          await _tts.setLanguage('id-ID');
        } catch (_) {
          await _tts.setLanguage('en-US');
        }
        await _tts.setSpeechRate(0.5); // natural, tidak terburu-buru
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        _tts.setStartHandler(() => _speaking = true);
        _tts.setCompletionHandler(() {
          _speaking = false;
          _speakCompleter?.complete();
          _speakCompleter = null;
        });
        _tts.setCancelHandler(() {
          _speaking = false;
          _speakCompleter?.complete();
          _speakCompleter = null;
        });
        _tts.setErrorHandler((_) {
          _speaking = false;
          _speakCompleter?.complete();
          _speakCompleter = null;
        });
        _ttsReady = true;
      } catch (_) {
        _ttsReady = false;
      }
    }

    if (!_sttReady) {
      try {
        _sttReady = await _stt.initialize(
          onError: (e) {
            debugPrint(
              '[AURA voice] STT error: ${e.errorMsg} permanent=${e.permanent}',
            );
            // error_no_match/timeout BUKAN fatal untuk loop wake word; akhiri
            // sesi ini & biarkan pemanggil memutuskan mendengar lagi.
            _listening = false;
            _fireListenEnd();
          },
          onStatus: (status) {
            debugPrint('[AURA voice] STT status: $status');
            if (status == 'done' || status == 'notListening') {
              _listening = false;
              _fireListenEnd();
            }
          },
          debugLogging: false,
        );
        debugPrint(
          '[AURA voice] STT initialize -> $_sttReady (hasPermission=${_stt.hasPermission})',
        );
      } catch (e) {
        debugPrint('[AURA voice] STT initialize threw: $e');
        _sttReady = false;
      }
    }
    return _sttReady;
  }

  /// Mulai mendengarkan. [onResult] dipanggil tiap pembacaan (parsial & final),
  /// [onFinal] dipanggil sekali saat hasil final siap.
  /// [fastFinalize] = mode cepat untuk frasa pendek (wake word): finalisasi lebih
  /// gesit dengan pauseFor singkat & listenMode confirmation.
  /// Barge-in: TTS yang sedang berjalan dihentikan dulu.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(String finalText)? onFinal,
    void Function()?
    onDone, // dipanggil saat sesi berakhir tanpa hasil final (mis. no-match)
    Duration listenFor = const Duration(seconds: 20),
    Duration? pauseFor,
    bool fastFinalize = false,
  }) async {
    if (!_sttReady) {
      final ok = await init();
      if (!ok) return;
    }

    // Barge-in: hentikan TTS lebih dulu. TTS & STT berbagi AVAudioSession;
    // beri jeda SINGKAT (sesi playAndRecord sudah kompatibel, jadi 120ms cukup).
    if (_speaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 120));
    }

    // Cegah dobel-listen: bila engine masih aktif, bersihkan dulu (jeda minimal).
    if (_stt.isListening) {
      try {
        await _stt.cancel();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _listening = true;
    _gotFinalThisSession = false;
    _onListenEnd = onDone;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          final text = r.recognizedWords;
          onResult(text, r.finalResult);
          if (r.finalResult) {
            _gotFinalThisSession = true;
            _listening = false;
            soundLevel.value = 0.0;
            if (text.trim().isNotEmpty) onFinal?.call(text.trim());
          }
        },
        onSoundLevelChange: (level) {
          // speech_to_text mengirim dB kira-kira -2..10; normalkan ke 0..1.
          final norm = ((level + 2) / 12).clamp(0.0, 1.0);
          soundLevel.value = norm;
        },
        listenOptions: SpeechListenOptions(
          localeId: 'id_ID',
          partialResults: true,
          // confirmation lebih cepat memfinalisasi frasa pendek (wake word);
          // dictation untuk perintah/kalimat panjang.
          listenMode: fastFinalize
              ? ListenMode.confirmation
              : ListenMode.dictation,
          // JANGAN cancelOnError: error_no_match sering muncul saat sunyi; itu
          // normal untuk loop wake word, bukan alasan membunuh sesi permanen.
          cancelOnError: false,
          listenFor: listenFor,
          pauseFor:
              pauseFor ??
              (fastFinalize
                  ? const Duration(milliseconds: 1200)
                  : const Duration(seconds: 2)),
        ),
      );
    } catch (_) {
      // Kegagalan audio engine jangan sampai meng-crash app.
      _listening = false;
      soundLevel.value = 0.0;
      _fireListenEnd();
    }
  }

  /// Panggil callback akhir-sesi SEKALI, hanya bila tidak ada hasil final
  /// (mis. no-match / timeout). Mencegah dobel-trigger.
  void _fireListenEnd() {
    final cb = _onListenEnd;
    _onListenEnd = null;
    soundLevel.value = 0.0;
    if (!_gotFinalThisSession && cb != null) {
      cb();
    }
  }

  Future<void> stopListening() async {
    if (_listening) {
      try {
        await _stt.stop();
      } catch (_) {}
      _listening = false;
    }
  }

  Future<void> cancelListening() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    _listening = false;
  }

  /// Bacakan teks dengan suara. Menunggu sampai selesai (awaitSpeakCompletion).
  Future<void> speak(String text) async {
    final clean = _sanitizeForSpeech(text);
    if (clean.isEmpty) return;
    if (!_ttsReady) {
      await init();
      if (!_ttsReady) return;
    }
    await stopSpeaking();
    _speakCompleter = Completer<void>();
    _speaking = true;
    try {
      await _tts.speak(clean);
    } catch (_) {
      _speaking = false;
      _speakCompleter = null;
      return;
    }
    // awaitSpeakCompletion(true) membuat speak() menunggu, tapi jaga-jaga timeout.
    await _speakCompleter?.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  Future<void> stopSpeaking() async {
    if (_speaking) {
      try {
        await _tts.stop();
      } catch (_) {}
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
  }

  /// Deteksi wake word di awal kalimat. Mengembalikan sisa perintah setelah
  /// wake word (bila ada), atau null bila tidak diawali wake word.
  /// Contoh: "hi aura berapa produksi solar" -> "berapa produksi solar".
  static String? extractAfterWakeWord(String text) {
    final t = text.trim().toLowerCase();
    for (final w in wakeWords) {
      if (t == w) return ''; // hanya memanggil, belum ada perintah
      if (t.startsWith('$w ') || t.startsWith('$w,')) {
        return text
            .trim()
            .substring(w.length)
            .replaceFirst(RegExp(r'^[,\s]+'), '')
            .trim();
      }
    }
    return null;
  }

  static bool containsWakeWord(String text) {
    final t = text.trim().toLowerCase();
    return wakeWords.any(
      (w) => t == w || t.startsWith('$w ') || t.startsWith('$w,'),
    );
  }

  /// Buang markdown & elemen yang tak enak dibacakan (biar TTS natural).
  String _sanitizeForSpeech(String text) {
    var t = text;
    t = t.replaceAll(RegExp(r'[*_`#>]'), ''); // markdown
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.trim();
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
  }
}
