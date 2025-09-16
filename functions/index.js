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

// Cloud Function for 5-minute auto-approval of supplier verification requests
exports.autoApproveVerifications = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
  console.log('Running auto-approval check for supplier verifications...');

  try {
    const now = admin.firestore.Timestamp.now();
    const fiveMinutesAgo = new Date(now.toDate().getTime() - (5 * 60 * 1000));

    // Query for pending verification requests older than 5 minutes
    const pendingVerifications = await admin.firestore()
      .collection('supplier_verifications')
      .where('status', '==', 'pending')
      .where('submittedAt', '<=', admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
      .get();

    console.log(`Found ${pendingVerifications.docs.length} verification requests eligible for auto-approval`);

    const batch = admin.firestore().batch();
    const autoApprovedVerifications = [];

    for (const doc of pendingVerifications.docs) {
      const verificationData = doc.data();

      // Auto-approve the verification
      batch.update(doc.ref, {
        status: 'approved',
        reviewedAt: now,
        reviewedBy: 'system_auto_approval',
        reviewNotes: 'Automatically approved after 5 minutes without admin review',
        autoApproved: true,
        updatedAt: now,
      });

      // Update supplier's verification status in users collection
      batch.update(admin.firestore().collection('users').doc(verificationData.supplierId), {
        isVerified: true,
        verificationStatus: 'approved',
        verifiedAt: now,
        updatedAt: now,
      });

      autoApprovedVerifications.push({
        id: doc.id,
        supplierId: verificationData.supplierId,
        supplierName: verificationData.supplierName,
        supplierEmail: verificationData.supplierEmail,
      });
    }

    // Commit all updates
    if (autoApprovedVerifications.length > 0) {
      await batch.commit();
      console.log(`Auto-approved ${autoApprovedVerifications.length} verification requests`);

      // Send notifications to auto-approved suppliers
      for (const verification of autoApprovedVerifications) {
        try {
          // Get supplier's FCM token
          const supplierDoc = await admin.firestore()
            .collection('users')
            .doc(verification.supplierId)
            .get();

          if (supplierDoc.exists) {
            const supplierData = supplierDoc.data();
            const fcmToken = supplierData.fcmToken;

            if (fcmToken) {
              const message = {
                token: fcmToken,
                notification: {
                  title: 'Verification Approved!',
                  body: 'Your supplier verification has been automatically approved. You can now manage products and access all supplier features.',
                },
                data: {
                  type: 'verification_auto_approved',
                  verificationId: verification.id,
                  screen: 'supplier_profile',
                },
                android: {
                  notification: {
                    channelId: 'verification',
                    priority: 'high',
                    sound: 'default',
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      alert: {
                        title: 'Verification Approved!',
                        body: 'Your supplier verification has been automatically approved. You can now manage products and access all supplier features.',
                      },
                      sound: 'default',
                      badge: 1,
                    },
                  },
                },
              };

              await admin.messaging().send(message);
              console.log(`Auto-approval notification sent to supplier: ${verification.supplierEmail}`);
            }

            // Also create in-app notification
            await admin.firestore()
              .collection('users')
              .doc(verification.supplierId)
              .collection('notifications')
              .add({
                title: 'Verification Approved!',
                body: 'Your supplier verification has been automatically approved. You can now manage products and access all supplier features.',
                type: 'verification_auto_approved',
                data: {
                  verificationId: verification.id,
                  screen: 'supplier_profile',
                },
                isRead: false,
                createdAt: now,
              });
          }
        } catch (notificationError) {
          console.error(`Error sending auto-approval notification to ${verification.supplierEmail}:`, notificationError);
          // Continue with other notifications even if one fails
        }
      }

      // Send notification to admins about auto-approvals
      try {
        const adminUsers = await admin.firestore()
          .collection('users')
          .where('role', '==', 'admin')
          .get();

        const adminTokens = [];
        const adminNotifications = [];

        adminUsers.docs.forEach((doc) => {
          const adminData = doc.data();
          if (adminData.fcmToken) {
            adminTokens.push(adminData.fcmToken);
          }

          // Create in-app notification for each admin
          adminNotifications.push(
            admin.firestore()
              .collection('users')
              .doc(doc.id)
              .collection('notifications')
              .add({
                title: 'Auto-Approval Summary',
                body: `${autoApprovedVerifications.length} supplier verification${autoApprovedVerifications.length > 1 ? 's' : ''} automatically approved after 5 minutes.`,
                type: 'admin_auto_approval_summary',
                data: {
                  count: autoApprovedVerifications.length,
                  screen: 'verification_requests',
                },
                isRead: false,
                createdAt: now,
              }),
          );
        });

        // Send FCM to all admins
        if (adminTokens.length > 0) {
          const adminMessage = {
            tokens: adminTokens,
            notification: {
              title: 'Auto-Approval Summary',
              body: `${autoApprovedVerifications.length} supplier verification${autoApprovedVerifications.length > 1 ? 's' : ''} automatically approved after 5 minutes.`,
            },
            data: {
              type: 'admin_auto_approval_summary',
              count: autoApprovedVerifications.length.toString(),
              screen: 'verification_requests',
            },
            android: {
              notification: {
                channelId: 'admin',
                priority: 'default',
                sound: 'default',
              },
            },
          };

          await admin.messaging().sendMulticast(adminMessage);
          console.log(`Auto-approval summary sent to ${adminTokens.length} admins`);
        }

        // Create in-app notifications for admins
        await Promise.all(adminNotifications);
      } catch (adminNotificationError) {
        console.error('Error sending admin auto-approval notifications:', adminNotificationError);
      }
    } else {
      console.log('No verification requests found for auto-approval');
    }

    return null;
  } catch (error) {
    console.error('Error in auto-approval function:', error);
    throw error;
  }
});

// Trigger to schedule auto-approval when verification is submitted
exports.scheduleAutoApproval = functions.firestore
  .document('supplier_verifications/{verificationId}')
  .onCreate(async (snap, context) => {
    try {
      const verificationData = snap.data();
      const verificationId = context.params.verificationId;

      // Calculate auto-approval time (5 minutes from submission)
      const submittedAt = verificationData.submittedAt;
      const autoApprovalTime = new Date(submittedAt.toDate().getTime() + (5 * 60 * 1000));

      // Update the verification document with scheduled auto-approval time
      await snap.ref.update({
        autoApprovalScheduledAt: admin.firestore.Timestamp.fromDate(autoApprovalTime),
      });

      console.log(`Auto-approval scheduled for verification ${verificationId} at ${autoApprovalTime.toISOString()}`);

      return null;
    } catch (error) {
      console.error('Error scheduling auto-approval:', error);
      throw error;
    }
  });

// Cancel auto-approval when verification is manually reviewed
exports.cancelAutoApproval = functions.firestore
  .document('supplier_verifications/{verificationId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const verificationId = context.params.verificationId;

      // Check if status changed from pending to approved/rejected (manual review)
      if (before.status === 'pending' &&
          (after.status === 'approved' || after.status === 'rejected') &&
          after.reviewedBy !== 'system_auto_approval') {
        console.log(`Manual review completed for verification ${verificationId}, auto-approval cancelled`);

        // Update to remove auto-approval scheduling
        await change.after.ref.update({
          autoApprovalScheduledAt: admin.firestore.FieldValue.delete(),
        });
      }

      return null;
    } catch (error) {
      console.error('Error cancelling auto-approval:', error);
      throw error;
    }
  });

// Cloud Function for 5-minute auto-approval of product submissions
exports.autoApproveProducts = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  console.log('Running auto-approval check for product submissions...');

  try {
    const now = admin.firestore.Timestamp.now();
    const fiveMinutesAgo = new Date(now.toDate().getTime() - (5 * 60 * 1000));

    // Query for pending products older than 5 minutes
    const pendingProducts = await admin.firestore()
      .collection('products')
      .where('status', '==', 'pending')
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
      .get();

    console.log(`Found ${pendingProducts.docs.length} products eligible for auto-approval`);

    const batch = admin.firestore().batch();
    const autoApprovedProducts = [];

    for (const doc of pendingProducts.docs) {
      const productData = doc.data();

      // Auto-approve the product
      batch.update(doc.ref, {
        status: 'approved',
        isVerified: true,
        reviewedAt: now,
        reviewedBy: 'system_auto_approval',
        rejectionReason: '',
        autoApproved: true,
        updatedAt: now,
      });

      autoApprovedProducts.push({
        id: doc.id,
        name: productData.name,
        supplierId: productData.sellerId,
        supplierName: productData.supplierName,
      });
    }

    // Commit all updates
    if (autoApprovedProducts.length > 0) {
      await batch.commit();
      console.log(`Auto-approved ${autoApprovedProducts.length} products`);

      // Send notifications to suppliers about auto-approved products
      for (const product of autoApprovedProducts) {
        try {
          // Get supplier's FCM token
          const supplierDoc = await admin.firestore()
            .collection('users')
            .doc(product.supplierId)
            .get();

          if (supplierDoc.exists) {
            const supplierData = supplierDoc.data();
            const fcmToken = supplierData.fcmToken;

            if (fcmToken) {
              const message = {
                token: fcmToken,
                notification: {
                  title: 'Product Approved!',
                  body: `Your product "${product.name}" has been automatically approved and is now live for customers.`,
                },
                data: {
                  type: 'product_auto_approved',
                  productId: product.id,
                  screen: 'supplier_products',
                },
                android: {
                  notification: {
                    channelId: 'products',
                    priority: 'high',
                    sound: 'default',
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      alert: {
                        title: 'Product Approved!',
                        body: `Your product "${product.name}" has been automatically approved and is now live for customers.`,
                      },
                      sound: 'default',
                      badge: 1,
                    },
                  },
                },
              };

              await admin.messaging().send(message);
              console.log(`Auto-approval notification sent for product: ${product.name}`);
            }

            // Also create in-app notification
            await admin.firestore()
              .collection('users')
              .doc(product.supplierId)
              .collection('notifications')
              .add({
                title: 'Product Approved!',
                body: `Your product "${product.name}" has been automatically approved and is now live for customers.`,
                type: 'product_auto_approved',
                data: {
                  productId: product.id,
                  screen: 'supplier_products',
                },
                isRead: false,
                createdAt: now,
              });
          }
        } catch (notificationError) {
          console.error(`Error sending auto-approval notification for product ${product.name}:`, notificationError);
        }
      }

      // Send summary notification to admins
      try {
        const adminUsers = await admin.firestore()
          .collection('users')
          .where('role', '==', 'admin')
          .get();

        const adminTokens = [];
        const adminNotifications = [];

        adminUsers.docs.forEach((doc) => {
          const adminData = doc.data();
          if (adminData.fcmToken) {
            adminTokens.push(adminData.fcmToken);
          }

          adminNotifications.push(
            admin.firestore()
              .collection('users')
              .doc(doc.id)
              .collection('notifications')
              .add({
                title: 'Product Auto-Approval Summary',
                body: `${autoApprovedProducts.length} product${autoApprovedProducts.length > 1 ? 's' : ''} automatically approved after 5 minutes.`,
                type: 'admin_product_auto_approval',
                data: {
                  count: autoApprovedProducts.length,
                  screen: 'admin_products',
                },
                isRead: false,
                createdAt: now,
              }),
          );
        });

        if (adminTokens.length > 0) {
          const adminMessage = {
            tokens: adminTokens,
            notification: {
              title: 'Product Auto-Approval Summary',
              body: `${autoApprovedProducts.length} product${autoApprovedProducts.length > 1 ? 's' : ''} automatically approved after 5 minutes.`,
            },
            data: {
              type: 'admin_product_auto_approval',
              count: autoApprovedProducts.length.toString(),
              screen: 'admin_products',
            },
            android: {
              notification: {
                channelId: 'admin',
                priority: 'default',
                sound: 'default',
              },
            },
          };

          await admin.messaging().sendMulticast(adminMessage);
          console.log(`Product auto-approval summary sent to ${adminTokens.length} admins`);
        }

        await Promise.all(adminNotifications);
      } catch (adminNotificationError) {
        console.error('Error sending admin product auto-approval notifications:', adminNotificationError);
      }
    } else {
      console.log('No products found for auto-approval');
    }

    return null;
  } catch (error) {
    console.error('Error in product auto-approval function:', error);
    throw error;
  }
});

// Trigger to schedule product auto-approval when product is submitted
exports.scheduleProductAutoApproval = functions.firestore
  .document('products/{productId}')
  .onCreate(async (snap, context) => {
    try {
      const productData = snap.data();
      const productId = context.params.productId;

      // Only schedule auto-approval for pending products
      if (productData.status === 'pending') {
        const createdAt = productData.createdAt;
        const autoApprovalTime = new Date(createdAt.toDate().getTime() + (5 * 60 * 1000));

        await snap.ref.update({
          autoApprovalScheduledAt: admin.firestore.Timestamp.fromDate(autoApprovalTime),
        });

        console.log(`Product auto-approval scheduled for ${productId} at ${autoApprovalTime.toISOString()}`);
      }

      return null;
    } catch (error) {
      console.error('Error scheduling product auto-approval:', error);
      throw error;
    }
  });

// Cancel product auto-approval when manually reviewed
exports.cancelProductAutoApproval = functions.firestore
  .document('products/{productId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const productId = context.params.productId;

      // Check if status changed from pending to approved/rejected (manual review)
      if (before.status === 'pending' &&
          (after.status === 'approved' || after.status === 'rejected') &&
          after.reviewedBy !== 'system_auto_approval') {
        console.log(`Manual review completed for product ${productId}, auto-approval cancelled`);

        await change.after.ref.update({
          autoApprovalScheduledAt: admin.firestore.FieldValue.delete(),
        });
      }

      return null;
    } catch (error) {
      console.error('Error cancelling product auto-approval:', error);
      throw error;
    }
  });

// Cloud Function for real-time supplier ban management
exports.processSupplierBan = functions.firestore
  .document('supplier_reports/{reportId}')
  .onCreate(async (snap, context) => {
    try {
      const reportData = snap.data();
      const supplierId = reportData.supplierId;

      console.log(`Processing new report for supplier: ${supplierId}`);

      // Count total reports for this supplier
      const reportsSnapshot = await admin.firestore()
        .collection('supplier_reports')
        .where('supplierId', '==', supplierId)
        .get();

      const reportCount = reportsSnapshot.docs.length;
      console.log(`Supplier ${supplierId} now has ${reportCount} reports`);

      // Auto-ban if 3 or more reports
      if (reportCount >= 3) {
        const now = admin.firestore.Timestamp.now();

        // Update supplier status to banned
        await admin.firestore()
          .collection('users')
          .doc(supplierId)
          .update({
            isBanned: true,
            bannedAt: now,
            banReason: `Automatically banned due to ${reportCount} customer reports`,
            bannedBy: 'system_auto_ban',
            updatedAt: now,
          });

        // Deactivate all supplier's products
        const supplierProducts = await admin.firestore()
          .collection('products')
          .where('sellerId', '==', supplierId)
          .get();

        const batch = admin.firestore().batch();
        supplierProducts.docs.forEach((doc) => {
          batch.update(doc.ref, {
            isActive: false,
            deactivatedAt: now,
            deactivationReason: 'Supplier banned due to multiple reports',
          });
        });

        await batch.commit();
        console.log(`Banned supplier ${supplierId} and deactivated ${supplierProducts.docs.length} products`);

        // Send notification to banned supplier
        try {
          const supplierDoc = await admin.firestore()
            .collection('users')
            .doc(supplierId)
            .get();

          if (supplierDoc.exists) {
            const supplierData = supplierDoc.data();
            const fcmToken = supplierData.fcmToken;

            if (fcmToken) {
              const message = {
                token: fcmToken,
                notification: {
                  title: 'Account Suspended',
                  body: 'Your supplier account has been suspended due to multiple customer reports. Please contact support for assistance.',
                },
                data: {
                  type: 'account_banned',
                  reason: 'multiple_reports',
                  screen: 'supplier_profile',
                },
                android: {
                  notification: {
                    channelId: 'account',
                    priority: 'high',
                    sound: 'default',
                  },
                },
              };

              await admin.messaging().send(message);
            }

            // Create in-app notification
            await admin.firestore()
              .collection('users')
              .doc(supplierId)
              .collection('notifications')
              .add({
                title: 'Account Suspended',
                body: 'Your supplier account has been suspended due to multiple customer reports. Please contact support for assistance.',
                type: 'account_banned',
                data: {
                  reason: 'multiple_reports',
                  reportCount: reportCount,
                  screen: 'supplier_profile',
                },
                isRead: false,
                createdAt: now,
              });
          }
        } catch (notificationError) {
          console.error('Error sending ban notification to supplier:', notificationError);
        }

        // Notify admins about the auto-ban
        try {
          const adminUsers = await admin.firestore()
            .collection('users')
            .where('role', '==', 'admin')
            .get();

          const adminTokens = [];
          const adminNotifications = [];

          adminUsers.docs.forEach((doc) => {
            const adminData = doc.data();
            if (adminData.fcmToken) {
              adminTokens.push(adminData.fcmToken);
            }

            adminNotifications.push(
              admin.firestore()
                .collection('users')
                .doc(doc.id)
                .collection('notifications')
                .add({
                  title: 'Supplier Auto-Banned',
                  body: `Supplier ${reportData.supplierName || supplierId} has been automatically banned due to ${reportCount} reports.`,
                  type: 'admin_supplier_banned',
                  data: {
                    supplierId: supplierId,
                    reportCount: reportCount,
                    screen: 'admin_reports',
                  },
                  isRead: false,
                  createdAt: now,
                }),
            );
          });

          if (adminTokens.length > 0) {
            const adminMessage = {
              tokens: adminTokens,
              notification: {
                title: 'Supplier Auto-Banned',
                body: `Supplier ${reportData.supplierName || supplierId} has been automatically banned due to ${reportCount} reports.`,
              },
              data: {
                type: 'admin_supplier_banned',
                supplierId: supplierId,
                reportCount: reportCount.toString(),
                screen: 'admin_reports',
              },
              android: {
                notification: {
                  channelId: 'admin',
                  priority: 'high',
                  sound: 'default',
                },
              },
            };

            await admin.messaging().sendMulticast(adminMessage);
            console.log(`Auto-ban notification sent to ${adminTokens.length} admins`);
          }

          await Promise.all(adminNotifications);
        } catch (adminNotificationError) {
          console.error('Error sending admin ban notifications:', adminNotificationError);
        }
      } else {
        // Send warning notification to supplier if approaching ban threshold
        if (reportCount === 2) {
          try {
            const supplierDoc = await admin.firestore()
              .collection('users')
              .doc(supplierId)
              .get();

            if (supplierDoc.exists) {
              const supplierData = supplierDoc.data();
              const fcmToken = supplierData.fcmToken;

              if (fcmToken) {
                const message = {
                  token: fcmToken,
                  notification: {
                    title: 'Account Warning',
                    body: 'You have received multiple customer reports. One more report may result in account suspension. Please review your service quality.',
                  },
                  data: {
                    type: 'account_warning',
                    reportCount: reportCount.toString(),
                    screen: 'supplier_profile',
                  },
                  android: {
                    notification: {
                      channelId: 'account',
                      priority: 'high',
                      sound: 'default',
                    },
                  },
                };

                await admin.messaging().send(message);
              }

              // Create in-app notification
              await admin.firestore()
                .collection('users')
                .doc(supplierId)
                .collection('notifications')
                .add({
                  title: 'Account Warning',
                  body: 'You have received multiple customer reports. One more report may result in account suspension. Please review your service quality.',
                  type: 'account_warning',
                  data: {
                    reportCount: reportCount,
                    screen: 'supplier_profile',
                  },
                  isRead: false,
                  createdAt: admin.firestore.Timestamp.now(),
                });
            }
          } catch (warningError) {
            console.error('Error sending warning notification:', warningError);
          }
        }
      }

      return null;
    } catch (error) {
      console.error('Error processing supplier ban:', error);
      throw error;
    }
  });

// Cloud Function to unban suppliers (callable by admins)
exports.unbanSupplier = functions.https.onCall(async (data, context) => {
  try {
    // Verify admin authentication
    if (!context.auth || !context.auth.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    // Verify admin role
    const adminDoc = await admin.firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!adminDoc.exists || adminDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Must be admin');
    }

    const { supplierId, reason } = data;

    if (!supplierId) {
      throw new functions.https.HttpsError('invalid-argument', 'Supplier ID required');
    }

    const now = admin.firestore.Timestamp.now();

    // Update supplier status
    await admin.firestore()
      .collection('users')
      .doc(supplierId)
      .update({
        isBanned: false,
        unbannedAt: now,
        unbanReason: reason || 'Unbanned by admin',
        unbannedBy: context.auth.uid,
        updatedAt: now,
      });

    // Reactivate supplier's products
    const supplierProducts = await admin.firestore()
      .collection('products')
      .where('sellerId', '==', supplierId)
      .where('deactivationReason', '==', 'Supplier banned due to multiple reports')
      .get();

    const batch = admin.firestore().batch();
    supplierProducts.docs.forEach((doc) => {
      batch.update(doc.ref, {
        isActive: true,
        reactivatedAt: now,
        reactivationReason: 'Supplier unbanned by admin',
      });
    });

    await batch.commit();

    console.log(`Supplier ${supplierId} unbanned by admin ${context.auth.uid}`);

    // Send notification to unbanned supplier
    try {
      const supplierDoc = await admin.firestore()
        .collection('users')
        .doc(supplierId)
        .get();

      if (supplierDoc.exists) {
        const supplierData = supplierDoc.data();
        const fcmToken = supplierData.fcmToken;

        if (fcmToken) {
          const message = {
            token: fcmToken,
            notification: {
              title: 'Account Restored',
              body: 'Your supplier account has been restored. You can now access all supplier features and manage your products.',
            },
            data: {
              type: 'account_unbanned',
              screen: 'supplier_dashboard',
            },
            android: {
              notification: {
                channelId: 'account',
                priority: 'high',
                sound: 'default',
              },
            },
          };

          await admin.messaging().send(message);
        }

        // Create in-app notification
        await admin.firestore()
          .collection('users')
          .doc(supplierId)
          .collection('notifications')
          .add({
            title: 'Account Restored',
            body: 'Your supplier account has been restored. You can now access all supplier features and manage your products.',
            type: 'account_unbanned',
            data: {
              reason: reason || 'Unbanned by admin',
              screen: 'supplier_dashboard',
            },
            isRead: false,
            createdAt: now,
          });
      }
    } catch (notificationError) {
      console.error('Error sending unban notification:', notificationError);
    }

    return {
      success: true,
      message: 'Supplier unbanned successfully',
      productsReactivated: supplierProducts.docs.length,
    };
  } catch (error) {
    console.error('Error unbanning supplier:', error);
    throw new functions.https.HttpsError('internal', 'Failed to unban supplier');
  }
});

// Cloud Function: approve any pending products whose autoApprovalScheduledAt has arrived
exports.autoApproveScheduledProducts = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  console.log('Running scheduled auto-approval for products with autoApprovalScheduledAt <= now...');

  try {
    const now = admin.firestore.Timestamp.now();

    const dueProducts = await admin.firestore()
      .collection('products')
      .where('status', '==', 'pending')
      .where('autoApprovalScheduledAt', '<=', now)
      .get();

    if (dueProducts.empty) {
      console.log('No products due for scheduled auto-approval');
      return null;
    }

    const batch = admin.firestore().batch();
    const approved = [];

    dueProducts.docs.forEach((doc) => {
      const data = doc.data();
      batch.update(doc.ref, {
        status: 'approved',
        isVerified: true,
        reviewedAt: now,
        reviewedBy: 'system_auto_approval',
        rejectionReason: '',
        autoApproved: true,
        updatedAt: now,
        autoApprovalScheduledAt: admin.firestore.FieldValue.delete(),
      });
      approved.push({ id: doc.id, name: data.name, supplierId: data.sellerId });
    });

    await batch.commit();
    console.log(`Scheduled auto-approved ${approved.length} products`);

    for (const product of approved) {
      try {
        const supplierDoc = await admin.firestore().collection('users').doc(product.supplierId).get();
        if (supplierDoc.exists && supplierDoc.data().fcmToken) {
          await admin.messaging().send({
            token: supplierDoc.data().fcmToken,
            notification: {
              title: 'Product Approved!',
              body: `Your product "${product.name || ''}" has been approved.`,
            },
            data: { type: 'product_auto_approved', productId: product.id, screen: 'supplier_products' },
            android: { notification: { channelId: 'products', priority: 'high', sound: 'default' } },
          });
        }
      } catch (e) {
        console.error(`Notify failed for product ${product.id}:`, e);
      }
    }

    return null;
  } catch (error) {
    console.error('Error in autoApproveScheduledProducts:', error);
    throw error;
  }
});

// Trigger: when a product's content is cleared (contentFlagged: true -> false) and still pending, schedule short auto-approval (e.g., 2 minutes)
exports.scheduleAutoApprovalOnContentCleared = functions.firestore
  .document('products/{productId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();

      if (!before || !after) return null;

      const wasFlagged = !!before.contentFlagged;
      const isFlagged = !!after.contentFlagged;
      const isPending = after.status === 'pending' || !after.status;

      if (wasFlagged && !isFlagged && isPending) {
        const now = new Date();
        const inTwoMinutes = new Date(now.getTime() + 2 * 60 * 1000);
        await change.after.ref.update({
          autoApprovalScheduledAt: admin.firestore.Timestamp.fromDate(inTwoMinutes),
          updatedAt: admin.firestore.Timestamp.now(),
        });
        console.log(`Scheduled auto-approval in 2 minutes for product ${context.params.productId}`);
      }

      return null;
    } catch (error) {
      console.error('Error scheduling auto-approval on content cleared:', error);
      throw error;
    }
  });

// Cron: approve pending verifications whose autoApprovalScheduledAt has arrived
exports.autoApproveScheduledVerifications = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  console.log('Running scheduled auto-approval for supplier verifications...');

  try {
    const now = admin.firestore.Timestamp.now();
    const due = await admin.firestore()
      .collection('supplier_verifications')
      .where('status', '==', 'pending')
      .where('autoApprovalScheduledAt', '<=', now)
      .get();

    if (due.empty) {
      console.log('No verifications due for auto-approval');
      return null;
    }

    const batch = admin.firestore().batch();
    const toNotify = [];

    due.docs.forEach((doc) => {
      const data = doc.data();
      batch.update(doc.ref, {
        status: 'approved',
        reviewedAt: now,
        reviewedBy: 'system_auto_approval',
        reviewNotes: 'Automatically approved after timer elapsed',
        autoApproved: true,
        updatedAt: now,
        autoApprovalScheduledAt: admin.firestore.FieldValue.delete(),
      });
      batch.update(admin.firestore().collection('users').doc(data.supplierId), {
        isVerified: true,
        verificationStatus: 'approved',
        verifiedAt: now,
        updatedAt: now,
      });
      toNotify.push({ supplierId: data.supplierId, supplierEmail: data.supplierEmail });
    });

    await batch.commit();
    console.log(`Auto-approved ${toNotify.length} verifications by schedule`);

    for (const item of toNotify) {
      try {
        const userDoc = await admin.firestore().collection('users').doc(item.supplierId).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
          await admin.messaging().send({
            token: userDoc.data().fcmToken,
            notification: {
              title: 'Verification Approved!',
              body: 'Your supplier verification was approved.',
            },
            data: { type: 'verification_auto_approved', screen: 'supplier_profile' },
            android: { notification: { channelId: 'verification', priority: 'high', sound: 'default' } },
          });
        }
      } catch (e) {
        console.error('Notify verification approval failed:', e);
      }
    }

    return null;
  } catch (error) {
    console.error('Error in autoApproveScheduledVerifications:', error);
    throw error;
  }
});

// Cloud Function to ban a supplier (callable by admins) with optional durationDays for temporary ban
exports.banSupplier = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth || !context.auth.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!adminDoc.exists || adminDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Must be admin');
    }

    const { supplierId, reason, durationDays } = data;
    if (!supplierId || !reason) {
      throw new functions.https.HttpsError('invalid-argument', 'supplierId and reason are required');
    }

    const now = admin.firestore.Timestamp.now();
    const isTemporary = Number.isInteger(durationDays) && durationDays > 0;
    const expiresAt = isTemporary ? admin.firestore.Timestamp.fromDate(new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000)) : null;

    const banRef = await admin.firestore().collection('user_bans').add({
      userId: supplierId,
      bannedBy: context.auth.uid,
      reason,
      bannedAt: now,
      expiresAt: expiresAt,
      isPermanent: !isTemporary,
      isActive: true,
    });

    await admin.firestore().collection('users').doc(supplierId).update({
      isBanned: true,
      banType: isTemporary ? 'temporary' : 'permanent',
      banExpiresAt: expiresAt || admin.firestore.FieldValue.delete(),
      updatedAt: now,
    });

    const prods = await admin.firestore().collection('products').where('sellerId', '==', supplierId).get();
    const batch = admin.firestore().batch();
    prods.docs.forEach((doc) => batch.update(doc.ref, { isActive: false, deactivatedAt: now, deactivationReason: 'Supplier banned by admin' }));
    await batch.commit();

    return { success: true, banId: banRef.id };
  } catch (error) {
    console.error('Error banning supplier:', error);
    throw new functions.https.HttpsError('internal', 'Failed to ban supplier');
  }
});

// Scheduled job: unban users whose temporary bans have expired
exports.unbanExpiredBans = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  console.log('Running unbanExpiredBans...');
  try {
    const now = admin.firestore.Timestamp.now();
    const usersSnap = await admin.firestore()
      .collection('users')
      .where('isBanned', '==', true)
      .where('banType', '==', 'temporary')
      .where('banExpiresAt', '<=', now)
      .get();

    if (usersSnap.empty) {
      console.log('No expired bans found');
      return null;
    }

    for (const userDoc of usersSnap.docs) {
      const userId = userDoc.id;
      const batch = admin.firestore().batch();

      const activeBans = await admin.firestore()
        .collection('user_bans')
        .where('userId', '==', userId)
        .where('isActive', '==', true)
        .get();
      activeBans.docs.forEach((b) => batch.update(b.ref, { isActive: false }));

      batch.update(admin.firestore().collection('users').doc(userId), {
        isBanned: false,
        banType: admin.firestore.FieldValue.delete(),
        banExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: now,
      });

      await batch.commit();
      console.log(`Unbanned user ${userId} due to expired temporary ban`);
    }

    return null;
  } catch (error) {
    console.error('Error in unbanExpiredBans:', error);
    throw error;
  }
});
