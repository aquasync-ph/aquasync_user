import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/order_provider.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../widgets/top_banner.dart';
import 'review_screen.dart';

/// Helper utility for Cancellation Reason Validations
class CancellationValidationUtils {
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

  /// Validate Cancellation Reason
  static String? validateReason(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Cancellation reason is required.';
    }
    final clean = sanitizeInput(raw);
    if (clean.isEmpty) {
      return 'Cancellation reason cannot be empty or spaces-only.';
    }
    if (clean.length < 5) {
      return 'Cancellation reason must be at least 5 characters.';
    }
    if (clean.length > 250) {
      return 'Cancellation reason must not exceed 250 characters.';
    }

    final lower = clean.toLowerCase();
    for (var word in _inappropriateWords) {
      if (lower.contains(word)) {
        return 'Please maintain polite and respectful language in your reason.';
      }
    }

    return null;
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchMyOrders();
    });
  }

  void _showCancellationDialog(BuildContext context, WaterOrder order) {
    HapticFeedback.lightImpact();

    // Eligibility check
    if (order.status != OrderStatus.pending) {
      TopBanner.show(
        context,
        'Order #${order.orderNumber} is no longer eligible for cancellation as it is already processing or completed.',
        isError: true,
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _CancellationDialogContent(
        order: order,
        cardBg: cardBg,
        textColor: textColor,
        subTextColor: subTextColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = Provider.of<OrderProvider>(context).history;
    final filteredHistory = _filter == 'All'
        ? allHistory
        : allHistory.where((o) {
            final statusStr = o.status.name.toLowerCase();
            final filterStr = _filter.toLowerCase();
            if (filterStr == 'pending') return statusStr == 'pending';
            if (filterStr == 'confirmed') {
              return statusStr == 'confirmed' || statusStr == 'assigned' || statusStr == 'accepted';
            }
            if (filterStr == 'delivered') {
              return statusStr == 'delivered' || statusStr == 'outfordelivery';
            }
            if (filterStr == 'completed') return statusStr == 'completed';
            return statusStr == filterStr;
          }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Header & Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredHistory.length} ${filteredHistory.length == 1 ? 'Order' : 'Orders'}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filter,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0284C7), size: 24),
                      style: TextStyle(
                        color: const Color(0xFF0284C7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      dropdownColor: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      items: ['All', 'Pending', 'Confirmed', 'Delivered', 'Cancelled']
                          .map((option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option == 'All' ? 'All Statuses' : option,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: option == _filter ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          HapticFeedback.lightImpact();
                          setState(() => _filter = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Provider.of<OrderProvider>(context, listen: false).fetchMyOrders(),
              child: filteredHistory.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.receipt_long_rounded, size: 56, color: Color(0xFF0284C7)),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Orders Found',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No orders found under filter "$_filter"',
                                style: TextStyle(color: subTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final order = filteredHistory[index];
                        final isCompleted = order.status == OrderStatus.completed || order.status == OrderStatus.delivered;
                        final isCancelled = order.status == OrderStatus.cancelled;
                        final isPending = order.status == OrderStatus.pending;
                        final isActive = !isCompleted && !isCancelled;

                        final isRated = (order.rating != null && order.rating! > 0) ||
                            (order.review != null && order.review!.isNotEmpty);

                        Color statusColor;
                        if (isCompleted) {
                          statusColor = const Color(0xFF10B981);
                        } else if (isCancelled) {
                          statusColor = const Color(0xFFEF4444);
                        } else {
                          statusColor = const Color(0xFF0284C7);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showOrderDetails(context, order, cardBg, textColor, subTextColor, borderColor),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order #${order.orderNumber}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${order.product} • ${order.quantity} Gallons',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year}',
                                                style: TextStyle(color: subTextColor, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₱${order.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFF0284C7),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                WaterOrder.toDisplayLabel(order.status).toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                    Divider(height: 1, color: borderColor),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (isPending)
                                          OutlinedButton.icon(
                                            onPressed: () => _showCancellationDialog(context, order),
                                            icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                            label: const Text('Cancel', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
                                              backgroundColor: const Color(0xFFEF4444).withOpacity(0.05),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          )
                                        else
                                          Row(
                                            children: [
                                              Icon(Icons.info_outline_rounded, size: 16, color: subTextColor),
                                              const SizedBox(width: 6),
                                              Text('Tap for details', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
                                            ],
                                          ),

                                        if (isActive)
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Provider.of<OrderProvider>(context, listen: false).setActiveOrder(order);
                                              Navigator.of(context).pushNamed('/tracker');
                                            },
                                            icon: const Icon(Icons.near_me_rounded, size: 16),
                                            label: const Text('TRACK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0284C7),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              minimumSize: const Size(90, 38),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              elevation: 0,
                                            ),
                                          )
                                        else if (isCompleted)
                                          if (isRated)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'RATED',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => ReviewScreen(order: order)),
                                                );
                                              },
                                              icon: const Icon(Icons.star_rounded, size: 16),
                                              label: const Text('RATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0284C7),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                minimumSize: const Size(90, 38),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                elevation: 0,
                                              ),
                                            )
                                        else if (isCancelled)
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).pushNamed('/order', arguments: order);
                                            },
                                            icon: const Icon(Icons.refresh_rounded, size: 16),
                                            label: const Text('REORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: cardBg,
                                              foregroundColor: const Color(0xFF0284C7),
                                              side: const BorderSide(color: Color(0xFF0284C7)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              minimumSize: const Size(80, 36),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              elevation: 0,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, WaterOrder order, Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = order.status == OrderStatus.completed || order.status == OrderStatus.delivered;
    final isCancelled = order.status == OrderStatus.cancelled;
    final isPending = order.status == OrderStatus.pending;

    // Palette Colors specified:
    // 60% Dominant (Backgrounds): #ADE1FB (Light Blue / frosted gradient with white)
    // 30% Secondary (Cards/Panels): #266CA9 (Medium Blue) & White Glass
    // 10% Accent (Buttons, Highlights, Text): #0F2573 (Dark Royal), #041D56 (Dark Navy), #01082D (Midnight)
    const accentRoyal = Color(0xFF0F2573);
    const accentNavy = Color(0xFF041D56);
    const accentMidnight = Color(0xFF01082D);
    const secondaryMediumBlue = Color(0xFF266CA9);
    const dominantLightBlue = Color(0xFFADE1FB);

    final sheetBg = isDark ? const Color(0xFF081226) : Colors.white;
    final cardGlassBg = isDark ? const Color(0xFF0F223D) : Colors.white.withValues(alpha: 0.95);
    final cardBorder = isDark ? const Color(0xFF1E3A5F) : dominantLightBlue.withValues(alpha: 0.6);
    final primaryTxt = isDark ? Colors.white : accentNavy;
    final subTxt = isDark ? const Color(0xFF94A3B8) : secondaryMediumBlue;

    // Admin Message / Remarks Extraction
    final String? adminMessage = (order.adminNotes != null && order.adminNotes!.trim().isNotEmpty)
        ? order.adminNotes
        : (order.cancellationReason != null && order.cancellationReason!.trim().isNotEmpty)
            ? order.cancellationReason
            : (order.notes != null && order.notes!.trim().isNotEmpty && !order.notes!.contains('Walk-In'))
                ? order.notes
                : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            gradient: isDark
                ? null
                : LinearGradient(
                    colors: [
                      const Color(0xFFF0F9FF),
                      dominantLightBlue.withValues(alpha: 0.45),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: accentMidnight.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Drag Handle Pill
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: secondaryMediumBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Main Glass Card Panel
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardGlassBg,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: secondaryMediumBlue.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header Bar with Title & Status Pill
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: secondaryMediumBlue.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      color: accentRoyal,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Order Receipt',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: primaryTxt,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : isCancelled
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                          : secondaryMediumBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCompleted
                                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                        : isCancelled
                                            ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                            : secondaryMediumBlue.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  WaterOrder.toDisplayLabel(order.status).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isCompleted
                                        ? const Color(0xFF10B981)
                                        : isCancelled
                                            ? const Color(0xFFEF4444)
                                            : secondaryMediumBlue,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2. High-Tech Reference ID Box (Fixes Overlap!)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: secondaryMediumBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: secondaryMediumBlue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.pin_rounded, size: 16, color: secondaryMediumBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ORDER REFERENCE ID',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: secondaryMediumBlue,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      SelectableText(
                                        '#${order.orderNumber}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: accentRoyal,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: secondaryMediumBlue),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: order.orderNumber));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Order reference ID copied!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  tooltip: 'Copy Reference ID',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                          Divider(color: cardBorder, height: 1),
                          const SizedBox(height: 16),

                          // 3. ADMIN MESSAGE / STATION REMARKS CARD (User Request)
                          if (adminMessage != null && adminMessage.trim().isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isCancelled
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                                    : secondaryMediumBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isCancelled
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                      : secondaryMediumBlue.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isCancelled
                                            ? Icons.error_outline_rounded
                                            : Icons.admin_panel_settings_rounded,
                                        color: isCancelled ? const Color(0xFFDC2626) : accentRoyal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isCancelled ? 'CANCELLATION REASON' : 'ADMIN / STATION MESSAGE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: isCancelled ? const Color(0xFFDC2626) : accentRoyal,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    adminMessage.trim(),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: primaryTxt,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 4. Order Meta Details
                          _detailRow(
                            Icons.calendar_today_rounded,
                            'DATE & TIME',
                            '${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year} at ${order.timestamp.hour.toString().padLeft(2, '0')}:${order.timestamp.minute.toString().padLeft(2, '0')}',
                            primaryTxt,
                            subTxt,
                          ),
                          _detailRow(
                            Icons.payments_outlined,
                            'PAYMENT METHOD',
                            order.paymentMethod,
                            primaryTxt,
                            subTxt,
                          ),
                          _detailRow(
                            Icons.location_on_outlined,
                            'DELIVERY / PICKUP ADDRESS',
                            order.isWalkIn
                                ? 'Counter Walk-in / Station Pickup'
                                : order.address.isNotEmpty
                                    ? order.address
                                    : 'Station Pickup',
                            primaryTxt,
                            subTxt,
                          ),

                          const SizedBox(height: 16),
                          Divider(color: cardBorder, height: 1),
                          const SizedBox(height: 16),

                          // 5. Items Breakdown Table
                          Text(
                            'ITEMS ORDERED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: subTxt,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (order.items.isNotEmpty)
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: secondaryMediumBlue.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${item.quantity}x',
                                          style: const TextStyle(
                                            color: accentRoyal,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          style: TextStyle(
                                            color: primaryTxt,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₱${item.subtotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: primaryTxt,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: secondaryMediumBlue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${order.quantity}x',
                                      style: const TextStyle(
                                        color: accentRoyal,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      order.product,
                                      style: TextStyle(
                                        color: primaryTxt,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₱${order.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: primaryTxt,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),
                          Divider(color: cardBorder, height: 1),
                          const SizedBox(height: 16),

                          // 6. Total Amount Highlight Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentRoyal.withValues(alpha: 0.1),
                                  secondaryMediumBlue.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: secondaryMediumBlue.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL PAID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: accentNavy,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '₱${order.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: accentRoyal,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Cancel Option for Pending Orders
                          if (isPending) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showCancellationDialog(context, order);
                                },
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                label: const Text(
                                  'Cancel Order',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // 7. QR Verification
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: order.orderNumber,
                                    version: QrVersions.auto,
                                    size: 90.0,
                                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: accentMidnight),
                                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: accentMidnight),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'ORDER VERIFICATION QR',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: secondaryMediumBlue,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 8. Action Buttons Row (Reorder & Close - Properly Separated!)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
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
                                Navigator.of(context).pushNamed('/order', arguments: order);
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                              label: const Text(
                                'REORDER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'CLOSE',
                          style: TextStyle(
                            color: subTxt,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF266CA9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF0F2573)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancellationDialogContent extends StatefulWidget {
  final WaterOrder order;
  final Color cardBg;
  final Color textColor;
  final Color subTextColor;

  const _CancellationDialogContent({
    required this.order,
    required this.cardBg,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  State<_CancellationDialogContent> createState() => __CancellationDialogContentState();
}

class __CancellationDialogContentState extends State<_CancellationDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isCancelling = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitCancellation() async {
    if (_isCancelling) return;
    if (!_formKey.currentState!.validate()) return;

    final rawReason = _reasonController.text;
    final cleanReason = CancellationValidationUtils.sanitizeInput(rawReason);

    HapticFeedback.mediumImpact();
    setState(() => _isCancelling = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await SupabaseService.cancelCustomerOrder(
        orderId: widget.order.id,
        customerId: user.id,
        reason: cleanReason,
        existingNotes: widget.order.notes,
      );

      if (!mounted) return;

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchMyOrders();

      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      TopBanner.show(
        context,
        'Order #${widget.order.orderNumber} cancelled successfully.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchMyOrders();

      if (!mounted) return;
      Navigator.pop(context);

      TopBanner.show(
        context,
        'Order #${widget.order.orderNumber} cancelled successfully.',
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 20,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: widget.cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cancel_outlined,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Cancel Order',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: widget.textColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: widget.subTextColor),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Order #${widget.order.orderNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Please specify a valid reason for cancelling this water refill order.',
                  style: TextStyle(fontSize: 12, color: widget.subTextColor, height: 1.35, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _reasonController,
                  enabled: !_isCancelling,
                  maxLines: 3,
                  maxLength: 250,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                  ],
                  style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w600, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Reason for Cancellation *',
                    hintText: 'e.g. Ordered by mistake / Change of schedule...',
                    alignLabelWithHint: true,
                  ),
                  validator: CancellationValidationUtils.validateReason,
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCancelling ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'KEEP ORDER',
                          style: TextStyle(color: widget.subTextColor, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isCancelling ? null : _submitCancellation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text(
                                  'CANCEL ORDER',
                                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
