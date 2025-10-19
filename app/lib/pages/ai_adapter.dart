// lib/pages/npa_bot_chat.dart
// Встраиваемый диалог с НПА-ботом (ГОСУСЛУГИ-style)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// можно переопределить при сборке: --dart-define=BACKEND_URL=http://127.0.0.1:8010
const String kBackendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://91.132.57.66:8066',
);

const String kQueryParam = 'query';

const kChatBlue = Color(0xFF0C5EFF);
const kChatBg = Color(0xFFF2F5F9);

const List<String> kDefaultPopular = <String>[
  'все НПА 2025 года',
  'ссылка на приказ о личных делах сотрудников',
  'когда зарегистрирован приказ №847?',
];

const String kPopularKey = 'npa_bot_popular_queries'; // JSON: Map<String,int>

class _Message {
  final bool fromUser; // true = пользователь, false = бот
  final String text;
  const _Message({required this.fromUser, required this.text});
}

/// Вызов диалога
Future<void> openNpaBotDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: const _NPABotChatPanel(),
      ),
    ),
  );
}

/// Собственно панель чата (внутри диалога)
class _NPABotChatPanel extends StatefulWidget {
  const _NPABotChatPanel();

  @override
  State<_NPABotChatPanel> createState() => _NPABotChatPanelState();
}

class _NPABotChatPanelState extends State<_NPABotChatPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  final List<_Message> _messages = <_Message>[];

  Map<String, int> _popular = <String, int>{};

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPopularKey);
    if (raw == null) {
      setState(() {
        for (int i = 0; i < kDefaultPopular.length; i++) {
          _popular[kDefaultPopular[i]] = kDefaultPopular.length - i;
        }
      });
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _popular = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
        if (_popular.isEmpty) {
          for (int i = 0; i < kDefaultPopular.length; i++) {
            _popular[kDefaultPopular[i]] = kDefaultPopular.length - i;
          }
        }
      });
    } catch (_) {
      setState(() {
        for (int i = 0; i < kDefaultPopular.length; i++) {
          _popular[kDefaultPopular[i]] = kDefaultPopular.length - i;
        }
      });
    }
  }

  Future<void> _savePopular() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPopularKey, jsonEncode(_popular));
  }

  List<String> get _top3 {
    final entries = _popular.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((e) => e.key).toList();
  }

  Future<void> _bumpPopular(String q) async {
    _popular[q] = (_popular[q] ?? 0) + 1;
    await _savePopular();
    setState(() {});
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Message(fromUser: true, text: text));
      _sending = true;
      _input.clear();
    });
    _scrollDown();
    await _bumpPopular(text);

    try {
      final uri = Uri.parse('$kBackendBase/ask')
          .replace(queryParameters: {'query': text});
      final res = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final ans = (m['answer'] as String?)?.trim();
        _appendBot((ans?.isNotEmpty ?? false) ? ans! : 'Пустой ответ сервера.');
      } else {
        _appendBot('Ошибка сервера: HTTP ${res.statusCode}.');
      }
    } catch (e) {
      _appendBot('Ошибка соединения с сервером.');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollDown();
      }
    }
  }



  void _appendBot(String text) {
    setState(() {
      _messages.add(_Message(fromUser: false, text: text));
    });
  }

  Future<void> _scrollDown() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 120,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kChatBg,
      child: Column(
        children: [
          // "AppBar" диалога
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: kChatBlue, borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('НПА-бот ФТС',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFFEFF5FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Лента сообщений
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final alignEnd = m.fromUser;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!alignEnd) _avatarBot(),
                      if (!alignEnd) const SizedBox(width: 8),
                      Flexible(child: _bubble(m)),
                      if (alignEnd) const SizedBox(width: 8),
                      if (alignEnd) _avatarUser(),
                    ],
                  ),
                );
              },
            ),
          ),

          // ТОП-3 запросов
          if (_top3.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Популярные запросы', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: _top3.map((q) => _chip(q)).toList()),
                  const SizedBox(height: 4),
                  const Text('Статистика считается локально на этом устройстве.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),

          // Инпут + кнопка
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: TextField(
                      controller: _input,
                      maxLines: null,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Введите ваш запрос...',
                        isDense: true,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kChatBlue),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sending ? const Color(0xFF93C5FD) : kChatBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(_sending ? 'Отправляю…' : 'Отправить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Message m) {
    final isUser = m.fromUser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? kChatBlue : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: SelectableText(
        m.text,
        style: TextStyle(color: isUser ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _chip(String q) {
    return InkWell(
      onTap: _sending
          ? null
          : () {
        setState(() => _input.text = q);
        _send();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(q, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _avatarBot() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Icon(Icons.policy, size: 16, color: kChatBlue),
    );
  }

  Widget _avatarUser() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: kChatBlue, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.person, size: 16, color: Colors.white),
    );
  }
}
