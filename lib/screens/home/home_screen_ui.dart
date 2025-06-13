import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../location/select_location_screen.dart';
import 'all_departures/all_departures_screen.dart';
import 'my_departures/my_departures_screen.dart';
import 'profile/profile_screen.dart';
import 'nested_flight_details/nested_flight_details_screen.dart';
import '../../services/navigation/nested_navigation_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/logger.dart';

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
  final NestedNavigationService _navigationService = NestedNavigationService();

  @override
  void initState() {
    super.initState();
    _loadSelectedLocation();

    // Escuchar cambios en el servicio de navegación anidada
    _navigationService.addListener(_onNestedNavigationChanged);
  }

  @override
  void dispose() {
    _navigationService.removeListener(_onNestedNavigationChanged);
    super.dispose();
  }

  /// Callback que se ejecuta cuando cambia el estado de navegación anidada
  void _onNestedNavigationChanged() {
    // Forzar rebuild cuando cambie el estado de navegación
    if (mounted) {
      setState(() {});
    }
  }

  /// Ejecuta el refresh de la pantalla anidada de detalles de vuelo
  void _refreshNestedFlightDetails() {
    _navigationService.refreshNestedDetails();
  }

  /// Formatea el título para los detalles de vuelo: "NUMEROVUELO dd/mm details"
  String _formatFlightDetailsTitle(Map<String, dynamic> flightData) {
    try {
      final localizations = AppLocalizations.of(context)!;
      final String flightId = flightData['flight_id'] ?? 'XX';
      final String? scheduleTime = flightData['schedule_time'];

      if (scheduleTime != null && scheduleTime.isNotEmpty) {
        // Intentar parsear la fecha
        DateTime? flightDate;
        try {
          flightDate = DateTime.parse(scheduleTime);
        } catch (e) {
          AppLogger.error('Error parseando fecha vuelo', e);
        }

        if (flightDate != null) {
          final String formattedDate = DateFormat('dd/MM').format(flightDate);
          return '$flightId $formattedDate ${localizations.details}';
        }
      }

      // Fallback si no se puede obtener la fecha
      return '$flightId ${localizations.details}';
    } catch (e) {
      AppLogger.error('Error formateando título vuelo', e);
      return 'Flight details';
    }
  }

  Future<void> _loadSelectedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final location = prefs.getString('selected_location') ?? 'Bins';
      setState(() {
        _selectedLocation = location;
      });
    } catch (e) {
      AppLogger.error('Error al cargar ubicación', e);
    }
  }

  void _onItemTapped(int index) {
    // Si estamos mostrando detalles de vuelo, regresar primero
    if (_navigationService.isShowingFlightDetails) {
      _navigationService.navigateBack();
    }

    final localizations = AppLocalizations.of(context)!;
    final titles = [
      localizations.allDeparturesLabel,
      localizations.myDeparturesLabel,
      localizations.profileLabel
    ];
    AppLogger.debug('Usuario navegó a ${titles[index]}');
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Si estamos mostrando detalles de vuelo, usar ese título
    String appBarTitle;
    if (_navigationService.isShowingFlightDetails &&
        _navigationService.currentFlightData != null) {
      appBarTitle =
          _formatFlightDetailsTitle(_navigationService.currentFlightData!);
    } else {
      final titles = [
        localizations.allDeparturesLabel,
        localizations.myDeparturesLabel,
        localizations.profileLabel
      ];
      appBarTitle = titles[_selectedIndex];
    }

    AppLogger.debug('Construyendo UI HomeScreen, título: $appBarTitle');
    AppLogger.debug(
        'Mostrando detalles de vuelo: ${_navigationService.isShowingFlightDetails}');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          // Si estamos en detalles de vuelo, mostrar botón de refresh
          if (_navigationService.isShowingFlightDetails)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Notificar a la pantalla anidada que debe refrescar
                // Esto se puede hacer a través del servicio de navegación
                _refreshNestedFlightDetails();
              },
            ),
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
        leading: _navigationService.isShowingFlightDetails
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _navigationService.navigateBack();
                },
              )
            : null,
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
        currentIndex: _navigationService.isShowingFlightDetails
            ? _navigationService
                .originalTabIndex // Mantener el tab original resaltado
            : _selectedIndex,
        selectedItemColor: const Color(0xFF202124), // Negro Google
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    // Si estamos mostrando detalles de vuelo, mostrar la pantalla anidada
    if (_navigationService.isShowingFlightDetails) {
      final flightData = _navigationService.currentFlightData;
      final flightsList = _navigationService.flightsList;
      final flightsSource = _navigationService.flightsSource;

      if (flightData != null && flightsList != null && flightsSource != null) {
        // Crear una nueva instancia cada vez que cambie el vuelo
        return NestedFlightDetailsScreen(
          key:
              ValueKey('flight_${flightData['id']}_${flightData['flight_id']}'),
          flight: flightData,
          flightsList: flightsList,
          flightsSource: flightsSource,
        );
      }
    }

    // Mostrar las pantallas normales
    final localizations = AppLocalizations.of(context)!;
    final titles = [
      localizations.allDeparturesLabel,
      localizations.myDeparturesLabel,
      localizations.profileLabel
    ];

    // Usar los componentes modularizados según el índice seleccionado
    AppLogger.debug('Cargando contenido sección: ${titles[_selectedIndex]}');
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
