import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../services/supabase_service.dart';

class AnnouncementProvider with ChangeNotifier {
  final List<Announcement> _announcements = [];
  bool _isLoading = false;

  List<Announcement> get announcements => [..._announcements];
  bool get isLoading => _isLoading;

  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rawList = await SupabaseService.client
          .from('announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);

      _announcements.clear();
      for (var raw in rawList) {
        _announcements.add(Announcement.fromSupabaseMap(raw));
      }
    } catch (_) {
      _announcements.clear();
    } finally {
      if (_announcements.isEmpty) {
        _announcements.addAll([
          Announcement(
            id: 'default_1',
            title: 'Station System Update',
            message: 'System Update: New purified water options and revised delivery times will be available starting April 20th. Stay tuned for details.',
            type: AnnouncementType.info,
            createdAt: DateTime.now(),
          ),
          Announcement(
            id: 'default_2',
            title: 'Free Delivery Special Promo',
            message: 'Enjoy FREE delivery on all water orders of 5 gallons or more! Use promo code FREEDELIVERY at checkout.',
            type: AnnouncementType.promo,
            createdAt: DateTime.now(),
          ),
        ]);
      }
      _isLoading = false;
      notifyListeners();
    }
  }
}
