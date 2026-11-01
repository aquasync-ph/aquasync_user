class GallonTransaction {
  final String id;
  final String gallonId;
  final String action; // borrowed, returned, lost, damaged, etc.
  final DateTime timestamp;
  final String? gallonLabel;

  GallonTransaction({
    required this.id,
    required this.gallonId,
    required this.action,
    required this.timestamp,
    this.gallonLabel,
  });

  factory GallonTransaction.fromSupabaseMap(Map<String, dynamic> map) {
    final dtStr = map['created_at'] as String?;
    final dt = dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();

    // The query might join with gallons to get the label
    final gallonData = map['gallons'] as Map<String, dynamic>?;
    final label = gallonData?['label'] as String? ?? gallonData?['type'] as String? ?? 'Gallon Container';

    return GallonTransaction(
      id: map['id']?.toString() ?? '',
      gallonId: map['gallon_id']?.toString() ?? '',
      action: map['action'] as String? ?? 'transaction',
      timestamp: dt,
      gallonLabel: label,
    );
  }
}
