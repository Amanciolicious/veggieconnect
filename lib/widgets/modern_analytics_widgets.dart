// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern Analytics Dashboard Components
/// Implements latest analytics indicators and design patterns for 2024

class ModernAnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? loadingText;

  const ModernAnalyticsCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
    this.onTap,
    this.isLoading = false,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (iconColor ?? const Color(0xFF4CAF50)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor ?? const Color(0xFF4CAF50),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (isLoading)
                  _buildLoadingState()
                else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(
    strokeWidth: 2.5, // adjust thickness
    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 16),
        Text(
          loadingText ?? 'Loading...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class ModernKPIWidget extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? change;
  final IconData icon;
  final Color color;
  final Color? valueColor;
  final bool isPositive;
  final VoidCallback? onTap;

  const ModernKPIWidget({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.change,
    required this.icon,
    required this.color,
    this.valueColor,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 14,
                ),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        change!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ModernChartWidget extends StatelessWidget {
  final String title;
  final Widget chart;
  final String? subtitle;
  final List<String>? legends;
  final List<Color>? legendColors;

  const ModernChartWidget({
    super.key,
    required this.title,
    required this.chart,
    this.subtitle,
    this.legends,
    this.legendColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: chart,
          ),
          if (legends != null && legends!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: legends!.asMap().entries.map((entry) {
        final index = entry.key;
        final legend = entry.value;
        final color = legendColors != null && index < legendColors!.length
            ? legendColors![index]
            : Colors.grey;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                legend,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class RealTimeMetricWidget extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Duration updateInterval;
  final String Function() valueBuilder;

  const RealTimeMetricWidget({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.updateInterval = const Duration(seconds: 5),
    required this.valueBuilder,
  });

  @override
  State<RealTimeMetricWidget> createState() => _RealTimeMetricWidgetState();
}

class _RealTimeMetricWidgetState extends State<RealTimeMetricWidget> {
  late String _currentValue;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    Future.delayed(widget.updateInterval, () {
      if (mounted) {
        setState(() {
          _isUpdating = true;
        });
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _currentValue = widget.valueBuilder();
              _isUpdating = false;
            });
            _startPeriodicUpdate();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.icon,
                color: widget.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              if (_isUpdating)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
    strokeWidth: 2.5, // adjust thickness
    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentValue,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

class PerformanceIndicatorWidget extends StatelessWidget {
  final String title;
  final double value;
  final double maxValue;
  final Color color;
  final String unit;
  final String? description;

  const PerformanceIndicatorWidget({
    super.key,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.color,
    this.unit = '%',
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue * 100).clamp(0, 100);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}$unit',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TopPerformersWidget extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String nameKey;
  final String valueKey;
  final String? subtitleKey;
  final IconData? itemIcon;
  final Color? iconColor;
  final int maxItems;
  final String valueSuffix;

  const TopPerformersWidget({
    super.key,
    required this.title,
    required this.items,
    required this.nameKey,
    required this.valueKey,
    this.subtitleKey,
    this.itemIcon,
    this.iconColor,
    this.maxItems = 5,
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          ...items.take(maxItems).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isTopThree = index < 3;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTopThree 
                    ? (iconColor ?? const Color(0xFF4CAF50)).withOpacity(0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: isTopThree 
                    ? Border.all(
                        color: (iconColor ?? const Color(0xFF4CAF50)).withOpacity(0.2),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isTopThree 
                          ? (iconColor ?? const Color(0xFF4CAF50))
                          : Colors.grey[400],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (itemIcon != null) ...[
                    Icon(
                      itemIcon,
                      color: iconColor ?? const Color(0xFF4CAF50),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item[nameKey]?.toString() ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (subtitleKey != null && item[subtitleKey] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item[subtitleKey].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${item[valueKey]?.toString() ?? '0'}$valueSuffix',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isTopThree 
                          ? (iconColor ?? const Color(0xFF4CAF50))
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TrendIndicatorWidget extends StatelessWidget {
  final String title;
  final double currentValue;
  final double previousValue;
  final String unit;
  final IconData icon;
  final Color color;

  const TrendIndicatorWidget({
    super.key,
    required this.title,
    required this.currentValue,
    required this.previousValue,
    this.unit = '',
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final change = previousValue != 0 
        ? ((currentValue - previousValue) / previousValue * 100)
        : 0.0;
    final isPositive = change >= 0;
    final changeText = change == 0 
        ? 'No change'
        : '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${currentValue.toStringAsFixed(1)}$unit',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                changeText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InteractiveChartWidget extends StatefulWidget {
  final String title;
  final Widget chart;
  final String? subtitle;
  final List<String>? legends;
  final List<Color>? legendColors;
  final VoidCallback? onTap;
  final bool isExpandable;

  const InteractiveChartWidget({
    super.key,
    required this.title,
    required this.chart,
    this.subtitle,
    this.legends,
    this.legendColors,
    this.onTap,
    this.isExpandable = true,
  });

  @override
  State<InteractiveChartWidget> createState() => _InteractiveChartWidgetState();
}

class _InteractiveChartWidgetState extends State<InteractiveChartWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isExpandable)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ),
              if (widget.onTap != null)
                IconButton(
                  onPressed: widget.onTap,
                  icon: Icon(
                    Icons.open_in_new,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? 400 : 200,
            child: widget.chart,
          ),
          if (widget.legends != null && widget.legends!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.legends!.asMap().entries.map((entry) {
        final index = entry.key;
        final legend = entry.value;
        final color = widget.legendColors != null && index < widget.legendColors!.length
            ? widget.legendColors![index]
            : Colors.grey;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                legend,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class AnalyticsFilterWidget extends StatefulWidget {
  final List<String> options;
  final String selectedOption;
  final Function(String) onChanged;
  final String title;

  const AnalyticsFilterWidget({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onChanged,
    required this.title,
  });

  @override
  State<AnalyticsFilterWidget> createState() => _AnalyticsFilterWidgetState();
}

class _AnalyticsFilterWidgetState extends State<AnalyticsFilterWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.options.map((option) {
                final isSelected = option == widget.selectedOption;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => widget.onChanged(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected 
                            ? null
                            : Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickActionWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickActionWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
