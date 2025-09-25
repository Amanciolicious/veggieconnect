// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/supplier_verification.dart';
import '../services/supplier_verification_service.dart';
import '../services/auth_state_service.dart';
import '../widgets/lottie_loading_widget.dart';
import '../widgets/role_page_header.dart';

class AdminVerificationReviewPage extends StatefulWidget {
  const AdminVerificationReviewPage({super.key});

  @override
  State<AdminVerificationReviewPage> createState() => _AdminVerificationReviewPageState();
}

class _AdminVerificationReviewPageState extends State<AdminVerificationReviewPage> {
  final AuthStateService _authService = AuthStateService();
  String _filterStatus = 'pending'; // 'all', 'pending', 'approved', 'rejected'
  final TextEditingController _reviewNotesController = TextEditingController();
  late final Ticker _ticker;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(DateTime.now());

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _nowNotifier.dispose();
    _reviewNotesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((_) {
      final current = DateTime.now();
      if (current.second != _nowNotifier.value.second) {
        _nowNotifier.value = current;
      }
    });
    _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: RolePageHeader(
        title: 'Verification Review',
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            setState(() { _filterStatus = value; });
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'all', child: Text('All Requests')),
            PopupMenuItem(value: 'pending', child: Text('Pending Review')),
            PopupMenuItem(value: 'approved', child: Text('Approved')),
            PopupMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          icon: const Icon(Icons.filter_list, color: Color(0xFF4CAF50)),
        ),
      ),
      body: Column(
        children: [
          // Status Filter Chips
          Container(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  SizedBox(width: 8),
                  _buildFilterChip('Approved', 'approved'),
                  SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),
          // Verification Requests List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getVerificationRequestsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: LottieLoadingWidget(
                    assetPath: 'assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json',
                    showText: true,
                  ));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading verification requests',
                          style: GoogleFonts.quicksand(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _filterStatus == 'pending' 
                            ? 'No pending verification requests'
                            : 'No verification requests found',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final verification = SupplierVerification.fromFirestore(docs[index]);
                    return _buildVerificationCard(verification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.quicksand(
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Color(0xFF6CA04A),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Color(0xFF6CA04A),
      checkmarkColor: Colors.white,
      elevation: isSelected ? 4 : 1,
      shadowColor: Color(0xFF6CA04A).withOpacity(0.3),
    );
  }

  Stream<QuerySnapshot> _getVerificationRequestsStream() {
    Query query = FirebaseFirestore.instance
        .collection('supplier_verifications')
        .orderBy('submittedAt', descending: true);

    if (_filterStatus != 'all') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return query.snapshots();
  }

  Widget _buildVerificationCard(SupplierVerification verification) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with supplier info, status, and countdown timer
            Stack(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFF6CA04A).withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF6CA04A),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            verification.supplierName,
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E2E2E),
                            ),
                          ),
                          Text(
                            verification.supplierEmail,
                            style: GoogleFonts.quicksand(
                              fontSize: 11,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(verification.status),
                  ],
                ),
                // Live countdown timer in upper right corner
                if (verification.status == 'pending')
                  Positioned(
                    top: 0,
                    right: 0,
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: _nowNotifier,
                      builder: (_, now, _) {
                        final DateTime target = (verification.autoApprovalScheduledAt ?? verification.submittedAt.add(Duration(hours: 24)));
                        final timeLeft = target.difference(now);
                        
                        if (timeLeft.isNegative) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, size: 16, color: Colors.red),
                                SizedBox(width: 4),
                                Text(
                                  'OVERDUE',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        final hours = timeLeft.inHours;
                        final minutes = timeLeft.inMinutes % 60;
                        final seconds = timeLeft.inSeconds % 60;
                        
                        final isUrgent = timeLeft.inHours < 1;
                        
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUrgent ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUrgent ? Colors.red : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 16,
                                color: isUrgent ? Colors.red : Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${seconds}s',
                                style: GoogleFonts.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isUrgent ? Colors.red : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            
            // Submission details
            _buildInfoRow('Submitted', _formatDateTime(verification.submittedAt)),
            if (verification.reviewedAt != null)
              _buildInfoRow('Reviewed', _formatDateTime(verification.reviewedAt!)),
            if (verification.reviewedBy != null)
              _buildInfoRow('Reviewed By', verification.reviewedBy!),
            if (verification.status == 'pending') ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: _nowNotifier,
                        builder: (_, now, _) {
                          final DateTime target = (verification.autoApprovalScheduledAt ?? verification.submittedAt.add(Duration(hours: 24)));
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-approval scheduled for 24 hours after submission',
                                style: GoogleFonts.quicksand(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatCountdown(target, now),
                                style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 16),
            
            // OCR extracted data
            if (verification.extractedName != null || 
                verification.extractedIdNumber != null ||
                verification.extractedAddress != null) ...[
              Text(
                'Extracted Information',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (verification.extractedName != null)
                      _buildExtractedDataRow('Name', verification.extractedName!),
                    if (verification.extractedIdNumber != null)
                      _buildExtractedDataRow('ID Number', verification.extractedIdNumber!),
                    if (verification.extractedAddress != null)
                      _buildExtractedDataRow('Address', verification.extractedAddress!),
                    if (verification.extractedDateOfBirth != null)
                      _buildExtractedDataRow('Date of Birth', verification.extractedDateOfBirth!),
                    if (verification.extractedGender != null)
                      _buildExtractedDataRow('Gender', verification.extractedGender!),
                    if (verification.ocrConfidenceScore != null)
                      _buildExtractedDataRow('OCR Confidence', '${(verification.ocrConfidenceScore! * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            // ID Images
            Row(
              children: [
                Expanded(
                  child: _buildImagePreview('Front ID', verification.frontIdImageUrl),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildImagePreview('Back ID', verification.backIdImageUrl),
                ),
              ],
            ),
            
            // Review notes (if any)
            if (verification.reviewNotes != null && verification.reviewNotes!.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Review Notes',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  verification.reviewNotes!,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ],
            
            // Action buttons (only for pending requests)
            if (verification.status == 'pending') ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(verification),
                      icon: Icon(Icons.close, color: Colors.red),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showApprovalDialog(context, verification),
                      icon: Icon(Icons.check, color: Colors.white),
                      label: Text(
                        'Approve',
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6CA04A),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    switch (status) {
      case 'approved':
        backgroundColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        backgroundColor = Colors.red;
        textColor = Colors.white;
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        icon = Icons.pending;
        break;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedDataRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String title, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E2E2E),
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showFullScreenImage(imageUrl, title),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / 
                            loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'Failed to load',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: GoogleFonts.quicksand(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Text(
                title,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApprovalDialog(BuildContext context, SupplierVerification verification) async {
    Timer? countdownTimer;
    
    return showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start countdown timer for the dialog
            countdownTimer ??= Timer.periodic(Duration(seconds: 1), (timer) {
              if (mounted) {
                setState(() {});
              }
            });
            
            return AlertDialog(
              title: Stack(
                children: [
                  Text('Approve Verification'),
                  // Live countdown timer in upper right corner
                  Positioned(
                    top: 0,
                    right: 0,
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: _nowNotifier,
                      builder: (_, now, _) {
                        final DateTime target = (verification.autoApprovalScheduledAt ?? verification.submittedAt.add(Duration(hours: 24)));
                        final timeLeft = target.difference(now);
                        
                        if (timeLeft.isNegative) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, size: 16, color: Colors.red),
                                SizedBox(width: 4),
                                Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        final hours = timeLeft.inHours;
                        final minutes = timeLeft.inMinutes % 60;
                        final seconds = timeLeft.inSeconds % 60;
                        
                        final isUrgent = timeLeft.inHours < 1;
                        
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isUrgent ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUrgent ? Colors.red : Colors.green,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isUrgent ? Colors.red : Colors.green).withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 18,
                                color: isUrgent ? Colors.red : Colors.green,
                              ),
                              SizedBox(width: 6),
                              Text(
                                hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${seconds}s',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isUrgent ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Are you sure you want to approve this supplier verification?'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _nowNotifier,
                            builder: (_, now, _) {
                              final DateTime target = (verification.autoApprovalScheduledAt ?? verification.submittedAt.add(Duration(hours: 24)));
                              final timeLeft = target.difference(now);
                              
                              String countdownText;
                              if (timeLeft.isNegative) {
                                countdownText = 'Auto-approval overdue - will be approved immediately';
                              } else {
                                final hours = timeLeft.inHours;
                                final minutes = timeLeft.inMinutes % 60;
                                final seconds = timeLeft.inSeconds % 60;
                                
                                if (hours > 0) {
                                  countdownText = 'Auto-approval in ${hours}h ${minutes}m ${seconds}s';
                                } else if (minutes > 0) {
                                  countdownText = 'Auto-approval in ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
                                } else {
                                  countdownText = 'Auto-approval in ${seconds}s';
                                }
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manual approval will prevent auto-approval',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    countdownText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    countdownTimer?.cancel();
                    Navigator.of(context).pop();
                    await _approveVerification(verification);
                  },
                  child: Text('Approve', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      countdownTimer?.cancel();
    });
  }


  Future<void> _approveVerification(SupplierVerification verification) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await SupplierVerificationService.approveVerification(
        verification.id,
        user.uid,
        notes: 'Approved by admin review',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error approving verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(SupplierVerification verification) {
    _reviewNotesController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Verification',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejecting this verification request:',
              style: GoogleFonts.quicksand(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _reviewNotesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.quicksand(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectVerification(verification, _reviewNotesController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Reject',
              style: GoogleFonts.quicksand(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectVerification(SupplierVerification verification, String reason) async {
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please provide a reason for rejection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await SupplierVerificationService.rejectVerification(
        verification.id,
        user.uid,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error rejecting verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatCountdown(DateTime target, DateTime now) {
    final diff = target.difference(now);
    if (diff.isNegative) return 'Auto-approval overdue';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return 'Auto-approval in ${h}h ${m}m ${s}s';
    if (m > 0) return 'Auto-approval in ${m}m ${s.toString().padLeft(2, '0')}s';
    return 'Auto-approval in ${s}s';
  }
}
