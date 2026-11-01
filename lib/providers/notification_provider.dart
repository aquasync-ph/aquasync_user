import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/local_notification_service.dart';
import '../widgets/top_banner.dart';
import '../main.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationItem.fromSupabaseMap(Map<String, dynamic> map) {
    final dtStr = map['created_at'] as String?;
    final dt = dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();

    return NotificationItem(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? (map['type'] as String? ?? 'Notification'),
      message: map['message'] as String? ?? (map['body'] as String? ?? ''),
      timestamp: dt,
      isRead: map['is_read'] as bool? ?? false,
    );
  }
}

class NotificationProvider with ChangeNotifier {
  final List<NotificationItem> _items = [];
  final Set<String> _deletedNotificationIds = {};
  bool _isLoading = false;
  String? _subscribedUserId;

  List<NotificationItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> fetchNotifications() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    initRealtimeSubscription(user.id);

    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _items.clear();
      for (var map in response) {
        final item = NotificationItem.fromSupabaseMap(map);
        if (!_deletedNotificationIds.contains(item.id)) {
          _items.add(item);
        }
      }
    } catch (_) {
      // Keep existing list on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void initRealtimeSubscription(String userId) {
    if (_subscribedUserId == userId) return;
    _subscribedUserId = userId;

    SupabaseService.subscribeToCustomerNotifications(
      userId: userId,
      onNotification: (record) {
        final item = NotificationItem.fromSupabaseMap(record);
        if (!_deletedNotificationIds.contains(item.id)) {
          _items.insert(0, item);
          notifyListeners();

          // Trigger System Notification outside the app in Phone Notification Tray
          LocalNotificationService.showNotification(
            id: item.id.hashCode,
            title: item.title,
            body: item.message,
          );

          // Trigger In-App Real-Time Alert Banner
          try {
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              TopBanner.show(
                ctx,
                '🔔 ${item.title}: ${item.message}',
                isError: false,
              );
            }
          } catch (_) {}
        }
      },
    );
  }

  void addNotification(NotificationItem item) {
    if (!_deletedNotificationIds.contains(item.id)) {
      _items.insert(0, item);
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index].isRead = true;
      notifyListeners();

      try {
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead() async {
    final user = SupabaseService.currentUser;
    for (var item in _items) {
      item.isRead = true;
    }
    notifyListeners();

    if (user != null) {
      try {
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', user.id);
      } catch (_) {}
    }
  }

  Future<void> deleteNotification(String id) async {
    _deletedNotificationIds.add(id);
    _items.removeWhere((item) => item.id == id);
    notifyListeners();

    try {
      await SupabaseService.client
          .from('notifications')
          .delete()
          .eq('id', id);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    for (var item in _items) {
      _deletedNotificationIds.add(item.id);
    }
    _items.clear();
    notifyListeners();

    try {
      await SupabaseService.client
          .from('notifications')
          .delete()
          .eq('user_id', user.id);
    } catch (_) {}
  }

  void clearAll() {
    for (var item in _items) {
      _deletedNotificationIds.add(item.id);
    }
    _items.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    SupabaseService.unsubscribeCustomerNotifications();
    super.dispose();
  }
}
