# RavenGate App

Flutter application for real-time flight monitoring at airports.

## Notification System in RavenGate

RavenGate's notification system is designed to keep users informed about critical changes to their flights in real time. The application implements two different detection and notification systems: one for gate changes and another for flight delays, each optimized for its specific use case.

## 1. Gate Change Notification System

### Architecture and Operation

The gate change notification system works by real-time monitoring of the Firestore database. This approach allows changes to be detected and notified almost instantly when they occur.

#### Initialization

- The `GateMonitorService` is automatically initialized when the application starts.
- It activates when the user authenticates and stops when they log out.

```dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user != null) {
    gateMonitorService.startMonitoring();
  } else {
    gateMonitorService.stopMonitoring();
  }
});
```

#### Real-Time Monitoring

1. When monitoring starts, the system retrieves all flights saved by the user that are not archived.
2. For each flight, it establishes a subscription to the `history` subcollection in Firestore that contains change records.
3. Subscriptions use the `snapshots().listen()` method to receive real-time updates:

```dart
final StreamSubscription<QuerySnapshot> subscription = _firestore
    .collection('flights')
    .doc(flightRef)
    .collection('history')
    .orderBy('change_time', descending: true)
    .limit(5)
    .snapshots()
    .listen((QuerySnapshot snapshot) {
        _handleHistoryChanges(snapshot, flightRef, flightId);
    });
```

#### Intelligent Filtering

- A cutoff time of 2 hours before the scheduled flight time is established.
- Gate changes that occur before this cutoff time do not generate notifications.
- A record of the last notified changes is maintained to avoid duplicates.

#### Valid Change Detection

A gate change is considered valid for notification when:

1. The flight has not departed or landed (status_code ≠ 'D' or 'L').
2. The change has a more recent timestamp than the last notified change.
3. The change occurs after the established cutoff time.
4. Gate change notifications are enabled in user preferences.

#### Notification Presentation

When a valid change is detected, the system builds a notification with:

- **Title**: "Gate Change"
- **Message**: "Flight [ID] ([Airline]) to [Destination] has changed gates from [Old Gate] to [New Gate]"

## 2. Flight Delay Notification System

Unlike the gate change system, delay notifications work through a system of periodic data comparison.

### Architecture and Operation

#### Periodic Initialization

- The system activates in the `MyDeparturesScreen` when loading the user's flights.
- A timer is configured to check for delays every 3 minutes:

```dart
_refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
  _previousUserFlights = List.from(_userFlights);
  _loadUserFlights();
});
```

#### Delay Detection

The delay detector (`FlightDelayDetector`) uses a comparison logic between previous and current data:

1. **Previous status verification**: Checks if the flight has already departed (status_code = 'D') or is canceled (status_code = 'C'). In these cases, no delays are notified.

2. **Direct indicator verification**: Analyzes if the boolean field `delayed` has changed from `false` to `true`.

3. **Schedule comparison**: If there is no direct indicator, the following are compared:

   - `schedule_time`: The original scheduled time
   - `status_time`: The current updated time
   - `previousStatusTimeStr`: The last known time

4. **Detection logic**: A delay is considered valid when:
   - The `delayed` indicator changes from false to true, or
   - The current time (`status_time`) is later than the scheduled time (`schedule_time`) and has also changed since the last check

```dart
bool _detectDelayChange({
  required Map<String, dynamic> previousFlight,
  required Map<String, dynamic> currentFlight,
}) {
  // Check if the flight has already departed or is canceled
  if (currentStatus == 'D' || currentStatus == 'C') {
    return false;
  }

  // Check for change in the 'delayed' flag
  if (!wasDelayedBefore && isDelayedNow) {
    return true;
  }

  // Compare changes in times
  if (statusTimeStr.isNotEmpty) {
    if (_isTimeAfter(statusTimeFormatted, scheduleTimeFormatted)) {
      return previousStatusTimeStr != statusTimeStr;
    }
  }

  return false;
}
```

#### Notification Presentation

When a delay is detected, a notification is built with:

- **Title**: "Flight Delay"
- **Message**: "Flight [ID] ([Airline]) to [Destination] has been delayed. New time: [New Time]"

## 3. Key Differences Between the Systems

| Feature                  | Gate Changes                                       | Flight Delays                       |
| ------------------------ | -------------------------------------------------- | ----------------------------------- |
| **Detection mechanism**  | Real-time listening (Firestore)                    | Periodic verification (every 3 min) |
| **Activation moment**    | Immediate                                          | Only when the timer executes        |
| **Data source**          | `history` subcollection                            | Comparison between complete updates |
| **Duplicate prevention** | Record of change timestamps                        | Comparison with last update         |
| **Persistence**          | Remains active even with the app in the background | Only works with the app in use      |

## 4. Notification Channel Configuration

The application configures specific channels for notifications:

- **`_gateChangeChannelId`**: Used for all flight-related notifications (gate changes, delays, and departures).
- **`_foregroundServiceChannelId`**: Used for the foreground service that keeps monitoring active.

Each channel is configured with its own importance, priority, and behavior characteristics.

**Important Note**: All flight-related notifications (including delays, gate changes, and departures) use the same notification channel (`_gateChangeChannelId`) for consistency in the user experience. This means they share the same notification sound, vibration pattern, and importance level.

```dart
// Example of channel configuration for all flight notifications
const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
  _gateChangeChannelId,
  'Gate Changes',
  channelDescription: 'Gate change notifications',
  importance: Importance.high,
  priority: Priority.high,
  ticker: 'ticker',
  styleInformation: BigTextStyleInformation(''),
);
```

## 5. User Control

Users have control over notifications through stored preferences:

- `CacheService.getGateChangeNotificationsPreference()`: Controls gate change notifications
- `CacheService.getDelayNotificationsPreference()`: Controls delay notifications
- `CacheService.getDepartureNotificationsPreference()`: Controls departure notifications

These preferences are stored using SharedPreferences and are enabled by default.

## 6. Permission Management

The system verifies and requests the necessary permissions to show notifications:

```dart
Future<bool> requestPermissions() async {
  // Check Android version (for Android 13+ explicit permission is required)
  if (Platform.isAndroid) {
    final int sdkInt = (await _getAndroidSdkInt()) ?? 0;
    if (sdkInt < 33) {
      return true; // No need to request permission on Android 12 or lower
    }
  }

  // Verify and request permissions
  final status = await Permission.notification.status;
  if (status.isGranted) {
    return true;
  }
  final result = await Permission.notification.request();
  return result.isGranted;
}
```

## Technical Considerations

1. **Performance and Battery**: The gate change monitoring system uses a background service to maintain active subscriptions, which can have an impact on battery life. Therefore, it implements:

   - Cutoff time filtering to reduce unnecessary notifications
   - Limit of 5 documents per query
   - Cancellation of subscriptions for flights that have already departed

2. **Error Handling**: Both systems implement error handling to ensure the application continues to function even if notification delivery fails.

3. **Debugging**: An optional debug mode is included to force notifications during testing:

   ```dart
   bool isDebugMode = false; // Change to true to force notifications
   ```

4. **Detailed Logs**: The systems generate detailed logs to facilitate debugging, using a consistent format with identifying prefixes:
   - `🔔 NOTIFICATIONS`: For the notification service
   - `🚪 GATE-MONITOR`: For the gate change monitor

The dual notification architecture in RavenGate allows balancing the immediacy needed for gate changes with energy efficiency for flight delays, providing users with timely information without compromising the user experience.

## Getting Started with Flutter Development

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
