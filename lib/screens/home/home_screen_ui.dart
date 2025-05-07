import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../location/select_location_screen.dart';
import 'all_departures/all_departures_screen.dart';
import 'my_departures/my_departures_screen.dart';
import 'profile/profile_screen.dart';

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

  // Lista de títulos para el AppBar
  final List<String> _titles = ['All Departures', 'My Departures', 'Profile'];

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
    print('LOG: Usuario navegó a ${_titles[index]}');
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        'LOG: Construyendo UI de HomeScreen, sección actual: ${_titles[_selectedIndex]}');
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_titles[_selectedIndex]),
            const SizedBox(width: 8),
            Text(
              '• $_selectedLocation',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white70,
              ),
            ),
          ],
        ),
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: SizedBox(
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
            label: 'All Departures',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight),
            label: 'My Departures',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
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
    // Usar los componentes modularizados según el índice seleccionado
    print(
        'LOG: Cargando contenido para la sección: ${_titles[_selectedIndex]}');
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
