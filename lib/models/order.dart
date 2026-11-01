enum OrderStatus { 
  pending, 
  confirmed, 
  assigned, 
  accepted, 
  outForDelivery, 
  delivered, 
  completed, 
  cancelled 
}

enum GallonType { own, borrowed }

class OrderItemData {
  final String? id;
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final GallonType gallonType;
  final double unitPrice;
  final double subtotal;

  OrderItemData({
    this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.gallonType,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItemData.fromSupabaseMap(Map<String, dynamic> map) {
    String gallonTypeStr = (map['gallon_type'] as String? ?? 'own').toLowerCase();
    GallonType gType = gallonTypeStr.contains('borrow') ? GallonType.borrowed : GallonType.own;

    return OrderItemData(
      id: map['id']?.toString(),
      orderId: map['order_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name'] as String? ?? 'Unknown Product',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      gallonType: gType,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toSupabaseMap(String orderId) {
    return {
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'gallon_type': gallonType == GallonType.borrowed ? 'borrowed' : 'own',
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}

class WaterOrder {
  final String id;
  final String orderNumber;
  final String customerId;
  final String product;
  final int quantity;
  final GallonType gallonType;
  final String address;
  final String? notes;
  final String paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final OrderStatus status;
  final double? latitude;
  final double? longitude;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double? driverLatitude;
  final double? driverLongitude;
  final String? gcashReference;
  final String? promoCode;
  final double? discountAmount;
  final int? rating;
  final String? review;
  final String? proofOfDelivery;
  final String? adminNotes;
  final String? cancellationReason;
  final DateTime timestamp;
  final List<OrderItemData> items;
  final bool isWalkIn;

  WaterOrder({
    required this.id,
    String? orderNumber,
    this.customerId = '',
    required this.product,
    required this.quantity,
    required this.gallonType,
    required this.address,
    this.notes,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.status,
    this.latitude,
    this.longitude,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverLatitude,
    this.driverLongitude,
    this.gcashReference,
    this.promoCode,
    this.discountAmount,
    this.rating,
    this.review,
    this.proofOfDelivery,
    this.adminNotes,
    this.cancellationReason,
    required this.timestamp,
    this.items = const [],
    this.isWalkIn = false,
  }) : orderNumber = orderNumber ?? id;

  factory WaterOrder.fromSupabaseMap(
    Map<String, dynamic> map, [
    List<Map<String, dynamic>>? rawItems,
  ]) {
    final rawStatus = map['order_status'] as String? ?? map['status'] as String? ?? 'pending';
    final status = _parseOrderStatus(rawStatus);

    List<OrderItemData> items = [];
    if (rawItems != null && rawItems.isNotEmpty) {
      items = rawItems.map((i) => OrderItemData.fromSupabaseMap(i)).toList();
    } else if (map['order_items'] != null && map['order_items'] is List) {
      final list = map['order_items'] as List;
      items = list.map((i) => OrderItemData.fromSupabaseMap(i as Map<String, dynamic>)).toList();
    }

    String productName = 'Unknown Product';
    int qty = 1;
    GallonType gType = GallonType.own;

    if (items.isNotEmpty) {
      productName = items.first.productName;
      qty = items.fold(0, (sum, item) => sum + item.quantity);
      gType = items.first.gallonType;
    } else if (map['product_name'] != null) {
      productName = map['product_name'] as String;
    }

    final dateStr = map['created_at'] as String?;
    final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    final rawPayment = (map['payment_method'] as String? ?? 'Not specified').trim();
    String canonicalPayment = rawPayment;
    if (rawPayment == 'Cash on Delivery' || rawPayment.toUpperCase() == 'COD') {
      canonicalPayment = 'COD';
    } else if (rawPayment.contains('GCash') || rawPayment.contains('E-Wallet')) {
      canonicalPayment = 'GCash';
    }

    int? ratingVal = (map['rating'] as num?)?.toInt() ?? 
                      (map['review_rating'] as num?)?.toInt() ??
                      (map['order_rating'] as num?)?.toInt();
    String? reviewVal = map['review'] as String? ?? 
                      map['review_text'] as String? ?? 
                      map['customer_review'] as String?;

    if (map['reviews'] != null) {
      if (map['reviews'] is List && (map['reviews'] as List).isNotEmpty) {
        final rMap = (map['reviews'] as List).first as Map<String, dynamic>;
        ratingVal ??= (rMap['rating'] as num?)?.toInt();
        reviewVal ??= rMap['review'] as String?;
      } else if (map['reviews'] is Map<String, dynamic>) {
        final rMap = map['reviews'] as Map<String, dynamic>;
        ratingVal ??= (rMap['rating'] as num?)?.toInt();
        reviewVal ??= rMap['review'] as String?;
      }
    }

    final proofUrl = map['receipt_url'] as String? ??
                     map['proof_of_delivery'] as String? ?? 
                     map['proof_image_url'] as String? ?? 
                     map['proof_image'] as String? ?? 
                     map['delivery_proof'] as String? ?? 
                     map['delivery_proof_url'] as String? ?? 
                     map['driver_proof'] as String? ?? 
                     map['proof_url'] as String? ??
                     map['proof'] as String?;

    final dId = map['driver_id'] as String? ?? map['rider_id'] as String?;
    
    final dName = map['driver_name'] as String? ?? 
                  map['rider_name'] as String? ?? 
                  (map['driver'] is Map ? (map['driver']['full_name'] as String? ?? map['driver']['name'] as String?) : null) ??
                  (map['rider'] is Map ? (map['rider']['full_name'] as String? ?? map['rider']['name'] as String?) : null);

    final dPhone = map['driver_phone'] as String? ?? 
                   map['rider_phone'] as String? ?? 
                   (map['driver'] is Map ? (map['driver']['phone_number'] as String? ?? map['driver']['phone'] as String?) : null) ??
                   (map['rider'] is Map ? (map['rider']['phone_number'] as String? ?? map['rider']['phone'] as String?) : null);

    final dLat = (map['driver_latitude'] as num?)?.toDouble() ?? 
                 (map['driver_lat'] as num?)?.toDouble() ?? 
                 (map['rider_latitude'] as num?)?.toDouble() ??
                 (map['driver'] is Map ? (map['driver']['latitude'] as num?)?.toDouble() : null);

    final dLng = (map['driver_longitude'] as num?)?.toDouble() ?? 
                 (map['driver_lng'] as num?)?.toDouble() ?? 
                 (map['rider_longitude'] as num?)?.toDouble() ??
                 (map['driver'] is Map ? (map['driver']['longitude'] as num?)?.toDouble() : null);

    final adminNotesVal = map['admin_notes'] as String? ??
                          map['admin_note'] as String? ??
                          map['admin_message'] as String? ??
                          map['admin_remarks'] as String? ??
                          map['admin_remark'] as String? ??
                          map['remarks'] as String? ??
                          map['station_note'] as String?;

    final cancelReasonVal = map['cancellation_reason'] as String? ??
                            map['cancel_reason'] as String? ??
                            map['rejection_reason'] as String? ??
                            map['reject_reason'] as String?;

    return WaterOrder(
      id: map['id']?.toString() ?? '',
      orderNumber: map['order_number'] as String? ?? (map['id']?.toString() ?? ''),
      customerId: map['customer_id'] as String? ?? '',
      product: productName,
      quantity: qty > 0 ? qty : 1,
      gallonType: gType,
      address: map['delivery_address'] as String? ?? (map['address'] as String? ?? ''),
      notes: map['notes'] as String?,
      paymentMethod: canonicalPayment,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: status,
      latitude: (map['delivery_latitude'] as num?)?.toDouble() ??
                (map['latitude'] as num?)?.toDouble() ??
                (map['delivery_lat'] as num?)?.toDouble() ??
                (map['customer_latitude'] as num?)?.toDouble() ??
                (map['customer_lat'] as num?)?.toDouble() ??
                (map['lat'] as num?)?.toDouble(),
      longitude: (map['delivery_longitude'] as num?)?.toDouble() ??
                 (map['longitude'] as num?)?.toDouble() ??
                 (map['delivery_lng'] as num?)?.toDouble() ??
                 (map['customer_longitude'] as num?)?.toDouble() ??
                 (map['customer_lng'] as num?)?.toDouble() ??
                 (map['lng'] as num?)?.toDouble(),
      driverId: dId,
      driverName: dName,
      driverPhone: dPhone,
      driverLatitude: dLat,
      driverLongitude: dLng,
      gcashReference: map['gcash_reference'] as String? ?? map['gcash_ref'] as String?,
      promoCode: map['promo_code'] as String?,
      discountAmount: (map['discount_amount'] as num?)?.toDouble(),
      rating: ratingVal,
      review: reviewVal,
      proofOfDelivery: proofUrl,
      adminNotes: adminNotesVal,
      cancellationReason: cancelReasonVal,
      timestamp: dt,
      items: items,
      isWalkIn: map['is_walk_in'] == true ||
          (map['order_type']?.toString().toLowerCase() == 'walk_in') ||
          (map['notes']?.toString().contains('Walk-In') == true) ||
          (map['order_source']?.toString().toLowerCase() == 'walk_in'),
    );
  }

  static OrderStatus _parseOrderStatus(String statusStr) {
    final clean = statusStr.toLowerCase().replaceAll('-', '_').trim();
    switch (clean) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'assigned':
        return OrderStatus.assigned;
      case 'accepted':
        return OrderStatus.accepted;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static String toDbStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static String toDisplayLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.assigned:
        return 'Driver Assigned';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  WaterOrder copyWith({
    OrderStatus? status,
    int? rating,
    String? review,
    String? proofOfDelivery,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? driverLatitude,
    double? driverLongitude,
    bool? isWalkIn,
    String? adminNotes,
    String? cancellationReason,
  }) {
    return WaterOrder(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      product: product,
      quantity: quantity,
      gallonType: gallonType,
      address: address,
      notes: notes,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      totalAmount: totalAmount,
      status: status ?? this.status,
      latitude: latitude,
      longitude: longitude,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      gcashReference: gcashReference,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      proofOfDelivery: proofOfDelivery ?? this.proofOfDelivery,
      adminNotes: adminNotes ?? this.adminNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      timestamp: timestamp,
      items: items,
      isWalkIn: isWalkIn ?? this.isWalkIn,
    );
  }
}
