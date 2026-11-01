import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../widgets/top_banner.dart';

/// Helper utility for Order Support Chat Message Validations
class OrderChatValidationUtils {
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

  static bool containsEmoji(String input) {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(input);
  }

  static String sanitizeInput(String raw) {
    return raw.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Validate Support Chat Message
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

class OrderChatScreen extends StatefulWidget {
  final WaterOrder order;

  const OrderChatScreen({super.key, required this.order});

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  String? _lastSentMessage;
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToChat();
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('order_messages')
          .select()
          .eq('order_id', widget.order.id)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(List<Map<String, dynamic>>.from(response));
          _messages.sort((a, b) {
            final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
            final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
            return aTime.compareTo(bTime);
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToChat() {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      _chatChannel = SupabaseService.client
          .channel('order-chat-${widget.order.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'order_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: widget.order.id,
            ),
            callback: (payload) {
              if (payload.newRecord.isNotEmpty && mounted) {
                final newMsg = payload.newRecord;
                setState(() {
                  if (!_messages.any((m) => m['id'] == newMsg['id'])) {
                    _messages.add(newMsg);
                    _messages.sort((a, b) {
                      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
                      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
                      return aTime.compareTo(bTime);
                    });
                  }
                });

                if (newMsg['sender_id'] != user.id) {
                  final msgText = newMsg['message'] ?? 'Sent a message regarding your delivery.';
                  SupabaseService.client.from('notifications').insert({
                    'user_id': user.id,
                    'title': 'New Message from Driver',
                    'message': msgText,
                    'is_read': false,
                  }).then((_) {}).catchError((_) {});
                }
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final rawText = _controller.text;
    final err = OrderChatValidationUtils.validateMessage(rawText);
    if (err != null) {
      TopBanner.show(context, err, isError: true);
      return;
    }

    final cleanText = OrderChatValidationUtils.sanitizeInput(rawText);

    if (_lastSentMessage == cleanText) {
      TopBanner.show(context, 'You already sent this message. Please wait for a response.', isError: true);
      return;
    }

    final user = SupabaseService.currentUser;
    if (user == null) {
      TopBanner.show(context, 'You must be logged in to send a message.', isError: true);
      return;
    }

    if (widget.order.customerId.isNotEmpty && widget.order.customerId != user.id) {
      TopBanner.show(context, 'You can only send messages for your own order.', isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    _lastSentMessage = cleanText;

    try {
      final response = await SupabaseService.client
          .from('order_messages')
          .insert({
            'order_id': widget.order.id,
            'sender_id': user.id,
            'message': cleanText,
          })
          .select()
          .single();

      _controller.clear();

      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m['id'] == response['id'])) {
            _messages.add(response);
            _messages.sort((a, b) {
              final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
              final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
              return aTime.compareTo(bTime);
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        TopBanner.show(
          context,
          'Failed to send message: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Order #${widget.order.orderNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No messages yet. Send a message to your assigned driver regarding your water delivery.',
                            style: TextStyle(color: subTextColor, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final isMe = m['sender_id'] == user?.id;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF0284C7) : cardBg,
                                  borderRadius: BorderRadius.circular(16).copyWith(
                                    bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
                                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(2),
                                  ),
                                  border: isMe ? null : Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  m['message'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : textColor,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 1000,
                      enabled: !_isSending,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        hintText: 'Message driver...',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            ),
          ),
        ],
      ),
    );
  }
}
