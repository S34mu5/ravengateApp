import 'package:flutter/material.dart';
import '../../../services/cache/cache_service.dart';
import '../../../l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _delayNotificationsEnabled = true;
  bool _departureNotificationsEnabled = true;
  bool _gateChangeNotificationsEnabled = true;
  bool _oversizeNotificationsEnabled = true;

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
    final oversizeEnabled =
        await CacheService.getOversizeNotificationsPreference();

    if (mounted) {
      setState(() {
        _delayNotificationsEnabled = delayEnabled;
        _departureNotificationsEnabled = departureEnabled;
        _gateChangeNotificationsEnabled = gateChangeEnabled;
        _oversizeNotificationsEnabled = oversizeEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.notificationSettings),
        elevation: 0,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              localizations.notificationsDescription,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(localizations.flightDelayNotifications),
            subtitle: Text(localizations.delayNotificationsSubtitle),
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
            title: Text(localizations.flightDepartureNotifications),
            subtitle: Text(localizations.departureNotificationsSubtitle),
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
            title: Text(localizations.gateChangeNotifications),
            subtitle: Text(localizations.gateChangeNotificationsSubtitle),
            value: _gateChangeNotificationsEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _gateChangeNotificationsEnabled = value;
              });
              await CacheService.saveGateChangeNotificationsPreference(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(localizations.oversizeNotifications),
            subtitle: Text(localizations.oversizeNotificationsSubtitle),
            value: _oversizeNotificationsEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _oversizeNotificationsEnabled = value;
              });
              await CacheService.saveOversizeNotificationsPreference(value);
            },
          ),
        ],
      ),
    );
  }
}
