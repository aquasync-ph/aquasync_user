import '../services/supabase_service.dart';

class Product {
  final String id;
  final String name;
  final String type;
  final double price;
  final String description;
  final bool isActive;
  final bool isAvailable;
  final int stock;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    this.type = 'Water',
    required this.price,
    this.description = '',
    this.isActive = true,
    this.isAvailable = true,
    this.stock = 100,
    this.imageUrl,
  });

  static bool _parseBool(dynamic val, {bool defaultValue = true}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'active' || s == 'available' || s == 'published' || s == 'enabled' || s == 'in_stock') {
        return true;
      }
      if (s == 'false' || s == '0' || s == 'no' || s == 'inactive' || s == 'unavailable' || s == 'archived' || s == 'disabled' || s == 'deleted' || s == 'out_of_stock') {
        return false;
      }
    }
    return defaultValue;
  }

  static double _parseNum(dynamic val, {double defaultValue = 0.0}) {
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
    return defaultValue;
  }

  factory Product.fromSupabaseMap(Map<String, dynamic> map) {
    // 1. Determine active status (i.e. not archived in admin catalog)
    bool active = true;
    if (map['is_active'] != null) {
      final v = map['is_active'];
      if (v is bool) {
        active = v;
      } else if (v is num) {
        active = v != 0;
      } else if (v is String) {
        active = v.toLowerCase() == 'true' || v == '1' || v.toLowerCase() == 'active';
      }
    }
    if (map['is_archived'] == true ||
        map['is_archived'] == 1 ||
        map['is_archived']?.toString().toLowerCase() == 'true') {
      active = false;
    }

    // 2. Determine stock and availability status
    int st = 100;
    if (map['stock'] is num) {
      st = (map['stock'] as num).toInt();
    } else if (map['stock'] is String) {
      st = int.tryParse(map['stock']) ?? 100;
    }

    bool available = true;
    if (map['is_available'] != null) {
      final v = map['is_available'];
      if (v is bool) {
        available = v;
      } else if (v is num) {
        available = v != 0;
      } else if (v is String) {
        available = v.toLowerCase() == 'true' || v == '1' || v.toLowerCase() == 'available';
      }
    } else if (map['stock'] != null) {
      available = st > 0;
    }

    // 3. Image URL Resolution matching admin storage bucket 'products'
    String? img;
    final rawImg = map['image_url'] ??
        map['imageUrl'] ??
        map['image'] ??
        map['photo_url'] ??
        map['picture'] ??
        map['picture_url'] ??
        map['img_url'] ??
        map['photo'] ??
        map['img'];

    if (rawImg != null) {
      final imgStr = rawImg.toString().trim();
      if (imgStr.isNotEmpty) {
        if (!imgStr.startsWith('http://') && !imgStr.startsWith('https://')) {
          try {
            img = SupabaseService.client.storage.from('products').getPublicUrl(imgStr);
          } catch (_) {
            try {
              img = SupabaseService.client.storage.from('product_images').getPublicUrl(imgStr);
            } catch (_) {}
          }
        } else {
          img = imgStr;
        }
      }
    }

    final rawName = map['name'] ?? map['product_name'] ?? map['title'] ?? map['label'] ?? map['item_name'];
    final rawType = map['category'] ?? map['type'] ?? map['product_type'] ?? map['gallon_type'];
    final rawPrice = map['price'] ?? map['unit_price'] ?? map['cost'] ?? map['amount'] ?? map['rate'];
    final rawDesc = map['description'] ?? map['desc'] ?? map['details'] ?? map['info'] ?? '';

    return Product(
      id: map['id']?.toString() ?? (map['product_id']?.toString() ?? ''),
      name: rawName?.toString() ?? 'Water Product',
      type: rawType?.toString() ?? 'Water',
      price: _parseNum(rawPrice, defaultValue: 0.0),
      description: rawDesc.toString(),
      isActive: active,
      isAvailable: available,
      stock: st,
      imageUrl: img,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'price': price,
      'description': description,
      'is_active': isActive,
      'is_available': isAvailable,
      'stock': stock,
      'image_url': imageUrl,
    };
  }
}
