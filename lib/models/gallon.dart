enum GallonStatus { borrowed, returned, available }

class Gallon {
  final String id;
  final String label;
  final GallonStatus status;
  final String condition;

  Gallon({
    required this.id,
    required this.label,
    required this.status,
    this.condition = 'Good Condition',
  });

  factory Gallon.fromSupabaseMap(Map<String, dynamic> map) {
    final statusStr = (map['status'] as String? ?? 'borrowed').toLowerCase();
    GallonStatus gStatus = GallonStatus.borrowed;
    if (statusStr.contains('return') || statusStr.contains('avail')) {
      gStatus = GallonStatus.returned;
    }

    return Gallon(
      id: map['id']?.toString() ?? (map['barcode'] as String? ?? 'GAL-0000'),
      label: map['label'] as String? ?? (map['type'] as String? ?? 'Gallon Container'),
      status: gStatus,
      condition: map['condition'] as String? ?? 'Good Condition',
    );
  }
}
