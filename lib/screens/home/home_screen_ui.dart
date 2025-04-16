import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'all_departures/all_departures_screen_new.dart';
import 'my_departures/my_departures_screen_new.dart';
import 'profile/profile_screen_new.dart';

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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
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
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    // Usar los componentes modularizados según el índice seleccionado
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
