import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_language.dart';

class TutorialStep {
  final String id;
  final GlobalKey key;
  final String titleEn;
  final String titleTl;
  final String descriptionEn;
  final String descriptionTl;
  final int targetTabIndex;
  final IconData icon;

  const TutorialStep({
    required this.id,
    required this.key,
    required this.titleEn,
    required this.titleTl,
    required this.descriptionEn,
    required this.descriptionTl,
    this.targetTabIndex = -1,
    this.icon = Icons.info_outline_rounded,
  });

  String getTitle(AppLanguage lang) => lang == AppLanguage.tagalog ? titleTl : titleEn;
  String getDescription(AppLanguage lang) => lang == AppLanguage.tagalog ? descriptionTl : descriptionEn;
}

class TutorialService with ChangeNotifier {
  static final TutorialService instance = TutorialService._internal();
  factory TutorialService() => instance;
  TutorialService._internal();

  static const String _prefKey = 'has_seen_app_tutorial_v1';

  // Global Keys for targeting UI components across the app
  final GlobalKey homeTabKey = GlobalKey(debugLabel: 'homeTab');
  final GlobalKey ordersTabKey = GlobalKey(debugLabel: 'ordersTab');
  final GlobalKey gallonsTabKey = GlobalKey(debugLabel: 'gallonsTab');
  final GlobalKey helpTabKey = GlobalKey(debugLabel: 'helpTab');
  final GlobalKey profileTabKey = GlobalKey(debugLabel: 'profileTab');
  final GlobalKey orderButtonKey = GlobalKey(debugLabel: 'orderButton');
  final GlobalKey notificationButtonKey = GlobalKey(debugLabel: 'notificationButton');
  final GlobalKey stationStatusKey = GlobalKey(debugLabel: 'stationStatusKey');

  void recreateKeys() {
    // Keep keys stable to prevent duplicate GlobalKey reparenting issues during layout
  }

  bool _hasSeenTutorial = false;
  bool _isTutorialActive = false;
  int _currentStepIndex = 0;
  String _currentUserId = '';
  Function(int)? _onTabChangeCallback;

  bool get hasSeenTutorial => _hasSeenTutorial;
  bool get isTutorialActive => _isTutorialActive;
  int get currentStepIndex => _currentStepIndex;

  String _getUserPrefKey(String? userId) {
    final uid = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;
    if (uid.isNotEmpty) {
      return 'has_seen_app_tutorial_v2_$uid';
    }
    return _prefKey;
  }

  List<TutorialStep> get steps => [
        TutorialStep(
          id: 'home_dashboard',
          key: homeTabKey,
          targetTabIndex: 0,
          icon: Icons.home_rounded,
          titleEn: 'Home Dashboard',
          titleTl: 'Pangunahing Pahina',
          descriptionEn: 'This is your main dashboard. View station operational status, active announcements, and quick refill actions.',
          descriptionTl: 'Dito mo makikita ang pangkalahatang status ng iyong account, live status ng water station, at mga anunsyo.',
        ),
        TutorialStep(
          id: 'notification_alerts',
          key: notificationButtonKey,
          targetTabIndex: 0,
          icon: Icons.notifications_active_rounded,
          titleEn: 'Notifications & Alerts',
          titleTl: 'Mga Abiso at Alert',
          descriptionEn: 'Tap this bell icon anytime to check instant alerts on your order delivery progress, station announcements, and promos.',
          descriptionTl: 'I-tap ang kampana para makita ang mga instant updates sa iyong order delivery at mga anunsyo mula sa station.',
        ),
        TutorialStep(
          id: 'order_water',
          key: orderButtonKey,
          targetTabIndex: 0,
          icon: Icons.water_drop_rounded,
          titleEn: 'Order Water Refill',
          titleTl: 'Mag-order ng Refill',
          descriptionEn: 'Tap this button to place a water refill order. Choose Purified or Mineral water, gallon quantity, and delivery schedule.',
          descriptionTl: 'Ito ang button para mag-order! Pumili ng klase ng tubig (Purified/Mineral), dami ng galon, at oras ng delivery.',
        ),
        TutorialStep(
          id: 'orders_tracker',
          key: ordersTabKey,
          targetTabIndex: 1,
          icon: Icons.receipt_long_rounded,
          titleEn: 'Live Orders & History',
          titleTl: 'Subaybayan ang Order',
          descriptionEn: 'Track your water delivery rider in real-time on an interactive map, or view your past receipts and order history.',
          descriptionTl: 'Dito mo masasubaybayan sa live map ang kinaroroonan ng delivery rider at ang iyong mga nakaraang resibo.',
        ),
        TutorialStep(
          id: 'gallons_inventory',
          key: gallonsTabKey,
          targetTabIndex: 2,
          icon: Icons.inventory_2_rounded,
          titleEn: 'Gallon Inventory',
          titleTl: 'Inventory ng Galon',
          descriptionEn: 'Keep track of your borrowed, returned, and owned water containers (Slim & Round gallons) effortlessly.',
          descriptionTl: 'Subaybayan ang iyong hiram, naibalik, at sariling galon (Slim o Round) para laging updated ang iyong balanse.',
        ),
        TutorialStep(
          id: 'chat_support',
          key: helpTabKey,
          targetTabIndex: 3,
          icon: Icons.support_agent_rounded,
          titleEn: 'Station Chat & Support',
          titleTl: 'Tulong at Chat',
          descriptionEn: 'Need help or have special delivery instructions? Chat directly with AquaSync water station staff in real-time.',
          descriptionTl: 'May katanungan o bilin sa delivery? Kausapin nang direkta ang mga tauhan ng water station para sa mabilis na tulong.',
        ),
        TutorialStep(
          id: 'profile_settings',
          key: profileTabKey,
          targetTabIndex: 4,
          icon: Icons.person_rounded,
          titleEn: 'Profile & Settings',
          titleTl: 'Profile at Settings',
          descriptionEn: 'Manage your profile details, default delivery address, dark mode theme, app language, or restart this tutorial anytime!',
          descriptionTl: 'Dito mo maaayos ang iyong profile, saved delivery address, Dark Mode, wika, at maaari mong ulitin ang tutorial na ito.',
        ),
      ];

  Future<void> init([String? userId]) async {
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getUserPrefKey(_currentUserId);
      _hasSeenTutorial = prefs.getBool(key) ?? false;
    } catch (_) {
      _hasSeenTutorial = false;
    }
    notifyListeners();
  }

  void registerTabChangeCallback(Function(int) callback) {
    _onTabChangeCallback = callback;
  }

  void startTutorial({bool force = false}) {
    if (!force && _hasSeenTutorial) return;

    _isTutorialActive = true;
    _currentStepIndex = 0;

    _syncTabWithCurrentStep();
    notifyListeners();
  }

  void _syncTabWithCurrentStep() {
    if (_currentStepIndex >= 0 && _currentStepIndex < steps.length) {
      final step = steps[_currentStepIndex];
      if (step.targetTabIndex != -1 && _onTabChangeCallback != null) {
        _onTabChangeCallback!(step.targetTabIndex);
      }
    }
  }

  void nextStep() {
    if (_currentStepIndex < steps.length - 1) {
      _currentStepIndex++;
      _syncTabWithCurrentStep();
      notifyListeners();
    } else {
      completeTutorial();
    }
  }

  void prevStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _syncTabWithCurrentStep();
      notifyListeners();
    }
  }

  Future<void> completeTutorial() async {
    _isTutorialActive = false;
    _hasSeenTutorial = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getUserPrefKey(_currentUserId);
      await prefs.setBool(key, true);
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
  }

  Future<void> skipTutorial() async {
    await completeTutorial();
  }

  Future<void> resetTutorial([String? userId]) async {
    _hasSeenTutorial = false;
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getUserPrefKey(_currentUserId);
      await prefs.remove(key);
      await prefs.remove(_prefKey);
    } catch (_) {}
    notifyListeners();
  }
}
