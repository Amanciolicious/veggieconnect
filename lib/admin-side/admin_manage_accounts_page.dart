// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import '../services/supplier_report_service.dart';
import '../services/ban_service.dart';

class AdminManageAccountsPage extends StatefulWidget {
  const AdminManageAccountsPage({super.key});

  @override
  State<AdminManageAccountsPage> createState() => _AdminManageAccountsPageState();
}

class _AdminManageAccountsPageState extends State<AdminManageAccountsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Manage Accounts',
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        elevation: 0,
      ),
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
                fontFamily: 'Poppins',
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
                    fontFamily: 'Poppins',
                  ),
                  suffixIcon: Icon(Icons.search, size: screenWidth * 0.04),
                ),
                onChanged: (query) => setState(() => _searchQuery = query),
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
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
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
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.02),
                            Text(
                              'No user accounts found',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Color(0xFF757575),
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final users = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index].data() as Map<String, dynamic>;
                      return _buildUserCard(context, screenWidth, users[index].id, user);
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
          // User Header
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
                    fontFamily: 'Poppins',
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
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      user['email'] ?? 'No email',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Color(0xFF757575),
                        fontFamily: 'Poppins',
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
                            fontFamily: 'Poppins',
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
                    fontFamily: 'Poppins',
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
                    final intensity = SupplierReportService.getReportColorIntensity(reportCount);
                    final percentage = (reportCount / 5.0 * 100).clamp(0.0, 100.0);
                    
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025, vertical: screenWidth * 0.015),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(intensity),
                        borderRadius: BorderRadius.circular(screenWidth * 0.03),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.report_problem,
                            size: screenWidth * 0.035,
                            color: Colors.white,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            '$reportCount (${percentage.toInt()}%)',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
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
                        fontFamily: 'Poppins',
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
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                if (isBanned && user['banExpiresAt'] != null) ...[
                  SizedBox(height: screenWidth * 0.02),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: screenWidth * 0.04, color: Colors.red),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        'Ban expires: ${_formatBanExpiry(user['banExpiresAt'] as Timestamp)}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.red,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: screenWidth * 0.03),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBanned ? Color(0xFF6CA04A) : Colors.red,
                  ),
                  onPressed: () => isBanned ? _unbanUser(userId) : _showBanDialog(context, screenWidth, userId, user),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                    child: Text(
                      isBanned ? 'Unban' : 'Ban',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.04,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                  ),
                  onPressed: () => _viewUserDetails(context, screenWidth, userId, user),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        color: Color(0xFF6CA04A),
                        fontSize: screenWidth * 0.04,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBanDialog(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
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
                'Ban User',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  color: Colors.red,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'Choose ban type for ${user['fullName'] ?? 'this user'}:',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.06),
              // Temporary Ban Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showTemporaryBanDialog(context, screenWidth, userId, user);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                    child: Column(
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: screenWidth * 0.06),
                        SizedBox(height: screenWidth * 0.02),
                        Text(
                          'Temporary Ban',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Specify number of days',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: screenWidth * 0.035,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              // Permanent Ban Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPermanentBanDialog(context, screenWidth, userId, user);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                    child: Column(
                      children: [
                        Icon(Icons.block, color: Colors.white, size: screenWidth * 0.06),
                        SizedBox(height: screenWidth * 0.02),
                        Text(
                          'Permanent Ban',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Account will be permanently banned',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: screenWidth * 0.035,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              // Cancel Button
              SizedBox(
                width: double.infinity,
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
                        fontFamily: 'Poppins',
                      ),
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

  void _showTemporaryBanDialog(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
    final TextEditingController daysController = TextEditingController();
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
                'Temporary Ban',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  color: Colors.orange,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'Ban ${user['fullName'] ?? 'this user'} temporarily:',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth * 0.06),
              // Days input
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
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Number of days (e.g., 7, 30)',
                    hintStyle: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Color(0xFF757575),
                      fontFamily: 'Poppins',
                    ),
                    labelText: 'Ban Duration (Days)',
                    labelStyle: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
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
                    hintText: 'Reason for ban...',
                    hintStyle: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Color(0xFF757575),
                      fontFamily: 'Poppins',
                    ),
                    labelText: 'Ban Reason',
                    labelStyle: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontFamily: 'Poppins',
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
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () => _applyTemporaryBan(context, userId, daysController.text, reasonController.text),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                        child: Text(
                          'Apply Ban',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Poppins',
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
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'Permanently ban ${user['fullName'] ?? 'this user'}?',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontFamily: 'Poppins',
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
                  fontFamily: 'Poppins',
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
                      fontFamily: 'Poppins',
                    ),
                    labelText: 'Ban Reason',
                    labelStyle: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontFamily: 'Poppins',
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
                            fontFamily: 'Poppins',
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
                            fontFamily: 'Poppins',
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

  String _formatBanExpiry(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _applyTemporaryBan(BuildContext context, String userId, String daysText, String reason) async {
    if (daysText.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final days = int.tryParse(daysText);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid number of days')),
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

  Future<void> _unbanUser(String userId) async {
    try {
      await BanService.removeBan(userId);
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('User unbanned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('Error unbanning user: $e')),
      );
    }
  }

  void _viewUserDetails(BuildContext context, double screenWidth, String userId, Map<String, dynamic> user) {
    // Placeholder for user details view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User details view - to be implemented')),
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