// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/countdown_timer_service.dart';
import 'package:google_fonts/google_fonts.dart';

class CountdownTimerWidget extends StatefulWidget {
  final String productId;
  final VoidCallback? onTimerComplete;

  const CountdownTimerWidget({
    super.key,
    required this.productId,
    this.onTimerComplete,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget>
    with TickerProviderStateMixin {
  final CountdownTimerService _countdownService = CountdownTimerService();
  StreamSubscription<int>? _countdownSubscription;
  int _remainingSeconds = 120;
  bool _isActive = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCountdown();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (_remainingSeconds <= 30) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _initializeCountdown() {
    // Start countdown if not already active
    if (!_countdownService.isCountdownActive(widget.productId)) {
      _countdownService.startCountdown(widget.productId);
    }

    // Get current remaining time
    final currentRemainingTime = _countdownService.getRemainingTime(widget.productId);
    if (currentRemainingTime != null) {
      setState(() {
        _remainingSeconds = currentRemainingTime;
        _isActive = true;
      });
    }

    // Listen to countdown updates
    _countdownSubscription = _countdownService.getCountdownStream(widget.productId)?.listen(
      (remainingSeconds) {
        setState(() {
          _remainingSeconds = remainingSeconds;
          _isActive = true;
        });

        if (remainingSeconds <= 0) {
          _isActive = false;
          widget.onTimerComplete?.call();
        } else if (remainingSeconds <= 30) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      },
    );
  }

  @override
  void dispose() {
    _countdownSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingSeconds > 60) {
      return const Color(0xFF4CAF50);
    } else if (_remainingSeconds > 30) {
      return const Color(0xFFFF9800);
    } else {
      return const Color(0xFFF44336);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActive && _remainingSeconds <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4CAF50), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Auto-approved!',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _remainingSeconds <= 30 ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getTimerColor(), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getTimerColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.timer,
                    color: _getTimerColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-approval in:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getTimerColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_remainingSeconds <= 30)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF44336).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF44336).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'URGENT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF44336),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}