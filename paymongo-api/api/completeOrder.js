const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const { orderId, paymentMethod, status } = req.body;

    if (!orderId) {
      return res.status(400).json({ error: 'Order ID is required' });
    }

    console.log(`Processing order completion for orderId: ${orderId}`);

    // Get temporary order data
    const tempOrderDoc = await admin.firestore()
        .collection('temp_orders')
        .doc(orderId)
        .get();

    if (!tempOrderDoc.exists) {
      console.log(`No temporary order found for orderId: ${orderId}`);
      return res.status(404).json({ error: 'Order not found' });
    }

    const tempOrderData = tempOrderDoc.data();
    console.log('Temporary order data:', tempOrderData);

    // Create the actual order in Firestore
    const orderData = {
      orderId: orderId,
      buyerId: tempOrderData.buyerId,
      buyerName: tempOrderData.buyerName,
      items: tempOrderData.cartItems,
      totalAmount: tempOrderData.amount,
      paymentMethod: paymentMethod || 'online_payment',
      paymentStatus: status === 'success' ? 'paid' : 'failed',
      orderStatus: status === 'success' ? 'confirmed' : 'cancelled',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Save order to orders collection
    await admin.firestore()
        .collection('orders')
        .doc(orderId)
        .set(orderData);

    console.log(`Order ${orderId} created successfully`);

    // Remove items from cart for each cart item
    if (tempOrderData.cartItems && Array.isArray(tempOrderData.cartItems)) {
      const batch = admin.firestore().batch();
      
      for (const item of tempOrderData.cartItems) {
        if (item.cartDocId) {
          const cartDocRef = admin.firestore()
              .collection('carts')
              .doc(tempOrderData.buyerId)
              .collection('items')
              .doc(item.cartDocId);
          
          batch.delete(cartDocRef);
        }
      }
      
      await batch.commit();
      console.log(`Cart items removed for order ${orderId}`);
    }

    // Delete temporary order
    await admin.firestore()
        .collection('temp_orders')
        .doc(orderId)
        .delete();

    console.log(`Temporary order ${orderId} cleaned up`);

    // Send notification to buyer
    try {
      const userDoc = await admin.firestore()
          .collection('users')
          .doc(tempOrderData.buyerId)
          .get();

      if (userDoc.exists) {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (fcmToken) {
          const message = {
            token: fcmToken,
            notification: {
              title: status === 'success' ? 'Order Confirmed!' : 'Payment Failed',
              body: status === 'success' 
                ? `Your order #${orderId.substring(0, 8)} has been confirmed.`
                : `Payment for order #${orderId.substring(0, 8)} failed.`,
            },
            data: {
              type: 'order_update',
              orderId: orderId,
              status: status,
            },
            android: {
              notification: {
                channelId: 'orders',
                priority: 'high',
                sound: 'default',
              },
            },
          };

          await admin.messaging().send(message);
          console.log(`Notification sent for order ${orderId}`);
        }
      }
    } catch (notificationError) {
      console.error('Error sending notification:', notificationError);
      // Don't fail the order completion if notification fails
    }

    res.status(200).json({
      success: true,
      message: 'Order completed successfully',
      orderId: orderId,
    });

  } catch (error) {
    console.error('Error completing order:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to complete order',
      details: error.message,
    });
  }
};
