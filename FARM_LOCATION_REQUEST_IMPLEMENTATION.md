# Farm Location Request System Implementation

## Overview
This document describes the implementation of a farm location request system where suppliers can request farm locations that are automatically approved after 2 minutes, with real-time countdown timers and admin map integration.

## Key Features Implemented

### 1. 2-Minute Auto-Approval Timer
- **Service**: `FarmLocationCountdownService` - Manages countdown timers for each pending request
- **Duration**: 120 seconds (2 minutes) countdown
- **Auto-approval**: Automatically approves requests when countdown reaches zero
- **Real-time updates**: Countdown updates every second

### 2. Supplier Side Features
- **Location Selection**: Suppliers can tap on map to select farm location
- **Request Form**: Dialog for farm name and description
- **Pending Requests Display**: Shows all pending requests with countdown timers
- **Real-time Updates**: Uses StreamBuilder for live updates
- **Success Messages**: Clear feedback when requests are submitted

### 3. Admin Side Features
- **Map Integration**: Shows both approved farms (green) and pending requests (orange)
- **Request Details**: Click on pending request pins to see details
- **Countdown Display**: Shows time remaining until auto-approval
- **Real-time Updates**: Map updates automatically as requests are approved
- **Legend**: Clear distinction between approved and pending locations

### 4. Technical Implementation

#### Services Created/Modified:
- `FarmLocationCountdownService` - New service for countdown management
- `FarmLocationRequestService` - Updated with 2-minute auto-approval
- `FarmAutoApprovalService` - Updated to process every 15 seconds

#### Models Used:
- `FarmLocationRequest` - Request data structure
- `FarmLocation` - Approved farm location data

#### Real-time Features:
- StreamBuilder for live updates
- Timer-based countdown display
- Auto-approval processing
- Notification system integration

### 5. User Flow

#### Supplier Flow:
1. Navigate to "Manage Location" page
2. Select location on map by tapping
3. Click "Request Farm Location" button
4. Fill in farm name and description
5. Submit request
6. See pending request with 2-minute countdown
7. Request auto-approves after 2 minutes
8. Receive notification of approval

#### Admin Flow:
1. View admin farm map
2. See orange pins for pending requests
3. See green pins for approved farms
4. Click on pending request pins for details
5. View countdown timer
6. Option to manually approve/reject
7. Real-time updates as requests are processed

### 6. Database Collections

#### `farm_location_requests`:
- Request details (farm name, description, location)
- Status (pending, approved, rejected)
- Auto-approval timestamp
- Requester information

#### `farm_locations`:
- Approved farm location data
- Supplier information
- Location coordinates and address

### 7. Auto-Approval Process

1. **Request Submission**: Supplier submits farm location request
2. **Timer Start**: 2-minute countdown begins immediately
3. **Processing**: Auto-approval service checks every 15 seconds
4. **Approval**: Request automatically approved when timer expires
5. **Notification**: Supplier receives approval notification
6. **Map Update**: Farm location appears on admin map

### 8. Security & Validation

- Location validation within Bogo City boundaries
- User authentication required for all operations
- Admin-only access to approval/rejection functions
- Input validation for farm names and descriptions

### 9. Performance Optimizations

- Real-time streams for live updates
- Efficient countdown timer management
- Background auto-approval processing
- Optimized map rendering with filtered markers

## Files Modified/Created

### New Files:
- `lib/services/farm_location_countdown_service.dart`

### Modified Files:
- `lib/supplier-side/supplier_location_management_page.dart`
- `lib/admin-side/admin_farm_map_page.dart`
- `lib/services/farm_location_request_service.dart`
- `lib/services/farm_auto_approval_service.dart`

## Testing Recommendations

1. **Timer Accuracy**: Verify 2-minute countdown works correctly
2. **Auto-approval**: Test automatic approval after countdown
3. **Real-time Updates**: Verify map updates without refresh
4. **Notifications**: Test approval notifications
5. **Boundary Validation**: Test location selection within city limits
6. **Error Handling**: Test with invalid inputs and network issues

## Future Enhancements

1. **Manual Override**: Allow admins to extend or reduce countdown time
2. **Batch Processing**: Process multiple requests simultaneously
3. **Analytics**: Track approval times and request patterns
4. **Mobile Notifications**: Push notifications for mobile apps
5. **Audit Trail**: Log all approval actions for compliance
