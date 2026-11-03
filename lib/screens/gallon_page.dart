import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/gallon.dart';
import '../models/gallon_transaction.dart';
import '../providers/gallon_provider.dart';
import '../theme/premium_theme.dart';

class GallonPage extends StatefulWidget {
  const GallonPage({super.key});

  @override
  State<GallonPage> createState() => _GallonPageState();
}

class _GallonPageState extends State<GallonPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GallonProvider>(context, listen: false).fetchGallonsAndHistory();
    });
  }

  void _showContainerDetails(BuildContext context, Gallon g) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.paletteNavy : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppGradients.electric,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.opacity_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTAINER TELEMETRY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: isDark ? AppColors.paletteLight : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.label.isNotEmpty ? g.label : 'AquaSync 20L Smart Container',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.paletteMidnight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _detailRow(Icons.fingerprint_rounded, 'Container Serial / ID', g.id, isDark),
              const Divider(height: 24),
              _detailRow(Icons.verified_rounded, 'Structural Condition', g.condition, isDark),
              const Divider(height: 24),
              _detailRow(
                Icons.radar_rounded,
                'Current Telemetry Status',
                g.status == GallonStatus.borrowed ? 'At Customer Location (Secure)' : 'In Transit / Dispatched',
                isDark,
              ),
              const Divider(height: 24),
              _detailRow(Icons.security_rounded, 'RFID / IoT Chip Sync', 'Active & Encrypted (AquaSync Secure)', isDark),
              const SizedBox(height: 28),
              LiquidButton(
                text: 'CLOSE DETAILS',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: isDark ? AppColors.subTextDark : AppColors.subTextLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.paletteMidnight, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallonProvider = Provider.of<GallonProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? AppColors.subTextDark : AppColors.subTextLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final activeGallons = gallonProvider.activeGallons;
    final history = gallonProvider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Gallons & Telemetry'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Telemetry',
            onPressed: () {
              HapticFeedback.lightImpact();
              gallonProvider.fetchGallonsAndHistory();
            },
          ),
        ],
      ),
      body: gallonProvider.isLoading && activeGallons.isEmpty && history.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await gallonProvider.fetchGallonsAndHistory();
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Container Telemetry Overview Banner
                    _buildTelemetryBanner(activeGallons.length, history.length),
                    const SizedBox(height: 24),

                    // ACTIVE INVENTORY SECTION
                    _sectionHeader(
                      Icons.inventory_2_rounded,
                      'ACTIVE SMART CONTAINERS',
                      '${activeGallons.length} At Home',
                    ),
                    const SizedBox(height: 12),

                    if (activeGallons.isEmpty) ...[
                      _buildEmptyState(
                        Icons.inventory_2_outlined,
                        'No Active Containers',
                        'You currently don\'t have any borrowed or active water containers at home.',
                        cardBg,
                        borderColor,
                        textColor,
                        subTextColor,
                      ),
                    ] else ...[
                      ...activeGallons.map((g) => _buildGallonItem(g, cardBg, borderColor, textColor, subTextColor)),
                    ],

                    const SizedBox(height: 32),

                    // TRANSACTION HISTORY SECTION
                    _sectionHeader(Icons.history_rounded, 'CONTAINER LOGS & HISTORY', 'Recent Updates'),
                    const SizedBox(height: 12),

                    if (history.isEmpty) ...[
                      _buildEmptyState(
                        Icons.history_outlined,
                        'No Transaction History',
                        'Your container borrowing, return, and swap logs will appear here.',
                        cardBg,
                        borderColor,
                        textColor,
                        subTextColor,
                      ),
                    ] else ...[
                      ...history.map((t) => _buildHistoryItem(t, cardBg, borderColor, textColor, subTextColor)),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTelemetryBanner(int activeCount, int totalHistory) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.ocean,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.paletteNavy.withValues(alpha: 0.35),
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
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: AppColors.paletteLight, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'IoT CONTAINER TELEMETRY',
                    style: TextStyle(
                      color: AppColors.paletteLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 5),
                    Text('Live Sync', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol('$activeCount', 'AT HOME', Icons.home_rounded),
              Container(width: 1, height: 36, color: Colors.white24),
              _statCol('$totalHistory', 'TOTAL LOGS', Icons.analytics_rounded),
              Container(width: 1, height: 36, color: Colors.white24),
              _statCol('100%', 'CONDITION', Icons.verified_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCol(String num, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.paletteLight, size: 14),
            const SizedBox(width: 4),
            Text(num, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title, String badge) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.secondary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildGallonItem(Gallon g, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final statusColor = g.status == GallonStatus.borrowed ? AppColors.secondary : AppColors.success;
    final statusLabel = g.status == GallonStatus.borrowed ? 'WITH CUSTOMER' : 'IN TRANSIT';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showContainerDetails(context, g),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.opacity_rounded, color: statusColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ID: ${g.id}',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              g.condition,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subTextColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        g.label.isNotEmpty ? g.label : 'AquaSync 20L Refill Container',
                        style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(GallonTransaction t, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final isReturn = t.action.toLowerCase().contains('return');
    final actionColor = isReturn ? AppColors.success : AppColors.primary;
    final actionIcon = isReturn ? Icons.assignment_return_rounded : Icons.shopping_bag_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(actionIcon, color: actionColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${t.action.toUpperCase()} • ${t.gallonLabel}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDate(t.timestamp),
                      style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Container ID: ${t.gallonId}',
                  style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    IconData icon,
    String title,
    String desc,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 12, color: subTextColor, height: 1.4), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

