// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_dashboard.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
            );
          },
        ),
        title: Text(
          'Reports',
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Color(0xFF6CA04A),
              child: TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    child: Text(
                      'Supplier Reports',
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'System Reports',
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSupplierReportsTab(),
                  _buildSystemReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('supplier_reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.quicksand(
                color: Colors.red,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
            ),
          );
        }

        final reports = snapshot.data!.docs;

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No reports yet',
                  style: GoogleFonts.quicksand(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                title: Text(
                  report['supplierName'] ?? 'Unknown Supplier',
                  style: GoogleFonts.quicksand(
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      report['reason'] ?? 'No reason provided',
                      style: GoogleFonts.quicksand(
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Status: ${report['status'] ?? 'pending'}',
                      style: GoogleFonts.quicksand(
                        color: Color(0xFF6CA04A),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.visibility, color: Color(0xFF6CA04A)),
                  onPressed: () => _showReportDetails(context, report),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSystemReportsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'System Reports',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: GoogleFonts.quicksand(
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Report Details',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w400,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier: ${report['supplierName'] ?? 'Unknown'}',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
            ),
            SizedBox(height: 8),
            Text(
              'Reason: ${report['reason'] ?? 'No reason provided'}',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
            ),
            SizedBox(height: 8),
            Text(
              'Status: ${report['status'] ?? 'pending'}',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
            ),
            if (report['description'] != null) ...[
              SizedBox(height: 8),
              Text(
                'Description: ${report['description']}',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.w400),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.quicksand(
                color: Color(0xFF6CA04A),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}