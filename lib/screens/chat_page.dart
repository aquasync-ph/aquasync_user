import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/top_banner.dart';

/// Helper utility for Chat Message Validations
class ChatValidationUtils {
  static final List<String> _inappropriateWords = [
    'tangina',
    'gago',
    'bobo',
    'tarantado',
    'ulol',
    'putangina',
    'pUTA',
    'bitch',
    'fuck',
    'shit',
    'asshole',
    'bastardo',
  ];

  static String sanitizeInput(String raw) {
    return raw.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Validate Chat Message Text
  static String? validateMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Message cannot be empty.';
    }
    final clean = sanitizeInput(raw);
    if (clean.isEmpty) {
      return 'Message cannot be empty or contain only spaces.';
    }
    if (clean.length > 1000) {
      return 'Message must not exceed 1000 characters.';
    }

    final lower = clean.toLowerCase();
    for (var word in _inappropriateWords) {
      if (lower.contains(word)) {
        return 'Please maintain polite and respectful language in chat.';
      }
    }

    return null;
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hello! Welcome to AquaBot Customer Support. How can I help you today?', 'isBot': true, 'time': '10:00 AM'},
  ];
  final TextEditingController _inputController = TextEditingController();
  bool _isTyping = false;
  bool _isSending = false;
  String? _lastSentMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addMessage(String text, bool isBot) {
    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _messages.add({'text': text, 'isBot': isBot, 'time': timeStr});
    });
  }

  void _handleSend() {
    if (_isSending) return;

    final rawText = _inputController.text;
    final err = ChatValidationUtils.validateMessage(rawText);
    if (err != null) {
      TopBanner.show(context, err, isError: true);
      return;
    }

    final cleanText = ChatValidationUtils.sanitizeInput(rawText);

    // Prevent duplicate consecutive messages
    if (_lastSentMessage == cleanText) {
      TopBanner.show(context, 'You already sent this message. Please wait for support response.', isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    _lastSentMessage = cleanText;
    _inputController.clear();

    _handleQuickReply(cleanText);
  }

  void _handleQuickReply(String reply) {
    _addMessage(reply, false);
    
    setState(() {
      _isTyping = true;
      _isSending = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isSending = false;
      });
      String botResponse = '';
      if (reply == 'Delivery') {
        botResponse = 'Delivery Hours:\n8:00 AM – 6:00 PM daily.\nAverage delivery time is 20–45 minutes.';
      } else if (reply == 'Business Hours') {
        botResponse = 'Water refilling stations operate daily from 7:00 AM to 7:00 PM.';
      } else if (reply == 'Prices') {
        botResponse = 'Water Refill Prices:\n• Purified Water: ₱30 / gallon\n• Mineral Water: ₱35 / gallon';
      } else {
        botResponse = 'Thank you for reaching out regarding "$reply". Our customer support team will assist you shortly.';
      }
      _addMessage(botResponse, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0F2573),
              child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AquaBot Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Online', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final bool isBot = m['isBot'];
                return Align(
                  alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      gradient: isBot
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF0F2573), Color(0xFF266CA9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isBot ? cardBg : null,
                      borderRadius: BorderRadius.circular(18).copyWith(
                        topLeft: isBot ? const Radius.circular(4) : const Radius.circular(18),
                        topRight: isBot ? const Radius.circular(18) : const Radius.circular(4),
                      ),
                      border: isBot ? Border.all(color: borderColor, width: 1.2) : null,
                      boxShadow: [
                        BoxShadow(
                          color: isBot
                              ? Colors.black.withValues(alpha: 0.02)
                              : const Color(0xFF0F2573).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['text'],
                          style: TextStyle(
                            color: isBot ? textColor : Colors.white,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: isBot ? FontWeight.w500 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m['time'] ?? '',
                          style: TextStyle(
                            color: isBot ? subTextColor : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'AquaBot is typing...',
                    style: TextStyle(fontSize: 12, color: subTextColor, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: subTextColor),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _quickReplyChip('Orders', isDark),
                        _quickReplyChip('Delivery', isDark),
                        _quickReplyChip('Prices', isDark),
                        _quickReplyChip('Business Hours', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          maxLength: 1000,
                          enabled: !_isSending,
                          onSubmitted: (_) => _handleSend(),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending ? null : _handleSend,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2573),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickReplyChip(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: _isSending ? null : () => _handleQuickReply(label),
        backgroundColor: const Color(0xFF266CA9).withValues(alpha: 0.12),
        side: BorderSide(color: const Color(0xFF266CA9).withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(color: Color(0xFF0F2573), fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
