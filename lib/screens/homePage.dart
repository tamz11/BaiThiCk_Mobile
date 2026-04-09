import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../carouselSlider.dart';
import '../firestore-data/notificationList.dart';
import '../firestore-data/searchList.dart';
import '../firestore-data/topRatedList.dart';
import '../model/cardModel.dart';
import 'exploreList.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _fallbackLocationLabel = 'Hà Nội, Việt Nam';
  static const double _fallbackLatitude = 21.0285;
  static const double _fallbackLongitude = 105.8542;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _doctorName = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<_ChatMessage> _chatMessages = [];
  final List<String> _quickPrompts = const [
    'Tôi đau ngực, hồi hộp',
    'Tôi đau răng và ê buốt',
    'Mắt mờ, nhức mắt',
    'Đau lưng, đau khớp gối',
    'Bé sốt và ho 2 ngày',
  ];

  static const Color _chatPrimary = Color(0xFF2A4BA0);
  static const Duration _chatNetworkTimeout = Duration(seconds: 6);
  bool _chatSessionLoaded = false;
  bool _isHistoryLoading = false;
  bool _isBotTyping = false;
  bool _loadingLocation = false;
  String _locationLabel = _fallbackLocationLabel;
  String _temperatureLabel = '--°C';
  String _weatherCondition = 'cloudy';

  Widget _notificationBell() {
    final user = _auth.currentUser;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : _firestore
                .collection('notification_history')
                .doc(user.uid)
                .collection('messages')
                .where('read', isEqualTo: false)
                .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();

        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 18,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_active),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 1.2,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      badgeText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationList()),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _chatMessages.add(_welcomeMessage());
    _loadDeviceLocationAndWeather();
  }

  @override
  void dispose() {
    _doctorName.dispose();
    _chatController.dispose();
    super.dispose();
  }

  _ChatMessage _welcomeMessage() {
    return const _ChatMessage(
      text:
          'Xin chào, tôi là trợ lý tư vấn. Bạn mô tả triệu chứng để tôi gợi ý chuyên khoa phù hợp nhé.',
      isUser: false,
    );
  }

  String? _normalizeSpecialty(String? raw) {
    if (raw == null) {
      return null;
    }
    final text = raw.toLowerCase();
    if (text.contains('tim')) {
      return 'Tim mạch';
    }
    if (text.contains('răng') || text.contains('hàm') || text.contains('nha')) {
      return 'Răng hàm mặt';
    }
    if (text.contains('mắt')) {
      return 'Mắt';
    }
    if (text.contains('xương') ||
        text.contains('khớp') ||
        text.contains('chỉnh')) {
      return 'Cơ xương khớp';
    }
    if (text.contains('nhi') || text.contains('trẻ') || text.contains('bé')) {
      return 'Nhi khoa';
    }
    if (text.contains('nội')) {
      return 'Nội tổng quát';
    }
    return null;
  }

  Future<void> _loadChatHistory(
    void Function(void Function()) sheetSetState,
  ) async {
    if (_chatSessionLoaded || _isHistoryLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      sheetSetState(() {
        _chatMessages
          ..clear()
          ..add(_welcomeMessage());
        _chatSessionLoaded = true;
      });
      return;
    }

    _isHistoryLoading = true;
    try {
      final snap = await _firestore
          .collection('chat_history')
          .doc(user.uid)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(60)
          .get();

      final loaded = snap.docs
          .map((doc) {
            final data = doc.data();
            final alternativesRaw = data['alternatives'];
            final alternatives = alternativesRaw is List
                ? alternativesRaw.map((e) => e.toString()).toList()
                : <String>[];
            return _ChatMessage(
              text: (data['text'] ?? '').toString(),
              isUser: (data['isUser'] ?? false) == true,
              specialty: _normalizeSpecialty(data['specialty']?.toString()),
              alternatives: alternatives,
              urgency: data['urgency']?.toString(),
            );
          })
          .where((m) => m.text.trim().isNotEmpty)
          .toList();

      sheetSetState(() {
        _chatMessages
          ..clear()
          ..addAll(loaded.isEmpty ? [_welcomeMessage()] : loaded);
        _chatSessionLoaded = true;
      });
    } catch (_) {
      sheetSetState(() {
        if (_chatMessages.isEmpty) {
          _chatMessages.add(_welcomeMessage());
        }
        _chatSessionLoaded = true;
      });
    } finally {
      _isHistoryLoading = false;
    }
  }

  Future<void> _saveMessageToHistory(_ChatMessage message) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('chat_history')
        .doc(user.uid)
        .collection('messages')
        .add({
          'text': message.text,
          'isUser': message.isUser,
          'specialty': message.specialty,
          'alternatives': message.alternatives,
          'urgency': message.urgency,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _clearChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final messagesRef = _firestore
        .collection('chat_history')
        .doc(user.uid)
        .collection('messages');
    final snap = await messagesRef.get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  _ChatAdvice? _analyzeSymptoms(String message) {
    final text = _normalizeVietnamese(message);
    final scores = <String, int>{
      'Tim mạch': 0,
      'Răng hàm mặt': 0,
      'Mắt': 0,
      'Cơ xương khớp': 0,
      'Nhi khoa': 0,
      'Nội tổng quát': 0,
    };

    void bump(List<String> keywords, String specialty, [int value = 2]) {
      for (final key in keywords) {
        if (text.contains(key)) {
          scores[specialty] = (scores[specialty] ?? 0) + value;
        }
      }
    }

    bump(
      ['dau nguc', 'hoi hop', 'tim dap', 'kho tho', 'huyet ap', 'tuc nguc'],
      'Tim mạch',
      3,
    );
    bump(
      ['rang', 'nuou', 'sau rang', 'ham', 'loi', 'viem loi'],
      'Răng hàm mặt',
      3,
    );
    bump(['mat', 'mo', 'can', 'nhin', 'do mat', 'choi mat'], 'Mắt', 3);
    bump(
      ['dau lung', 'xuong', 'khop', 'goi', 'vai gay', 'trat'],
      'Cơ xương khớp',
      3,
    );
    bump(['tre', 'be', 'sot', 'ho', 'so mui', 'tieu chay'], 'Nhi khoa', 2);
    bump(
      ['met', 'chong mat', 'buon non', 'dau dau', 'mat ngu'],
      'Nội tổng quát',
      1,
    );

    final ordered = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = ordered.first;
    if (top.value == 0) return null;

    String urgency = 'Ưu tiên thường';
    String note = 'Bạn có thể đặt lịch khám sớm trong 1-3 ngày tới.';
    final emergencySignals = [
      'kho tho nhieu',
      'dau nguc du doi',
      'ngat',
      'co giat',
      'liet',
    ];
    final urgentSignals = [
      'dau du doi',
      'sot cao',
      'non nhieu',
      'keo dai',
      'nang dan',
    ];
    if (emergencySignals.any(text.contains)) {
      urgency = 'Khẩn cấp';
      note = 'Bạn nên đến cơ sở y tế gần nhất hoặc cấp cứu ngay.';
    } else if (urgentSignals.any(text.contains)) {
      urgency = 'Ưu tiên cao';
      note = 'Bạn nên đi khám trong ngày để được đánh giá trực tiếp.';
    }

    final alternatives = ordered
        .where((e) => e.key != top.key && e.value > 0)
        .take(2)
        .map((e) => e.key)
        .toList();

    return _ChatAdvice(
      primarySpecialty: top.key,
      alternatives: alternatives,
      urgency: urgency,
      note: note,
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final word in keywords) {
      if (text.contains(word)) return true;
    }
    return false;
  }

  String _normalizeVietnamese(String input) {
    final source = input.trim().toLowerCase();
    if (source.isEmpty) return '';
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final buffer = StringBuffer();
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      final idx = from.indexOf(ch);
      if (idx >= 0) {
        buffer.write(to[idx]);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _buildNaturalOfflineReply(String rawInput, _ChatAdvice? advice) {
    final text = _normalizeVietnamese(rawInput);

    if (_containsAny(text, const ['xin chao', 'chao', 'hello', 'hi'])) {
      return 'Chào bạn, mình ở đây để hỗ trợ tư vấn ban đầu. Bạn mô tả giúp mình triệu chứng đang khó chịu nhất để mình gợi ý đúng chuyên khoa nhé.';
    }

    if (_containsAny(text, const ['cam on', 'thanks', 'thank'])) {
      return 'Không có gì, rất vui được hỗ trợ bạn. Nếu cần mình có thể gợi ý thêm bác sĩ phù hợp để bạn đặt lịch luôn.';
    }

    if (advice == null) {
      return 'Mình chưa đủ thông tin để gợi ý chính xác. Bạn cho mình thêm 3 ý: đau ở đâu, kéo dài bao lâu, và mức độ từ 1-10 nhé.';
    }

    final primary = advice.primarySpecialty;
    final urgency = advice.urgency;
    final alternatives = advice.alternatives;
    final altText = alternatives.isNotEmpty
        ? ' Nếu cần, bạn cũng có thể cân nhắc ${alternatives.join(' hoặc ')}.'
        : '';

    if (urgency == 'Khẩn cấp') {
      return 'Với mô tả hiện tại, mình ưu tiên chuyên khoa $primary và mức độ đang ở nhóm khẩn cấp. ${advice.note}$altText';
    }

    if (urgency == 'Ưu tiên cao') {
      return 'Mình nghiêng về chuyên khoa $primary. Triệu chứng của bạn ở mức ưu tiên cao, nên đi khám trong ngày để bác sĩ đánh giá trực tiếp. $altText';
    }

    return 'Dựa trên triệu chứng bạn mô tả, chuyên khoa phù hợp nhất hiện tại là $primary. ${advice.note}$altText';
  }

  bool _shouldUseOnlineLookup(String normalizedInput, _ChatAdvice? advice) {
    if (advice == null) return true;
    if (normalizedInput.contains('?')) return true;
    const cues = <String>[
      'la gi',
      'nguyen nhan',
      'trieu chung',
      'dieu tri',
      'phong ngua',
      'thuoc',
      'can kieng',
      'an gi',
      'co nguy hiem khong',
    ];
    return cues.any(normalizedInput.contains);
  }

  Future<String?> _fetchOnlineHealthSnippet(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    try {
      final uri = Uri.https('api.duckduckgo.com', '/', {
        'q': 'suc khoe $clean',
        'format': 'json',
        'no_html': '1',
        'no_redirect': '1',
        'skip_disambig': '1',
      });

      final response = await http.get(uri).timeout(_chatNetworkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final map = jsonDecode(response.body);
      if (map is! Map<String, dynamic>) return null;

      final abstractText = (map['AbstractText'] ?? '').toString().trim();
      if (abstractText.isNotEmpty) {
        return abstractText;
      }

      final related = map['RelatedTopics'];
      if (related is List) {
        for (final item in related) {
          if (item is Map<String, dynamic>) {
            final text = (item['Text'] ?? '').toString().trim();
            if (text.isNotEmpty) return text;
            final nested = item['Topics'];
            if (nested is List) {
              for (final n in nested) {
                if (n is Map<String, dynamic>) {
                  final nestedText = (n['Text'] ?? '').toString().trim();
                  if (nestedText.isNotEmpty) return nestedText;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _buildSmartReply({
    required String userInput,
    required _ChatAdvice? advice,
    required String? onlineSnippet,
  }) {
    final offline = _buildNaturalOfflineReply(userInput, advice);
    if (onlineSnippet == null || onlineSnippet.isEmpty) {
      return '$offline\n\nMẹo: bạn có thể hỏi rõ hơn theo mẫu “nguyên nhân, dấu hiệu cảnh báo, khi nào cần đi khám ngay” để mình tư vấn sát hơn.';
    }

    final compactOnline = onlineSnippet.length > 420
        ? '${onlineSnippet.substring(0, 420)}...'
        : onlineSnippet;

    return '$offline\n\nTham khảo thêm từ nguồn online:\n$compactOnline\n\nLưu ý: thông tin này chỉ để tham khảo, không thay thế chẩn đoán trực tiếp từ bác sĩ.';
  }

  Future<void> _sendChatMessage(
    void Function(void Function()) sheetSetState,
  ) async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final userMessage = _ChatMessage(text: text, isUser: true);
    _chatController.clear();
    sheetSetState(() {
      _chatMessages.add(userMessage);
      _isBotTyping = true;
    });
    await _saveMessageToHistory(userMessage);

    final advice = _analyzeSymptoms(text);
    final normalized = _normalizeVietnamese(text);
    String? onlineSnippet;
    if (_shouldUseOnlineLookup(normalized, advice)) {
      onlineSnippet = await _fetchOnlineHealthSnippet(text);
    }
    final botReply = _buildSmartReply(
      userInput: text,
      advice: advice,
      onlineSnippet: onlineSnippet,
    );
    final botMessage = _ChatMessage(
      text: botReply,
      isUser: false,
      specialty: advice?.primarySpecialty,
      alternatives: advice?.alternatives ?? const [],
      urgency: advice?.urgency,
    );

    sheetSetState(() {
      _chatMessages.add(botMessage);
      _isBotTyping = false;
    });
    await _saveMessageToHistory(botMessage);
  }

  void _openChatBot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            _loadChatHistory(sheetSetState);
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _chatPrimary,
                            child: Icon(
                              Icons.support_agent_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Tư vấn chọn chuyên khoa',
                            style: GoogleFonts.lato(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Xóa chat',
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () async {
                              await _clearChatHistory();
                              sheetSetState(() {
                                _chatMessages
                                  ..clear()
                                  ..add(_welcomeMessage());
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _quickPrompts.length,
                        separatorBuilder: (_, separatorIndex) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final prompt = _quickPrompts[index];
                          return ActionChip(
                            label: Text(
                              prompt,
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () async {
                              _chatController.text = prompt;
                              await _sendChatMessage(sheetSetState);
                            },
                            backgroundColor: const Color(0xFFEAF1FF),
                            side: const BorderSide(color: Color(0xFFBBD0FF)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount:
                            _chatMessages.length + (_isBotTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isBotTyping && index == _chatMessages.length) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Đang tư vấn...'),
                                  ],
                                ),
                              ),
                            );
                          }

                          final item = _chatMessages[index];
                          return Align(
                            alignment: item.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                color: item.isUser
                                    ? _chatPrimary
                                    : const Color(0xFFEAF1FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.text,
                                    style: GoogleFonts.lato(
                                      fontSize: 14,
                                      color: item.isUser
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!item.isUser && item.urgency != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _urgencyBg(item.urgency!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.urgency!,
                                        style: GoogleFonts.lato(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _urgencyText(item.urgency!),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!item.isUser &&
                                      item.specialty != null) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 34,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: _chatPrimary,
                                          ),
                                          foregroundColor: _chatPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            this.context,
                                            MaterialPageRoute(
                                              builder: (_) => ExploreList(
                                                type: item.specialty!,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Xem bác sĩ ${item.specialty}',
                                          style: GoogleFonts.lato(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!item.isUser &&
                                      item.alternatives.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Chuyên khoa có thể cân nhắc: ${item.alternatives.join(', ')}',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        MediaQuery.of(context).viewInsets.bottom + 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) async =>
                                  _sendChatMessage(sheetSetState),
                              decoration: InputDecoration(
                                hintText: 'Nhập triệu chứng của bạn...',
                                hintStyle: GoogleFonts.lato(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: _chatPrimary,
                            child: IconButton(
                              onPressed: () async =>
                                  _sendChatMessage(sheetSetState),
                              icon: Icon(
                                Icons.send_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _message() {
    final now = DateTime.now();
    final hour = int.parse(DateFormat('kk').format(now));
    if (hour >= 5 && hour < 12) return 'Chào buổi sáng';
    if (hour >= 12 && hour <= 17) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  Future<void> _loadDeviceLocationAndWeather() async {
    if (_loadingLocation) return;
    setState(() {
      _loadingLocation = true;
    });

    try {
      final weather = await _fetchCurrentWeather(
        latitude: _fallbackLatitude,
        longitude: _fallbackLongitude,
      );
      if (!mounted) return;
      setState(() {
        _locationLabel = _fallbackLocationLabel;
        _temperatureLabel = weather?.temperatureLabel ?? '--°C';
        _weatherCondition = weather?.condition ?? 'cloudy';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationLabel = _fallbackLocationLabel;
        _temperatureLabel = '--°C';
        _weatherCondition = 'cloudy';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<_WeatherSnapshot?> _fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final current = map['current'];
      if (current is Map<String, dynamic>) {
        final rawTemp = current['temperature_2m'];
        if (rawTemp is num) {
          final weatherCode = current['weather_code'];
          return _WeatherSnapshot(
            temperatureLabel: '${rawTemp.round()}°C',
            condition: _mapConditionFromOpenMeteoCode(weatherCode),
          );
        }
      }

      final currentWeather = map['current_weather'];
      if (currentWeather is Map<String, dynamic>) {
        final rawTemp = currentWeather['temperature'];
        if (rawTemp is num) {
          final weatherCode = currentWeather['weathercode'];
          return _WeatherSnapshot(
            temperatureLabel: '${rawTemp.round()}°C',
            condition: _mapConditionFromOpenMeteoCode(weatherCode),
          );
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _mapConditionFromOpenMeteoCode(Object? codeRaw) {
    final code = codeRaw is num ? codeRaw.toInt() : -1;
    if (code == 0) return 'sunny';
    if (code >= 1 && code <= 3) return 'cloudy';
    if (code == 45 || code == 48) return 'cloudy';
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'rainy';
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return 'snow';
    }
    if (code == 95 || code == 96 || code == 99) return 'storm';
    return 'cloudy';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: scheme.surface,
        elevation: 0,
        toolbarHeight: 82,
        titleSpacing: 0,
        title: Container(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _message(),
                      style: GoogleFonts.lato(
                        color: scheme.onSurfaceVariant,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _notificationBell(),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lato(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _weatherIconForCondition(_weatherCondition),
                        size: 14,
                        color: _weatherIconColor(_weatherCondition),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _temperatureLabel,
                        style: GoogleFonts.lato(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        padding: EdgeInsets.zero,
                        splashRadius: 12,
                        iconSize: 13,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        onPressed: _loadingLocation
                            ? null
                            : () {
                                _loadDeviceLocationAndWeather();
                              },
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      body: SafeArea(
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (overscroll) {
            overscroll.disallowIndicator();
            return true;
          },
          child: ListView(
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            children: <Widget>[
              Column(
                children: [
                  const SizedBox(height: 18),
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20, bottom: 20),
                    child: Text(
                      'Hãy tìm bác sĩ\nphù hợp với bạn',
                      style: GoogleFonts.lato(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                    child: TextFormField(
                      textInputAction: TextInputAction.search,
                      controller: _doctorName,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(
                          left: 20,
                          top: 10,
                          bottom: 10,
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15.0)),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        hintText: 'Tìm bác sĩ',
                        hintStyle: GoogleFonts.lato(
                          color: Colors.black26,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        suffixIcon: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[900]?.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            iconSize: 20,
                            splashRadius: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              final value = _doctorName.text.trim();
                              if (value.isEmpty) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SearchList(searchKey: value),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      onFieldSubmitted: (value) {
                        final key = value.trim();
                        if (key.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchList(searchKey: key),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 23, bottom: 10),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chúng tôi luôn đồng hành cùng bạn',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: const Carouselslider(),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 20),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chuyên khoa',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.only(top: 14),
                    child: ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 14),
                          height: 150,
                          width: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Color(cards[index].cardBackground),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.black45
                                    : Colors.grey[400]!,
                                blurRadius: 4.0,
                                spreadRadius: 0.0,
                                offset: const Offset(3, 3),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ExploreList(type: cards[index].doctor),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 16),
                                CircleAvatar(
                                  backgroundColor: scheme.surface,
                                  radius: 29,
                                  child: Icon(
                                    cards[index].cardIcon,
                                    size: 26,
                                    color: Color(cards[index].cardBackground),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  alignment: Alignment.bottomCenter,
                                  child: Text(
                                    cards[index].doctor,
                                    style: GoogleFonts.lato(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.only(left: 20),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bác sĩ nổi bật',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.lightBlue[300]
                            : Colors.blue[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.only(left: 15, right: 15),
                    child: TopRatedList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _openChatBot,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3562D9), Color(0xFF1B3F9A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _chatPrimary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 26,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF54E37B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _urgencyBg(String urgency) {
    if (urgency == 'Khẩn cấp') return const Color(0xFFFFE4E6);
    if (urgency == 'Ưu tiên cao') return const Color(0xFFFFF4DB);
    return const Color(0xFFE8F5E9);
  }

  Color _urgencyText(String urgency) {
    if (urgency == 'Khẩn cấp') return const Color(0xFFB42318);
    if (urgency == 'Ưu tiên cao') return const Color(0xFFB54708);
    return const Color(0xFF067647);
  }

  IconData _weatherIconForCondition(String condition) {
    switch (condition) {
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'rainy':
        return Icons.grain;
      case 'storm':
        return Icons.thunderstorm_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      default:
        return Icons.cloud_outlined;
    }
  }

  Color _weatherIconColor(String condition) {
    switch (condition) {
      case 'sunny':
        return const Color(0xFFFF9800);
      case 'rainy':
        return const Color(0xFF1E88E5);
      case 'storm':
        return const Color(0xFF5E35B1);
      case 'snow':
        return const Color(0xFF26C6DA);
      default:
        return const Color(0xFF78909C);
    }
  }
}

class _WeatherSnapshot {
  const _WeatherSnapshot({
    required this.temperatureLabel,
    required this.condition,
  });

  final String temperatureLabel;
  final String condition;
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.specialty,
    this.alternatives = const [],
    this.urgency,
  });

  final String text;
  final bool isUser;
  final String? specialty;
  final List<String> alternatives;
  final String? urgency;
}

class _ChatAdvice {
  const _ChatAdvice({
    required this.primarySpecialty,
    required this.alternatives,
    required this.urgency,
    required this.note,
  });

  final String primarySpecialty;
  final List<String> alternatives;
  final String urgency;
  final String note;
}
