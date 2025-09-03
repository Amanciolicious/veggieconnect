// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// One-time migration: rename existing order status 'delivered' -> 'picked_up'
  static Future<void> migrateDeliveredToPickedUp() async {
    try {
      final flagRef = _firestore.collection('migrations').doc('delivered_to_picked_up');
      final flagSnap = await flagRef.get();
      if (flagSnap.exists && (flagSnap.data()?['done'] == true)) {
        return; // Already migrated
      }

      const int pageSize = 400; // Keep below 500 writes per batch
      Query query = _firestore.collection('orders').where('status', isEqualTo: 'delivered').limit(pageSize);

      int totalUpdated = 0;
      while (true) {
        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {
            'status': 'picked_up',
            'migratedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        totalUpdated += snapshot.docs.length;

        // Use cursor for next page
        final lastDoc = snapshot.docs.last;
        query = _firestore
            .collection('orders')
            .where('status', isEqualTo: 'delivered')
            .startAfterDocument(lastDoc)
            .limit(pageSize);
      }

      await flagRef.set({
        'done': true,
        'updatedCount': totalUpdated,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Migration delivered -> picked_up completed. Updated: $totalUpdated');
    } catch (e) {
      print('Migration error (delivered -> picked_up): $e');
    }
  }
}


