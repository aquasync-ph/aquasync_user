enum AnnouncementType {
  info,
  promo,
  warning,
}

class Announcement {
  final String id;
  final String title;
  final String message;
  final AnnouncementType type;
  final bool isActive;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isActive = true,
    required this.createdAt,
  });

  factory Announcement.fromSupabaseMap(Map<String, dynamic> map) {
    AnnouncementType parseType(String typeStr) {
      switch (typeStr.toLowerCase()) {
        case 'promo':
        case 'promotion':
          return AnnouncementType.promo;
        case 'warning':
        case 'alert':
          return AnnouncementType.warning;
        case 'info':
        case 'information':
        default:
          return AnnouncementType.info;
      }
    }

    final dateStr = map['created_at'] as String?;
    final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    return Announcement(
      id: map['id']?.toString() ?? '',
      title: map['title'] as String? ?? 'Announcement',
      message: map['message'] as String? ?? (map['body'] as String? ?? ''),
      type: parseType(map['type'] as String? ?? 'info'),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: dt,
    );
  }
}
