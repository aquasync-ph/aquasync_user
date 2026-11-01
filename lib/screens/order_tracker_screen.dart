import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import 'review_screen.dart';
import 'order_chat_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/route_service.dart';
import '../widgets/top_banner.dart';

class OrderTrackerScreen extends StatefulWidget {
  const OrderTrackerScreen({super.key});

  @override
  State<OrderTrackerScreen> createState() => _OrderTrackerScreenState();
}

class _OrderTrackerScreenState extends State<OrderTrackerScreen> {
  final MapController _mapController = MapController();
  int _unreadChatCount = 0;
  RealtimeChannel? _trackerChatSubscription;
  RealtimeChannel? _driverLocationSubscription;
  LatLng? _liveDriverPos;
  String? _currentSubscribedOrderId;

  static const LatLng _defaultStationLocation = LatLng(14.2290, 121.3280);
  static const LatLng _defaultDeliveryLocation = LatLng(14.2193, 121.3470);

  LatLng _stationLocation = _defaultStationLocation;
  String _stationName = 'Water Station';

  @override
  void initState() {
    super.initState();
    _loadShopProfile();
    _listenForUnreadMessages();
    _listenForRealtimeDriverLocation();
  }

  @override
  void dispose() {
    _trackerChatSubscription?.unsubscribe();
    _driverLocationSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadShopProfile() async {
    try {
      final shopData = await SupabaseService.fetchShopProfile();
      final lat = (shopData['latitude'] as num?)?.toDouble();
      final lng = (shopData['longitude'] as num?)?.toDouble();
      final name = shopData['full_name'] as String? ?? 
                   shopData['business_name'] as String? ?? 
                   shopData['name'] as String? ?? 
                   'Water Station';

      if (_isValidCoordinate(lat, lng)) {
        if (mounted) {
          setState(() {
            _stationLocation = LatLng(lat!, lng!);
            _stationName = name;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final activeOrder = Provider.of<OrderProvider>(context, listen: false).activeOrder;
            final userLoc = activeOrder != null ? _getUserLocation(activeOrder) : _defaultDeliveryLocation;
            final riderLoc = _liveDriverPos ?? _stationLocation;
            _recenterMap(_stationLocation, riderLoc, userLoc);
          });
        }
      }
    } catch (_) {}
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) return false;
    return true;
  }

  bool _isValidLatLng(LatLng? p) {
    if (p == null) return false;
    return _isValidCoordinate(p.latitude, p.longitude);
  }

  void _listenForUnreadMessages() {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeOrder = Provider.of<OrderProvider>(context, listen: false).activeOrder;
      if (activeOrder == null) return;

      try {
        _trackerChatSubscription?.unsubscribe();
        _trackerChatSubscription = SupabaseService.client
            .channel('tracker-chat-notif-${activeOrder.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'order_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'order_id',
                value: activeOrder.id,
              ),
              callback: (payload) {
                if (payload.newRecord.isNotEmpty && mounted) {
                  final newMsg = payload.newRecord;
                  if (newMsg['sender_id'] != user.id) {
                    setState(() {
                      _unreadChatCount++;
                    });
                  }
                }
              },
            )
            .subscribe();
      } catch (_) {}
    });
  }

  void _listenForRealtimeDriverLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final activeOrder = orderProvider.activeOrder;
      if (activeOrder == null) return;

      if (_currentSubscribedOrderId == activeOrder.id) return;
      _currentSubscribedOrderId = activeOrder.id;

      // Set initial driver position if valid in order model
      if (_isValidCoordinate(activeOrder.driverLatitude, activeOrder.driverLongitude)) {
        setState(() {
          _liveDriverPos = LatLng(activeOrder.driverLatitude!, activeOrder.driverLongitude!);
        });
      }

      try {
        _driverLocationSubscription?.unsubscribe();
        _driverLocationSubscription = SupabaseService.client
            .channel('tracker-driver-pos-${activeOrder.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'orders',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: activeOrder.id,
              ),
              callback: (payload) {
                if (payload.newRecord.isNotEmpty && mounted) {
                  final rec = payload.newRecord;
                  final lat = (rec['driver_latitude'] as num?)?.toDouble() ?? (rec['driver_lat'] as num?)?.toDouble();
                  final lng = (rec['driver_longitude'] as num?)?.toDouble() ?? (rec['driver_lng'] as num?)?.toDouble();
                  
                  if (_isValidCoordinate(lat, lng)) {
                    final newPos = LatLng(lat!, lng!);
                    setState(() {
                      _liveDriverPos = newPos;
                    });
                  }

                  // Refresh active order data in provider to update status, driver info, etc.
                  orderProvider.fetchOrderById(activeOrder.id);
                }
              },
            )
            .subscribe();
      } catch (_) {}
    });
  }

  LatLng _getUserLocation(WaterOrder order) {
    if (_isValidCoordinate(order.latitude, order.longitude)) {
      return LatLng(order.latitude!, order.longitude!);
    }
    final userProfile = Provider.of<UserProvider>(context, listen: false).profile;
    if (_isValidCoordinate(userProfile?.latitude, userProfile?.longitude)) {
      return LatLng(userProfile!.latitude!, userProfile.longitude!);
    }
    return LatLng(_stationLocation.latitude - 0.003, _stationLocation.longitude + 0.003);
  }

  void _recenterMap(LatLng stationPos, LatLng driverPos, LatLng userPos, {bool hasDriver = true}) {
    if (!mounted) return;

    final List<LatLng> validPoints = [];
    if (_isValidLatLng(stationPos)) validPoints.add(stationPos);
    if (hasDriver && _isValidLatLng(driverPos)) validPoints.add(driverPos);
    if (_isValidLatLng(userPos)) validPoints.add(userPos);

    if (validPoints.isEmpty) return;
    if (validPoints.length == 1) {
      try { _mapController.move(validPoints.first, 15.0); } catch (_) {}
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(validPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40.0),
          maxZoom: 16.0,
          minZoom: 10.0,
        ),
      );
    } catch (_) {
      try {
        _mapController.move(hasDriver ? driverPos : stationPos, 15.0);
      } catch (_) {}
    }
  }

  List<LatLng> _roadRoutePoints = [];
  LatLng? _lastRouteStart;
  LatLng? _lastRouteEnd;

  void _fetchRoadRouteIfNeeded(LatLng start, LatLng end) {
    if (_lastRouteStart?.latitude == start.latitude &&
        _lastRouteStart?.longitude == start.longitude &&
        _lastRouteEnd?.latitude == end.latitude &&
        _lastRouteEnd?.longitude == end.longitude) {
      return;
    }

    _lastRouteStart = start;
    _lastRouteEnd = end;

    RouteService.fetchRoadRoute(start, end).then((points) {
      if (mounted && points.length >= 2) {
        setState(() {
          _roadRoutePoints = points;
        });
      }
    });
  }

  List<LatLng> _buildRoutePoints(LatLng station, LatLng rider, LatLng user) {
    final List<LatLng> raw = [station, rider, user];
    final List<LatLng> valid = [];
    for (var p in raw) {
      if (_isValidLatLng(p)) {
        if (valid.isEmpty || (valid.last.latitude != p.latitude || valid.last.longitude != p.longitude)) {
          valid.add(p);
        }
      }
    }
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    final order = Provider.of<OrderProvider>(context).activeOrder;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    final deliveryLocation = order != null ? _getUserLocation(order) : _defaultDeliveryLocation;
    
    // Check if driver/rider has been assigned by admin
    final bool hasDriver = order != null &&
        ((order.driverId != null && order.driverId!.trim().isNotEmpty) ||
         (order.driverName != null && order.driverName!.trim().isNotEmpty) ||
         (order.status != OrderStatus.pending && order.status != OrderStatus.confirmed));

    // Live Rider position from DB stream, or order model, or station as starting hub
    LatLng currentRiderPos = _stationLocation;
    if (_isValidLatLng(_liveDriverPos)) {
      currentRiderPos = _liveDriverPos!;
    } else if (order != null && _isValidCoordinate(order.driverLatitude, order.driverLongitude)) {
      currentRiderPos = LatLng(order.driverLatitude!, order.driverLongitude!);
    }

    final bool hasLiveRiderLocation = hasDriver && (_isValidLatLng(_liveDriverPos) || _isValidCoordinate(order.driverLatitude, order.driverLongitude));
    
    // Fetch road route dynamically
    _fetchRoadRouteIfNeeded(hasDriver ? currentRiderPos : _stationLocation, deliveryLocation);

    final displayRoutePoints = _roadRoutePoints.length >= 2
        ? _roadRoutePoints
        : _buildRoutePoints(_stationLocation, hasDriver ? currentRiderPos : _stationLocation, deliveryLocation);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dispatch Tracker'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/main');
            }
          },
        ),
      ),
      body: order == null
          ? _buildEmptyState(context, textColor, subTextColor)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // OpenStreetMap Tracker View connected to Supabase Realtime DB
                  Stack(
                    children: [
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: hasDriver ? currentRiderPos : _stationLocation,
                              initialZoom: 14.5,
                              minZoom: 3.0,
                              maxZoom: 18.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.aquasync_user_app',
                              ),
                              if (displayRoutePoints.length >= 2)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: displayRoutePoints,
                                      strokeWidth: 4.5,
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  // Admin / Station Location Marker (Dynamic from Admin Profile DB)
                                  Marker(
                                    point: _stationLocation,
                                    width: 80,
                                    height: 70,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF075985),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _stationName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Rider Live Location Marker (Shown ONLY when rider is assigned)
                                  if (hasDriver)
                                    Marker(
                                      point: currentRiderPos,
                                      width: 80,
                                      height: 70,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              order.driverName ?? 'Rider',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 18),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Customer / Delivery Address Marker
                                  Marker(
                                    point: deliveryLocation,
                                    width: 80,
                                    height: 70,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Your Address',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const Icon(Icons.location_pin, color: Color(0xFFDC2626), size: 28),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Realtime Database Connection Badge & Controls
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: (hasDriver && hasLiveRiderLocation) ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                !hasDriver
                                    ? (order.status == OrderStatus.pending
                                        ? 'WAITING FOR CONFIRMATION'
                                        : 'AWAITING RIDER ASSIGNMENT')
                                    : (hasLiveRiderLocation ? 'LIVE REALTIME RIDER' : 'RIDER AT STATION'),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Recenter Map Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter_map',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0284C7),
                          elevation: 3,
                          onPressed: () => _recenterMap(_stationLocation, currentRiderPos, deliveryLocation, hasDriver: hasDriver),
                          child: const Icon(Icons.my_location_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Header Order Info Card
                  _buildOrderInfoCard(order),
                  const SizedBox(height: 20),
                  
                  // Rider Info Card with Real Call & Chat Functionality (Shown ONLY when rider is assigned)
                  if (hasDriver) ...[
                    _buildRiderInfoCard(context, order, cardBg, textColor, subTextColor, borderColor),
                    const SizedBox(height: 20),
                  ],

                  // Rating Section
                  if (order.status == OrderStatus.delivered || order.status == OrderStatus.completed) ...[
                    _buildRatingSection(context, order, subTextColor),
                    const SizedBox(height: 20),
                  ],

                  Text('Delivery Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),

                  // Modern Vertical Step Indicator
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: _buildModernTimeline(order.status, textColor, subTextColor, isDark),
                  ),

                  const SizedBox(height: 24),
                  if (order.status == OrderStatus.pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: () => _showCancelDialog(context),
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                        label: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed('/main');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardBg,
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('BACK TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined, size: 50, color: Color(0xFF0284C7)),
            ),
            const SizedBox(height: 20),
            Text('No Active Dispatch Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 6),
            Text('Place a new order to track live delivery status', style: TextStyle(color: subTextColor)),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/order'),
              child: const Text('ORDER WATER NOW'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(WaterOrder order) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2573), Color(0xFF266CA9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2573).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Order #${order.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(order.status),
            ],
          ),
          const Divider(height: 24, color: Colors.white24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.product,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
                    Text(
                      '${order.quantity} Gallons • ₱${order.totalAmount.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String> _getActualDriverPhone(WaterOrder order) async {
    // 1. ALWAYS query the driver's database profile first using driverId (to ensure we get the correct updated number from the driver's database profile)
    if (order.driverId != null && order.driverId!.trim().isNotEmpty) {
      final tables = ['profiles', 'drivers', 'riders', 'delivery_personnel', 'users'];
      for (final tbl in tables) {
        try {
          final res = await SupabaseService.client
              .from(tbl)
              .select('phone, phone_number, mobile, contact_number, contact, telephone, mobile_number, phone_no')
              .eq('id', order.driverId!)
              .maybeSingle();
          if (res != null) {
            final p = res['phone'] ?? res['phone_number'] ?? res['mobile'] ?? res['contact_number'] ?? res['contact'] ?? res['telephone'] ?? res['mobile_number'] ?? res['phone_no'];
            if (p != null && p.toString().trim().isNotEmpty) {
              return p.toString().trim();
            }
          }
        } catch (_) {}

        try {
          final res = await SupabaseService.client
              .from(tbl)
              .select('phone, phone_number, mobile, contact_number, contact, telephone, mobile_number, phone_no')
              .eq('user_id', order.driverId!)
              .maybeSingle();
          if (res != null) {
            final p = res['phone'] ?? res['phone_number'] ?? res['mobile'] ?? res['contact_number'] ?? res['contact'] ?? res['telephone'] ?? res['mobile_number'] ?? res['phone_no'];
            if (p != null && p.toString().trim().isNotEmpty) {
              return p.toString().trim();
            }
          }
        } catch (_) {}
      }
    }

    // 2. Query by driverName if driverId didn't yield a phone
    if (order.driverName != null && order.driverName!.trim().isNotEmpty) {
      final tables = ['profiles', 'drivers', 'riders', 'delivery_personnel', 'users'];
      for (final tbl in tables) {
        try {
          final res = await SupabaseService.client
              .from(tbl)
              .select('phone, phone_number, mobile, contact_number, contact, telephone, mobile_number, phone_no')
              .ilike('full_name', '%${order.driverName!.trim()}%')
              .maybeSingle();
          if (res != null) {
            final p = res['phone'] ?? res['phone_number'] ?? res['mobile'] ?? res['contact_number'] ?? res['contact'] ?? res['telephone'] ?? res['mobile_number'] ?? res['phone_no'];
            if (p != null && p.toString().trim().isNotEmpty) {
              return p.toString().trim();
            }
          }
        } catch (_) {}
      }
    }

    // 3. Fall back to order.driverPhone if database profile lookup didn't find anything
    if (order.driverPhone != null && order.driverPhone!.trim().isNotEmpty && order.driverPhone != '+639123456789') {
      return order.driverPhone!.trim();
    }

    // 4. Fall back to shop/station profile phone
    try {
      final shopData = await SupabaseService.fetchShopProfile();
      final p = shopData['phone'] ?? shopData['phone_number'] ?? shopData['station_phone'];
      if (p != null && p.toString().trim().isNotEmpty) {
        return p.toString().trim();
      }
    } catch (_) {}

    return order.driverPhone ?? '+639123456789';
  }

  Widget _buildRiderInfoCard(BuildContext context, WaterOrder order, Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    final driverName = order.driverName ?? 'Assigned Station Rider';

    return FutureBuilder<String>(
      future: _getActualDriverPhone(order),
      builder: (context, snapshot) {
        final driverPhone = snapshot.data ?? order.driverPhone ?? '+639123456789';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF0284C7),
                child: Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    Text(
                      driverPhone.isNotEmpty && driverPhone != '+639123456789' ? 'Phone: $driverPhone' : 'Station Delivery Personnel',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final phoneToCall = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data! : driverPhone;
                  final Uri phoneUri = Uri(scheme: 'tel', path: phoneToCall);
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else {
                    if (context.mounted) {
                      TopBanner.show(context, 'Could not launch phone dialer', isError: true);
                    }
                  }
                },
                icon: const Icon(Icons.phone_rounded, color: Color(0xFF16A34A)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 6),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _unreadChatCount = 0;
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OrderChatScreen(order: order)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF0284C7)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                ),
              ),
              if (_unreadChatCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        '$_unreadChatCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildRatingSection(BuildContext context, WaterOrder order, Color subTextColor) {
    final hasAlreadyRated = (order.rating != null && order.rating! > 0) || (order.review != null && order.review!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasAlreadyRated 
            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
            : const Color(0xFF0284C7).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAlreadyRated 
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : const Color(0xFF0284C7).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                hasAlreadyRated ? Icons.check_circle_rounded : Icons.star_rounded, 
                color: hasAlreadyRated ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Text(
                hasAlreadyRated ? 'Thank You For Your Rating!' : 'Rate Your Delivery',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasAlreadyRated ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: hasAlreadyRated 
                ? null 
                : () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewScreen(order: order))),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasAlreadyRated ? Colors.grey : const Color(0xFF0284C7), 
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(hasAlreadyRated ? 'RATED SUCCESSFULLY' : 'RATE NOW', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(OrderStatus s) {
    Color badgeColor;
    switch (s) {
      case OrderStatus.pending:
        badgeColor = const Color(0xFFD97706);
        break;
      case OrderStatus.confirmed:
      case OrderStatus.assigned:
      case OrderStatus.accepted:
      case OrderStatus.outForDelivery:
        badgeColor = const Color(0xFF0284C7);
        break;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        badgeColor = const Color(0xFF16A34A);
        break;
      case OrderStatus.cancelled:
        badgeColor = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        WaterOrder.toDisplayLabel(s).toUpperCase(),
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) async {
    final order = Provider.of<OrderProvider>(context, listen: false).activeOrder;
    if (order == null) return;

    final confirm = await SweetAlert.showConfirm(
      context,
      title: 'Cancel Order?',
      message: 'Are you sure you want to cancel this pending order?',
      confirmText: 'Yes, Cancel',
      cancelText: 'Keep Order',
      isDanger: true,
    );

    if (confirm == true) {
      final user = SupabaseService.currentUser;
      if (user != null && order.status == OrderStatus.pending) {
        try {
          await SupabaseService.cancelCustomerOrder(
            orderId: order.id,
            customerId: user.id,
            reason: 'Cancelled by customer from order tracker',
            existingNotes: order.notes,
          );

          if (context.mounted) {
            await Provider.of<OrderProvider>(context, listen: false).fetchMyOrders();
            TopBanner.show(context, 'Pending order cancelled successfully.', isError: false);
          }
        } catch (e) {
          if (context.mounted) {
            await Provider.of<OrderProvider>(context, listen: false).fetchMyOrders();
            TopBanner.show(context, 'Pending order cancelled successfully.', isError: false);
          }
        }
      }
    }
  }

  Widget _buildModernTimeline(OrderStatus current, Color textColor, Color subTextColor, bool isDark) {
    final stages = [
      {'s': OrderStatus.pending, 't': 'Order Placed', 'sub': 'Waiting for station to confirm', 'icon': Icons.assignment_turned_in_rounded},
      {'s': OrderStatus.confirmed, 't': 'Confirmed', 'sub': 'Station is preparing your order', 'icon': Icons.inventory_2_rounded},
      {'s': OrderStatus.assigned, 't': 'Rider Assigned', 'sub': 'A rider has been designated', 'icon': Icons.person_pin_circle_rounded},
      {'s': OrderStatus.outForDelivery, 't': 'Out for Delivery', 'sub': 'Rider is on the way to you', 'icon': Icons.delivery_dining_rounded},
      {'s': OrderStatus.delivered, 't': 'Arrived', 'sub': 'Water delivered at your door', 'icon': Icons.home_work_rounded},
    ];

    return Column(
      children: stages.map((stage) {
        final index = stages.indexOf(stage);
        final isLast = index == stages.length - 1;
        final status = stage['s'] as OrderStatus;

        bool isCompleted = current.index > status.index || current == OrderStatus.completed;
        bool isActive = current == status;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF16A34A)
                          : (isActive ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0))),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : (isActive
                              ? const Icon(Icons.circle, size: 12, color: Colors.white)
                              : Icon(stage['icon'] as IconData, size: 14, color: subTextColor)),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 2,
                        color: isCompleted ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage['t'] as String,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isActive ? const Color(0xFF0284C7) : (isCompleted ? textColor : subTextColor),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage['sub'] as String,
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
