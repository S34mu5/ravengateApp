import 'package:flutter/material.dart';
import '../../../services/cache/cache_service.dart';

class DataVisualizationSettings extends StatefulWidget {
  const DataVisualizationSettings({super.key});

  @override
  State<DataVisualizationSettings> createState() =>
      _DataVisualizationSettingsState();
}

class _DataVisualizationSettingsState extends State<DataVisualizationSettings> {
  bool _norwegianEquivalenceEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNorwegianPreference();
  }

  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();
    if (mounted) {
      setState(() {
        _norwegianEquivalenceEnabled = isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Visualization Settings'),
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
            title: const Text('Norwegian DY/D8 Equivalence'),
            subtitle: const Text(
                'Show flights with DY code when searching for D8 and vice versa'),
            value: _norwegianEquivalenceEnabled,
            activeColor: Colors.blue,
            onChanged: (bool value) async {
              setState(() {
                _norwegianEquivalenceEnabled = value;
              });
              await CacheService.saveNorwegianEquivalencePreference(value);
            },
          ),
        ],
      ),
    );
  }
}
