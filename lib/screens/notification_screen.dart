import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/top_banner.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  IconData _getNotificationIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('order') || lower.contains('delivery') || lower.contains('dispatch') || lower.contains('tracker')) {
      return Icons.local_shipping_rounded;
    }
    if (lower.contains('water') || lower.contains('refill') || lower.contains('gallon')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('promo') || lower.contains('discount') || lower.contains('offer')) {
      return Icons.local_offer_rounded;
    }
    if (lower.contains('welcome')) {
      return Icons.stars_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Color _getIconAccentColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('order') || lower.contains('delivery')) {
      return const Color(0xFF10B981); // Emerald green
    }
    if (lower.contains('promo') || lower.contains('discount')) {
      return const Color(0xFFF59E0B); // Amber
    }
    return const Color(0xFF0284C7); // Aqua blue
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final items = notificationProvider.items;
    final unreadCount = notificationProvider.unreadCount;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const Text('Notifications'),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount NEW',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notificationProvider.markAllAsRead();
                },
                icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF0284C7)),
                label: const Text(
                  'Mark Read',
                  style: TextStyle(
                    color: Color(0xFF0284C7),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final confirm = await SweetAlert.showConfirm(
                  context,
                  title: 'Delete All',
                  message: 'Are you sure you want to delete all notifications?',
                  confirmText: 'Delete',
                  cancelText: 'Cancel',
                  isDanger: true,
                );

                if (confirm == true) {
                  notificationProvider.deleteAll();
                }
              },
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              tooltip: 'Delete All',
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_off_rounded,
                        size: 56,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are all caught up! Updates regarding your water orders and station promos will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subTextColor, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final iconData = _getNotificationIcon(item.title);
                final accentColor = _getIconAccentColor(item.title);

                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    HapticFeedback.lightImpact();
                    notificationProvider.deleteNotification(item.id);
                  },
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: item.isRead
                          ? cardBg
                          : (isDark ? const Color(0xFF0F223D) : const Color(0xFFF0F9FF)),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: item.isRead
                            ? borderColor
                            : const Color(0xFF0284C7).withValues(alpha: 0.4),
                        width: item.isRead ? 1.0 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.isRead
                              ? Colors.black.withValues(alpha: 0.02)
                              : const Color(0xFF0284C7).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          notificationProvider.markAsRead(item.id);

                          // Redirect logic based on notification type & content
                          final lowerTitle = item.title.toLowerCase();
                          final lowerMessage = item.message.toLowerCase();

                          // 1. Chat / Driver / Rider Message Notification -> Chat Tab (Tab 3)
                          bool isChatRelated = lowerTitle.contains('message') || 
                                               lowerTitle.contains('chat') || 
                                               lowerTitle.contains('rider') || 
                                               lowerTitle.contains('driver') ||
                                               lowerMessage.contains('message') ||
                                               lowerMessage.contains('chat');

                          if (isChatRelated) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false, arguments: 3);
                            return;
                          }

                          // 2. Gallon / Container Inventory Notification -> Gallons Tab (Tab 2)
                          bool isGallonRelated = lowerTitle.contains('gallon') || 
                                                 lowerTitle.contains('container') || 
                                                 lowerTitle.contains('inventory') || 
                                                 lowerMessage.contains('gallon') || 
                                                 lowerMessage.contains('container');

                          if (isGallonRelated) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false, arguments: 2);
                            return;
                          }

                          // 3. Profile / Settings Notification -> Profile Tab (Tab 4)
                          bool isProfileRelated = lowerTitle.contains('profile') || 
                                                  lowerTitle.contains('account') || 
                                                  lowerTitle.contains('address') || 
                                                  lowerTitle.contains('settings');

                          if (isProfileRelated) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false, arguments: 4);
                            return;
                          }

                          // 4. Order / Delivery Related Notification -> Tracker Screen or History Tab (Tab 1)
                          bool isOrderRelated = lowerTitle.contains('order') || 
                                                lowerTitle.contains('delivery') || 
                                                lowerTitle.contains('dispatch') || 
                                                lowerTitle.contains('tracker') || 
                                                lowerTitle.contains('placed') || 
                                                lowerTitle.contains('confirmed') || 
                                                lowerTitle.contains('assigned') || 
                                                lowerTitle.contains('accepted') ||
                                                lowerMessage.contains('order') ||
                                                lowerMessage.contains('delivery');

                          if (isOrderRelated) {
                            bool isCompletedOrCancelled = 
                                lowerTitle.contains('completed') || 
                                lowerTitle.contains('cancelled') || 
                                lowerTitle.contains('canceled') || 
                                lowerTitle.contains('delivered') ||
                                lowerMessage.contains('completed') ||
                                lowerMessage.contains('cancelled') ||
                                lowerMessage.contains('canceled') ||
                                lowerMessage.contains('delivered');

                            if (isCompletedOrCancelled) {
                              // Send to Order History Tab (Tab 1)
                              Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false, arguments: 1);
                            } else {
                              // Active order -> Send to Live Tracker Screen
                              Navigator.of(context).pushNamed('/tracker');
                            }
                            return;
                          }

                          // 5. Default / Promos -> Home Tab (Tab 0)
                          Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false, arguments: 0);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Accent Icon Badge
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  iconData,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Content Body
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: item.isRead ? FontWeight.bold : FontWeight.w800,
                                              color: textColor,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimeAgo(item.timestamp),
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Unread Indicator Pulse Dot
                              if (!item.isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
