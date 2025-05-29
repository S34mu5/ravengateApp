import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../location/select_location_screen.dart';
import 'all_departures/all_departures_screen.dart';
import 'my_departures/my_departures_screen.dart';
import 'profile/profile_screen.dart';
import '../../l10n/app_localizations.dart';

/// Widget que maneja la UI de la pantalla principal
class HomeScreenUI extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const HomeScreenUI({
    required this.user,
    required this.onLogout,
    super.key,
  });

  @override
  State<HomeScreenUI> createState() => _HomeScreenUIState();
}

class _HomeScreenUIState extends State<HomeScreenUI> {
  int _selectedIndex = 0;
  String _selectedLocation = 'Bins'; // Valor por defecto

  @override
  void initState() {
    super.initState();
    _loadSelectedLocation();
  }

  Future<void> _loadSelectedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final location = prefs.getString('selected_location') ?? 'Bins';
      setState(() {
        _selectedLocation = location;
      });
    } catch (e) {
      print('Error al cargar la ubicación: $e');
    }
  }

  void _onItemTapped(int index) {
    final localizations = AppLocalizations.of(context)!;
    final titles = [
      localizations.allDeparturesLabel,
      localizations.myDeparturesLabel,
      localizations.profileLabel
    ];
    print('LOG: Usuario navegó a ${titles[index]}');
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final titles = [
      localizations.allDeparturesLabel,
      localizations.myDeparturesLabel,
      localizations.profileLabel
    ];

    print(
        'LOG: Construyendo UI de HomeScreen, sección actual: ${titles[_selectedIndex]}');
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: InkWell(
              onTap: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (context) => SelectLocationScreen(
                      user: widget.user,
                    ),
                  ),
                )
                    .then((_) {
                  // Recargar la ubicación cuando regrese
                  _loadSelectedLocation();
                });
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _selectedLocation == 'Bins'
                    ? Theme.of(context).colorScheme.primary
                    : Colors.amber,
                child: Text(
                  _selectedLocation == 'Bins' ? 'B' : 'OZ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const SizedBox(
              width: 48,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.airplanemode_active, size: 16),
                  Icon(Icons.airplanemode_active, size: 16),
                  Icon(Icons.airplanemode_active, size: 16),
                ],
              ),
            ),
            label: localizations.allDeparturesLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.flight),
            label: localizations.myDeparturesLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: localizations.profileLabel,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF202124), // Negro Google
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    final localizations = AppLocalizations.of(context)!;
    final titles = [
      localizations.allDeparturesLabel,
      localizations.myDeparturesLabel,
      localizations.profileLabel
    ];

    // Usar los componentes modularizados según el índice seleccionado
    print('LOG: Cargando contenido para la sección: ${titles[_selectedIndex]}');
    switch (_selectedIndex) {
      case 0:
        return const AllDeparturesScreen();
      case 1:
        return const MyDeparturesScreen();
      case 2:
        return ProfileScreen(
          user: widget.user,
          onLogout: widget.onLogout,
        );
      default:
        return const AllDeparturesScreen();
    }
  }
}
