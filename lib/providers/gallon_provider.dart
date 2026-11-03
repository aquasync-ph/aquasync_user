import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallon.dart';
import '../models/gallon_transaction.dart';
import '../services/supabase_service.dart';

class GallonProvider with ChangeNotifier {
  List<Gallon> _activeGallons = [];
  List<GallonTransaction> _history = [];
  bool _isLoading = false;
  String? _subscribedCustomerId;
  RealtimeChannel? _gallonChannel;

  List<Gallon> get activeGallons => [..._activeGallons];
  List<GallonTransaction> get history => [..._history];
  bool get isLoading => _isLoading;

  Future<void> fetchGallonsAndHistory() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch active gallons (borrowed or out_for_delivery)
      final gallonResponse = await SupabaseService.client
          .from('gallons')
          .select()
          .eq('customer_id', user.id)
          .eq('is_archived', false)
          .inFilter('status', ['borrowed', 'out_for_delivery']);

      _activeGallons = List<Map<String, dynamic>>.from(gallonResponse)
          .map((g) => Gallon.fromSupabaseMap(g))
          .toList();

      // 2. Fetch transaction history
      final historyResponse = await SupabaseService.client
          .from('gallon_transactions')
          .select('*, gallons(type)')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);

      _history = List<Map<String, dynamic>>.from(historyResponse)
          .map((t) => GallonTransaction.fromSupabaseMap(t))
          .toList();

      _initRealtimeSubscription(user.id);
    } catch (e) {
      debugPrint('Error fetching gallons: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setupBorrowedGallons({
    required String type,
    required String label,
    required int quantity,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return false;

    try {
      for (int i = 0; i < quantity; i++) {
        final String itemLabel = label.trim().isNotEmpty
            ? (quantity > 1 ? '${label.trim()} #${i + 1}' : label.trim())
            : (quantity > 1 ? '$type Container #${i + 1}' : '$type Container');

        final insertedGallon = await SupabaseService.client.from('gallons').insert({
          'customer_id': user.id,
          'label': itemLabel,
          'type': type,
          'status': 'borrowed',
          'condition': 'Good Condition',
        }).select().single();

        final gallonId = insertedGallon['id'];
        if (gallonId != null) {
          try {
            await SupabaseService.client.from('gallon_transactions').insert({
              'customer_id': user.id,
              'gallon_id': gallonId,
              'action': 'borrowed',
            });
          } catch (e) {
            debugPrint('Error inserting transaction: $e');
          }
        }
      }
      await fetchGallonsAndHistory();
      return true;
    } catch (e) {
      debugPrint('Error setting up borrowed gallons: $e');
      return false;
    }
  }

  void _initRealtimeSubscription(String customerId) {
    if (_subscribedCustomerId == customerId) return;
    _subscribedCustomerId = customerId;

    _gallonChannel?.unsubscribe();

    _gallonChannel = SupabaseService.client
        .channel('public:gallons:customer_id=eq.$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gallons',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            fetchGallonsAndHistory(); // Refresh both on any change
          },
        )
        .subscribe();
    
    // Also listen to transactions for history updates
    SupabaseService.client
        .channel('public:gallon_transactions:customer_id=eq.$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'gallon_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            fetchGallonsAndHistory();
          },
        )
        .subscribe();
  }

  void clearData() {
    _activeGallons.clear();
    _history.clear();
    _subscribedCustomerId = null;
    _gallonChannel?.unsubscribe();
    _gallonChannel = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _gallonChannel?.unsubscribe();
    super.dispose();
  }
}
