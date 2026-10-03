import 'api_client.dart';

enum AuraActionType {
  none,
  monitoring,
  order,
  roi,
  warranty,
  pendingAction,
  insight,
}

AuraActionType auraActionTypeFrom(String? type) {
  switch (type) {
    case 'monitoring':
      return AuraActionType.monitoring;
    case 'order':
      return AuraActionType.order;
    case 'roi':
      return AuraActionType.roi;
    case 'warranty':
      return AuraActionType.warranty;
    case 'pending_action':
      return AuraActionType.pendingAction;
    case 'insight':
      return AuraActionType.insight;
    default:
      return AuraActionType.none;
  }
}

/// Jenis event streaming yang dipancarkan sendMessageStream.
enum AuraStreamKind { meta, delta, status, card, memory, done, error }

/// Satu event dari aliran AURA (SSE).
class AuraStreamEvent {
  final AuraStreamKind kind;
  final Map<String, dynamic> data;

  const AuraStreamEvent(this.kind, this.data);
}

/// Fakta memori yang diingat AURA (untuk chip).
class AuraMemoryFact {
  final String key;
  final String value;
  final String label;

  const AuraMemoryFact({
    required this.key,
    required this.value,
    required this.label,
  });
}

/// Insight proaktif perangkat.
class AuraInsight {
  final int id;
  final String type;
  final String severity; // info|warning|critical
  final String title;
  final String body;
  final bool isRead;

  const AuraInsight({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.isRead,
  });

  static AuraInsight? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as num?)?.toInt();
    if (id == null) return null;
    return AuraInsight(
      id: id,
      type: (j['type'] ?? '').toString(),
      severity: (j['severity'] ?? 'info').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      isRead: j['is_read'] == true,
    );
  }
}

/// Kartu interaktif yang dikirim server (data berasal dari tool nyata).
class AuraCard {
  final AuraActionType type;
  final Map<String, dynamic> data;

  const AuraCard(this.type, this.data);
}

class AuraMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AuraCard> cards;
  final List<String> suggestions;
  final bool offline;

  const AuraMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.cards = const [],
    this.suggestions = const [],
    this.offline = false,
  });

  AuraMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<AuraCard>? cards,
    List<String>? suggestions,
    bool? offline,
  }) {
    return AuraMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      cards: cards ?? this.cards,
      suggestions: suggestions ?? this.suggestions,
      offline: offline ?? this.offline,
    );
  }
}

class AuraActionResult {
  final bool ok;
  final String message;
  const AuraActionResult(this.ok, this.message);
}

class AuraAiService {
  static final AuraAiService instance = AuraAiService._();
  AuraAiService._();

  int? _conversationId;

  /// Mulai percakapan baru (lupa konteks server-side).
  void resetConversation() => _conversationId = null;

  /// Salam pembuka berdasarkan waktu saja — angka telemetri datang dari AURA, bukan dikarang di sini.
  String getProactiveGreeting({String? userName}) {
    final hour = DateTime.now().hour;
    final who = (userName == null || userName.isEmpty) ? '' : ', $userName';
    final String part;
    if (hour >= 5 && hour < 11) {
      part = 'Selamat pagi';
    } else if (hour >= 11 && hour < 15) {
      part = 'Selamat siang';
    } else if (hour >= 15 && hour < 18) {
      part = 'Selamat sore';
    } else {
      part = 'Selamat malam';
    }
    return '$part$who! Saya AURA. Saya bisa membaca data perangkat Anda secara langsung, '
        'mengecek pesanan & garansi, menghitung penghematan, dan menjalankan aksi atas '
        'persetujuan Anda. Mau mulai dari mana?';
  }

  Future<AuraMessage> sendMessage({required String userText}) async {
    final res = await ApiClient.instance.post('/aura/chat', {
      'message': userText,
      if (_conversationId != null) 'conversation_id': _conversationId,
    }, timeout: const Duration(seconds: 40));

    if (res.ok && res.body is Map) {
      final body = res.body as Map;
      _conversationId =
          (body['conversation_id'] as num?)?.toInt() ?? _conversationId;
      final cards = <AuraCard>[];
      for (final c in (body['cards'] as List? ?? const [])) {
        if (c is Map) {
          final type = auraActionTypeFrom(c['type'] as String?);
          if (type != AuraActionType.none) {
            cards.add(
              AuraCard(
                type,
                Map<String, dynamic>.from(c['data'] as Map? ?? {}),
              ),
            );
          }
        }
      }
      return AuraMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: (body['reply'] as String?)?.trim().isNotEmpty == true
            ? body['reply'] as String
            : 'Maaf, saya belum bisa menjawab itu.',
        isUser: false,
        timestamp: DateTime.now(),
        cards: cards,
        suggestions: [
          for (final s in (body['suggestions'] as List? ?? const []))
            s.toString(),
        ],
      );
    }

    final String msg;
    if (res.status == 401) {
      msg = 'Sesi Anda berakhir. Silakan login ulang agar AURA bisa mengakses data Anda.';
    } else if (res.status == 429) {
      msg = 'AURA sedang menerima terlalu banyak permintaan. Coba lagi sebentar lagi.';
    } else {
      msg =
          'Mode offline: AURA tidak dapat terhubung ke server saat ini, jadi saya tidak '
          'bisa membaca data Anda. Periksa koneksi lalu coba lagi.';
    }
    return AuraMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: msg,
      isUser: false,
      timestamp: DateTime.now(),
      offline: true,
    );
  }

  /// Kirim pesan via STREAMING (SSE). Memancarkan delta teks, status, kartu,
  /// memori, lalu done. Bila koneksi stream gagal SEBELUM event pertama,
  /// otomatis fallback ke sendMessage() (JSON) dan memancarkan satu done.
  Stream<AuraStreamEvent> sendMessageStream({required String userText}) async* {
    var sawAnyEvent = false;
    try {
      final stream = ApiClient.instance.postStream('/aura/chat/stream', {
        'message': userText,
        if (_conversationId != null) 'conversation_id': _conversationId,
      });

      await for (final e in stream) {
        sawAnyEvent = true;
        switch (e.event) {
          case 'meta':
            _conversationId =
                (e.data['conversation_id'] as num?)?.toInt() ?? _conversationId;
            yield AuraStreamEvent(AuraStreamKind.meta, e.data);
            break;
          case 'delta':
            yield AuraStreamEvent(AuraStreamKind.delta, e.data);
            break;
          case 'status':
            yield AuraStreamEvent(AuraStreamKind.status, e.data);
            break;
          case 'card':
            yield AuraStreamEvent(AuraStreamKind.card, e.data);
            break;
          case 'memory':
            yield AuraStreamEvent(AuraStreamKind.memory, e.data);
            break;
          case 'done':
            _conversationId =
                (e.data['conversation_id'] as num?)?.toInt() ?? _conversationId;
            yield AuraStreamEvent(AuraStreamKind.done, e.data);
            break;
          case 'error':
            yield AuraStreamEvent(AuraStreamKind.error, e.data);
            break;
          default:
            break;
        }
      }
    } catch (_) {
      // Gagal menyambung stream. Fallback hanya bila belum ada event sama sekali.
      if (sawAnyEvent) {
        yield const AuraStreamEvent(AuraStreamKind.error, {
          'message': 'Koneksi terputus di tengah jawaban.',
        });
        return;
      }
      final msg = await sendMessage(userText: userText);
      yield AuraStreamEvent(AuraStreamKind.done, {
        'reply': msg.text,
        'cards': [
          for (final c in msg.cards)
            {'type': _cardTypeName(c.type), 'data': c.data},
        ],
        'suggestions': msg.suggestions,
        'fallback': true,
      });
    }
  }

  String _cardTypeName(AuraActionType t) {
    switch (t) {
      case AuraActionType.monitoring:
        return 'monitoring';
      case AuraActionType.order:
        return 'order';
      case AuraActionType.roi:
        return 'roi';
      case AuraActionType.warranty:
        return 'warranty';
      case AuraActionType.pendingAction:
        return 'pending_action';
      case AuraActionType.insight:
        return 'insight';
      case AuraActionType.none:
        return 'none';
    }
  }

  /// Parse list kartu dari payload server menjadi AuraCard.
  List<AuraCard> parseCards(dynamic rawCards) {
    final cards = <AuraCard>[];
    for (final c in (rawCards as List? ?? const [])) {
      if (c is Map) {
        final type = auraActionTypeFrom(c['type'] as String?);
        if (type != AuraActionType.none) {
          cards.add(
            AuraCard(type, Map<String, dynamic>.from(c['data'] as Map? ?? {})),
          );
        }
      }
    }
    return cards;
  }

  /// Lanjutkan percakapan terakhir bila < 30 menit; selain itu mulai baru.
  /// Mengembalikan daftar pesan historis (kosong bila mulai baru).
  Future<List<AuraMessage>> resumeOrStart() async {
    final res = await ApiClient.instance.get('/aura/conversations?limit=1');
    if (!res.ok || res.body is! Map) {
      resetConversation();
      return const [];
    }
    final list = (res.body as Map)['conversations'] as List? ?? const [];
    if (list.isEmpty) {
      resetConversation();
      return const [];
    }
    final conv = list.first as Map;
    final updatedAt = DateTime.tryParse((conv['updated_at'] ?? '').toString());
    if (updatedAt == null ||
        DateTime.now().toUtc().difference(updatedAt.toUtc()).inMinutes > 30) {
      resetConversation();
      return const [];
    }

    final id = (conv['id'] as num?)?.toInt();
    if (id == null) {
      resetConversation();
      return const [];
    }
    _conversationId = id;

    final full = await ApiClient.instance.get('/aura/conversations/$id');
    if (!full.ok || full.body is! Map) return const [];
    final msgs = (full.body as Map)['messages'] as List? ?? const [];
    return [
      for (final m in msgs)
        if (m is Map)
          AuraMessage(
            id: 'hist_${m['created_at'] ?? DateTime.now().microsecondsSinceEpoch}_${msgs.indexOf(m)}',
            text: (m['text'] ?? '').toString(),
            isUser: (m['role'] ?? '') == 'user',
            timestamp:
                DateTime.tryParse((m['created_at'] ?? '').toString()) ??
                DateTime.now(),
            cards: parseCards(m['cards']),
          ),
    ];
  }

  /// Insight proaktif milik pengguna.
  Future<List<AuraInsight>> fetchInsights({
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final q = '/aura/insights?limit=$limit${unreadOnly ? '&unread=1' : ''}';
    final res = await ApiClient.instance.get(q);
    if (!res.ok || res.body is! Map) return const [];
    final rows = (res.body as Map)['insights'] as List? ?? const [];
    final out = <AuraInsight>[];
    for (final r in rows) {
      if (r is Map) {
        final parsed = AuraInsight.fromJson(Map<String, dynamic>.from(r));
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }

  Future<void> markInsightRead(int id) async {
    await ApiClient.instance.post('/aura/insights/$id/read', {});
  }

  /// Daftar fakta memori milik pengguna.
  Future<List<AuraMemoryFact>> fetchMemory() async {
    final res = await ApiClient.instance.get('/aura/memory');
    if (!res.ok || res.body is! Map) return const [];
    final rows = (res.body as Map)['memory'] as List? ?? const [];
    return [
      for (final r in rows)
        if (r is Map)
          AuraMemoryFact(
            key: (r['key'] ?? '').toString(),
            value: (r['value'] ?? '').toString(),
            label: (r['label'] ?? r['key'] ?? '').toString(),
          ),
    ];
  }

  Future<bool> forget(String key) async {
    final res = await ApiClient.instance.delete('/aura/memory/$key');
    return res.ok;
  }

  Future<AuraActionResult> confirmAction(String id) => _resolve(id, 'confirm');
  Future<AuraActionResult> cancelAction(String id) => _resolve(id, 'cancel');

  Future<AuraActionResult> _resolve(String id, String verb) async {
    final res = await ApiClient.instance.post('/aura/actions/$id/$verb', {});
    final body = res.body;
    final message = body is Map && body['message'] != null
        ? body['message'].toString()
        : (res.ok ? 'Berhasil.' : 'Gagal memproses aksi.');
    return AuraActionResult(res.ok, message);
  }
}
