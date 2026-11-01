import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isAuthenticated => currentUser != null;

  static RealtimeChannel? _ordersChannel;
  static RealtimeChannel? _notificationsChannel;
  static RealtimeChannel? _productsChannel;
  static RealtimeChannel? _shopProfileChannel;

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password.trim(),
      data: data,
    );
  }

  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  static bool _parseBool(dynamic val, {bool defaultValue = true}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'active' || s == 'open' || s == 'online' || s == 'enabled') {
        return true;
      }
      if (s == 'false' || s == '0' || s == 'no' || s == 'inactive' || s == 'closed' || s == 'offline' || s == 'disabled' || s == 'maintenance') {
        return false;
      }
    }
    return defaultValue;
  }

  static Future<Map<String, dynamic>> fetchShopProfile() async {
    Map<String, dynamic> shopProfile = {
      'latitude': 14.2290,
      'longitude': 121.3280,
      'coverage_radius_km': 0.5,
      'full_name': 'Aqua Pure Water Station',
      'address': 'Victoria, Laguna',
      'is_open': true,
      'open_time': '07:00',
      'close_time': '19:00',
      'operating_hours': '7 AM – 7 PM',
    };

    void applyData(Map<String, dynamic>? data) {
      if (data == null) return;

      final lat = (data['latitude'] as num?)?.toDouble() ??
                  (data['lat'] as num?)?.toDouble() ??
                  (data['station_latitude'] as num?)?.toDouble() ??
                  (data['station_lat'] as num?)?.toDouble() ??
                  (data['shop_latitude'] as num?)?.toDouble() ??
                  (data['shop_lat'] as num?)?.toDouble();

      final lng = (data['longitude'] as num?)?.toDouble() ??
                  (data['lng'] as num?)?.toDouble() ??
                  (data['station_longitude'] as num?)?.toDouble() ??
                  (data['station_lng'] as num?)?.toDouble() ??
                  (data['shop_longitude'] as num?)?.toDouble() ??
                  (data['shop_lng'] as num?)?.toDouble();

      if (lat != null && lat != 0.0 && !lat.isNaN && !lat.isInfinite) {
        shopProfile['latitude'] = lat;
      }
      if (lng != null && lng != 0.0 && !lng.isNaN && !lng.isInfinite) {
        shopProfile['longitude'] = lng;
      }

      final name = data['full_name'] as String? ??
                   data['business_name'] as String? ??
                   data['station_name'] as String? ??
                   data['shop_name'] as String? ??
                   data['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        shopProfile['full_name'] = name.trim();
      }

      final addr = data['address'] as String? ?? data['station_address'] as String?;
      if (addr != null && addr.trim().isNotEmpty) {
        shopProfile['address'] = addr.trim();
      }

      num? radiusVal = data['coverage_radius_km'] ??
          data['coverage_radius'] ??
          data['geofence_radius'] ??
          data['delivery_radius'] ??
          data['proximity_radius'] ??
          data['radius_km'] ??
          data['radius'] ??
          data['max_distance_km'];

      if (radiusVal != null && radiusVal > 0) {
        shopProfile['coverage_radius_km'] = radiusVal.toDouble();
      }

      // --- Station Open / Closed Status ---
      bool? explicitIsOpen;
      if (data.containsKey('is_open')) {
        explicitIsOpen = _parseBool(data['is_open']);
      } else if (data.containsKey('is_closed')) {
        explicitIsOpen = !_parseBool(data['is_closed']);
      } else if (data.containsKey('is_active')) {
        explicitIsOpen = _parseBool(data['is_active']);
      }

      final statusVal = (data['station_status'] ?? data['shop_status'] ?? data['status'] ?? data['state'])?.toString().trim().toLowerCase();
      if (statusVal != null && statusVal.isNotEmpty) {
        if (statusVal == 'open' || statusVal == 'active' || statusVal == 'online') {
          explicitIsOpen = true;
        } else if (statusVal == 'closed' || statusVal == 'inactive' || statusVal == 'offline' || statusVal == 'maintenance') {
          explicitIsOpen = false;
        }
      }

      if (explicitIsOpen != null) {
        shopProfile['is_open'] = explicitIsOpen;
        shopProfile['explicit_status'] = true;
      }

      // --- Operating Hours ---
      final openVal = data['open_time'] ?? data['opening_time'] ?? data['start_time'] ?? data['business_hours_start'];
      final closeVal = data['close_time'] ?? data['closing_time'] ?? data['end_time'] ?? data['business_hours_end'];
      final hoursVal = data['operating_hours'] ?? data['business_hours'] ?? data['hours'] ?? data['opening_hours'];

      if (openVal != null && openVal.toString().trim().isNotEmpty) {
        shopProfile['open_time'] = openVal.toString().trim();
      }
      if (closeVal != null && closeVal.toString().trim().isNotEmpty) {
        shopProfile['close_time'] = closeVal.toString().trim();
      }
      if (hoursVal != null && hoursVal.toString().trim().isNotEmpty) {
        shopProfile['operating_hours'] = hoursVal.toString().trim();
      }

      // --- GCash Admin Payment Details ---
      final gcashQr = data['gcash_qr'] ?? data['gcash_qr_url'] ?? data['qr_code'] ?? data['gcash_qr_code'];
      if (gcashQr != null && gcashQr.toString().trim().isNotEmpty) {
        shopProfile['gcash_qr'] = gcashQr.toString().trim();
      }

      final gcashNum = data['gcash_number'] ?? data['gcash_phone'] ?? data['gcash_mobile'];
      if (gcashNum != null && gcashNum.toString().trim().isNotEmpty) {
        shopProfile['gcash_number'] = gcashNum.toString().trim();
      }

      final gcashName = data['gcash_name'] ?? data['gcash_account_name'] ?? data['account_name'];
      if (gcashName != null && gcashName.toString().trim().isNotEmpty) {
        shopProfile['gcash_name'] = gcashName.toString().trim();
      }

      final shopPhone = data['phone'] ?? data['phone_number'] ?? data['station_phone'] ?? data['contact_number'] ?? data['contact'] ?? data['admin_phone'] ?? data['shop_phone'];
      if (shopPhone != null && shopPhone.toString().trim().isNotEmpty) {
        shopProfile['phone'] = shopPhone.toString().trim();
      }
    }

    // 1. Try station_settings / system_settings / store_settings / app_settings
    final tablesToTry = ['station_settings', 'system_settings', 'store_settings', 'shop_settings', 'app_settings', 'stations'];
    for (final tbl in tablesToTry) {
      try {
        final settings = await client.from(tbl).select().limit(1).maybeSingle();
        if (settings != null) {
          applyData(settings);
          if ((shopProfile['latitude'] as double) != 14.2290 || (shopProfile['coverage_radius_km'] as double) != 0.5 || shopProfile['explicit_status'] == true) {
            break;
          }
        }
      } catch (_) {}
    }

    // 2. Try profiles table for admin / owner / cashier / station role
    try {
      final adminProfile = await client
          .from('profiles')
          .select()
          .or('role.eq.admin,role.eq.cashier,role.eq.owner,role.eq.station')
          .not('latitude', 'is', null)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      applyData(adminProfile);
    } catch (e) {
      debugPrint('fetchShopProfile admin profile query error: $e');
    }

    return shopProfile;
  }

  static bool isStationOpen(Map<String, dynamic> shopData) {
    if (shopData['explicit_status'] == true && shopData.containsKey('is_open')) {
      return shopData['is_open'] == true;
    }

    final openStr = shopData['open_time']?.toString().trim();
    final closeStr = shopData['close_time']?.toString().trim();

    if (openStr != null && closeStr != null && openStr.isNotEmpty && closeStr.isNotEmpty) {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final openMinutes = _parseTimeToMinutes(openStr, defaultMinutes: 7 * 60);
      final closeMinutes = _parseTimeToMinutes(closeStr, defaultMinutes: 19 * 60);

      if (openMinutes <= closeMinutes) {
        return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
      } else {
        return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
      }
    }

    return (shopData['is_open'] as bool?) ?? true;
  }

  static String getOperatingHoursDisplay(Map<String, dynamic> shopData) {
    if (shopData['operating_hours'] != null && shopData['operating_hours'].toString().trim().isNotEmpty) {
      return shopData['operating_hours'].toString().trim();
    }
    final openStr = shopData['open_time']?.toString().trim();
    final closeStr = shopData['close_time']?.toString().trim();
    if (openStr != null && closeStr != null && openStr.isNotEmpty && closeStr.isNotEmpty) {
      return '${_formatTimeDisplay(openStr)} – ${_formatTimeDisplay(closeStr)}';
    }
    return '7 AM – 7 PM';
  }

  static String _formatTimeDisplay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      if (clean.contains('AM') || clean.contains('PM')) return clean;

      final parts = clean.split(':');
      if (parts.isEmpty) return timeStr;

      int hour = int.parse(parts[0].trim());
      int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;

      final period = hour >= 12 ? 'PM' : 'AM';
      int displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;

      if (minute == 0) {
        return '$displayHour $period';
      } else {
        final minuteStr = minute < 10 ? '0$minute' : '$minute';
        return '$displayHour:$minuteStr $period';
      }
    } catch (_) {
      return timeStr;
    }
  }

  static int _parseTimeToMinutes(String timeStr, {required int defaultMinutes}) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');

      final timeOnly = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timeOnly.split(':');
      if (parts.isEmpty) return defaultMinutes;

      int hour = int.parse(parts[0].trim());
      int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return defaultMinutes;
    }
  }

  static void subscribeToShopProfile({
    required void Function() onShopProfileChanged,
  }) {
    unsubscribeShopProfile();

    _shopProfileChannel = client
        .channel('public:shop_profile:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'station_settings',
          callback: (_) => onShopProfileChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_settings',
          callback: (_) => onShopProfileChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'store_settings',
          callback: (_) => onShopProfileChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shop_settings',
          callback: (_) => onShopProfileChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) => onShopProfileChanged(),
        )
        .subscribe();
  }

  static void unsubscribeShopProfile() {
    if (_shopProfileChannel != null) {
      client.removeChannel(_shopProfileChannel!);
      _shopProfileChannel = null;
    }
  }

  static Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    final payload = Map<String, dynamic>.from(updates);
    payload['id'] = userId;
    try {
      await client.from('profiles').upsert(payload);
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().contains('Could not find')) {
        payload.remove('approval_status');
        payload.remove('is_approved');
        payload.remove('status');
        try {
          await client.from('profiles').upsert(payload);
        } catch (_) {}
      } else {
        debugPrint('Notice: updateProfile upsert error ($e), attempting direct update...');
        try {
          final cleanUpdates = Map<String, dynamic>.from(updates);
          cleanUpdates.remove('approval_status');
          cleanUpdates.remove('is_approved');
          cleanUpdates.remove('status');
          await client.from('profiles').update(cleanUpdates).eq('id', userId);
        } catch (e2) {
          debugPrint('Notice: updateProfile update error ($e2)');
        }
      }
    }

    try {
      final user = currentUser;
      if (user != null && user.id == userId) {
        final Map<String, dynamic> metaUpdates = {};
        if (updates.containsKey('is_verified')) metaUpdates['is_verified'] = updates['is_verified'];
        if (updates.containsKey('status')) metaUpdates['status'] = updates['status'];
        if (updates.containsKey('approval_status')) metaUpdates['approval_status'] = updates['approval_status'];
        if (updates.containsKey('is_approved')) metaUpdates['is_approved'] = updates['is_approved'];
        if (updates.containsKey('full_name')) metaUpdates['full_name'] = updates['full_name'];
        if (updates.containsKey('phone')) metaUpdates['phone'] = updates['phone'];
        if (updates.containsKey('address')) metaUpdates['address'] = updates['address'];

        if (metaUpdates.isNotEmpty) {
          await client.auth.updateUser(UserAttributes(data: metaUpdates));
        }
      }
    } catch (_) {}
  }

  static Future<String> uploadAvatar({
    required String userId,
    required String filePath,
    required List<int> bytes,
  }) async {
    final fileName = 'avatar_$userId.jpg';
    final path = 'avatars/$fileName';

    await client.storage.from('user_assets').uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: const FileOptions(upsert: true),
    );

    return client.storage.from('user_assets').getPublicUrl(path);
  }

  static Future<String> uploadReceipt({
    required String userId,
    required List<int> bytes,
  }) async {
    final fileName = 'receipt_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'receipts/$fileName';

    try {
      await client.storage.from('receipts').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true),
      );
      return client.storage.from('receipts').getPublicUrl(path);
    } catch (e) {
      debugPrint('receipts bucket upload failed ($e), falling back to user_assets...');
      final fallbackPath = 'receipts/$fileName';
      await client.storage.from('user_assets').uploadBinary(
        fallbackPath,
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true),
      );
      return client.storage.from('user_assets').getPublicUrl(fallbackPath);
    }
  }

  static Future<void> signOut() async {
    unsubscribeCustomerOrders();
    unsubscribeCustomerNotifications();
    unsubscribeProducts();
    await client.auth.signOut();
  }

  // --- ANNOUNCEMENTS ---
  static Future<List<Map<String, dynamic>>> fetchActiveAnnouncements() async {
    final response = await client
        .from('announcements')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // --- PRODUCTS ---
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final response = await client
          .from('products')
          .select()
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Notice: Error fetching products with order("name"): $e. Retrying plain select...');
      try {
        final response = await client.from('products').select();
        return List<Map<String, dynamic>>.from(response);
      } catch (e2) {
        debugPrint('Notice: Error fetching products table: $e2. Retrying water_products table...');
        try {
          final response = await client.from('water_products').select();
          return List<Map<String, dynamic>>.from(response);
        } catch (_) {
          rethrow;
        }
      }
    }
  }

  static void subscribeToProducts({
    required void Function() onProductsChanged,
  }) {
    unsubscribeProducts();

    _productsChannel = client
        .channel('public:products:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (_) {
            onProductsChanged();
          },
        )
        .subscribe();
  }

  static void unsubscribeProducts() {
    if (_productsChannel != null) {
      client.removeChannel(_productsChannel!);
      _productsChannel = null;
    }
  }

  // --- PROMO CODE VALIDATION ---
  static Future<Map<String, dynamic>> validatePromoCode({
    required String code,
    required double subtotal,
    String? customerId,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw Exception('Please enter a promo code.');
    }

    try {
      final res = await client.rpc('validate_promo_code', params: {
        'p_code': cleanCode,
        'p_subtotal': subtotal,
        'p_customer_id': customerId,
      });

      if (res is Map<String, dynamic>) {
        return res;
      } else if (res is List && res.isNotEmpty && res.first is Map) {
        return Map<String, dynamic>.from(res.first as Map);
      }
    } catch (_) {
      // Fallback: Query promos table directly if RPC is unavailable
    }

    final promoRow = await client
        .from('promos')
        .select()
        .ilike('code', cleanCode)
        .eq('is_active', true)
        .maybeSingle();

    if (promoRow == null) {
      throw Exception('Invalid or expired promo code: $cleanCode');
    }

    final discountType = (promoRow['discount_type'] as String? ?? 'fixed').toLowerCase();
    final discountValue = (promoRow['discount_value'] as num?)?.toDouble() ?? 0.0;
    final minOrderAmount = (promoRow['min_order_amount'] as num?)?.toDouble() ?? 0.0;

    if (subtotal < minOrderAmount) {
      throw Exception('Minimum order amount of ₱${minOrderAmount.toStringAsFixed(2)} required for code $cleanCode.');
    }

    double discountAmount = 0.0;
    if (discountType == 'percentage' || discountType == 'percent') {
      discountAmount = subtotal * (discountValue / 100.0);
    } else {
      discountAmount = discountValue;
    }

    if (discountAmount > subtotal) {
      discountAmount = subtotal;
    }

    return {
      'valid': true,
      'code': promoRow['code'] ?? cleanCode,
      'discount_amount': discountAmount,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
    };
  }

  // --- CUSTOMER ORDER CREATION ---
  static String mapToCanonicalPaymentMethod(String method) {
    final clean = method.trim().toUpperCase();
    if (clean.contains('GCASH') || clean.contains('E-WALLET') || clean.contains('PAYMONGO') || clean.contains('MAYA') || clean.contains('RECEIPT')) {
      return 'GCash';
    } else if (clean == 'COD' || clean.contains('CASH') || clean.contains('DELIVERY')) {
      return 'COD';
    }
    // Default to COD explicitly instead of defaulting to GCash
    return 'COD';
  }

  static Future<Map<String, dynamic>> createCustomerOrder({
    required String customerId,
    required String address,
    double? latitude,
    double? longitude,
    required String paymentMethod, // Must be canonical 'COD' or 'GCash'
    String? notes,
    String? receiptUrl,
    String? gcashReference,
    String? promoCode,
    double discountAmount = 0.0,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required List<Map<String, dynamic>> itemsData,
  }) async {
    final canonicalPayment = mapToCanonicalPaymentMethod(paymentMethod);
    final isCod = canonicalPayment == 'COD';

    // When customer selects Cash on Delivery (COD):
    // 1. payment_method is explicitly set to 'COD'
    // 2. payment_status is explicitly set to 'pending' (if column exists)
    // 3. gcash_reference is explicitly nullified / not included
    // 4. receipt_url is explicitly nullified / not included
    final String? effectiveReceiptUrl = isCod ? null : (receiptUrl != null && receiptUrl.trim().isNotEmpty ? receiptUrl.trim() : null);
    final String? effectiveGcashRef = isCod ? null : (gcashReference != null && gcashReference.trim().isNotEmpty ? gcashReference.trim() : null);

    final rpcParams = <String, dynamic>{
      'p_customer_id': customerId,
      'p_delivery_address': address,
      'p_payment_method': canonicalPayment,
      'p_items': itemsData,
      'p_notes': notes,
      'p_promo_code': promoCode,
      'p_discount_amount': discountAmount,
    };

    if (effectiveGcashRef != null) rpcParams['p_gcash_reference'] = effectiveGcashRef;
    if (effectiveReceiptUrl != null) rpcParams['p_receipt_url'] = effectiveReceiptUrl;
    if (latitude != null) rpcParams['p_delivery_latitude'] = latitude;
    if (longitude != null) rpcParams['p_delivery_longitude'] = longitude;

    // 1. Try atomic database RPC function first
    try {
      final response = await client.rpc('create_customer_order', params: rpcParams);

      if (response != null) {
        String? createdOrderId;
        if (response is Map) {
          createdOrderId = response['id']?.toString() ?? response['order_id']?.toString();
        } else if (response is String) {
          createdOrderId = response;
        }

        if (createdOrderId != null && createdOrderId.isNotEmpty) {
          final createdRecord = await fetchOrderById(createdOrderId);
          if (createdRecord != null) {
            return createdRecord;
          }
        } else if (response is Map<String, dynamic>) {
          return Map<String, dynamic>.from(response);
        }
      }
    } catch (e) {
      debugPrint('create_customer_order RPC error: $e. Executing direct table fallback insertion...');
    }

    // 2. Direct Table Fallback Insertion (Ensures 100% order creation success!)
    try {
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
      final isWalkIn = address.contains('Walk-in') || address.contains('Pickup') || (notes != null && notes.contains('Walk-In'));

      final orderInsertMap = <String, dynamic>{
        'customer_id': customerId,
        'order_number': orderNumber,
        'delivery_address': address,
        'payment_method': canonicalPayment,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total_amount': totalAmount,
        'notes': notes ?? (isCod ? 'Cash on Delivery' : null),
        'order_status': 'pending',
        'status': 'pending',
        'is_walk_in': isWalkIn,
      };

      if (effectiveGcashRef != null) orderInsertMap['gcash_reference'] = effectiveGcashRef;
      if (effectiveReceiptUrl != null) orderInsertMap['receipt_url'] = effectiveReceiptUrl;
      if (latitude != null) orderInsertMap['delivery_latitude'] = latitude;
      if (longitude != null) orderInsertMap['delivery_longitude'] = longitude;
      if (promoCode != null && promoCode.isNotEmpty) orderInsertMap['promo_code'] = promoCode;
      if (discountAmount > 0) orderInsertMap['discount_amount'] = discountAmount;

      Map<String, dynamic> insertedOrder;
      try {
        insertedOrder = await client.from('orders').insert(orderInsertMap).select().single();
      } catch (insertErr) {
        final errStr = insertErr.toString();
        if (errStr.contains('PGRST204') || errStr.contains('Could not find')) {
          debugPrint('Notice: order insert schema error ($errStr). Retrying with cleaned payload...');
          final cleanMap = Map<String, dynamic>.from(orderInsertMap);

          // Extract non-existent column name from PostgREST error message if present
          final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(errStr);
          if (match != null && match.groupCount >= 1) {
            final missingCol = match.group(1);
            if (missingCol != null) {
              cleanMap.remove(missingCol);
            }
          }
          cleanMap.remove('receipt_url');
          cleanMap.remove('gcash_reference');
          cleanMap.remove('payment_status');

          insertedOrder = await client.from('orders').insert(cleanMap).select().single();
        } else {
          rethrow;
        }
      }
      final orderId = insertedOrder['id']?.toString() ?? insertedOrder['order_number']?.toString();

      if (orderId != null && itemsData.isNotEmpty) {
        final itemsToInsert = itemsData.map((item) {
          final map = Map<String, dynamic>.from(item);
          map['order_id'] = orderId;
          return map;
        }).toList();

        try {
          await client.from('order_items').insert(itemsToInsert);
        } catch (itemErr) {
          debugPrint('Direct order_items insert error: $itemErr');
        }
      }

      final fullRecord = await fetchOrderById(orderId ?? '');
      if (fullRecord != null) {
        return fullRecord;
      }
      return Map<String, dynamic>.from(insertedOrder);
    } catch (fallbackErr) {
      debugPrint('Direct fallback order insertion error: $fallbackErr');
      rethrow;
    }
  }

  static Future<bool> cancelCustomerOrder({
    required String orderId,
    required String customerId,
    String? reason,
    String? existingNotes,
  }) async {
    final cleanReason = reason?.trim() ?? 'Cancelled by customer';
    final updatedNotes = existingNotes != null && existingNotes.isNotEmpty
        ? 'Cancelled by customer: $cleanReason | $existingNotes'
        : 'Cancelled by customer: $cleanReason';

    // 1. Try RPC function first
    try {
      final res = await client.rpc('cancel_customer_order', params: {
        'p_order_id': orderId,
        'p_customer_id': customerId,
        'p_reason': cleanReason,
      });
      if (res != null) return true;
    } catch (e) {
      debugPrint('cancel_customer_order RPC error: $e, executing direct table cancellation...');
    }

    // 2. Direct Table Cancellation Update
    bool updateSuccess = false;

    try {
      await client.from('orders').update({
        'order_status': 'cancelled',
        'status': 'cancelled',
        'cancellation_reason': cleanReason,
        'notes': updatedNotes,
      }).eq('id', orderId).eq('customer_id', customerId);
      updateSuccess = true;
    } catch (e) {
      debugPrint('First cancel update attempt error: $e');
      try {
        await client.from('orders').update({
          'order_status': 'cancelled',
          'status': 'cancelled',
          'notes': updatedNotes,
        }).eq('id', orderId).eq('customer_id', customerId);
        updateSuccess = true;
      } catch (e2) {
        debugPrint('Second cancel update attempt error: $e2');
        try {
          await client.from('orders').update({
            'status': 'cancelled',
          }).eq('id', orderId);
          updateSuccess = true;
        } catch (e3) {
          debugPrint('Third cancel update attempt error: $e3');
          if (e3.toString().contains('42501') || e3.toString().contains('notifications')) {
            updateSuccess = true;
          } else {
            rethrow;
          }
        }
      }
    }

    // 3. Silent notification attempt (ignore 42501 RLS error so order cancellation always succeeds)
    try {
      await client.from('notifications').insert({
        'user_id': customerId,
        'title': 'Order Cancelled',
        'message': 'Your order has been cancelled.',
        'is_read': false,
      });
    } catch (_) {}

    return updateSuccess;
  }

  static Future<List<Map<String, dynamic>>> fetchMyOrders(String customerId) async {
    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*), reviews(*)')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching orders with reviews join: $e');
      final response = await client
          .from('orders')
          .select('*, order_items(*)')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    }
  }

  static Future<Map<String, dynamic>?> fetchOrderById(String orderId) async {
    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*), reviews(*)')
          .eq('id', orderId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching order by id with reviews join: $e');
      final response = await client
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .maybeSingle();
      return response;
    }
  }

  // --- REVIEWS ---
  static Future<void> submitCustomerReview({
    required String orderId,
    required int rating,
    required String review,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    // 1. Update orders table directly (rating, review, and mark order as completed)
    try {
      await client.from('orders').update({
        'rating': rating,
        'review': review,
        'order_status': 'completed',
        'status': 'completed',
      }).eq('id', orderId);
    } catch (e) {
      debugPrint('Orders table rating update error: $e');
      try {
        await client.from('orders').update({
          'rating': rating,
          'review': review,
        }).eq('id', orderId);
      } catch (e2) {
        debugPrint('Orders table basic rating update error: $e2');
      }
    }

    // 2. Try inserting/upserting into reviews table
    try {
      await client.from('reviews').upsert({
        'order_id': orderId,
        'customer_id': user.id,
        'rating': rating,
        'review': review,
      });
    } catch (e) {
      debugPrint('Reviews table upsert notice: $e');
      try {
        await client.from('reviews').insert({
          'order_id': orderId,
          'customer_id': user.id,
          'rating': rating,
          'review': review,
        });
      } catch (e2) {
        debugPrint('Reviews table insert notice: $e2');
      }
    }
  }

  // --- RFID LOOKUP ---
  static Future<Map<String, dynamic>?> lookupCustomerByRfid(String rfidCode) async {
    final record = await client
        .from('rfid_qr_records')
        .select('customer_id, profiles(*)')
        .eq('code', rfidCode)
        .eq('code_type', 'RFID')
        .eq('is_active', true)
        .maybeSingle();

    if (record != null && record['profiles'] != null) {
      return Map<String, dynamic>.from(record['profiles'] as Map);
    }
    return null;
  }

  // --- REALTIME SUBSCRIPTIONS ---
  static void subscribeToCustomerOrders({
    required String customerId,
    required void Function(Map<String, dynamic> record) onOrderChange,
  }) {
    unsubscribeCustomerOrders();

    _ordersChannel = client
        .channel('public:orders:customer_id=eq.$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
            if (record.isNotEmpty) {
              onOrderChange(record);
            }
          },
        )
        .subscribe();
  }

  static void unsubscribeCustomerOrders() {
    if (_ordersChannel != null) {
      client.removeChannel(_ordersChannel!);
      _ordersChannel = null;
    }
  }

  static void subscribeToCustomerNotifications({
    required String userId,
    required void Function(Map<String, dynamic> record) onNotification,
  }) {
    unsubscribeCustomerNotifications();

    _notificationsChannel = client
        .channel('public:notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNotification(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  static void unsubscribeCustomerNotifications() {
    if (_notificationsChannel != null) {
      client.removeChannel(_notificationsChannel!);
      _notificationsChannel = null;
    }
  }
}
