import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class UserProfile {
  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final bool isVerified;

  UserProfile({
    this.id = '',
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    this.role = 'customer',
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.isVerified = true,
  });

  String get fullName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    }
    return 'Valued Customer';
  }

  factory UserProfile.fromSupabaseMap(Map<String, dynamic> data, String email) {
    final fullName = data['full_name'] as String? ?? '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final rawVerified = data['is_verified'];
    final approvalStatus = (data['approval_status'] as String? ?? '').toLowerCase();
    final status = (data['status'] as String? ?? '').toLowerCase();
    final isApproved = data['is_approved'];

    bool verified = true;
    if (rawVerified is bool) {
      verified = rawVerified;
    } else if (rawVerified is String) {
      verified = rawVerified.toLowerCase() == 'true' || rawVerified == '1';
    }

    if (approvalStatus == 'approved' || status == 'active' || isApproved == true) {
      verified = true;
    }

    return UserProfile(
      id: data['id'] as String? ?? '',
      firstName: firstName.isNotEmpty ? firstName : 'Customer',
      lastName: lastName,
      email: email,
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      role: data['role'] as String? ?? 'customer',
      avatarUrl: data['avatar_url'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble() ??
                (data['delivery_latitude'] as num?)?.toDouble() ??
                (data['lat'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble() ??
                 (data['delivery_longitude'] as num?)?.toDouble() ??
                 (data['lng'] as num?)?.toDouble(),
      isVerified: verified,
    );
  }
}

class UserProvider with ChangeNotifier {
  UserProfile? _profile;

  UserProfile? get profile => _profile;
  bool get isLoggedIn => _profile != null || SupabaseService.isAuthenticated;
  bool get isVerified => _profile?.isVerified ?? true;

  String get displayName => _profile?.firstName ?? 'Customer';

  Future<void> initializeFromSupabase() async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await fetchProfileForUser(user);
    }
  }

  Future<void> fetchProfileForUser(User user) async {
    try {
      final data = await SupabaseService.fetchProfile(user.id);
      final meta = user.userMetadata ?? {};

      final metaFullName = (meta['full_name'] as String?)?.trim() ?? '';
      final metaPhone = (meta['phone'] as String?)?.trim() ?? '';
      final metaAddress = (meta['address'] as String?)?.trim() ?? '';
      final metaLat = (meta['latitude'] as num?)?.toDouble();
      final metaLng = (meta['longitude'] as num?)?.toDouble();

      if (data != null) {
        final dbName = (data['full_name'] as String?)?.trim() ?? '';
        final dbPhone = (data['phone'] as String?)?.trim() ?? '';
        final dbAddress = (data['address'] as String?)?.trim() ?? '';
        final dbLat = (data['latitude'] as num?)?.toDouble() ??
            (data['delivery_latitude'] as num?)?.toDouble() ??
            (data['lat'] as num?)?.toDouble();
        final dbLng = (data['longitude'] as num?)?.toDouble() ??
            (data['delivery_longitude'] as num?)?.toDouble() ??
            (data['lng'] as num?)?.toDouble();

        // Fallback to userMetadata if database profile row fields are empty or null
        final finalFullName = dbName.isNotEmpty ? dbName : metaFullName;
        final finalPhone = dbPhone.isNotEmpty ? dbPhone : metaPhone;
        final finalAddress = dbAddress.isNotEmpty ? dbAddress : metaAddress;
        final finalLat = dbLat ?? metaLat;
        final finalLng = dbLng ?? metaLng;

        final parts = finalFullName.trim().split(RegExp(r'\s+'));
        final firstName = (parts.isNotEmpty && parts.first.isNotEmpty) ? parts.first : 'Customer';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        _profile = UserProfile(
          id: user.id,
          firstName: firstName,
          lastName: lastName,
          email: user.email ?? '',
          phone: finalPhone,
          address: finalAddress,
          role: data['role'] as String? ?? 'customer',
          avatarUrl: data['avatar_url'] as String?,
          latitude: finalLat,
          longitude: finalLng,
          isVerified: true,
        );

        // Sync missing fields back into profiles table if DB row was incomplete
        if ((dbName.isEmpty && finalFullName.isNotEmpty) ||
            (dbPhone.isEmpty && finalPhone.isNotEmpty) ||
            (dbAddress.isEmpty && finalAddress.isNotEmpty) ||
            (dbLat == null && finalLat != null) ||
            (data['is_verified'] == false) ||
            data['approval_status'] == 'pending' ||
            data['status'] == 'pending' ||
            data['is_approved'] == false) {
          final updates = <String, dynamic>{
            if (finalFullName.isNotEmpty) 'full_name': finalFullName,
            if (finalPhone.isNotEmpty) 'phone': finalPhone,
            if (finalAddress.isNotEmpty) 'address': finalAddress,
            // SECURITY: Do not overwrite role to prevent Admin privilege downgrades
            'is_verified': true,
            'status': 'active',
            'approval_status': 'approved',
            'is_approved': true,
          };
          if (finalLat != null) updates['latitude'] = finalLat;
          if (finalLng != null) updates['longitude'] = finalLng;

          SupabaseService.updateProfile(
            userId: user.id,
            updates: updates,
          ).catchError((e) {
            debugPrint('Error syncing metadata to profiles table: $e');
          });
        }
      } else {
        final parts = metaFullName.trim().split(RegExp(r'\s+'));
        final firstName = (parts.isNotEmpty && parts.first.isNotEmpty) ? parts.first : 'Customer';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        _profile = UserProfile(
          id: user.id,
          firstName: firstName,
          lastName: lastName,
          email: user.email ?? '',
          phone: metaPhone,
          address: metaAddress,
          latitude: metaLat,
          longitude: metaLng,
          role: 'customer',
          isVerified: true,
        );

        // Ensure profile exists in profiles table
        final newUpdates = <String, dynamic>{
          'full_name': _profile!.fullName,
          'phone': _profile!.phone,
          'address': _profile!.address,
          // SECURITY: Do not force 'role' to avoid overriding metadata defaults
          'is_verified': true,
          'status': 'active',
          'approval_status': 'approved',
          'is_approved': true,
        };
        if (metaLat != null) newUpdates['latitude'] = metaLat;
        if (metaLng != null) newUpdates['longitude'] = metaLng;

        SupabaseService.updateProfile(
          userId: user.id,
          updates: newUpdates,
        ).catchError((e) {
          debugPrint('Notice on auto-profile creation: $e');
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile for user: $e');
      final meta = user.userMetadata ?? {};
      final metaFullName = (meta['full_name'] as String?)?.trim() ?? '';
      final parts = metaFullName.trim().split(RegExp(r'\s+'));
      final firstName = (parts.isNotEmpty && parts.first.isNotEmpty) ? parts.first : 'Customer';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      _profile = UserProfile(
        id: user.id,
        firstName: firstName,
        lastName: lastName,
        email: user.email ?? '',
        phone: (meta['phone'] as String?)?.trim() ?? '',
        address: (meta['address'] as String?)?.trim() ?? '',
        role: 'customer',
        isVerified: true,
      );
      notifyListeners();
    }
  }

  void setProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void setDisplayName(String name) {
    if (_profile == null) {
      _profile = UserProfile(
        firstName: name,
        lastName: '',
        email: '',
        phone: '',
        address: '',
      );
    } else {
      _profile = UserProfile(
        id: _profile!.id,
        firstName: name,
        middleName: _profile!.middleName,
        lastName: _profile!.lastName,
        email: _profile!.email,
        phone: _profile!.phone,
        address: _profile!.address,
        role: _profile!.role,
        avatarUrl: _profile!.avatarUrl,
      );
    }
    notifyListeners();
  }

  Future<void> updateProfilePicture(List<int> bytes, String filePath) async {
    if (_profile == null) return;

    try {
      final publicUrl = await SupabaseService.uploadAvatar(
        userId: _profile!.id,
        filePath: filePath,
        bytes: bytes,
      );

      await SupabaseService.updateProfile(
        userId: _profile!.id,
        updates: {'avatar_url': publicUrl},
      );

      _profile = UserProfile(
        id: _profile!.id,
        firstName: _profile!.firstName,
        middleName: _profile!.middleName,
        lastName: _profile!.lastName,
        email: _profile!.email,
        phone: _profile!.phone,
        address: _profile!.address,
        role: _profile!.role,
        avatarUrl: publicUrl,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    _profile = null;
    notifyListeners();
  }
}
