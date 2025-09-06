// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/farm_location_request.dart';
import '../services/farm_location_request_service.dart';

class FarmLocationRequestsPage extends StatefulWidget {
  const FarmLocationRequestsPage({super.key});

  @override
  State<FarmLocationRequestsPage> createState() => _FarmLocationRequestsPageState();
}

class _FarmLocationRequestsPageState extends State<FarmLocationRequestsPage> {
  final FarmLocationRequestService _requestService = FarmLocationRequestService();
  final MapController _mapController = MapController();
  
  List<FarmLocationRequest> _pendingRequests = [];
  FarmLocationRequest? _selectedRequest;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    // Process auto-approvals when page loads
    _processAutoApprovals();
  }

  Future<void> _loadPendingRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final requests = await _requestService.getPendingRequests();
      setState(() {
        _pendingRequests = requests;
        if (_pendingRequests.isNotEmpty && _selectedRequest == null) {
          _selectedRequest = _pendingRequests.first;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load requests: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processAutoApprovals() async {
    try {
      await _requestService.processAutoApprovals();
      // Reload requests after processing auto-approvals
      await _loadPendingRequests();
    } catch (e) {
      // Silent fail for auto-approvals
    }
  }

  Future<void> _approveRequest(String requestId, String? notes) async {
    try {
      setState(() {
        _isProcessing = true;
      });

      await _requestService.approveRequest(
        requestId: requestId,
        reviewNotes: notes,
      );
      // After approval, sync to supplier_locations so customers see it
      try {
        final req = await _requestService.getRequestById(requestId);
        if (req != null) {
          await FirebaseFirestore.instance
              .collection('supplier_locations')
              .doc(req.requesterId)
              .set({
            'id': req.requesterId,
            'supplierId': req.requesterId,
            'supplierName': req.requesterName,
            'locationName': req.farmName,
            'description': req.farmDescription,
            'latitude': req.latitude,
            'longitude': req.longitude,
            'address': req.address,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'approvedIcon': true,
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm location request approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadPendingRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _rejectRequest(String requestId, String? notes) async {
    try {
      setState(() {
        _isProcessing = true;
      });

      await _requestService.rejectRequest(
        requestId: requestId,
        reviewNotes: notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm location request rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadPendingRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showApprovalDialog(FarmLocationRequest request, bool isApproval) {
    final TextEditingController notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproval ? 'Approve Request' : 'Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Farm: ${request.farmName}'),
            Text('Requested by: ${request.requesterName}'),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Review Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isApproval) {
                _approveRequest(request.id, notesController.text.trim());
              } else {
                _rejectRequest(request.id, notesController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isApproval ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  String _getTimeRemaining(FarmLocationRequest request) {
    if (request.autoApprovalAt == null) return '';
    
    final now = DateTime.now();
    final timeLeft = request.autoApprovalAt!.difference(now);
    
    if (timeLeft.isNegative) {
      return 'Auto-approval overdue';
    }
    
    final minutes = timeLeft.inMinutes;
    final seconds = timeLeft.inSeconds % 60;
    return 'Auto-approval in ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        title: Text(
          'Farm Location Requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF6CA04A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadPendingRequests,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6CA04A)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPendingRequests,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _pendingRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No pending farm location requests',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6CA04A),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        // Requests list
                        Expanded(
                          flex: 1,
                          child: Container(
                            margin: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6CA04A),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.pending_actions, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Pending Requests (${_pendingRequests.length})',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _pendingRequests.length,
                                    itemBuilder: (context, index) {
                                      final request = _pendingRequests[index];
                                      final isSelected = _selectedRequest?.id == request.id;
                                      
                                      return Container(
                                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Color(0xFF6CA04A).withOpacity(0.1) : null,
                                          borderRadius: BorderRadius.circular(8),
                                          border: isSelected ? Border.all(color: Color(0xFF6CA04A)) : null,
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            request.farmName,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('By: ${request.requesterName}'),
                                              Text(
                                                _getTimeRemaining(request),
                                                style: TextStyle(
                                                  color: request.isAutoApprovalDue ? Colors.red : Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedRequest = request;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Map and details
                        Expanded(
                          flex: 2,
                          child: _selectedRequest == null
                              ? Container()
                              : Container(
                                  margin: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Request details header
                                      Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF6CA04A),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.agriculture, color: Colors.white),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _selectedRequest!.farmName,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Map
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          margin: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: FlutterMap(
                                              mapController: _mapController,
                                              options: MapOptions(
                                                initialCenter: LatLng(
                                                  _selectedRequest!.latitude,
                                                  _selectedRequest!.longitude,
                                                ),
                                                initialZoom: 15.0,
                                              ),
                                              children: [
                                                TileLayer(
                                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                  userAgentPackageName: 'com.veggieconnect.app',
                                                ),
                                                MarkerLayer(
                                                  markers: [
                                                    Marker(
                                                      point: LatLng(
                                                        _selectedRequest!.latitude,
                                                        _selectedRequest!.longitude,
                                                      ),
                                                      child: Icon(
                                                        Icons.agriculture,
                                                        color: Colors.orange,
                                                        size: 40,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Request details
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Request Details',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text('Requested by: ${_selectedRequest!.requesterName}'),
                                              Text('Description: ${_selectedRequest!.farmDescription}'),
                                              Text('Address: ${_selectedRequest!.address}'),
                                              Text('Requested: ${_selectedRequest!.requestedAt.toString().split('.')[0]}'),
                                              Text(
                                                _getTimeRemaining(_selectedRequest!),
                                                style: TextStyle(
                                                  color: _selectedRequest!.isAutoApprovalDue ? Colors.red : Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: _isProcessing ? null : () => _showApprovalDialog(_selectedRequest!, false),
                                                      icon: Icon(Icons.close),
                                                      label: Text('Reject'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: _isProcessing ? null : () => _showApprovalDialog(_selectedRequest!, true),
                                                      icon: Icon(Icons.check),
                                                      label: Text('Approve'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }
}
