const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Cloud Function to send FCM notifications using V1 API
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    // Validate input
    if (!data.token || !data.title || !data.body) {
      throw new functions.https.HttpsError('invalid-argument',
        'Missing required fields');
    }

    // Prepare the message for FCM V1 API
    const message = {
      token: data.token,
      notification: {
        title: data.title,
        body: data.body,
      },
      data: {
        type: data.type || 'general',
        ...data.customData,
      },
      android: {
        notification: {
          channelId: getChannelIdForType(data.type || 'general'),
          priority: 'high',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: data.title,
              body: data.body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send the notification using FCM V1 API
    const response = await admin.messaging().send(message);

    console.log('Successfully sent message:', response);

    return {
      success: true,
      messageId: response,
    };
  } catch (error) {
    console.error('Error sending message:', error);
    throw new functions.https.HttpsError('internal',
      'Failed to send notification');
  }
});

/**
 * Helper function to get channel ID based on notification type
 * @param {string} type The notification type
 * @return {string} The channel ID
 */
function getChannelIdForType(type) {
  switch (type) {
  case 'order_update':
  case 'order':
    return 'orders';
  case 'chat':
    return 'chat';
  default:
    return 'general';
  }
}

// Cloud Function to send notification to multiple users
exports.sendNotificationToMultiple = functions.https.onCall(
  async (data, context) => {
    try {
      if (!data.tokens || !Array.isArray(data.tokens) ||
            !data.title || !data.body) {
        throw new functions.https.HttpsError('invalid-argument',
          'Missing required fields');
      }

      const message = {
        tokens: data.tokens,
        notification: {
          title: data.title,
          body: data.body,
        },
        data: {
          type: data.type || 'general',
          ...data.customData,
        },
        android: {
          notification: {
            channelId: getChannelIdForType(data.type || 'general'),
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: data.title,
                body: data.body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendMulticast(message);

      console.log('Successfully sent multicast message:', response);

      return {
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses,
      };
    } catch (error) {
      console.error('Error sending multicast message:', error);
      throw new functions.https.HttpsError('internal',
        'Failed to send notifications');
    }
  });

// Cloud Function to complete order after successful payment
exports.completeOrder = functions.https.onRequest(async (req, res) => {
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
              body: status === 'success' ?
                `Your order #${orderId.substring(0, 8)} has been confirmed.` :
                `Payment for order #${orderId.substring(0, 8)} failed.`,
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
});

// PayMongo webhook handler
exports.paymongoWebhook = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Paymongo-Signature');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const event = req.body;
    console.log('PayMongo webhook received:', event);

    // Handle checkout.session.completed event
    if (event.type === 'checkout.session.completed') {
      const session = event.data.attributes;
      const orderId = (session.metadata && session.metadata.orderId) ||
                     (session.description &&
                      session.description.match(/Order #(.+)/) &&
                      session.description.match(/Order #(.+)/)[1]);

      if (orderId) {
        console.log(`Processing successful payment for order: ${orderId}`);

        // Determine payment method from session
        let paymentMethod = 'online_payment';
        if (session.payment_method_types && session.payment_method_types.length > 0) {
          const usedMethod = session.payment_method_types[0];
          paymentMethod = usedMethod;
        }

        // Call the complete order function
        const completeOrderResponse = await admin.firestore()
          .collection('temp_orders')
          .doc(orderId)
          .get();

        if (completeOrderResponse.exists) {
          // Trigger order completion
          const orderData = completeOrderResponse.data();

          const orderDataFinal = {
            orderId: orderId,
            buyerId: orderData.buyerId,
            buyerName: orderData.buyerName,
            items: orderData.cartItems,
            totalAmount: orderData.amount,
            paymentMethod: paymentMethod,
            paymentStatus: 'paid',
            orderStatus: 'confirmed',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Save order to orders collection
          await admin.firestore()
            .collection('orders')
            .doc(orderId)
            .set(orderDataFinal);

          // Remove items from cart
          if (orderData.cartItems && Array.isArray(orderData.cartItems)) {
            const batch = admin.firestore().batch();

            for (const item of orderData.cartItems) {
              if (item.cartDocId) {
                const cartDocRef = admin.firestore()
                  .collection('carts')
                  .doc(orderData.buyerId)
                  .collection('items')
                  .doc(item.cartDocId);

                batch.delete(cartDocRef);
              }
            }

            await batch.commit();
          }

          // Delete temporary order
          await admin.firestore()
            .collection('temp_orders')
            .doc(orderId)
            .delete();

          console.log(`Order ${orderId} completed via webhook`);
        }
      }
    }

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('PayMongo webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});
