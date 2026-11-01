import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

class OrderProvider with ChangeNotifier {
  WaterOrder? _activeOrder;
  final List<WaterOrder> _history = [];
  final List<Product> _products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingOrders = false;
  String? _subscribedCustomerId;

  WaterOrder? get activeOrder => _activeOrder;
  WaterOrder? get currentOrder => _activeOrder;
  List<WaterOrder> get history => [..._history];
  List<Product> get products => [..._products];
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingOrders => _isLoadingOrders;

  // --- PRODUCTS ---
  Future<List<Product>> fetchProducts() async {
    _isLoadingProducts = true;
    notifyListeners();
    try {
      final rawList = await SupabaseService.fetchProducts();
      debugPrint('Supabase raw products fetched (${rawList.length} rows): $rawList');
      _products.clear();
      
      final List<Product> parsedList = [];
      for (var p in rawList) {
        try {
          final prod = Product.fromSupabaseMap(p);
          debugPrint('Parsed Product: ${prod.name}, price=${prod.price}, imageUrl=${prod.imageUrl}, isAvailable=${prod.isAvailable}, isActive=${prod.isActive}');
          if (prod.isActive) {
            parsedList.add(prod);
          }
        } catch (e, st) {
          debugPrint('Error parsing individual product row $p: $e\n$st');
        }
      }

      if (parsedList.isNotEmpty) {
        _products.addAll(parsedList);
      } else if (rawList.isNotEmpty) {
        // Fallback: If no products evaluated to isActive, show all parsed rows as fallback
        for (var p in rawList) {
          try {
            _products.add(Product.fromSupabaseMap(p));
          } catch (_) {}
        }
      }

      _initProductRealtimeSubscription();
    } catch (e, stack) {
      debugPrint('Error fetching products from Supabase: $e\n$stack');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
    return _products;
  }

  void _initProductRealtimeSubscription() {
    SupabaseService.subscribeToProducts(
      onProductsChanged: () {
        fetchProducts();
      },
    );
  }

  // --- CREATE ORDER VIA public.create_customer_order ---
  Future<WaterOrder> createOrder({
    required List<OrderItemData> items,
    required String address,
    double? latitude,
    double? longitude,
    String? notes,
    String? receiptUrl,
    String? gcashReference,
    required String paymentMethod, // 'COD' or 'GCash'
    String? promoCode,
    double discountAmount = 0.0,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated. Please log in to place an order.');
    }

    if (items.isEmpty) {
      throw Exception('Please select at least one water product.');
    }

    final canonicalPayment = SupabaseService.mapToCanonicalPaymentMethod(paymentMethod);

    final itemsData = items.map((item) => {
      'product_id': item.productId,
      'product_name': item.productName,
      'quantity': item.quantity,
      'gallon_type': item.gallonType == GallonType.borrowed ? 'borrowed' : 'own',
      'unit_price': item.unitPrice,
      'subtotal': item.subtotal,
    }).toList();

    // Call atomic create_customer_order operation
    final createdOrderRaw = await SupabaseService.createCustomerOrder(
      customerId: user.id,
      address: address,
      latitude: latitude,
      longitude: longitude,
      paymentMethod: canonicalPayment,
      notes: notes,
      receiptUrl: receiptUrl,
      gcashReference: gcashReference,
      promoCode: promoCode,
      discountAmount: discountAmount,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      totalAmount: totalAmount,
      itemsData: itemsData,
    );

    final newOrder = WaterOrder.fromSupabaseMap(createdOrderRaw, itemsData);
    _activeOrder = newOrder;
    _history.insert(0, newOrder);

    // Sync notification to database
    try {
      await SupabaseService.client.from('notifications').insert({
        'user_id': user.id,
        'title': 'Order Placed',
        'message': 'Your order #${newOrder.orderNumber} for ${newOrder.quantity} gallons has been successfully placed.',
        'is_read': false,
      });
    } catch (_) {}

    _initRealtimeSubscription(user.id);

    notifyListeners();
    return newOrder;
  }

  // --- FETCH MY ORDERS ---
  Future<List<WaterOrder>> fetchMyOrders() async {
    final user = SupabaseService.currentUser;
    if (user == null) return _history;

    _initRealtimeSubscription(user.id);

    _isLoadingOrders = true;
    notifyListeners();

    try {
      final rawList = await SupabaseService.fetchMyOrders(user.id);
      _history.clear();
      for (var raw in rawList) {
        final order = WaterOrder.fromSupabaseMap(raw);
        _history.add(order);
      }

      if (_history.isNotEmpty) {
        final activeOrRecentOrders = _history.where((o) => 
          o.status != OrderStatus.completed && 
          o.status != OrderStatus.cancelled
        ).toList();
        
        if (activeOrRecentOrders.isNotEmpty) {
          _activeOrder = activeOrRecentOrders.first;
        } else {
          _activeOrder = null; // No truly active order
        }
      } else {
        _activeOrder = null;
      }
    } catch (_) {
      // Keep existing local history on offline
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
    return _history;
  }

  void _initRealtimeSubscription(String customerId) {
    if (_subscribedCustomerId == customerId) return;
    _subscribedCustomerId = customerId;

    SupabaseService.subscribeToCustomerOrders(
      customerId: customerId,
      onOrderChange: (record) async {
        final orderId = record['id']?.toString();
        if (orderId == null || orderId.isEmpty) return;

        final fullRecord = await SupabaseService.fetchOrderById(orderId);
        if (fullRecord != null) {
          final updatedOrder = WaterOrder.fromSupabaseMap(fullRecord);

          final index = _history.indexWhere((o) => o.id == updatedOrder.id);
          bool shouldNotify = false;
          if (index != -1) {
            final oldOrder = _history[index];
            if (oldOrder.status != updatedOrder.status) {
              shouldNotify = true;
            }
            _history[index] = updatedOrder;
          } else {
            _history.insert(0, updatedOrder);
            shouldNotify = true;
          }

          if (shouldNotify) {
            _insertOrderNotification(updatedOrder);
          }

          final activeOrRecentOrders = _history.where((o) => 
            o.status != OrderStatus.completed && 
            o.status != OrderStatus.cancelled
          ).toList();
          
          if (activeOrRecentOrders.isNotEmpty) {
            _activeOrder = activeOrRecentOrders.first;
          } else {
            _activeOrder = null;
          }

          notifyListeners();
        }
      },
    );
  }

  Future<void> _insertOrderNotification(WaterOrder order) async {
    try {
      final statusLabel = WaterOrder.toDisplayLabel(order.status);
      String message = 'Your order #${order.orderNumber} status has updated to $statusLabel.';
      if (order.status == OrderStatus.confirmed) {
        message = 'Great news! Your order #${order.orderNumber} has been confirmed by the station/admin.';
      } else if (order.status == OrderStatus.assigned) {
        message = 'A delivery driver has been assigned to your order #${order.orderNumber}.';
      } else if (order.status == OrderStatus.accepted) {
        message = 'Your order #${order.orderNumber} has been accepted by the delivery rider!';
      } else if (order.status == OrderStatus.outForDelivery) {
        message = 'Your order #${order.orderNumber} is now out for delivery! Prepare payment/gallons.';
      } else if (order.status == OrderStatus.delivered) {
        message = 'Your order #${order.orderNumber} has been successfully delivered. Thank you!';
      } else if (order.status == OrderStatus.completed) {
        message = 'Your order #${order.orderNumber} is completed.';
      } else if (order.status == OrderStatus.cancelled) {
        message = 'Your order #${order.orderNumber} has been cancelled.';
      } else if (order.status == OrderStatus.pending) {
        message = 'Your order #${order.orderNumber} has been successfully placed and is pending confirmation.';
      }

      await SupabaseService.client.from('notifications').insert({
        'user_id': order.customerId,
        'title': 'Order $statusLabel',
        'message': message,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error inserting order notification: $e');
    }
  }

  // --- FETCH ORDER BY ID ---
  Future<WaterOrder?> fetchOrderById(String orderId) async {
    try {
      final raw = await SupabaseService.fetchOrderById(orderId);
      if (raw != null) {
        final order = WaterOrder.fromSupabaseMap(raw);
        _activeOrder = order;
        notifyListeners();
        return order;
      }
    } catch (_) {}
    return _activeOrder;
  }

  void setActiveOrder(WaterOrder order) {
    _activeOrder = order;
    notifyListeners();
  }

  void placeOrder(WaterOrder order) {
    _activeOrder = order;
    _history.insert(0, order);
    notifyListeners();
  }

  void clearActiveOrder() {
    _activeOrder = null;
    notifyListeners();
  }

  @override
  void dispose() {
    SupabaseService.unsubscribeCustomerOrders();
    SupabaseService.unsubscribeProducts();
    super.dispose();
  }
}
