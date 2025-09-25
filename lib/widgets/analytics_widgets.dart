// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final IconData? icon;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: icon != null ? Icon(icon, color: const Color(0xFF4CAF50)) : null,
        title: Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class AnalyticsMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? valueColor;
  final IconData? icon;

  const AnalyticsMetricItem({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change != null && change!.startsWith('+');
    final hasChange = change != null && change!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
        if (hasChange) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                change!,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class TopPerformersList extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String nameKey;
  final String valueKey;
  final String? subtitleKey;
  final IconData? itemIcon;
  final Color? iconColor;
  final int maxItems;

  const TopPerformersList({
    super.key,
    required this.title,
    required this.items,
    required this.nameKey,
    required this.valueKey,
    this.subtitleKey,
    this.itemIcon,
    this.iconColor,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        ...items.take(maxItems).map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                itemIcon ?? Icons.circle,
                color: iconColor ?? const Color(0xFF4CAF50),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item[nameKey]?.toString() ?? 'Unknown',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitleKey != null && item[subtitleKey] != null)
                      Text(
                        item[subtitleKey].toString(),
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _formatValue(item[valueKey]),
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  String _formatValue(dynamic value) {
    if (value is double) {
      if (value >= 1000000) {
        return '₱${(value / 1000000).toStringAsFixed(1)}M';
      } else if (value >= 1000) {
        return '₱${(value / 1000).toStringAsFixed(1)}K';
      } else {
        return '₱${value.toStringAsFixed(0)}';
      }
    }
    return value?.toString() ?? '0';
  }
}

class SeasonIndicator extends StatelessWidget {
  final String season;
  final bool isCurrent;

  const SeasonIndicator({
    super.key,
    required this.season,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent 
            ? const Color(0xFF4CAF50).withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent 
              ? const Color(0xFF4CAF50)
              : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSeasonIcon(season),
            size: 16,
            color: isCurrent 
                ? const Color(0xFF4CAF50)
                : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            season,
            style: GoogleFonts.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isCurrent 
                  ? const Color(0xFF4CAF50)
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSeasonIcon(String season) {
    switch (season.toLowerCase()) {
      case 'spring':
        return Icons.local_florist;
      case 'summer':
        return Icons.wb_sunny;
      case 'fall':
      case 'autumn':
        return Icons.park;
      case 'winter':
        return Icons.ac_unit;
      default:
        return Icons.help;
    }
  }
}

class AnalyticsLoadingCard extends StatelessWidget {
  final String title;
  final String loadingText;

  const AnalyticsLoadingCard({
    super.key,
    required this.title,
    this.loadingText = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
    strokeWidth: 2.5, // adjust thickness
    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 16),
            Text(
              loadingText,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
