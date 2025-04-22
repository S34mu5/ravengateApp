import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Lista de títulos para el AppBar
  final List<String> _titles = ['All Departures', 'My Departures', 'Profile'];

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
        title: Text(_titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: widget.user.photoURL != null
                  ? NetworkImage(widget.user.photoURL!)
                  : null,
              child: widget.user.photoURL == null
                  ? const Icon(Icons.person, size: 24)
                  : null,
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 48,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
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
          const BottomNavigationBarItem(
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
