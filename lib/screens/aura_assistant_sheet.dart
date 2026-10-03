import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/aura_living_orb.dart';
import '../widgets/motion_helpers.dart';
import '../services/aura_ai_service.dart';
import '../services/voice_service.dart';
import '../theme/theme_controller.dart';

class AuraAssistantSheet extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  final Map<String, dynamic>? initialTelemetry;

  /// Bila diisi, AURA otomatis mengirim pesan ini saat sheet terbuka
  /// (dipakai saat pengguna mengetuk tip insight di Home).
  final String? initialPrompt;

  const AuraAssistantSheet({
    super.key,
    this.onNavigateTab,
    this.initialTelemetry,
    this.initialPrompt,
  });

  static Future<void> show(
    BuildContext context, {
    Function(int tabIndex)? onNavigateTab,
    Map<String, dynamic>? initialTelemetry,
    String? initialPrompt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuraAssistantSheet(
        onNavigateTab: onNavigateTab,
        initialTelemetry: initialTelemetry,
        initialPrompt: initialPrompt,
      ),
    );
  }

  @override
  State<AuraAssistantSheet> createState() => _AuraAssistantSheetState();
}

class _AuraAssistantSheetState extends State<AuraAssistantSheet> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<AuraMessage> _messages = [];
  final List<AuraMemoryFact> _memoryChips = [];
  AuraState _orbState = AuraState.idle;
  bool _isTyping = false;
  bool _isWaitingResponse = false;
  String _statusLabel = ''; // label status streaming nyata (dari event status)

  // ── Suara (V1 push-to-talk + V2 listening mode "Hi AURA") ──
  final _voice = VoiceService.instance;
  bool _voiceEnabled = true; // feedback suara on/off (toggle di header)
  bool _micListening = false; // sedang merekam ucapan
  bool _micStarting =
      false; // sedang menyiapkan engine (cegah start/stop balapan)
  bool _listenMode = false; // V2: loop hands-free aktif
  String _partialText = ''; // transkrip sementara saat bicara

  List<String> _suggestions = [
    '⚡ Berapa produksi solar saya sekarang?',
    '📦 Cek status pesanan saya',
    '🛡️ Status garansi perangkat',
    '💰 Hitung hemat tagihan listrik',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Lanjutkan percakapan terakhir bila < 30 menit; selain itu salam pembuka.
  Future<void> _bootstrap() async {
    List<AuraMessage> history = const [];
    try {
      history = await AuraAiService.instance.resumeOrStart();
    } catch (_) {
      history = const [];
    }
    if (!mounted) return;
    setState(() {
      _messages.clear();
      if (history.isNotEmpty) {
        _messages.addAll(history);
      } else {
        _messages.add(
          AuraMessage(
            id: 'greeting_0',
            text: AuraAiService.instance.getProactiveGreeting(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _scrollToBottom();
    _loadMemoryChips();

    // Auto-kirim pesan awal (mis. "Jelaskan insight ini: …") bila diminta.
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleSend(prompt.trim());
      });
      return; // jangan auto-dengar bila sedang menjelaskan insight
    }

    // AUTO listening mode: begitu sheet terbuka, AURA langsung siap mendengar
    // "Hi AURA" tanpa perlu menekan tombol apa pun.
    _autoStartListening();
  }

  /// Nyalakan mode dengar secara otomatis & senyap (tanpa sapaan TTS) saat
  /// sheet dibuka. Bila izin mic belum ada, gagal diam-diam (tombol sensor
  /// tetap bisa dipakai untuk mencoba lagi).
  Future<void> _autoStartListening() async {
    // Tunggu sheet selesai animasi masuk sebelum menyentuh audio session
    // (mic engine butuh view yang sudah tampil penuh di iOS).
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    debugPrint('[AURA voice] autoStart: calling init()...');
    var ok = await _voice.init();
    // Retry sekali bila gagal (izin baru saja diberikan / sesi belum siap).
    if (!ok) {
      await Future.delayed(const Duration(milliseconds: 600));
      ok = await _voice.init();
    }
    debugPrint('[AURA voice] autoStart: init()=$ok mounted=$mounted');
    if (!ok || !mounted) return; // izin belum ada → biarkan user pakai tombol
    setState(() => _listenMode = true);
    debugPrint('[AURA voice] autoStart: starting listen loop');
    _listenLoop();
  }

  Future<void> _loadMemoryChips() async {
    try {
      final facts = await AuraAiService.instance.fetchMemory();
      if (!mounted) return;
      setState(() {
        _memoryChips
          ..clear()
          ..addAll(facts);
      });
    } catch (_) {
      /* abaikan: chip memori opsional */
    }
  }

  /// Mulai percakapan baru (tombol di header).
  void _newConversation() {
    HapticFeedback.selectionClick();
    AuraAiService.instance.resetConversation();
    setState(() {
      _messages
        ..clear()
        ..add(
          AuraMessage(
            id: 'greeting_${DateTime.now().millisecondsSinceEpoch}',
            text: AuraAiService.instance.getProactiveGreeting(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      _orbState = AuraState.idle;
    });
    _scrollToBottom();
  }

  Future<void> _forgetFact(AuraMemoryFact fact) async {
    HapticFeedback.selectionClick();
    final ok = await AuraAiService.instance.forget(fact.key);
    if (!mounted) return;
    if (ok) {
      setState(() => _memoryChips.removeWhere((f) => f.key == fact.key));
    }
  }

  @override
  void dispose() {
    _voice.dispose(); // hentikan mic & TTS saat sheet ditutup
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── SUARA ─────────────────────────

  /// Push-to-talk (V1): rekam sekali, lalu kirim hasilnya ke AURA.
  Future<void> _startPushToTalk() async {
    if (_isTyping || _micStarting || _micListening) return;
    _micStarting = true;
    HapticFeedback.mediumImpact();
    final ok = await _voice.init();
    if (!ok) {
      _micStarting = false;
      _showVoiceUnavailable();
      return;
    }
    if (!mounted) {
      _micStarting = false;
      return;
    }
    setState(() {
      _micListening = true;
      _partialText = '';
      _orbState = AuraState.listening;
    });
    await _voice.listen(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _partialText = text);
      },
      onFinal: (finalText) {
        if (!mounted) return;
        setState(() {
          _micListening = false;
          _partialText = '';
          if (_orbState == AuraState.listening) _orbState = AuraState.idle;
        });
        if (finalText.trim().isNotEmpty) _handleSend(finalText.trim());
      },
    );
    _micStarting = false; // engine sudah aktif → aman di-stop
  }

  Future<void> _stopPushToTalk() async {
    // Tunggu bila engine masih dalam proses start (cegah stop di tengah setup).
    var waited = 0;
    while (_micStarting && waited < 2000) {
      await Future.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    if (!_micListening) return;
    await _voice.stopListening();
    if (!mounted) return;
    setState(() {
      _micListening = false;
      if (_orbState == AuraState.listening) _orbState = AuraState.idle;
    });
  }

  /// V2: aktif/matikan mode mendengarkan hands-free "Hi AURA".
  Future<void> _toggleListenMode() async {
    HapticFeedback.selectionClick();
    if (_listenMode) {
      setState(() => _listenMode = false);
      await _voice.cancelListening();
      await _voice.stopSpeaking();
      if (mounted && _orbState == AuraState.listening) {
        setState(() => _orbState = AuraState.idle);
      }
      return;
    }
    final ok = await _voice.init();
    if (!ok) {
      _showVoiceUnavailable();
      return;
    }
    setState(() => _listenMode = true);
    // Sapaan pembuka SINGKAT & non-blocking: langsung mulai mendengar.
    if (_voiceEnabled) {
      _voice.speak('Mode suara aktif.'); // tidak di-await → mic cepat terbuka
    }
    _listenLoop();
  }

  /// Loop mendengarkan V2: tunggu "Hi AURA" + perintah, lalu proses.
  Future<void> _listenLoop() async {
    if (!mounted || !_listenMode || _isTyping) return;
    setState(() {
      _micListening = true;
      _partialText = '';
      if (_orbState == AuraState.idle) _orbState = AuraState.listening;
    });
    await _voice.listen(
      listenFor: const Duration(seconds: 15),
      fastFinalize: true, // confirmation mode + pauseFor 1.2s → wake word cepat terdeteksi
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _partialText = text);
      },
      onDone: () {
        // Sesi berakhir tanpa ucapan (no-match/timeout) → dengarkan lagi
        // selama mode masih aktif. Inilah yang membuat "always listening".
        if (mounted && _listenMode && !_isTyping) {
          setState(() => _micListening = false);
          // Jeda kecil agar sesi audio benar-benar lepas & tidak spin-loop.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _listenMode && !_isTyping && !_micListening) {
              _listenLoop();
            }
          });
        }
      },
      onFinal: (finalText) {
        if (!mounted) return;
        setState(() {
          _micListening = false;
          _partialText = '';
        });
        final after = VoiceService.extractAfterWakeWord(finalText);
        if (after == null) {
          // Bukan ditujukan ke AURA → dengarkan lagi (abaikan kebisingan).
          if (_listenMode) _listenLoop();
          return;
        }
        if (after.isEmpty) {
          // Hanya "Hi AURA" → sahut SINGKAT non-blocking, langsung dengar perintah.
          if (_voiceEnabled) _voice.speak('Ya?');
          if (_listenMode && mounted) _listenLoop();
          return;
        }
        // "Hi AURA <perintah>" → kirim perintahnya ke AURA.
        _handleSend(after);
      },
    );
  }

  void _showVoiceUnavailable() {
    if (!mounted) return;
    setState(() {
      _micListening = false;
      _listenMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Izin mikrofon/ucapan belum aktif. Aktifkan di Pengaturan untuk memakai suara.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = presetText ?? _textCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    _textCtrl.clear();
    setState(() {
      _messages.add(
        AuraMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _orbState = AuraState.thinking;
      _isTyping = true;
      _isWaitingResponse = true;
      _statusLabel = '';
    });

    HapticFeedback.lightImpact();
    _scrollToBottom();

    // Bubble balasan diisi bertahap oleh event delta NYATA dari server (bukan simulasi).
    final replyId = 'reply_${DateTime.now().microsecondsSinceEpoch}';
    final buffer = StringBuffer();
    final cards = <AuraCard>[];
    var bubbleAdded = false;

    void ensureBubble() {
      if (bubbleAdded) return;
      bubbleAdded = true;
      _isWaitingResponse = false; // hentikan thinking bubble; mulai speaking
      _orbState = AuraState.speaking;
      _messages.add(
        AuraMessage(
          id: replyId,
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    }

    void updateBubble() {
      final idx = _messages.indexWhere((m) => m.id == replyId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(
          text: buffer.toString(),
          cards: List.of(cards),
        );
      }
    }

    try {
      await for (final ev in AuraAiService.instance.sendMessageStream(
        userText: text,
      )) {
        if (!mounted) return;
        switch (ev.kind) {
          case AuraStreamKind.meta:
            break;
          case AuraStreamKind.status:
            setState(() => _statusLabel = (ev.data['label'] ?? '').toString());
            break;
          case AuraStreamKind.delta:
            setState(() {
              ensureBubble();
              buffer.write((ev.data['text'] ?? '').toString());
              updateBubble();
            });
            _scrollToBottom();
            break;
          case AuraStreamKind.card:
            setState(() {
              ensureBubble();
              final type = auraActionTypeFrom(ev.data['type'] as String?);
              if (type != AuraActionType.none) {
                cards.add(
                  AuraCard(
                    type,
                    Map<String, dynamic>.from(ev.data['data'] as Map? ?? {}),
                  ),
                );
                updateBubble();
              }
            });
            _scrollToBottom();
            break;
          case AuraStreamKind.memory:
            final fact = AuraMemoryFact(
              key: (ev.data['key'] ?? '').toString(),
              value: (ev.data['value'] ?? '').toString(),
              label: (ev.data['label'] ?? ev.data['key'] ?? '').toString(),
            );
            setState(() {
              _memoryChips.removeWhere((f) => f.key == fact.key);
              _memoryChips.add(fact);
            });
            break;
          case AuraStreamKind.done:
            setState(() {
              ensureBubble();
              final reply = (ev.data['reply'] ?? '').toString();
              if (buffer.isEmpty && reply.isNotEmpty) buffer.write(reply);
              if (cards.isEmpty) {
                cards.addAll(
                  AuraAiService.instance.parseCards(ev.data['cards']),
                );
              }
              updateBubble();
              final sugg = [
                for (final s in (ev.data['suggestions'] as List? ?? const []))
                  s.toString(),
              ];
              if (sugg.isNotEmpty) _suggestions = sugg;
              _orbState = AuraState.idle;
              _isTyping = false;
              _isWaitingResponse = false;
              _statusLabel = '';
            });
            _scrollToBottom();
            break;
          case AuraStreamKind.error:
            setState(() {
              ensureBubble();
              if (buffer.isEmpty) {
                buffer.write(
                  (ev.data['message'] ?? 'AURA sedang sibuk, coba lagi sesaat.')
                      .toString(),
                );
                updateBubble();
              }
              _orbState = AuraState.idle;
              _isTyping = false;
              _isWaitingResponse = false;
              _statusLabel = '';
            });
            _scrollToBottom();
            break;
        }
      }
    } catch (_) {
      // Pengaman terakhir bila stream melempar di luar dugaan.
    }

    if (!mounted) return;
    if (_isTyping) {
      setState(() {
        _orbState = AuraState.idle;
        _isTyping = false;
        _isWaitingResponse = false;
        _statusLabel = '';
      });
    }

    // Feedback suara: bacakan jawaban final (teks saja, bukan kartu).
    final spoken = buffer.toString().trim();
    if (_voiceEnabled && spoken.isNotEmpty) {
      setState(() => _orbState = AuraState.speaking);
      await _voice.speak(spoken);
      if (!mounted) return;
      setState(() {
        if (_orbState == AuraState.speaking) _orbState = AuraState.idle;
      });
    }

    // V2: lanjutkan loop mendengarkan setelah selesai menjawab.
    if (_listenMode && mounted && !_isTyping) {
      _listenLoop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? const Color(0x28FFFFFF) : const Color(0x1E000000),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. DRAG HANDLE
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // 2. LIVING ORB HEADER & STATUS BADGE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _voice.soundLevel,
                  builder: (context, level, _) => AuraLivingOrb(
                    size: 48,
                    state: _orbState,
                    amplitude: _orbState == AuraState.listening ? level : 0.0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _orbState = _orbState == AuraState.idle
                            ? AuraState.listening
                            : AuraState.idle;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'AURA',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F5D4)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00F5D4)
                                    .withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00F5D4),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF00F5D4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _orbState == AuraState.thinking
                                      ? 'ANALYZING...'
                                      : _orbState == AuraState.speaking
                                      ? 'SPEAKING'
                                      : 'ONLINE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF00F5D4),
                                    letterSpacing: 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Autonomous Solar Energy Copilot',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Toggle feedback suara (on/off) — mematikan TTS saat rapat.
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _voiceEnabled = !_voiceEnabled);
                    if (!_voiceEnabled) _voice.stopSpeaking();
                  },
                  tooltip: _voiceEnabled ? 'Suara: aktif' : 'Suara: nonaktif',
                  icon: Icon(
                    _voiceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 20,
                    color: _voiceEnabled
                        ? const Color(0xFF00F5D4)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                // Toggle listening mode "Hi AURA" (V2 hands-free).
                IconButton(
                  onPressed: _isTyping ? null : _toggleListenMode,
                  tooltip: _listenMode
                      ? 'Mode dengar: aktif'
                      : 'Mode dengar "Hi AURA"',
                  icon: Icon(
                    _listenMode
                        ? Icons.sensors_rounded
                        : Icons.sensors_off_rounded,
                    size: 20,
                    color: _listenMode
                        ? const Color(0xFF8B5CF6)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                IconButton(
                  onPressed: _isTyping ? null : _newConversation,
                  tooltip: 'Percakapan baru',
                  icon: Icon(
                    Icons.add_comment_outlined,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          ),

          // 3. MESSAGE TIMELINE
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _messages.length + (_isWaitingResponse ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx == _messages.length && _isWaitingResponse) {
                  return AuraThinkingBubble(
                    isDark: isDark,
                    statusLabel: _statusLabel,
                  );
                }
                final msg = _messages[idx];
                return _buildMessageItem(msg, isDark);
              },
            ),
          ),

          // 3b. MEMORY CHIPS — fakta yang diingat AURA (ketuk untuk lupakan)
          if (_memoryChips.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _memoryChips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _memoryChips[i];
                  return GestureDetector(
                    onTap: () => _forgetFact(f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6)
                            .withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.psychology_alt_rounded,
                            size: 13,
                            color: Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'AURA ingat: ${f.label} ${f.value}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF4C1D95),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 4. QUICK SUGGESTION CHIPS
          Container(
            height: 38,
            margin: const EdgeInsets.only(top: 2, bottom: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return GestureDetector(
                  onTap: () => _handleSend(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131A29)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF00F5D4).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4b. LIVE TRANSCRIPT — tampilkan ucapan yang sedang dikenali.
          if (_micListening)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mic_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _partialText.isEmpty
                          ? (_listenMode
                                ? 'Mendengarkan… ucapkan "Hi AURA"'
                                : 'Mendengarkan…')
                          : _partialText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontStyle: _partialText.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 5. INPUT BAR WITH SAFE AREA AWARENESS
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? 8 : 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D121D) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0x1FFFFFFF)
                        : const Color(0x0F000000),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161F2E)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x28FFFFFF)
                              : const Color(0x18000000),
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: TextField(
                          controller: _textCtrl,
                          onChanged: (val) {
                            if (val.isNotEmpty && _orbState == AuraState.idle) {
                              setState(() => _orbState = AuraState.listening);
                            } else if (val.isEmpty &&
                                _orbState == AuraState.listening) {
                              setState(() => _orbState = AuraState.idle);
                            }
                          },
                          onSubmitted: (_) => _handleSend(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            hintText: 'Tanya AURA seputar PLTS & inverter...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic push-to-talk (V1): tahan untuk bicara, lepas untuk kirim.
                  GestureDetector(
                    onTapDown: (_) => _startPushToTalk(),
                    onTapUp: (_) => _stopPushToTalk(),
                    onTapCancel: () => _stopPushToTalk(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _micListening
                            ? const Color(0xFFEF4444)
                            : (isDark
                                  ? const Color(0xFF161F2E)
                                  : const Color(0xFFE2E8F0)),
                        border: Border.all(
                          color: _micListening
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF00F5D4).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _micListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: _micListening
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569)),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ScaleOnPress(
                    onTap: _handleSend,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F5D4), Color(0xFF30D158)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F5D4)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Color(0xFF051711),
                        size: 22,
                      ),
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

  Widget _buildMessageItem(AuraMessage msg, bool isDark) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D5E56)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AURA BOT BUBBLE
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00F5D4), width: 1),
                ),
                child: const Center(
                  child: AuraLivingOrb(size: 24, showParticles: false),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111827)
                        : const Color(0xFFFFFFFF),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x24FFFFFF)
                          : const Color(0x1A000000),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.04,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // EMBEDDED ACTION CARDS
          for (final card in msg.cards)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: _buildActionCard(card.type, card.data, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    AuraActionType type,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    switch (type) {
      case AuraActionType.monitoring:
        return _CardTemplate(
          isDark: isDark,
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xFF00F5D4),
          title: data['title'] ?? 'Live Energy Telemetry',
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricChip(
                'Solar',
                data['solar'] ?? '-',
                const Color(0xFF00F5D4),
                isDark,
              ),
              _metricChip(
                'Baterai',
                data['battery'] ?? '-',
                const Color(0xFF30D158),
                isDark,
              ),
              _metricChip(
                'Beban',
                data['load'] ?? '-',
                const Color(0xFFFBBF24),
                isDark,
              ),
            ],
          ),
          btnLabel: 'Buka Live Monitoring ➔',
          onTap: () {
            Navigator.of(context).pop();
            widget.onNavigateTab?.call(2); // Tab Monitoring
          },
        );

      case AuraActionType.order:
        return _CardTemplate(
          isDark: isDark,
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFF30D158),
          title: 'Pesanan Aktif: ${data['order_id'] ?? '-'}',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['item'] ?? '-',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status: ${data['status'] ?? 'Diproses'}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF30D158),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    data['amount'] ?? '-',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF00F5D4)
                          : const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          btnLabel: 'Lihat Daftar Pesanan ➔',
          onTap: () {
            Navigator.of(context).pop();
            widget.onNavigateTab?.call(1); // Tab Orders
          },
        );

      case AuraActionType.roi:
        return _CardTemplate(
          isDark: isDark,
          icon: Icons.savings_rounded,
          iconColor: const Color(0xFFFBBF24),
          title: data['title'] ?? 'Estimasi ROI & Penghematan',
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payback Period',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    data['payback'] ?? '-',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Hemat Bulanan',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    data['saving'] ?? '-',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF30D158),
                    ),
                  ),
                ],
              ),
            ],
          ),
          btnLabel: 'Buka Kalkulator ROI ➔',
          onTap: () {
            Navigator.of(context).pop();
            widget.onNavigateTab?.call(4); // Tab ROI
          },
        );

      case AuraActionType.warranty:
        return _CardTemplate(
          isDark: isDark,
          icon: Icons.verified_user_rounded,
          iconColor: const Color(0xFF00F5D4),
          title: data['status'] ?? 'Garansi Resmi Aktif',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit: ${data['unit'] ?? '-'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'S/N: ${data['serial'] ?? '-'}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          btnLabel: 'Validasi & Scan QR Unit ➔',
          onTap: () {
            Navigator.of(context).pop();
            widget.onNavigateTab?.call(3); // Tab Warranty
          },
        );

      case AuraActionType.pendingAction:
        return _PendingActionCard(
          key: ValueKey(data['id']),
          data: data,
          isDark: isDark,
          onResolved: (text) {
            if (!mounted) return;
            setState(() {
              _messages.add(
                AuraMessage(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  text: text,
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
            });
            _scrollToBottom();
          },
        );

      case AuraActionType.insight:
        final severity = (data['severity'] ?? 'info').toString();
        final color = severity == 'critical'
            ? const Color(0xFFEF4444)
            : (severity == 'warning'
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF00F5D4));
        final icon = severity == 'critical'
            ? Icons.error_rounded
            : (severity == 'warning'
                  ? Icons.warning_amber_rounded
                  : Icons.insights_rounded);
        return _CardTemplate(
          isDark: isDark,
          icon: icon,
          iconColor: color,
          title: data['title']?.toString() ?? 'Insight Perangkat',
          body: Text(
            data['body']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
          btnLabel: 'Buka Monitoring ➔',
          onTap: () {
            Navigator.of(context).pop();
            widget.onNavigateTab?.call(2); // Tab Monitoring
          },
        );

      case AuraActionType.none:
        return const SizedBox.shrink();
    }
  }

  Widget _metricChip(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CardTemplate extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget body;
  final String btnLabel;
  final VoidCallback onTap;

  const _CardTemplate({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.btnLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
          const SizedBox(height: 10),
          ScaleOnPress(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  btnLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu konfirmasi aksi tulis AURA — dieksekusi hanya setelah user menekan Konfirmasi.
class _PendingActionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final ValueChanged<String> onResolved;

  const _PendingActionCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.onResolved,
  });

  @override
  State<_PendingActionCard> createState() => _PendingActionCardState();
}

enum _PendingState { idle, busy, confirmed, cancelled, failed }

class _PendingActionCardState extends State<_PendingActionCard> {
  _PendingState _state = _PendingState.idle;
  String _note = '';

  Future<void> _resolve(bool confirm) async {
    if (_state != _PendingState.idle) return;
    HapticFeedback.mediumImpact();
    setState(() => _state = _PendingState.busy);
    final id = widget.data['id'].toString();
    final res = confirm
        ? await AuraAiService.instance.confirmAction(id)
        : await AuraAiService.instance.cancelAction(id);
    if (!mounted) return;
    setState(() {
      _note = res.message;
      _state = !res.ok
          ? _PendingState.failed
          : (confirm ? _PendingState.confirmed : _PendingState.cancelled);
    });
    widget.onResolved(
      res.ok
          ? (confirm ? '✅ ${res.message}' : 'Baik, aksi dibatalkan.')
          : '⚠️ ${res.message}',
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFBBF24);
    final isDark = widget.isDark;
    final done = _state == _PendingState.confirmed;
    final color = done ? const Color(0xFF30D158) : accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.bolt_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  done ? 'Aksi Dijalankan' : 'Konfirmasi Aksi',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.data['summary']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          if (_state == _PendingState.idle || _state == _PendingState.busy)
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    label: 'Batal',
                    color: isDark ? Colors.white54 : Colors.black45,
                    filled: false,
                    onTap: () => _resolve(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _actionBtn(
                    label: _state == _PendingState.busy
                        ? 'Memproses…'
                        : 'Konfirmasi',
                    color: accent,
                    filled: true,
                    onTap: () => _resolve(true),
                  ),
                ),
              ],
            )
          else
            Text(
              _state == _PendingState.cancelled ? 'Dibatalkan' : _note,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _state == _PendingState.failed
                    ? const Color(0xFFEF4444)
                    : color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? const Color(0xFF1A1200) : color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget Animasi Berfikir AURA yang dinamis dan futuristik
class AuraThinkingBubble extends StatefulWidget {
  final bool isDark;
  final String
  statusLabel; // label status NYATA dari server (mis. "Membaca telemetri…")

  const AuraThinkingBubble({
    super.key,
    required this.isDark,
    this.statusLabel = '',
  });

  @override
  State<AuraThinkingBubble> createState() => _AuraThinkingBubbleState();
}

class _AuraThinkingBubbleState extends State<AuraThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  int _statusIndex = 0;
  Timer? _statusTimer;

  final List<String> _statusTexts = [
    'AURA sedang menganalisis telemetri PLTS...',
    'Menghitung efisiensi daya & kondisi baterai...',
    'Merumuskan rekomendasi cerdas untuk Anda...',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (!mounted) return;
      setState(() {
        _statusIndex = (_statusIndex + 1) % _statusTexts.length;
      });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini Living Orb Avatar with Thinking state
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: AuraLivingOrb(
                size: 26,
                state: AuraState.thinking,
                showParticles: false,
              ),
            ),
          ),

          // Thinking Bubble
          Expanded(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                final glow =
                    (math.sin(_animCtrl.value * 2 * math.pi) + 1.0) / 2.0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFF00F5D4).withValues(alpha: 0.35),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                        glow,
                      )!,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F5D4)
                            .withValues(alpha: 0.08 + glow * 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Baris 1: Bouncing Dots + AI Badge
                      Row(
                        children: [
                          _buildBouncingDots(),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F5D4)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AI THINKING',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00F5D4),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Baris 2: Animated status text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          widget.statusLabel.isNotEmpty
                              ? widget.statusLabel
                              : _statusTexts[_statusIndex],
                          key: ValueKey(
                            widget.statusLabel.isNotEmpty
                                ? widget.statusLabel
                                : 'rot_$_statusIndex',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.22;
        final phase = (_animCtrl.value - delay) % 1.0;
        final bounce = math.sin(phase * 2 * math.pi);
        final offsetY = bounce < 0 ? bounce * 4.0 : 0.0;
        final colors = [
          const Color(0xFF00F5D4),
          const Color(0xFF30D158),
          const Color(0xFF8B5CF6),
        ];

        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 5),
          transform: Matrix4.translationValues(0, offsetY, 0),
          decoration: BoxDecoration(
            color: colors[i],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: colors[i].withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
        );
      }),
    );
  }
}
