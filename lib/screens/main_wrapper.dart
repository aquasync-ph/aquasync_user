import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'home_screen.dart';
import 'history_screen.dart';
import 'gallon_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import '../providers/settings_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../providers/notification_provider.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/app_tutorial_overlay.dart';
import '../theme/premium_theme.dart';

class MainWrapper extends StatefulWidget {
  final int initialIndex;
  const MainWrapper({super.key, this.initialIndex = 0});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late int _currentIndex;
  bool _initializedFromArgs = false;

  final List<Widget> _pages = const [
    HomeScreen(),
    HistoryScreen(),
    GallonPage(),
    ChatPage(), // Help / Support page
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    TutorialService.instance.registerTabChangeCallback((index) {
      if (mounted && _currentIndex != index) {
        setState(() => _currentIndex = index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.profile?.id ?? SupabaseService.currentUser?.id ?? '';
      
      // Initialize Real-Time Notifications and Orders immediately upon app startup / login
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
      Provider.of<OrderProvider>(context, listen: false).fetchMyOrders();

      await TutorialService.instance.init(userId);
      if (!TutorialService.instance.hasSeenTutorial && mounted) {
        TutorialService.instance.startTutorial();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args < _pages.length) {
        _currentIndex = args;
      }
      _initializedFromArgs = true;
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final hasActiveOrder = orderProvider.activeOrder != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final barBg = isDark ? const Color(0xFF0F1D32).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.75);
    final borderColor = isDark ? const Color(0xFF1E3A5F).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5);
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final items = [
      _NavItemData(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        labelKey: 'home',
        key: TutorialService.instance.homeTabKey,
      ),
      _NavItemData(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        labelKey: 'orders',
        hasBadge: hasActiveOrder,
        key: TutorialService.instance.ordersTabKey,
      ),
      _NavItemData(
        icon: Icons.water_drop_outlined,
        activeIcon: Icons.water_drop_rounded,
        labelKey: 'gallons',
        key: TutorialService.instance.gallonsTabKey,
      ),
      _NavItemData(
        icon: Icons.help_outline_rounded,
        activeIcon: Icons.help_rounded,
        labelKey: 'help',
        key: TutorialService.instance.helpTabKey,
      ),
      _NavItemData(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        labelKey: 'profile',
        key: TutorialService.instance.profileTabKey,
      ),
    ];

    return AppTutorialOverlay(
      child: Scaffold(
        body: _FadeIndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        extendBody: true,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 16, top: 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isSelected = _currentIndex == index;
                      final label = LocalizationService.translate(context, item.labelKey, settings.language);

                      return Expanded(
                        flex: isSelected ? 2 : 1,
                        child: GestureDetector(
                          key: item.key,
                          onTap: () => _onTabTapped(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 10 : 4,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppGradients.electric : null,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      isSelected ? item.activeIcon : item.icon,
                                      color: isSelected ? Colors.white : unselectedColor,
                                      size: 20,
                                    ),
                                    if (item.hasBadge && !isSelected)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: AppColors.danger,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: barBg.withValues(alpha: 1.0),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final GlobalKey key;
  final bool hasBadge;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
    required this.key,
    this.hasBadge = false,
  });
}

class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _currentIndex = widget.index;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1.0).animate(_animation),
        child: IndexedStack(
          index: _currentIndex,
          children: widget.children,
        ),
      ),
    );
  }
}
