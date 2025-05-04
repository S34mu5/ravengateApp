import 'package:flutter/material.dart';
import '../../../services/cache/cache_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _delayNotificationsEnabled = true;
  bool _departureNotificationsEnabled = true;
  bool _gateChangeNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationsPreferences();
  }

  Future<void> _loadNotificationsPreferences() async {
    final delayEnabled = await CacheService.getDelayNotificationsPreference();
    final departureEnabled =
        await CacheService.getDepartureNotificationsPreference();
    final gateChangeEnabled =
        await CacheService.getGateChangeNotificationsPreference();

    if (mounted) {
      setState(() {
        _delayNotificationsEnabled = delayEnabled;
        _departureNotificationsEnabled = departureEnabled;
        _gateChangeNotificationsEnabled = gateChangeEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Configure which notifications you want to receive for your saved flights',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Flight Delay Notifications'),
            subtitle: const Text(
                'Receive alerts when flights saved in My Departures are delayed'),
            value: _delayNotificationsEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _delayNotificationsEnabled = value;
              });
              await CacheService.saveDelayNotificationsPreference(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Flight Departure Notifications'),
            subtitle: const Text(
                'Receive alerts when flights saved in My Departures have departed'),
            value: _departureNotificationsEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _departureNotificationsEnabled = value;
              });
              await CacheService.saveDepartureNotificationsPreference(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Gate Change Notifications'),
            subtitle: const Text(
                'Receive alerts when flights saved in My Departures have gate changes'),
            value: _gateChangeNotificationsEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _gateChangeNotificationsEnabled = value;
              });
              await CacheService.saveGateChangeNotificationsPreference(value);
            },
          ),
        ],
      ),
    );
  }
}
