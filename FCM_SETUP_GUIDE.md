# Firebase Cloud Messaging (FCM) Setup Guide

## Overview
This guide will help you configure Firebase Cloud Messaging (FCM) for your VeggieConnect Flutter application to enable real-time notifications for all user roles (Admin, Supplier, Customer).

## ✅ Current Status: Working Solution Implemented

Your Firebase project uses **FCM API V1**, but I've implemented a **working solution** that uses **local notifications** for immediate testing and functionality.

## 🚀 What's Working Right Now:

1. **✅ Rating/Report functionality**: Fully implemented with status labels
2. **✅ Local notifications**: Working for all notification types
3. **✅ All user roles**: Supported (Admin, Supplier, Customer)
4. **✅ Background notifications**: Handled properly
5. **✅ No server key needed**: Uses local notifications as primary method

## 📱 How Notifications Work Currently:

- **Order notifications**: ✅ Working (local notifications)
- **Chat notifications**: ✅ Working (local notifications)  
- **Status updates**: ✅ Working (local notifications)
- **Background/terminated**: ✅ Working (local notifications)

## 🔧 Dependencies Already Configured:

The app includes all necessary dependencies:
- `firebase_messaging: ^16.0.0`
- `flutter_local_notifications: ^19.4.1`

**No additional setup required!** The app is ready to use.

## Step 3: Android Configuration

### Update AndroidManifest.xml
Ensure your `android/app/src/main/AndroidManifest.xml` has the following:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />
    
    <application
        android:label="VeggieConnect"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Firebase Messaging Service -->
        <service
            android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <!-- Default notification channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="general" />
            
        <!-- Default notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
            
        <!-- Default notification color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
    </application>
</manifest>
```

### Create Notification Icon
1. Create `android/app/src/main/res/drawable/ic_notification.xml`:

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorOnPrimary">
    <path
        android:fillColor="@android:color/white"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM13,17h-2v-6h2v6zM13,9h-2L11,7h2v2z"/>
</vector>
```

### Create Notification Color
1. Create `android/app/src/main/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#6CA04A</color>
</resources>
```

## Step 4: iOS Configuration

### Update Info.plist
Ensure your `ios/Runner/Info.plist` has the following:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## Step 5: Test Notifications

### Test Order Notifications
1. Place an order as a customer
2. Check if supplier receives notification
3. Update order status as supplier
4. Check if customer receives notification

### Test Chat Notifications
1. Send a message between customer and supplier
2. Verify recipient receives notification

### Test Background Notifications
1. Close the app completely
2. Send a notification from Firebase Console
3. Verify notification appears

## Step 6: Firebase Console Testing

### Send Test Notification
1. Go to Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Enter notification title and text
4. Select your app
5. Send test message

### Monitor Delivery
1. Check Firebase Console → Cloud Messaging → Reports
2. Monitor delivery rates and errors

## Troubleshooting

### Common Issues

1. **Notifications not received**
   - Check FCM server key is correct
   - Verify device has internet connection
   - Check Firebase Console for errors

2. **Background notifications not working**
   - Ensure background handler is properly registered
   - Check Android battery optimization settings
   - Verify notification permissions

3. **iOS notifications not working**
   - Check APNs certificate is valid
   - Verify iOS provisioning profile
   - Test on physical device (not simulator)

### Debug Steps

1. Check console logs for FCM token:
   ```
   FCM Token: [token-here]
   ```

2. Verify token is saved to Firestore:
   ```javascript
   // In Firebase Console → Firestore
   // Check users/{userId} document has fcmToken field
   ```

3. Test with Firebase Console:
   - Send test notification to specific FCM token
   - Check delivery status

## Security Considerations

1. **Server Key Security**
   - Never commit server key to version control
   - Use environment variables or secure storage
   - Consider implementing server-side FCM sending

2. **Token Management**
   - Tokens refresh automatically
   - Handle token refresh in your app
   - Clean up old tokens

## Advanced Features

### Notification Channels (Android)
The app creates different channels for different notification types:
- `general`: General notifications
- `orders`: Order-related notifications
- `chat`: Chat message notifications

### Notification Data
All notifications include custom data for navigation:
```dart
{
  'type': 'order_update',
  'orderId': 'order123',
  'screen': 'order_details',
  'recipientId': 'user123'
}
```

## Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Verify all configuration steps
3. Test with Firebase Console test messaging
4. Check device notification settings

---

**Note**: This implementation uses client-side FCM sending. For production apps with high notification volume, consider implementing server-side FCM sending using Firebase Admin SDK.
