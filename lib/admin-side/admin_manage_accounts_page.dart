// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/role_page_header.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart';
import '../services/supplier_report_service.dart';
import '../models/supplier_report_model.dart';
import '../services/ban_service.dart';
import '../widgets/lottie_loading_widget.dart';

class AdminManageAccountsPage extends StatefulWidget {
  const AdminManageAccountsPage({super.key});

  @override
  State<AdminManageAccountsPage> createState() => _AdminManageAccountsPageState();
}

class _AdminManageAccountsPageState extends State<AdminManageAccountsPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Ticker _ticker;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(DateTime.now());

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _nowNotifier.dispose();
    _searchController.dispose();
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
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: const RolePageHeader(title: 'Manage Accounts'),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Accounts',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Color(0xFF8D9773).withOpacity(0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search users',
                  hintStyle: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Color(0xFF757575),
                  ),
                  suffixIcon: Icon(Icons.search, size: screenWidth * 0.04),
                ),
                onChanged: (query) => setState(() {}),
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: GroceryLoadingWidget(
                        size: 120,
                        showText: true,
                        loadingText: 'Loading users...',
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.08),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Color(0xFF8D9773).withOpacity(0.08),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: screenWidth * 0.15,
                              color: Color(0xFF6CA04A),
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            Text(
                              'No Users',
                              style: TextStyle(
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6CA04A),
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.02),
                            Text(
                              'No user accounts found',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Color(0xFF757575),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final users = snapshot.data!.docs;
                  final query = _searchController.text.toLowerCase();
                  final filteredUsers = users.where((user) {
                    final userData = user.data() as Map<String, dynamic>;
                    final fullName = userData['fullName']?.toLowerCase() ?? '';
                    final email = userData['email']?.toLowerCase() ?? '';
                    return fullName.contains(query) || email.contains(query);
                  }).toList();

                  return ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index].data() as Map<String, dynamic>;
                      return _buildUserCard(context, screenWidth, filteredUsers[index].id, user);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
    final createdAt = user['createdAt'] as Timestamp?;
    final date = createdAt?.toDate() ?? DateTime.now();
    final isSupplier = user['role']?.toLowerCase() == 'supplier';
    final isBanned = user['isBanned'] ?? false;
    final isAdmin = user['role']?.toLowerCase() == 'admin';
    final isCurrentAdmin = user['email'] == 'current_admin@example.com'; // Replace with actual current admin check
    final isTemporaryBan = user['banType'] == 'temporary';

    // Hide admin accounts and current admin from the list
    if (isAdmin || isCurrentAdmin) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.04),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Color(0xFF8D9773).withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header with countdown timer overlay
          Stack(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.04,
                    backgroundColor: isBanned ? Colors.red : Color(0xFF6CA04A),
                    child: Text(
                      (user['fullName'] ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['fullName'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user['email'] ?? 'No email',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Color(0xFF757575),
                          ),
                        ),
                        if (isBanned) ...[
                          SizedBox(height: screenWidth * 0.01),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenWidth * 0.005),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(screenWidth * 0.01),
                            ),
                            child: Text(
                              user['banType'] == 'permanent' ? 'PERMANENTLY BANNED' : 'TEMPORARILY BANNED',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenWidth * 0.01),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user['role']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Text(
                      user['role'] ?? 'User',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: _getRoleColor(user['role']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Report count indicator for suppliers only
                  if (isSupplier) ...[
                    SizedBox(width: screenWidth * 0.02),
                    FutureBuilder<int>(
                      future: SupplierReportService.getSupplierReportCount(userId),
                      builder: (context, reportSnapshot) {
                        final reportCount = reportSnapshot.data ?? 0;

                        // Determine color based on report count
                        Color reportColor;
                        String warningText = '';
                        if (reportCount >= 3) {
                          reportColor = Colors.red;
                          warningText = 'AUTO-BANNED';
                        } else if (reportCount >= 2) {
                          reportColor = Colors.orange;
                          warningText = 'WARNING';
                        } else {
                          reportColor = Colors.grey;
                        }

                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025, vertical: screenWidth * 0.015),
                          decoration: BoxDecoration(
                            color: reportColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                            border: Border.all(color: reportColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                reportCount >= 3 ? Icons.block : Icons.report_problem,
                                size: screenWidth * 0.035,
                                color: Colors.white,
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$reportCount/3 Reports',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.03,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (warningText.isNotEmpty)
                                    Text(
                                      warningText,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.025,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              // Live countdown timer for temporary bans in upper right corner
              if (isBanned && isTemporaryBan && user['banExpiresAt'] != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: _nowNotifier,
                    builder: (_, now, _) {
                      final banExpiresAt = (user['banExpiresAt'] as Timestamp).toDate();
                      final timeLeft = banExpiresAt.difference(now);

                      if (timeLeft.isNegative) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'EXPIRED',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final days = timeLeft.inDays;
                      final hours = timeLeft.inHours % 24;
                      final minutes = timeLeft.inMinutes % 60;
                      final seconds = timeLeft.inSeconds % 60;

                      final isUrgent = timeLeft.inHours < 24;

                      String displayText;
                      if (days > 0) {
                        displayText = '${days}d ${hours}h';
                      } else if (hours > 0) {
                        displayText = '${hours}h ${minutes}m';
                      } else {
                        displayText = '${minutes}m ${seconds}s';
                      }

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUrgent ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUrgent ? Colors.orange : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 16,
                              color: isUrgent ? Colors.orange : Colors.red,
                            ),
                            SizedBox(width: 4),
                            Text(
                              displayText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isUrgent ? Colors.orange : Colors.red,
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
          const SizedBox(height: 16),
          // User Details
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: Color(0xFF6CA04A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.phone, size: screenWidth * 0.04, color: Color(0xFF6CA04A)),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      'Phone: ${user['phone'] ?? 'Not provided'}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Color(0xFF6CA04A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenWidth * 0.02),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: screenWidth * 0.04, color: Color(0xFF6CA04A)),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      'Joined: ${date.day}/${date.month}/${date.year}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Color(0xFF6CA04A),
                      ),
                    ),
                  ],
                ),
                if (isBanned && user['banExpiresAt'] != null) ...[
                  SizedBox(height: screenWidth * 0.02),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: screenWidth * 0.04, color: Colors.red),
                        SizedBox(width: screenWidth * 0.02),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _nowNotifier,
                            builder: (_, now, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Temporary ban expires:',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.03,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatBanCountdown(user['banExpiresAt'] as Timestamp, now),
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
          SizedBox(height: screenWidth * 0.03),
          // Action Buttons - Single full-width View Details button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6CA04A),
              ),
              onPressed: () => _viewUserDetails(context, screenWidth, userId, user),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                child: Text(
                  'View Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
    Timer? countdownTimer;
    int selectedDays = 1;
    
    showDialog(
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Stack(
                children: [
                  Text('Ban User: ${user['fullName'] ?? 'Unknown'}'),
                  // Live countdown timer showing ban duration in upper right corner
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 18, color: Colors.red),
                          SizedBox(width: 6),
                          Text(
                            '${selectedDays}d Ban',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ban type selection
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            countdownTimer?.cancel();
                            Navigator.of(context).pop();
                            _showTemporaryBanDialog(context, screenWidth, userId, user);
                          },
                          child: Text('Temporary Ban'),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            countdownTimer?.cancel();
                            Navigator.of(context).pop();
                            _showPermanentBanDialog(context, screenWidth, userId, user);
                          },
                          child: Text('Permanent Ban'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Banning will immediately restrict user access. Choose temporary for specific duration or permanent for indefinite restriction.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
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
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      countdownTimer?.cancel();
    });
  }

  void _showTemporaryBanDialog(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
    final reasonController = TextEditingController();
    final daysController = TextEditingController(text: '1');
    Timer? countdownTimer;
    int selectedDays = 1;
    
    showDialog(
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
                  Text('Temporary Ban'),
                  // Live countdown timer showing exact ban duration in upper right corner
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 18, color: Colors.orange),
                          SizedBox(width: 6),
                          Text(
                            '${selectedDays}d Duration',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              content: LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = MediaQuery.of(context).size.height * 0.6;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: daysController,
                            decoration: InputDecoration(
                              labelText: 'Ban Duration (days)',
                              hintText: 'Enter number of days',
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onChanged: (value) {
                              setState(() {
                                selectedDays = int.tryParse(value) ?? 1;
                              });
                            },
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: reasonController,
                            decoration: InputDecoration(
                              labelText: 'Reason for ban',
                              hintText: 'Explain why this user is being banned',
                            ),
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.schedule, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text(
                                      'Ban Duration Preview:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.timer, color: Colors.orange, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selectedDays == 1 
                                            ? 'User will be banned for 1 day (24 hours)'
                                            : 'User will be banned for $selectedDays days (${selectedDays * 24} hours)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () {
                    countdownTimer?.cancel();
                    _applyTemporaryBan(context, userId, reasonController.text, selectedDays);
                  },
                  child: Text('Apply Ban', style: TextStyle(color: Colors.white)),
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

  void _showPermanentBanDialog(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.04)),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Permanent Ban',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'Permanently ban ${user['fullName'] ?? 'this user'}?',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                'This action cannot be undone easily.',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.06),
              // Reason input
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Color(0xFF8D9773).withOpacity(0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Reason for permanent ban...',
                    hintStyle: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Color(0xFF757575),
                    ),
                    labelText: 'Ban Reason',
                    labelStyle: TextStyle(
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.06),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF6CA04A),
                            fontSize: screenWidth * 0.04,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _applyPermanentBan(context, userId, reasonController.text),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                        child: Text(
                          'Permanent Ban',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                          ),
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
    );
  }

  String _formatBanCountdown(Timestamp timestamp, DateTime now) {
    final target = timestamp.toDate();
    final diff = target.difference(now);
    if (diff.isNegative) return 'Ban expired';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return 'Ban expires in ${d}d ${h}h ${m}m';
    if (h > 0) return 'Ban expires in ${h}h ${m}m';
    final s = diff.inSeconds % 60;
    if (m > 0) return 'Ban expires in ${m}m ${s.toString().padLeft(2, '0')}s';
    return 'Ban expires in ${s}s';
  }

  Future<void> _applyTemporaryBan(BuildContext context, String userId, String reason, int days) async {
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a reason for the ban')),
      );
      return;
    }

    try {
      await BanService.applyTemporaryBan(
        userId: userId,
        bannedBy: 'admin', // Replace with actual admin ID
        reason: reason,
        durationDays: days,
      );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User banned temporarily for $days days')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying ban: $e')),
      );
    }
  }

  Future<void> _applyPermanentBan(BuildContext context, String userId, String reason) async {
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a reason for the ban')),
      );
      return;
    }

    try {
      await BanService.applyPermanentBan(
        userId: userId,
        bannedBy: 'admin', // Replace with actual admin ID
        reason: reason,
      );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User banned permanently')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying ban: $e')),
      );
    }
  }


  void _viewUserDetails(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) async {
    final int reportCount = await SupplierReportService.getSupplierReportCount(userId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            top: screenWidth * 0.05,
            bottom: MediaQuery.of(context).viewInsets.bottom + screenWidth * 0.05,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.06,
                    backgroundColor: const Color(0xFF6CA04A).withOpacity(0.15),
                    child: Text(
                      (user['fullName'] ?? 'U').toString().isNotEmpty
                        ? (user['fullName'] as String).substring(0, 1).toUpperCase()
                        : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6CA04A),
                        fontSize: screenWidth * 0.05,
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['fullName'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user['email'] ?? 'No email',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenWidth * 0.04),
              Row(
                children: [
                  Icon(Icons.badge, size: screenWidth * 0.045, color: const Color(0xFF6CA04A)),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    (user['role'] ?? 'user').toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (user['phone'] != null && user['phone'].toString().isNotEmpty) ...[
                SizedBox(height: screenWidth * 0.02),
                Row(
                  children: [
                    Icon(Icons.phone, size: screenWidth * 0.045, color: const Color(0xFF6CA04A)),
                    SizedBox(width: screenWidth * 0.02),
                    Text(user['phone'], style: TextStyle(fontSize: screenWidth * 0.035)),
                  ],
                ),
              ],
              SizedBox(height: screenWidth * 0.05),
              Column(
                children: [
                  // First row of buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6CA04A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showBanDialog(context, screenWidth, userId, user);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                            child: Text(
                              'Ban/Unban',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: reportCount > 0 ? () => _showReportReasons(context, screenWidth, userId) : null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: reportCount > 0 ? const Color(0xFF6CA04A) : const Color(0xFFBDBDBD),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                            child: Text(
                              reportCount > 0 ? 'Reports ($reportCount)' : 'No Reports',
                              style: TextStyle(
                                color: reportCount > 0 ? const Color(0xFF6CA04A) : const Color(0xFFBDBDBD),
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  // Second row of buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: user['isActive'] == true ? Colors.orange : const Color(0xFF6CA04A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _toggleUserStatus(userId, !(user['isActive'] ?? true));
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                            child: Text(
                              user['isActive'] == true ? 'Deactivate' : 'Activate',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(context, userId, user['fullName'] ?? 'Unknown User');
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                            child: Text(
                              'Delete User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportReasons(BuildContext context, double screenWidth, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            top: screenWidth * 0.05,
            bottom: MediaQuery.of(context).viewInsets.bottom + screenWidth * 0.05,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Reasons',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenWidth * 0.03),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: StreamBuilder<List<SupplierReport>>(
                  stream: SupplierReportService.getSupplierReports(userId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final reports = List<SupplierReport>.from(snapshot.data!);
                    // Ensure newest first just in case index order shifts
                    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    if (reports.isEmpty) {
                      return const Center(child: Text('No reports found'));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final r = reports[index];
                        final reason = r.reason;
                        final productName = r.productName ?? '';
                        final createdText = r.createdAt.toString().split(' ').first;
                        return ListTile(
                          leading: const Icon(Icons.report, color: Colors.redAccent),
                          title: Text(reason),
                          subtitle: Text(productName.isNotEmpty ? 'Product: $productName\n$createdText' : createdText),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleUserStatus(String userId, bool newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('User status updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('Error updating user status: $e')),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('User deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, String userId, String fullName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete User?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Are you sure you want to delete $fullName?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteUser(userId);
                      },
                      child: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'supplier':
        return Colors.blue;
      case 'buyer':
        return Colors.green;
      default:
        return Color(0xFF6CA04A);
    }
  }
}