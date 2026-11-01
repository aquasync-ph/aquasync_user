import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/gallon.dart';
import '../models/gallon_transaction.dart';
import '../providers/gallon_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final gallonProvider = Provider.of<GallonProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    final activeGallons = gallonProvider.activeGallons;
    final history = gallonProvider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Gallons'),
        centerTitle: true,
      ),
      body: gallonProvider.isLoading && activeGallons.isEmpty && history.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await gallonProvider.fetchGallonsAndHistory();
              },
              color: const Color(0xFF0284C7),
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
                      'ACTIVE CONTAINERS',
                      '${activeGallons.length} At Home',
                    ),
                    const SizedBox(height: 12),

                    if (activeGallons.isEmpty) ...[
                      _buildEmptyState(
                        Icons.inventory_2_outlined,
                        'No Active Containers',
                        'You currently don\'t have any borrowed containers at home.',
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
                    _sectionHeader(Icons.history_rounded, 'TRANSACTION HISTORY', 'Recent Updates'),
                    const SizedBox(height: 12),

                    if (history.isEmpty) ...[
                      _buildEmptyState(
                        Icons.history_outlined,
                        'No Transactions Yet',
                        'Your gallon borrowing and return history will appear here.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2573), Color(0xFF266CA9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2573).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'CONTAINER TELEMETRY',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Live Track', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol('$activeCount', 'AT HOME'),
              Container(width: 1, height: 32, color: Colors.white24),
              _statCol('$totalHistory', 'TOTAL ACTIONS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCol(String num, String label) {
    return Column(
      children: [
        Text(num, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String title,
    String badge,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF266CA9).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF0F2573), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F2573), letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF266CA9))),
      ],
    );
  }

  Widget _buildGallonItem(Gallon g, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final statusColor = g.status == GallonStatus.borrowed ? const Color(0xFF0F2573) : const Color(0xFF10B981);
    final statusLabel = g.status == GallonStatus.borrowed ? 'WITH CUSTOMER' : 'TRANSIT';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF266CA9).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.opacity_rounded, color: statusColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gallon ID: ${g.id}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor)),
                  Text(g.label.isNotEmpty ? g.label : '20L Station Refill Container', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(GallonTransaction t, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final isReturn = t.action == 'returned';
    final actionColor = isReturn ? const Color(0xFF10B981) : const Color(0xFF0284C7);
    final actionIcon = isReturn ? Icons.assignment_return_rounded : Icons.shopping_bag_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(actionIcon, color: actionColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.action.toUpperCase()} - ${t.gallonLabel}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
                ),
                Text(
                  'ID: ${t.gallonId} • ${_formatDate(t.timestamp)}',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String desc, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0x330284C7)),
          const SizedBox(height: 18),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 12, color: subTextColor, height: 1.4), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
