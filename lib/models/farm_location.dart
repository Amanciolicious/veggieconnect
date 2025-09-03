import 'package:cloud_firestore/cloud_firestore.dart';

class FarmLocation {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String supplierId;
  final String supplierName;
  final String address;
  final DateTime createdAt;
  final bool isActive;
  double? distanceFromUser; // Distance in kilometers

  FarmLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.supplierId,
    required this.supplierName,
    required this.address,
    required this.createdAt,
    this.isActive = true,
    this.distanceFromUser,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'address': address,
      'createdAt': createdAt,
      'isActive': isActive,
      'distanceFromUser': distanceFromUser,
    };
  }

  factory FarmLocation.fromMap(Map<String, dynamic> map) {
    return FarmLocation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      address: map['address'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      distanceFromUser: map['distanceFromUser'],
    );
  }

  FarmLocation copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? supplierId,
    String? supplierName,
    String? address,
    DateTime? createdAt,
    bool? isActive,
    double? distanceFromUser,
  }) {
    return FarmLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
    );
  }
} 