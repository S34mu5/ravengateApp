import 'package:flutter/material.dart';
import '../../../services/cache/cache_service.dart';
import '../../../services/visualization/gate_stand_service.dart';
import '../../../l10n/app_localizations.dart';

class DataVisualizationSettings extends StatefulWidget {
  const DataVisualizationSettings({super.key});

  @override
  State<DataVisualizationSettings> createState() =>
      _DataVisualizationSettingsState();
}

class _DataVisualizationSettingsState extends State<DataVisualizationSettings> {
  bool _norwegianEquivalenceEnabled = true;
  bool _showStandEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNorwegianPreference();
    _loadShowStandPreference();
  }

  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();
    if (mounted) {
      setState(() {
        _norwegianEquivalenceEnabled = isEnabled;
      });
    }
  }

  Future<void> _loadShowStandPreference() async {
    final isEnabled = await GateStandService.getShowStandPreference();
    if (mounted) {
      setState(() {
        _showStandEnabled = isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.dataVisualizationSettings),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(localizations.norwegianDyD8Equivalence),
            subtitle: Text(localizations.norwegianDyD8EquivalenceSubtitle),
            value: _norwegianEquivalenceEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _norwegianEquivalenceEnabled = value;
              });
              await CacheService.saveNorwegianEquivalencePreference(value);
            },
          ),
          SwitchListTile(
            title: Text(localizations.showStandsInsteadOfGates),
            subtitle: Text(localizations.showStandsInsteadOfGatesSubtitle),
            value: _showStandEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _showStandEnabled = value;
              });
              await GateStandService.setShowStandPreference(value);
            },
          ),
        ],
      ),
    );
  }
}
