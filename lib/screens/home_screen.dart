import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/notification_provider.dart';
import '../providers/announcement_provider.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';
import '../services/tutorial_service.dart';
import '../models/announcement.dart';
import '../models/app_language.dart';
import '../services/supabase_service.dart';
import '../services/route_service.dart';
import '../theme/premium_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasShownAutoAnnouncement = false;
  Map<String, dynamic>? _shopProfile;

  @override
  void initState() {
    super.initState();
    TutorialService.instance.addListener(_onTutorialChanged);
    _loadShopProfile();

    SupabaseService.subscribeToShopProfile(
      onShopProfileChanged: () {
        _loadShopProfile();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
      final op = Provider.of<OrderProvider>(context, listen: false);
      op.fetchMyOrders();
      op.fetchProducts();
      final ap = Provider.of<AnnouncementProvider>(context, listen: false);
      await ap.fetchAnnouncements();
    });
  }

  Future<void> _loadShopProfile() async {
    try {
      final shopData = await SupabaseService.fetchShopProfile();
      if (mounted) {
        setState(() {
          _shopProfile = shopData;
        });
      }
    } catch (e) {
      debugPrint('Error loading shop profile in HomeScreen: $e');
    }
  }

  @override
  void dispose() {
    SupabaseService.unsubscribeShopProfile();
    TutorialService.instance.removeListener(_onTutorialChanged);
    super.dispose();
  }

  void _onTutorialChanged() {
    if (!mounted) return;
  }

  void _checkAndShowAutoAnnouncement(List<Announcement> announcements) {
    if (_hasShownAutoAnnouncement) return;
    if (TutorialService.instance.isTutorialActive || !TutorialService.instance.hasSeenTutorial) {
      return;
    }
    _hasShownAutoAnnouncement = true;
    _showAnnouncementsDialog(announcements);
  }

  void _showAnnouncementsDialog(List<Announcement> announcements) {
    if (announcements.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AnnouncementsDialog(announcements: announcements),
    );
  }

  String _getGreetingText(AppLanguage lang) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return lang == AppLanguage.tagalog ? "Magandang umaga" : "Good morning";
    } else if (hour < 18) {
      return lang == AppLanguage.tagalog ? "Magandang hapon" : "Good afternoon";
    } else {
      return lang == AppLanguage.tagalog ? "Magandang gabi" : "Good evening";
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<UserProvider>(context).profile;
    final activeOrder = Provider.of<OrderProvider>(context).activeOrder;
    final settings = Provider.of<SettingsProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      body: Stack(
        children: [
          // Wave Header Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: HeaderWaveClipper(),
              child: Container(
                height: 280,
                decoration: const BoxDecoration(
                  gradient: AppGradients.ocean,
                ),
              ),
            ),
          ),

          // Water Droplets Glass Decoration
          Positioned.fill(
            child: CustomPaint(
              painter: WaterDropletsPainter(isDark: isDark),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadShopProfile();
                Provider.of<OrderProvider>(context, listen: false).fetchMyOrders();
                Provider.of<OrderProvider>(context, listen: false).fetchProducts();
                Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'AquaSync',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        _tutorialButton(context, isDark),
                        _announcementButton(context, isDark),
                        _notificationButton(context, isDark),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Greeting
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreetingText(settings.language)},',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          profile?.firstName ?? 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LocalizationService.translate(context, 'ready_to_order', settings.language),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Station Status GlassCard
                    _stationStatusCardPremium(context, isDark, textColor, subTextColor),
                    const SizedBox(height: 20),

                    // Hero Order Button
                    _heroOrderButton(context),
                    const SizedBox(height: 28),

                    // OUR WATER PRODUCTS SECTION
                    _productsSectionPremium(context, isDark, textColor, subTextColor),
                    const SizedBox(height: 24),

                    // ACTIVE ORDER SECTION
                    if (activeOrder != null && activeOrder.status != OrderStatus.completed && activeOrder.status != OrderStatus.cancelled) ...[
                      _activeOrderCardPremium(context, activeOrder, textColor, subTextColor),
                    ] else ...[
                      _noActiveOrderCardPremium(context, textColor, subTextColor),
                    ],
                    const SizedBox(height: 100), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final provider = Provider.of<AnnouncementProvider>(context, listen: false);
        final announcements = provider.announcements;
        if (announcements.isNotEmpty) {
          _showAnnouncementsDialog(announcements);
        } else {
          provider.fetchAnnouncements().then((_) {
            if (mounted && provider.announcements.isNotEmpty) {
              _showAnnouncementsDialog(provider.announcements);
            }
          });
        }
      },
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.campaign_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _tutorialButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        TutorialService.instance.startTutorial(force: true);
      },
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.help_outline_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _notificationButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed('/notifications');
      },
      child: Container(
        key: TutorialService.instance.notificationButtonKey,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            final unread = provider.unreadCount;
            final hasUnread = unread > 0;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  hasUnread ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stationStatusCardPremium(BuildContext context, bool isDark, Color textColor, Color subTextColor) {
    final shopData = _shopProfile ?? {
      'latitude': 14.2290,
      'longitude': 121.3280,
      'coverage_radius_km': 0.5,
      'full_name': 'Aqua Pure Water Station',
      'address': 'Victoria, Laguna',
      'is_open': true,
      'operating_hours': '7 AM – 7 PM',
    };

    final isOpen = SupabaseService.isStationOpen(shopData);
    final statusColor = isOpen ? const Color(0xFF10B981) : AppColors.warning;
    final operatingHours = SupabaseService.getOperatingHoursDisplay(shopData);
    final stationName = (shopData['full_name'] as String? ?? shopData['station_name'] as String? ?? 'Main Refilling Station');

    return GlassCard(
      key: TutorialService.instance.stationStatusKey,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF0284C7), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOpen ? 'STATION OPEN' : 'STATION CLOSED',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stationName.isNotEmpty ? stationName : 'Main Refilling Station',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor, letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showShopLocationModal(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.map_rounded, color: Color(0xFF0284C7), size: 18),
                      SizedBox(height: 2),
                      Text(
                        'LOCATION',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: textColor.withValues(alpha: 0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _statusDetail(Icons.schedule_rounded, operatingHours, subTextColor)),
              const SizedBox(width: 8),
              Flexible(child: _statusDetail(Icons.timer_outlined, isOpen ? '25m delivery' : 'Closed now', subTextColor)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showShopLocationModal(BuildContext context) async {
    final userProfile = Provider.of<UserProvider>(context, listen: false).profile;

    // Default shop coordinates (Victoria, Laguna - Aqua Pure Water Station)
    double shopLat = 14.2290;
    double shopLng = 121.3280;
    double coverageRadiusKm = 0.5;
    String shopName = 'Aqua Pure Water Station';
    String shopAddress = 'Victoria, Laguna';

    // 1. Fetch Admin/Shop location from database
    try {
      final shopData = await SupabaseService.fetchShopProfile();
      if (shopData['latitude'] != null && shopData['longitude'] != null) {
        shopLat = (shopData['latitude'] as num).toDouble();
        shopLng = (shopData['longitude'] as num).toDouble();
      }
      final nameVal = shopData['full_name'] as String? ?? shopData['station_name'] as String? ?? '';
      if (nameVal.isNotEmpty && nameVal != 'New User' && nameVal != 'Customer') {
        shopName = nameVal;
      }
      final addrVal = shopData['address'] as String? ?? '';
      if (addrVal.isNotEmpty) {
        shopAddress = addrVal;
      }
      if (shopData['coverage_radius_km'] != null) {
        coverageRadiusKm = (shopData['coverage_radius_km'] as num).toDouble();
      }
    } catch (_) {}

    // 2. User coordinates
    double userLat = userProfile?.latitude ?? 14.5800;
    double userLng = userProfile?.longitude ?? 120.9800;
    
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      userLat = pos.latitude;
      userLng = pos.longitude;
    } catch (_) {}

    // Distance calculation
    final distanceMeters = Geolocator.distanceBetween(userLat, userLng, shopLat, shopLng);
    final distanceKm = distanceMeters / 1000.0;
    final estMinutes = (distanceKm * 3.5).round().clamp(5, 60);

    final shopPoint = LatLng(shopLat, shopLng);
    final userPoint = LatLng(userLat, userLng);
    final centerPoint = LatLng((shopLat + userLat) / 2, (shopLng + userLng) / 2);

    // Fetch real road route geometry from OSRM
    final roadRoutePoints = await RouteService.fetchRoadRoute(userPoint, shopPoint);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = Theme.of(ctx).cardColor;
        final txt = Theme.of(ctx).colorScheme.onSurface;
        final subTxt = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Header Drag Handle & Title
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shop Location & Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
                          Text('Distance from your current position', style: TextStyle(fontSize: 12, color: subTxt)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Interactive FlutterMap View
              Expanded(
                child: ClipRRect(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: centerPoint,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.aquasync_user_app',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: shopPoint,
                            radius: coverageRadiusKm * 1000.0,
                            useRadiusInMeter: true,
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            borderColor: const Color(0xFF0284C7),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: roadRoutePoints,
                            color: const Color(0xFF0284C7),
                            strokeWidth: 4.5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // Shop Marker
                          Marker(
                            point: shopPoint,
                            width: 50,
                            height: 50,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                          // User Marker
                          Marker(
                            point: userPoint,
                            width: 50,
                            height: 50,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Info Card & Directions Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: txt),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  shopAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: subTxt),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} KM',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0284C7)),
                                ),
                                Text(
                                  '~$estMinutes mins',
                                  style: TextStyle(fontSize: 11, color: subTxt, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final url = 'https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLng&destination=$shopLat,$shopLng';
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.directions_outlined, color: Colors.white),
                        label: const Text(
                          'OPEN DIRECTIONS IN GOOGLE MAPS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusDetail(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _heroOrderButton(BuildContext context) {
    return InkWell(
      key: TutorialService.instance.orderButtonKey,
      onTap: () => Navigator.of(context).pushNamed('/order'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Order Fresh Water Now',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsSectionPremium(BuildContext context, bool isDark, Color textColor, Color subTextColor) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final products = orderProvider.products;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'WATER PRODUCTS',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0284C7), letterSpacing: 1.0),
            ),
            Text(
              '${products.length} Available',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subTextColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final prod = products[index];
              return Container(
                width: 300,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF132A4A), const Color(0xFF0F223D)]
                        : [const Color(0xFFC7E7E6), const Color(0xFFE2F4F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBCE5E3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildProductGraphic(prod),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : const Color(0xFF0F1D32),
                                    height: 1.2,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₱${prod.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F1D32),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => Navigator.of(context).pushNamed('/order'),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SELECT',
                              style: TextStyle(
                                color: Color(0xFF033059),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: Color(0xFF033059), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _activeOrderCardPremium(BuildContext context, WaterOrder order, Color textColor, Color subTextColor) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ACTIVE DELIVERY', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  WaterOrder.toDisplayLabel(order.status).toUpperCase(),
                  style: const TextStyle(color: Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF0284C7), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.orderNumber}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor)),
                    Text('${order.product} • ${order.quantity} Gallons', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pushNamed('/tracker'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.map_rounded, color: Color(0xFF0284C7), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noActiveOrderCardPremium(BuildContext context, Color textColor, Color subTextColor) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.water_drop_outlined, color: subTextColor.withValues(alpha: 0.5), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NO ACTIVE ORDER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor)),
                Text('Ready for a refill?', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGraphic(Product prod) {
    if (prod.imageUrl != null && prod.imageUrl!.trim().isNotEmpty) {
      return Container(
        width: 110,
        height: 105,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            prod.imageUrl!.trim(),
            fit: BoxFit.contain,
            width: 110,
            height: 105,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading image for product ${prod.name} (${prod.imageUrl}): $error');
              return _buildWaterGallonGraphic();
            },
          ),
        ),
      );
    }
    return _buildWaterGallonGraphic();
  }

  Widget _buildWaterGallonGraphic() {
    return Container(
      width: 110,
      height: 105,
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: Container(
              width: 18,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            top: 18,
            child: Container(
              width: 60,
              height: 75,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.85),
                    const Color(0xFF0284C7).withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(height: 2, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  Container(height: 2, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  Container(height: 2, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 8)),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 45,
            child: Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint = Offset(size.width - (size.width / 4), size.height - 60);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class WaterDroplet {
  final Offset position;
  final double radius;
  final double opacity;
  const WaterDroplet(this.position, this.radius, this.opacity);
}

class WaterDropletsPainter extends CustomPainter {
  final bool isDark;
  WaterDropletsPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final droplets = [
      WaterDroplet(Offset(size.width * 0.85, size.height * 0.12), 18, 0.25),
      WaterDroplet(Offset(size.width * 0.92, size.height * 0.22), 10, 0.20),
      WaterDroplet(Offset(size.width * 0.80, size.height * 0.28), 7, 0.18),
      WaterDroplet(Offset(size.width * 0.08, size.height * 0.45), 14, 0.20),
      WaterDroplet(Offset(size.width * 0.76, size.height * 0.52), 12, 0.18),
      WaterDroplet(Offset(size.width * 0.78, size.height * 0.78), 16, 0.22),
      WaterDroplet(Offset(size.width * 0.18, size.height * 0.68), 8, 0.15),
    ];

    for (var d in droplets) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: d.opacity * 0.9),
            Colors.white.withValues(alpha: d.opacity * 0.3),
            const Color(0xFF0284C7).withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: d.position, radius: d.radius));

      canvas.drawCircle(d.position, d.radius, paint);

      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: d.opacity * 1.6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(d.position.dx - d.radius * 0.3, d.position.dy - d.radius * 0.3),
        d.radius * 0.28,
        highlightPaint,
      );

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(d.position, d.radius, shadowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnnouncementsDialog extends StatefulWidget {
  final List<Announcement> announcements;

  const _AnnouncementsDialog({required this.announcements});

  @override
  State<_AnnouncementsDialog> createState() => _AnnouncementsDialogState();
}

class _AnnouncementsDialogState extends State<_AnnouncementsDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dialogBg = Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 24,
      shadowColor: AppColors.paletteMidnight.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.paletteMedium.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header Row with Consistent Alignment
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppGradients.ocean,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.paletteMedium.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Announcements',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paletteNavy,
                          letterSpacing: -0.3,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Station News & Promos',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.slate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // PageView Area with Equal Alignment
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.announcements.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final a = widget.announcements[index];
                  Color primaryColor;
                  Color lightBg;
                  IconData icon;
                  String tagLabel;

                  switch (a.type) {
                    case AnnouncementType.promo:
                      primaryColor = const Color(0xFF10B981);
                      lightBg = const Color(0xFFECFDF5);
                      icon = Icons.stars_rounded;
                      tagLabel = 'SPECIAL PROMO';
                      break;
                    case AnnouncementType.warning:
                      primaryColor = const Color(0xFFEF4444);
                      lightBg = const Color(0xFFFEF2F2);
                      icon = Icons.warning_rounded;
                      tagLabel = 'IMPORTANT NOTICE';
                      break;
                    case AnnouncementType.info:
                      primaryColor = AppColors.paletteMedium;
                      lightBg = AppColors.paletteLight.withValues(alpha: 0.25);
                      icon = Icons.info_rounded;
                      tagLabel = 'STATION UPDATE';
                      break;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: primaryColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              tagLabel,
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                a.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppColors.paletteMidnight,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            if (widget.announcements.length > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.announcements.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.paletteMedium
                          : AppColors.subTextLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            LiquidButton(
              text: 'GOT IT',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

