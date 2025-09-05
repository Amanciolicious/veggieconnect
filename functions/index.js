const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Cloud Function to send FCM notifications using V1 API
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    // Validate input
    if (!data.token || !data.title || !data.body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
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
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Helper function to get channel ID based on notification type
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
exports.sendNotificationToMultiple = functions.https.onCall(async (data, context) => {
  try {
    if (!data.tokens || !Array.isArray(data.tokens) || !data.title || !data.body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
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
    throw new functions.https.HttpsError('internal', 'Failed to send notifications');
  }
});
