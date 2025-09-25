// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sub_admin_service.dart';
import '../services/auth_state_service.dart';
import '../widgets/role_page_header.dart';
import '../widgets/lottie_loading_widget.dart';

class AdminManageSubAdminsPage extends StatefulWidget {
  const AdminManageSubAdminsPage({super.key});

  @override
  State<AdminManageSubAdminsPage> createState() => _AdminManageSubAdminsPageState();
}

class _AdminManageSubAdminsPageState extends State<AdminManageSubAdminsPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreating = false;

  final _authService = AuthStateService();

  Future<void> _createSubAdmin() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    setState(() { _isCreating = true; });
    try {
      final current = _authService.currentUser;
      final data = _authService.currentUserData;
      if (current == null || data == null) {
        throw Exception('Not authenticated');
      }
      final superAdminId = current.uid;
      final superAdminEmail = data['email'] ?? '';

      await SubAdminService.createSubAdmin(
        superAdminUserId: superAdminId,
        superAdminEmail: superAdminEmail,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      _usernameController.clear();
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub admin created')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      setState(() { _isCreating = false; });
    }
  }

  Future<void> _deleteSubAdmin(String subAdminId) async {
    try {
      final current = _authService.currentUser;
      if (current == null) throw Exception('Not authenticated');
      await SubAdminService.deleteSubAdmin(
        superAdminUserId: current.uid,
        subAdminUserId: subAdminId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub admin deleted')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _authService.currentUser;
    if (current == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: RolePageHeader(
        title: 'Manage Sub Admins',
        onBackTap: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(),
            const SizedBox(height: 24),
            
            // Create Sub Admin Card
            _buildCreateSubAdminCard(),
            const SizedBox(height: 24),
            
            // Existing Sub Admins Section
            _buildExistingSubAdminsSection(current.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8D9773).withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group_add,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sub Admin Management',
                      style: GoogleFonts.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create and manage sub admin accounts for your team',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSubAdminCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8D9773).withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create New Sub Admin',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          
          // Username Field
          _buildModernTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'Enter a unique username',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          
          // Password Field
          _buildModernTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter a secure password',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 24),
          
          // Create Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createSubAdmin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create Sub Admin',
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.quicksand(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.quicksand(
              color: const Color(0xFF757575),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF8D9773).withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF8D9773).withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF4CAF50),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingSubAdminsSection(String superAdminUserId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing Sub Admins',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        
        FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          future: SubAdminService.getSubAdmins(superAdminUserId: superAdminUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: GroceryLoadingWidget(
                    size: 60,
                    showText: true,
                    loadingText: 'Loading sub admins...',
                  ),
                ),
              );
            }
            
            if (snapshot.hasError) {
              return _buildErrorCard('Error: ${snapshot.error}');
            }
            
            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return _buildEmptyStateCard();
            }
            
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                return _buildSubAdminCard(doc.id, data);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubAdminCard(String subAdminId, Map<String, dynamic> data) {
    final username = data['username'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final memberSince = createdAt != null 
        ? createdAt.toDate().toString().split(' ')[0]
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8D9773).withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Color(0xFF4CAF50),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: const Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member since: $memberSince',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(subAdminId, username),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8D9773).withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_add,
              color: Color(0xFF4CAF50),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Sub Admins Yet',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first sub admin account to get started',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String subAdminId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Sub Admin',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$username"? This action cannot be undone.',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.quicksand(
                color: const Color(0xFF757575),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSubAdmin(subAdminId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


