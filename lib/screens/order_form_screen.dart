import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/top_banner.dart';
import 'location_picker_screen.dart';

/// Validation utilities for Order Form / Checkout
class OrderFormValidationUtils {
  static final RegExp _fullNameRegex = RegExp(r"^[a-zA-ZñÑ\s\.\-\']+$");

  static bool containsEmoji(String input) {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(input);
  }

  static String sanitizeInput(String raw) {
    return raw.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
  }

  /// Validate Recipient Full Name
  static String? validateRecipientName(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Recipient name is required.';
    }
    final clean = sanitizeInput(raw).replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < 2) {
      return 'Recipient name must be at least 2 characters.';
    }
    if (clean.length > 100) {
      return 'Recipient name must not exceed 100 characters.';
    }
    if (containsEmoji(clean) || !_fullNameRegex.hasMatch(clean)) {
      return 'Please enter a valid recipient name (letters, spaces, period, hyphen, apostrophe only).';
    }
    return null;
  }

  /// Validate Contact Phone Number (Exactly 11 digits starting with 09)
  static String? validatePhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Contact phone number is required.';
    }
    final clean = sanitizeInput(raw).replaceAll(RegExp(r'[\s\-]'), '');
    if (containsEmoji(clean)) {
      return 'Please enter a valid Philippine mobile number.';
    }
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Numbers only. Letters and special characters are not allowed.';
    }
    if (!clean.startsWith('09')) {
      return 'Phone number must start with 09.';
    }
    if (clean.length != 11) {
      return 'Phone number must contain exactly 11 digits.';
    }
    return null;
  }

  /// Validate Delivery Address
  static String? validateAddress(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Delivery address is required.';
    }
    final clean = sanitizeInput(raw);
    if (clean.length < 5) {
      return 'Delivery address must be at least 5 characters.';
    }
    if (clean.length > 200) {
      return 'Delivery address must not exceed 200 characters.';
    }
    return null;
  }

  /// Validate GCash Reference Number
  static String? validateGCashRef(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'GCash reference number is required.';
    }
    final clean = sanitizeInput(raw).replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Reference number must contain digits only.';
    }
    if (clean.length < 10 || clean.length > 20) {
      return 'Reference number must be between 10 and 20 digits.';
    }
    return null;
  }

  /// Validate Paid Amount
  static String? validatePaidAmount(String? raw, double totalDue) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Paid amount is required.';
    }
    final clean = sanitizeInput(raw);
    final val = double.tryParse(clean);
    if (val == null || val <= 0) {
      return 'Please enter a valid payment amount.';
    }
    if (val < totalDue) {
      return 'Amount paid (₱${val.toStringAsFixed(2)}) is less than total due (₱${totalDue.toStringAsFixed(2)}).';
    }
    return null;
  }

  /// Validate Delivery Notes / Special Instructions
  static String? validateDeliveryNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = sanitizeInput(raw);
    if (clean.length > 250) {
      return 'Delivery instructions must not exceed 250 characters.';
    }
    return null;
  }
}

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  int _currentStep = 1; // 1 = Recipient & Products, 2 = Payment & Review
  bool _isSubmitting = false;
  bool _isOrderPlaced = false;

  final Map<String, int> _quantities = {};
  GallonType _gallonType = GallonType.own;

  late TextEditingController _recipientNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  final TextEditingController _promoController = TextEditingController();
  final TextEditingController _gcashRefController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _cashTenderedController = TextEditingController();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  XFile? _receiptImageFile;
  bool _isOcrProcessing = false;

  double? _deliveryLatitude;
  double? _selectedLongitude;

  // Station Geofence & Business Hours
  double _stationLat = 14.2290;
  double _stationLng = 121.3280;
  double _coverageRadiusKm = 0.5;
  double _coverageRadiusMeters = 500.0;
  String _stationName = 'Aqua Pure Water Station';
  bool _isStationOpen = true;
  bool _isGeofenceLoaded = false;
  Map<String, dynamic> _shopData = {};

  // Delivery Scheduling
  DateTime _deliveryDate = DateTime.now();

  String _paymentMethod = 'Cash on Delivery';
  String _deliveryMode = 'delivery'; // 'delivery' or 'pickup'
  double _discount = 0.0;
  String? _appliedPromoCode;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<UserProvider>(context, listen: false).profile;
    
    _recipientNameController = TextEditingController(text: profile?.fullName ?? '');

    String rawPhone = profile?.phone ?? '';
    if (rawPhone.startsWith('+63')) {
      rawPhone = '0${rawPhone.substring(3)}';
    }
    _phoneController = TextEditingController(text: rawPhone);

    String initialAddress = profile?.address ?? '';
    if (initialAddress == '-') initialAddress = '';
    _addressController = TextEditingController(text: initialAddress);

    if (profile?.latitude != null && profile?.longitude != null) {
      _deliveryLatitude = profile!.latitude;
      _selectedLongitude = profile.longitude;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchProducts();
      _fetchStationGeofence();
      _autoDetectGpsLocation();
    });
  }

  Future<void> _autoDetectGpsLocation() async {
    if (_deliveryLatitude != null && _selectedLongitude != null) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted && (_deliveryLatitude == null || _selectedLongitude == null)) {
          setState(() {
            _deliveryLatitude = pos.latitude;
            _selectedLongitude = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchStationGeofence() async {
    try {
      final shopData = await SupabaseService.fetchShopProfile();
      final lat = (shopData['latitude'] as num?)?.toDouble() ?? 14.2290;
      final lng = (shopData['longitude'] as num?)?.toDouble() ?? 121.3280;
      final radiusKm = (shopData['coverage_radius_km'] as num?)?.toDouble() ?? 0.5;
      final name = (shopData['full_name'] as String?) ?? 'Aqua Pure Water Station';
      final isOpen = SupabaseService.isStationOpen(shopData);

      if (mounted) {
        final profile = Provider.of<UserProvider>(context, listen: false).profile;
        if (_deliveryLatitude == null && profile?.latitude != null) {
          _deliveryLatitude = profile!.latitude;
        }
        if (_selectedLongitude == null && profile?.longitude != null) {
          _selectedLongitude = profile!.longitude;
        }

        setState(() {
          _shopData = shopData;
          _stationLat = lat;
          _stationLng = lng;
          _coverageRadiusKm = radiusKm;
          _coverageRadiusMeters = radiusKm * 1000.0;
          _stationName = name;
          _isStationOpen = isOpen;
          _isGeofenceLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGeofenceLoaded = true);
      }
    }
  }

  bool _validateGeofence() {
    if (_deliveryMode == 'pickup') return true;

    if (_deliveryLatitude == null || _selectedLongitude == null) {
      _showError('🚫 Location coordinates not set. Please pin your delivery location on map to check service area.');
      return false;
    }

    final distanceMeters = Geolocator.distanceBetween(
      _stationLat,
      _stationLng,
      _deliveryLatitude!,
      _selectedLongitude!,
    );

    if (distanceMeters > _coverageRadiusMeters) {
      final distKm = (distanceMeters / 1000.0).toStringAsFixed(2);
      _showError(
        '🚫 Out of Delivery Area: Your location ($distKm km) is outside the station\'s allowed delivery boundary (${_coverageRadiusKm.toStringAsFixed(1)} km limit from $_stationName).',
      );
      return false;
    }

    return true;
  }

  Widget _buildGeofenceBadge() {
    if (_deliveryMode == 'pickup') {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Station Pickup Selected • No delivery geofence restriction.',
                style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (_deliveryLatitude == null || _selectedLongitude == null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pin location on map to check proximity allowed radius (${_coverageRadiusKm.toStringAsFixed(1)} km limit).',
                style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final distanceMeters = Geolocator.distanceBetween(
      _stationLat,
      _stationLng,
      _deliveryLatitude!,
      _selectedLongitude!,
    );
    final isWithin = distanceMeters <= _coverageRadiusMeters;
    final distKm = (distanceMeters / 1000.0).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWithin
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWithin
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWithin ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isWithin ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isWithin
                  ? 'Within $_stationName Boundary • $distKm km away (Max ${_coverageRadiusKm.toStringAsFixed(1)} km)'
                  : 'OUTSIDE ALLOWED PROXIMITY • $distKm km away from $_stationName (Max ${_coverageRadiusKm.toStringAsFixed(1)} km)',
              style: TextStyle(
                color: isWithin ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_isGeofenceLoaded)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _promoController.dispose();
    _gcashRefController.dispose();
    _paidAmountController.dispose();
    _cashTenderedController.dispose();
    super.dispose();
  }

  double get _deliveryFee => 0.0;

  int get _totalGallonsSelected {
    int sum = 0;
    _quantities.forEach((_, qty) => sum += qty);
    return sum;
  }

  double _calculateSubtotal(List<Product> products) {
    double sum = 0.0;
    for (var prod in products) {
      final qty = _quantities[prod.id] ?? 0;
      sum += qty * prod.price;
    }
    return sum;
  }

  double _calculateTotal(List<Product> products) {
    final subtotal = _calculateSubtotal(products);
    return (subtotal + _deliveryFee - _discount).clamp(0.0, double.infinity);
  }

  void _showError(String msg) {
    TopBanner.show(context, msg, isError: true);
  }

  Future<void> _applyPromo(List<Product> products) async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showError('Please enter a voucher / promo code.');
      return;
    }
    if (code.length > 20) {
      _showError('Voucher code must not exceed 20 characters.');
      return;
    }

    HapticFeedback.lightImpact();
    final subtotal = _calculateSubtotal(products);
    final user = SupabaseService.currentUser;

    try {
      final res = await SupabaseService.validatePromoCode(
        code: code,
        subtotal: subtotal,
        customerId: user?.id,
      );

      final discountAmount = (res['discount_amount'] as num?)?.toDouble() ?? 0.0;
      final promoCodeApplied = res['code'] as String? ?? code;

      setState(() {
        _discount = discountAmount;
        _appliedPromoCode = promoCodeApplied;
        _paidAmountController.text = _calculateTotal(products).toStringAsFixed(2);
      });

      if (!mounted) return;
      TopBanner.show(
        context,
        'Voucher $promoCodeApplied applied! Saved ₱${discountAmount.toStringAsFixed(2)}',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _pickLocationOnMap() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _addressController.text = result.address;
        _deliveryLatitude = result.latitude;
        _selectedLongitude = result.longitude;
      });

      TopBanner.show(
        context,
        'Delivery location pinned: ${result.address}',
        isError: false,
      );
    }
  }

  Future<void> _pickAndScanReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _receiptImageFile = picked;
      _isOcrProcessing = true;
    });

    try {
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognizedText.text;
      debugPrint('OCR Recognized Text:\n$fullText');

      String? extractedRef;
      final lines = fullText.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        if (line.contains('ref') || line.contains('reference') || line.contains('transaction') || line.contains('id') || line.contains('no')) {
          for (int j = i; j <= i + 2 && j < lines.length; j++) {
            final candidateLine = lines[j];
            if (_isDateOrTimeLine(candidateLine)) continue;

            final digitsMatch = RegExp(r'\d{10,20}').firstMatch(candidateLine.replaceAll(RegExp(r'\s+'), ''));
            if (digitsMatch != null) {
              extractedRef = digitsMatch.group(0);
              break;
            }
          }
        }
        if (extractedRef != null) break;
      }

      if (extractedRef == null) {
        final refRegEx = RegExp(r'(?:ref(?:erence)?\s*(?:no\.?|number)?[:#]?\s*)([0-9\s\-]{10,20})', caseSensitive: false);
        final refMatch = refRegEx.firstMatch(fullText);
        if (refMatch != null && refMatch.group(1) != null) {
          final cleaned = refMatch.group(1)!.replaceAll(RegExp(r'\D'), '');
          if (cleaned.length >= 10 && cleaned.length <= 20) {
            extractedRef = cleaned;
          }
        }
      }

      String? extractedAmount;
      final amountRegEx = RegExp(r'(?:PHP|₱)\s*([0-9,]+\.\d{2})', caseSensitive: false);
      final amountMatch = amountRegEx.firstMatch(fullText);
      if (amountMatch != null && amountMatch.group(1) != null) {
        extractedAmount = amountMatch.group(1)!.replaceAll(',', '');
      } else {
        final decRegEx = RegExp(r'\b([0-9]{1,3}(?:,[0-9]{3})*\.\d{2})\b');
        final decMatch = decRegEx.firstMatch(fullText);
        if (decMatch != null && decMatch.group(1) != null) {
          extractedAmount = decMatch.group(1)!.replaceAll(',', '');
        }
      }

      setState(() {
        if (extractedRef != null) {
          _gcashRefController.text = extractedRef;
        }
        if (extractedAmount != null) {
          _paidAmountController.text = extractedAmount;
        }
        _isOcrProcessing = false;
      });

      if (!mounted) return;
      TopBanner.show(
        context,
        'Receipt scanned via OCR! Reference & amount extracted.',
        isError: false,
      );
    } catch (e) {
      setState(() => _isOcrProcessing = false);
      if (!mounted) return;
      TopBanner.show(context, 'OCR Scan failed: ${e.toString()}', isError: true);
    }
  }

  bool _isDateOrTimeLine(String line) {
    final lower = line.toLowerCase();
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    for (var m in months) {
      if (lower.contains(m)) return true;
    }
    if (lower.contains('am') || lower.contains('pm') || lower.contains(':')) return true;
    return false;
  }

  /// Step 1 Navigation Validation
  void _goToStep2(List<Product> products) {
    if (!_formKey1.currentState!.validate()) return;

    final recipientErr = OrderFormValidationUtils.validateRecipientName(_recipientNameController.text);
    if (recipientErr != null) {
      _showError(recipientErr);
      return;
    }

    final phoneErr = OrderFormValidationUtils.validatePhone(_phoneController.text);
    if (phoneErr != null) {
      _showError(phoneErr);
      return;
    }

    final addressErr = OrderFormValidationUtils.validateAddress(_addressController.text);
    if (addressErr != null) {
      _showError(addressErr);
      return;
    }

    if (!_validateGeofence()) {
      return;
    }

    if (_totalGallonsSelected < 1 && products.isNotEmpty) {
      _quantities[products.first.id] = 1;
    }

    final totalGallons = _totalGallonsSelected;
    if (totalGallons < 1) {
      _showError('Please select at least 1 water gallon to order.');
      return;
    }
    if (totalGallons > 50) {
      _showError('Maximum order limit is 50 gallons per transaction. Please adjust quantity.');
      return;
    }

    final totalAmount = _calculateTotal(products);
    if (_paidAmountController.text.trim().isEmpty) {
      _paidAmountController.text = totalAmount.toStringAsFixed(2);
    }

    HapticFeedback.lightImpact();
    setState(() => _currentStep = 2);
  }

  Future<void> _placeOrder(List<Product> products) async {
    if (_isSubmitting) return;

    if (!SupabaseService.isAuthenticated) {
      _showError('You must be logged in to place an order.');
      return;
    }

    // Step 1 Field Validation Checks
    final recipientErr = OrderFormValidationUtils.validateRecipientName(_recipientNameController.text);
    if (recipientErr != null) {
      _showError(recipientErr);
      setState(() => _currentStep = 1);
      return;
    }

    final phoneErr = OrderFormValidationUtils.validatePhone(_phoneController.text);
    if (phoneErr != null) {
      _showError(phoneErr);
      setState(() => _currentStep = 1);
      return;
    }

    if (_deliveryMode == 'delivery') {
      final addressErr = OrderFormValidationUtils.validateAddress(_addressController.text);
      if (addressErr != null) {
        _showError(addressErr);
        setState(() => _currentStep = 1);
        return;
      }
    }

    // Step 2 Form Validation Check
    if (_formKey2.currentState != null && !_formKey2.currentState!.validate()) {
      return;
    }

    final totalGallons = _totalGallonsSelected;
    if (totalGallons < 1) {
      _showError('Please select at least 1 water gallon to order.');
      setState(() => _currentStep = 1);
      return;
    }
    if (totalGallons > 50) {
      _showError('Maximum order limit is 50 gallons per transaction.');
      setState(() => _currentStep = 1);
      return;
    }

    if (!_validateGeofence()) {
      return;
    }

    final totalAmount = _calculateTotal(products);

    final bool isGcashSelected = _paymentMethod.toUpperCase().contains('GCASH') ||
                                  _paymentMethod.toUpperCase().contains('RECEIPT');

    // Validate Payment Method requirements
    if (isGcashSelected) {
      if (_receiptImageFile == null) {
        _showError('Please upload your GCash payment receipt image.');
        return;
      }

      final refErr = OrderFormValidationUtils.validateGCashRef(_gcashRefController.text);
      if (refErr != null) {
        _showError(refErr);
        return;
      }

      final paidErr = OrderFormValidationUtils.validatePaidAmount(_paidAmountController.text, totalAmount);
      if (paidErr != null) {
        _showError(paidErr);
        return;
      }
    } else {
      if (_cashTenderedController.text.trim().isNotEmpty) {
        final cashVal = double.tryParse(_cashTenderedController.text.trim());
        if (cashVal == null || cashVal < totalAmount) {
          _showError('Cash tendered must be equal to or greater than total amount due (₱${totalAmount.toStringAsFixed(2)}).');
          return;
        }
      }
    }

    final List<OrderItemData> selectedItems = [];
    for (var prod in products) {
      final qty = _quantities[prod.id] ?? 0;
      if (qty > 0) {
        selectedItems.add(
          OrderItemData(
            orderId: '',
            productId: prod.id,
            productName: prod.name,
            quantity: qty,
            gallonType: _gallonType,
            unitPrice: prod.price,
            subtotal: qty * prod.price,
          ),
        );
      }
    }

    if (selectedItems.isEmpty) {
      _showError('Please select at least 1 water product to order.');
      setState(() => _currentStep = 1);
      return;
    }

    final subtotal = _calculateSubtotal(products);

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final recipientName = OrderFormValidationUtils.sanitizeInput(_recipientNameController.text);
      final rawPhone = OrderFormValidationUtils.sanitizeInput(_phoneController.text);
      String phoneE164 = rawPhone;
      if (rawPhone.startsWith('0') && rawPhone.length > 1) {
        phoneE164 = '+63${rawPhone.substring(1)}';
      }
      final formattedDateStr = DateFormat('yyyy-MM-dd').format(_deliveryDate);
      final modeStr = _deliveryMode == 'delivery' ? 'Home Delivery' : 'Station Pickup';
      final headerMeta = 'Recipient: $recipientName ($phoneE164) | Mode: $modeStr | Date: $formattedDateStr';
      String finalNotes = '';

      String? uploadedReceiptUrl;
      String? gcashReference;

      if (isGcashSelected) {
        final ref = OrderFormValidationUtils.sanitizeInput(_gcashRefController.text);
        final amt = OrderFormValidationUtils.sanitizeInput(_paidAmountController.text);
        final receiptNote = 'GCash Ref: $ref (Amount Paid: ₱$amt)';
        finalNotes = finalNotes.isEmpty ? '$headerMeta | $receiptNote' : '$headerMeta | $receiptNote | $finalNotes';
        gcashReference = ref;

        if (_receiptImageFile != null) {
          final currentUser = SupabaseService.currentUser;
          if (currentUser != null) {
            final bytes = await _receiptImageFile!.readAsBytes();
            uploadedReceiptUrl = await SupabaseService.uploadReceipt(
              userId: currentUser.id,
              bytes: bytes,
            );
            if (uploadedReceiptUrl != null && uploadedReceiptUrl.isNotEmpty) {
              final receiptImgNote = 'Receipt Image: $uploadedReceiptUrl';
              finalNotes = '$finalNotes | $receiptImgNote';
            }
          }
        }
      } else {
        // Cash on Delivery (COD): Explicitly set payment method to 'COD' and nullify GCash reference and receipt fields
        final cashNote = _cashTenderedController.text.trim().isNotEmpty
            ? 'COD (Cash Tendered: ₱${_cashTenderedController.text.trim()})'
            : 'Cash on Delivery';
        finalNotes = finalNotes.isEmpty ? '$headerMeta | $cashNote' : '$headerMeta | $cashNote | $finalNotes';
        uploadedReceiptUrl = null;
        gcashReference = null;
      }

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.createOrder(
        items: selectedItems,
        address: _addressController.text.trim(),
        latitude: _deliveryLatitude,
        longitude: _selectedLongitude,
        notes: finalNotes,
        receiptUrl: uploadedReceiptUrl,
        gcashReference: gcashReference,
        paymentMethod: isGcashSelected ? 'GCash' : 'COD',
        promoCode: _appliedPromoCode,
        discountAmount: _discount,
        subtotal: subtotal,
        deliveryFee: _deliveryFee,
        totalAmount: totalAmount,
      );

      if (!mounted) return;

      setState(() {
        _isOrderPlaced = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to place order: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    final orderProvider = Provider.of<OrderProvider>(context);
    final products = orderProvider.products;

    if (_isOrderPlaced) {
      return _buildSuccessScreen();
    }

    final subtotal = _calculateSubtotal(products);
    final totalAmount = _calculateTotal(products);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 1 ? 'Step 1: Order Water' : 'Step 2: Payment & Review'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(_currentStep == 2 ? Icons.arrow_back_rounded : Icons.close_rounded),
          onPressed: _isSubmitting
              ? null
              : () {
                  if (_currentStep == 2) {
                    setState(() => _currentStep = 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
      ),
      body: Column(
        children: [
          _stepIndicator(_currentStep, isDark),
          Expanded(
            child: _currentStep == 1
                ? _buildStep1Page(products, cardBg, textColor, subTextColor, borderColor, orderProvider)
                : _buildStep2Page(products, subtotal, totalAmount, cardBg, textColor, subTextColor, borderColor),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator(int currentStep, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F223D) : const Color(0xFFF0F9FF),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: currentStep == 1 ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentStep == 1 ? Icons.water_drop_rounded : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text(
                      '1. Details & Products',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 20,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: currentStep == 2 ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFCBD5E1)),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: currentStep == 2
                    ? const Color(0xFF0284C7)
                    : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.payments_rounded,
                    color: currentStep == 2
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '2. Payment & Review',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: currentStep == 2
                            ? Colors.white
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1 PAGE: 1. Recipient Details, 2. Water Products, 3. Container Swap, 4. Address & Schedule
  Widget _buildStep1Page(
    List<Product> products,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    OrderProvider orderProvider,
  ) {
    return SingleChildScrollView(
      key: const ValueKey<int>(1),
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isStationOpen)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.access_time_filled_rounded, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Station is currently CLOSED. Your order will be queued and processed upon opening.',
                        style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. RECIPIENT & CONTACT INFORMATION
            _sectionHeader('1', 'RECIPIENT & CONTACT DETAILS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _recipientNameController,
                    enabled: !_isSubmitting,
                    maxLength: 100,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Recipient Full Name *',
                      hintText: 'Juan Dela Cruz',
                      counterText: '',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF0284C7)),
                    ),
                    validator: OrderFormValidationUtils.validateRecipientName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !_isSubmitting,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number (11-digits) *',
                      hintText: '09171234567',
                      counterText: '',
                      prefixIcon: Icon(Icons.phone_iphone_rounded, color: Color(0xFF0284C7)),
                    ),
                    validator: OrderFormValidationUtils.validatePhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. SELECT WATER PRODUCTS
            _sectionHeader('2', 'SELECT WATER PRODUCTS'),
            const SizedBox(height: 12),

            if (orderProvider.isLoadingProducts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                ),
              )
            else if (products.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
                child: Text('No water products available at the moment.', style: TextStyle(color: subTextColor, fontSize: 13), textAlign: TextAlign.center),
              )
            else
              ...products.map((prod) => _buildProductItemCard(prod, cardBg, textColor, subTextColor, borderColor)),

            const SizedBox(height: 16),

            // 3. CONTAINER SWAP OPTION
            _sectionHeader('3', 'CONTAINER SWAP OPTION'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  _gallonTile('Exchange Empty Gallon', GallonType.own, 'Swap your empty container upon delivery', subTextColor, textColor),
                  Divider(height: 1, color: borderColor),
                  _gallonTile('Borrow Station Gallon', GallonType.borrowed, 'Borrow container directly from station', subTextColor, textColor),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. DELIVERY OPTION & ADDRESS
            _sectionHeader('4', 'DELIVERY OPTION & ADDRESS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _deliveryMode = 'delivery';
                              final profile = Provider.of<UserProvider>(context, listen: false).profile;
                              _addressController.text = profile?.address ?? '';
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: _deliveryMode == 'delivery'
                                  ? const LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: _deliveryMode == 'delivery' ? null : cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _deliveryMode == 'delivery' ? const Color(0xFF0284C7) : borderColor,
                                width: _deliveryMode == 'delivery' ? 1.5 : 1,
                              ),
                              boxShadow: _deliveryMode == 'delivery'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_shipping_rounded,
                                  color: _deliveryMode == 'delivery' ? Colors.white : const Color(0xFF0284C7),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Home Delivery',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _deliveryMode == 'delivery' ? Colors.white : textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Doorstep drop-off',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _deliveryMode == 'delivery' ? Colors.white70 : subTextColor,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _deliveryMode = 'pickup';
                              _addressController.text = 'Counter Walk-in / Station Pickup';
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: _deliveryMode == 'pickup'
                                  ? const LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: _deliveryMode == 'pickup' ? null : cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _deliveryMode == 'pickup' ? const Color(0xFF0284C7) : borderColor,
                                width: _deliveryMode == 'pickup' ? 1.5 : 1,
                              ),
                              boxShadow: _deliveryMode == 'pickup'
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  color: _deliveryMode == 'pickup' ? Colors.white : const Color(0xFF0284C7),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Station Pickup',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _deliveryMode == 'pickup' ? Colors.white : textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Counter walk-in',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _deliveryMode == 'pickup' ? Colors.white70 : subTextColor,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_deliveryMode == 'delivery') ...[
                    TextFormField(
                      controller: _addressController,
                      enabled: !_isSubmitting,
                      maxLines: 2,
                      maxLength: 200,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Complete Delivery Address *',
                        hintText: 'House No, Street, Barangay, City',
                        counterText: '',
                        prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFF0284C7)),
                        alignLabelWithHint: true,
                      ),
                      validator: OrderFormValidationUtils.validateAddress,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _isSubmitting ? null : _pickLocationOnMap,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_rounded, color: Color(0xFF0284C7), size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'PIN LOCATION ON MAP',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildGeofenceBadge(),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pick up directly at $_stationName. No delivery fee or boundary check required.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Delivery Date Picker
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivery Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _isSubmitting ? null : _selectDeliveryDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMM dd, yyyy').format(_deliveryDate),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // NEXT BUTTON FOR STEP 1
            InkWell(
              onTap: () => _goToStep2(products),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'CONTINUE TO PAYMENT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _deliveryDate = picked);
    }
  }

  // STEP 2 PAGE: Order Summary, Voucher Code, Payment Method
  Widget _buildStep2Page(
    List<Product> products,
    double subtotal,
    double totalAmount,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      key: const ValueKey<int>(2),
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 5. ORDER SUMMARY & VOUCHER CODE
            _sectionHeader('5', 'ORDER SUMMARY & VOUCHER CODE'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  _summaryRow('Items Subtotal (${_totalGallonsSelected} gallons)', '₱${subtotal.toStringAsFixed(2)}', textColor, subTextColor),
                  if (_deliveryFee > 0)
                    _summaryRow('Delivery Fee', '₱${_deliveryFee.toStringAsFixed(2)}', textColor, subTextColor),
                  if (_discount > 0)
                    _summaryRow('Voucher Discount (${_appliedPromoCode ?? ''})', '-₱${_discount.toStringAsFixed(2)}', textColor, subTextColor, isDiscount: true),
                  Divider(height: 24, color: borderColor),
                  _summaryRow('GRAND TOTAL AMOUNT', '₱${totalAmount.toStringAsFixed(2)}', textColor, subTextColor, isBold: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          enabled: !_isSubmitting,
                          maxLength: 20,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Voucher / Promo Code (AQUAFREE)',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _applyPromo(products),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. SELECT PAYMENT METHOD
            _sectionHeader('6', 'SELECT PAYMENT METHOD'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  _paymentTile('Cash on Delivery', 'Pay cash on arrival upon water delivery', Icons.payments_rounded, subTextColor, textColor),
                  Divider(height: 1, color: borderColor),
                  _paymentTile('GCash Receipt Upload', 'Scan Admin QR & upload GCash receipt', Icons.document_scanner_rounded, subTextColor, textColor),
                ],
              ),
            ),

            if (_paymentMethod == 'Cash on Delivery') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash Amount Tendered (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text('Enter the cash bill you will pay to help the rider prepare exact change.', style: TextStyle(fontSize: 11, color: subTextColor)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _cashTenderedController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 500.00',
                        prefixIcon: Icon(Icons.money_rounded, color: Color(0xFF0284C7)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_cashTenderedController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final tendered = double.tryParse(_cashTenderedController.text.trim()) ?? 0.0;
                        final change = tendered - totalAmount;
                        if (change >= 0) {
                          return Text('Change: ₱${change.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13));
                        } else {
                          return const Text('Insufficient cash tendered', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12));
                        }
                      }),
                    ],
                  ],
                ),
              ),
            ] else if (_paymentMethod == 'GCash Receipt Upload') ...[
              const SizedBox(height: 16),
              _buildReceiptUploadSection(cardBg, textColor, subTextColor, borderColor),
            ],
            const SizedBox(height: 28),

            // SUBMIT PLACE ORDER BUTTON
            InkWell(
              onTap: _isSubmitting ? null : () => _placeOrder(products),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'PLACE ORDER • ₱${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: _isSubmitting ? null : () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF0284C7)),
              label: const Flexible(
                child: Text(
                  'BACK TO PRODUCTS & DETAILS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String num, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF0284C7),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0284C7),
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductItemCard(Product prod, Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    final qty = _quantities[prod.id] ?? 0;
    final isSelected = qty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.1) : cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF0284C7) : borderColor,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: (prod.imageUrl != null && prod.imageUrl!.trim().isNotEmpty)
                  ? Image.network(
                      prod.imageUrl!.trim(),
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${prod.price.toStringAsFixed(2)} / gallon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w800, fontSize: 12),
                ),
                if (prod.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    prod.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subTextColor, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? const Color(0xFF0284C7) : borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          if (qty > 0) {
                            setState(() => _quantities[prod.id] = qty - 1);
                          }
                        },
                  icon: const Icon(Icons.remove_rounded, color: Color(0xFF0284C7), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Text(
                    '$qty',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (_totalGallonsSelected >= 50) {
                            _showError('Maximum order limit is 50 gallons per transaction.');
                            return;
                          }
                          HapticFeedback.lightImpact();
                          setState(() => _quantities[prod.id] = qty + 1);
                        },
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF0284C7), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallonTile(String title, GallonType type, String desc, Color subTextColor, Color textColor) {
    final isSelected = _gallonType == type;
    return InkWell(
      onTap: _isSubmitting
          ? null
          : () {
              HapticFeedback.lightImpact();
              setState(() => _gallonType = type);
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(type == GallonType.own ? Icons.swap_horiz_rounded : Icons.opacity_rounded, color: const Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: subTextColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : subTextColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(String title, String val, IconData icon, Color subTextColor, Color textColor) {
    final isSelected = _paymentMethod == title;
    return InkWell(
      onTap: _isSubmitting
          ? null
          : () {
              HapticFeedback.lightImpact();
              setState(() {
                _paymentMethod = title;
                if (title == 'Cash on Delivery' || title == 'COD') {
                  _gcashRefController.clear();
                  _paidAmountController.clear();
                  _receiptImageFile = null;
                }
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: subTextColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : subTextColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String l, String r, Color textColor, Color subTextColor, {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 14 : 12,
                color: isBold ? textColor : subTextColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              fontSize: isBold ? 18 : 13,
              color: isDiscount
                  ? const Color(0xFF10B981)
                  : (isBold ? const Color(0xFF0284C7) : textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptUploadSection(Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF007DFE).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF007DFE).withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007DFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Admin GCash QR to Pay',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF007DFE)),
                          ),
                          Text(
                            _shopData['gcash_name'] != null ? 'Account: ${_shopData['gcash_name']}' : 'Account: AquaSync Water Station',
                            style: TextStyle(fontSize: 11, color: subTextColor),
                          ),
                          if (_shopData['gcash_number'] != null)
                            Text(
                              'Number: ${_shopData['gcash_number']}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_shopData['gcash_qr'] != null && _shopData['gcash_qr'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 180,
                      width: 180,
                      color: Colors.white,
                      child: Image.network(
                        _shopData['gcash_qr'],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF007DFE)),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 64, color: Color(0xFF007DFE)),
                        SizedBox(height: 4),
                        Text('Admin GCash QR', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (_shopData['gcash_number'] != null && _shopData['gcash_number'].toString().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _shopData['gcash_number'].toString()));
                      TopBanner.show(context, 'GCash number copied to clipboard!', isError: false);
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF007DFE)),
                    label: Text(
                      'Copy GCash #: ${_shopData['gcash_number']}',
                      style: const TextStyle(color: Color(0xFF007DFE), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      side: const BorderSide(color: Color(0xFF007DFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GCash Receipt OCR Scanner',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your payment receipt screenshot. Our OCR scanner will automatically extract the Reference Number and Amount.',
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
          const SizedBox(height: 16),
          
          if (_receiptImageFile != null) ...[
            Center(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.file(
                        File(_receiptImageFile!.path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(Icons.image_rounded, size: 48, color: subTextColor),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        onPressed: () => setState(() => _receiptImageFile = null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_isOcrProcessing) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0284C7)),
                    SizedBox(height: 8),
                    Text('Scanning Receipt via OCR...', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _pickAndScanReceipt(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7), size: 18),
                    label: const Text(
                      'Take Photo',
                      style: TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _pickAndScanReceipt(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7), size: 18),
                    label: const Text(
                      'Upload Gallery',
                      style: TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          TextFormField(
            controller: _gcashRefController,
            enabled: !_isSubmitting,
            maxLength: 20,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(20),
            ],
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Reference Number / Transaction ID *',
              hintText: 'e.g. 1029384756123',
              counterText: '',
              prefixIcon: Icon(Icons.tag_rounded, color: Color(0xFF0284C7)),
              isDense: true,
            ),
            validator: OrderFormValidationUtils.validateGCashRef,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paidAmountController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Amount Paid (₱) *',
              hintText: 'e.g. 150.00',
              prefixIcon: Icon(Icons.payments_rounded, color: Color(0xFF0284C7)),
              isDense: true,
            ),
            validator: (val) {
              final products = Provider.of<OrderProvider>(context, listen: false).products;
              return OrderFormValidationUtils.validatePaidAmount(val, _calculateTotal(products));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeOrder = Provider.of<OrderProvider>(context, listen: false).activeOrder;

    const accentRoyal = Color(0xFF0F2573);
    const accentNavy = Color(0xFF041D56);
    const accentMidnight = Color(0xFF01082D);
    const secondaryMediumBlue = Color(0xFF266CA9);
    const dominantLightBlue = Color(0xFFADE1FB);

    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF081226), Color(0xFF0F223D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : LinearGradient(
            colors: [
              const Color(0xFFF0F9FF),
              dominantLightBlue.withValues(alpha: 0.5),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    final cardBg = isDark ? const Color(0xFF0F223D) : Colors.white.withValues(alpha: 0.95);
    final cardBorder = isDark ? const Color(0xFF1E3A5F) : dominantLightBlue.withValues(alpha: 0.6);
    final primaryTxt = isDark ? Colors.white : accentNavy;
    final subTxt = isDark ? const Color(0xFF94A3B8) : secondaryMediumBlue;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated Glowing Checkmark Aura Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Success Header Text
                Text(
                  'Order Placed Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: primaryTxt,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for ordering with AquaSync!\nYour order has been dispatched to the water station.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: subTxt,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 28),

                // Order Confirmation Glass Summary Card
                if (activeOrder != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: secondaryMediumBlue.withValues(alpha: isDark ? 0.3 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ORDER REFERENCE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: secondaryMediumBlue,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${activeOrder.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: accentRoyal,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_filled_rounded, size: 12, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text(
                                    '~25 mins delivery',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: cardBorder, height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.water_drop_rounded, color: accentRoyal, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${activeOrder.product} (${activeOrder.quantity}x)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTxt,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '₱${activeOrder.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: accentRoyal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Action Buttons
                Column(
                  children: [
                    // TRACK ORDER LIVE BUTTON
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [accentRoyal, secondaryMediumBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accentRoyal.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/tracker');
                        },
                        icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'TRACK DELIVERY LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // BACK TO HOME BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.home_rounded, color: subTxt, size: 18),
                        label: Text(
                          'BACK TO HOME',
                          style: TextStyle(
                            color: subTxt,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cardBorder, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
