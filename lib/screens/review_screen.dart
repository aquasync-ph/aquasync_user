import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/top_banner.dart';

/// Helper utility for Review & Rating Validations
class ReviewValidationUtils {
  static final List<String> _inappropriateWords = [
    'tangina',
    'gago',
    'bobo',
    'tarantado',
    'ulol',
    'putangina',
    'pUTA',
    'bitch',
    'fuck',
    'shit',
    'asshole',
    'bastardo',
  ];

  static bool containsEmoji(String input) {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(input);
  }

  static String sanitizeInput(String raw) {
    return raw.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Validate Star Rating (Must be between 1 and 5 stars)
  static String? validateRating(int rating) {
    if (rating < 1 || rating > 5) {
      return 'Please select a star rating between 1 and 5 stars.';
    }
    return null;
  }

  /// Validate Review Feedback Comment
  static String? validateReviewComment(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Review comment / feedback is required.';
    }
    final clean = sanitizeInput(raw);
    if (clean.length < 5) {
      return 'Review feedback must be at least 5 characters.';
    }
    if (clean.length > 500) {
      return 'Review feedback must not exceed 500 characters.';
    }

    final lower = clean.toLowerCase();
    for (var word in _inappropriateWords) {
      if (lower.contains(word)) {
        return 'Please maintain polite and respectful language in your feedback.';
      }
    }

    return null;
  }
}

class ReviewScreen extends StatefulWidget {
  final WaterOrder order;

  const ReviewScreen({super.key, required this.order});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.order.rating != null && widget.order.rating! > 0) {
      _rating = widget.order.rating!;
    }
    if (widget.order.review != null && widget.order.review!.isNotEmpty) {
      _commentController.text = widget.order.review!;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    TopBanner.show(context, msg, isError: true);
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    final ratingErr = ReviewValidationUtils.validateRating(_rating);
    if (ratingErr != null) {
      _showError(ratingErr);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = SupabaseService.currentUser;
    if (user == null) {
      _showError('You must be logged in to submit a review.');
      return;
    }

    if (widget.order.customerId.isNotEmpty && widget.order.customerId != user.id) {
      _showError('Reviews are only allowed for your own completed orders.');
      return;
    }

    if (widget.order.status != OrderStatus.delivered && widget.order.status != OrderStatus.completed) {
      _showError('Reviews are only allowed after order has been delivered or completed.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final cleanComment = ReviewValidationUtils.sanitizeInput(_commentController.text);

    try {
      await SupabaseService.submitCustomerReview(
        orderId: widget.order.id,
        rating: _rating,
        review: cleanComment,
      );

      if (!mounted) return;

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchMyOrders();

      if (!mounted) return;

      TopBanner.show(
        context,
        'Thank you for rating your delivery! Review submitted successfully.',
        isError: false,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to submit review: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get _productSubtitle {
    final prod = widget.order.product;
    if (prod.toLowerCase().contains('gallon')) {
      return prod;
    }
    return '$prod • ${widget.order.quantity} Gallons';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Delivery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.water_drop_rounded, size: 36, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Order #${widget.order.orderNumber}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor),
                    ),
                    Text(
                      _productSubtitle,
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'How was your delivery experience?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            setState(() => _rating = starValue);
                          },
                    icon: Icon(
                      starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFD97706),
                      size: 40,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _rating == 1
                    ? '1 Star - Poor Experience'
                    : _rating == 2
                        ? '2 Stars - Fair Experience'
                        : _rating == 3
                            ? '3 Stars - Good'
                            : _rating == 4
                                ? '4 Stars - Very Good'
                                : '5 Stars - Excellent Delivery!',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 4,
                maxLength: 500,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Share feedback about your water quality, delivery speed, or rider...',
                  labelText: 'Feedback Comment *',
                  alignLabelWithHint: true,
                ),
                validator: ReviewValidationUtils.validateReviewComment,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'SUBMIT RATING & FEEDBACK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
