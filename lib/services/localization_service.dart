import 'package:flutter/material.dart';
import '../models/app_language.dart';

class LocalizationService {
  static const Map<String, Map<AppLanguage, String>> _translations = {
    'home': {
      AppLanguage.english: 'HOME',
      AppLanguage.tagalog: 'HOME',
    },
    'orders': {
      AppLanguage.english: 'ORDERS',
      AppLanguage.tagalog: 'ORDERS',
    },
    'gallons': {
      AppLanguage.english: 'GALLONS',
      AppLanguage.tagalog: 'GALON',
    },
    'help': {
      AppLanguage.english: 'HELP',
      AppLanguage.tagalog: 'TULONG',
    },
    'profile': {
      AppLanguage.english: 'PROFILE',
      AppLanguage.tagalog: 'PROFILE',
    },
    'settings': {
      AppLanguage.english: 'App Settings',
      AppLanguage.tagalog: 'Mga Setting',
    },
    'dark_mode': {
      AppLanguage.english: 'Dark Mode',
      AppLanguage.tagalog: 'Madilim na Tema',
    },
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.tagalog: 'Wika',
    },
    'ready_to_order': {
      AppLanguage.english: 'Ready to order water?',
      AppLanguage.tagalog: 'Handa nang umorder ng tubig?',
    },
    'order_water': {
      AppLanguage.english: 'ORDER WATER',
      AppLanguage.tagalog: 'UMORDER NG TUBIG',
    },
    'my_active_order': {
      AppLanguage.english: 'MY ACTIVE ORDER',
      AppLanguage.tagalog: 'AKING AKTIBONG ORDER',
    },
  };

  static String translate(BuildContext context, String key, AppLanguage lang) {
    return _translations[key]?[lang] ?? key;
  }
}
