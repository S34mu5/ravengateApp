import 'package:flutter/material.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/flight_filter_util.dart';

/// Clase para manejar todo lo relacionado con filtros de vuelos
class DeparturesFilters {
  // Propiedades para filtros de fecha y hora
  DateTime startDate;
  TimeOfDay startTime;
  DateTime endDate;
  TimeOfDay endTime;
  String searchQuery;
  bool norwegianEquivalenceEnabled;

  // Constructor
  DeparturesFilters({
    DateTime? startDate,
    TimeOfDay? startTime,
    DateTime? endDate,
    TimeOfDay? endTime,
    this.searchQuery = '',
    this.norwegianEquivalenceEnabled = true,
  })  : startDate =
            startDate ?? DateTime.now().subtract(const Duration(hours: 3)),
        startTime = startTime ??
            TimeOfDay(
                hour: DateTime.now().subtract(const Duration(hours: 3)).hour,
                minute:
                    DateTime.now().subtract(const Duration(hours: 3)).minute),
        endDate = endDate ?? DateTime.now().add(const Duration(days: 7)),
        endTime = endTime ?? const TimeOfDay(hour: 23, minute: 59);

  // Métodos para guardar y cargar filtros
  Future<void> saveFiltersToCache() async {
    try {
      await CacheService.saveFilters(
        startDate: startDate,
        startTime: startTime,
        endDate: endDate,
        endTime: endTime,
        searchQuery: searchQuery,
      );
      print('LOG: Filters saved to cache');
    } catch (e) {
      print('ERROR: Could not save filters to cache: $e');
    }
  }

  // Cargar filtros desde la caché
  static Future<DeparturesFilters> loadFiltersFromCache() async {
    try {
      final savedFilters = await CacheService.getFilters();
      if (savedFilters != null) {
        print('LOG: Filters loaded from cache');
        return DeparturesFilters(
          startDate: savedFilters['startDate'] as DateTime,
          startTime: savedFilters['startTime'] as TimeOfDay,
          endDate: savedFilters['endDate'] as DateTime,
          endTime: savedFilters['endTime'] as TimeOfDay,
          searchQuery: savedFilters['searchQuery'] as String,
        );
      }
    } catch (e) {
      print('ERROR: Could not load filters from cache: $e');
    }

    // Si no hay filtros guardados, devolver valores predeterminados
    return DeparturesFilters();
  }

  // Método para cargar preferencia de Norwegian
  Future<void> loadNorwegianPreference() async {
    final isEnabled = await FlightFilterUtil.loadNorwegianPreference();
    norwegianEquivalenceEnabled = isEnabled;
    print(
        'LOG: Norwegian equivalence preference loaded: $norwegianEquivalenceEnabled');
  }

  // Convertir TimeOfDay a DateTime
  DateTime timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Obtener el rango de fechas formateado para mostrar
  String formatDateTimeRange() {
    final startDateTime = timeOfDayToDateTime(startDate, startTime);
    final endDateTime = timeOfDayToDateTime(endDate, endTime);

    return '${FlightFilterUtil.displayFormatter.format(startDateTime)} to ${FlightFilterUtil.displayFormatter.format(endDateTime)}';
  }

  // Aplicar filtro de texto a la lista de vuelos
  List<Map<String, dynamic>> applyTextFilter(
      List<Map<String, dynamic>> flights) {
    return FlightFilterUtil.filterFlights(
      flights: flights,
      searchQuery: searchQuery,
      norwegianEquivalenceEnabled: norwegianEquivalenceEnabled,
    );
  }

  // Aplicar filtro de fecha y hora a la lista de vuelos
  List<Map<String, dynamic>> applyDateTimeFilter(
      List<Map<String, dynamic>> flights) {
    final startDateTime = timeOfDayToDateTime(startDate, startTime);
    final endDateTime = timeOfDayToDateTime(endDate, endTime);

    print(
        'LOG: Applying date filter: ${FlightFilterUtil.dateFormatter.format(startDateTime)} ${FlightFilterUtil.timeFormatter.format(startDateTime)} - ${FlightFilterUtil.dateFormatter.format(endDateTime)} ${FlightFilterUtil.timeFormatter.format(endDateTime)}');

    final filteredFlights = FlightFilterUtil.filterFlightsByDateRange(
      flights: flights,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
    );

    print('LOG: Filtered ${filteredFlights.length} flights within date range');
    return filteredFlights;
  }

  // Aplicar todos los filtros a la lista de vuelos
  List<Map<String, dynamic>> applyAllFilters(
      List<Map<String, dynamic>> flights) {
    final textFiltered = applyTextFilter(flights);
    return applyDateTimeFilter(textFiltered);
  }

  // Resetear filtros a valores predeterminados pero mantener la fecha final actualizada
  void resetToDefaultFilters({DateTime? latestFlightDate}) {
    searchQuery = '';
    startDate = DateTime.now().subtract(const Duration(hours: 3));
    startTime = TimeOfDay(
        hour: DateTime.now().subtract(const Duration(hours: 3)).hour,
        minute: DateTime.now().subtract(const Duration(hours: 3)).minute);

    // Si se proporciona una fecha de vuelo más tardía, usarla
    if (latestFlightDate != null) {
      endDate = DateTime(
        latestFlightDate.year,
        latestFlightDate.month,
        latestFlightDate.day,
        23,
        59,
      );
    } else {
      // Sino, usar 7 días como valor predeterminado
      endDate = DateTime.now().add(const Duration(days: 7));
    }
    endTime = const TimeOfDay(hour: 23, minute: 59);
  }

  // Actualizar la fecha de fin basada en el vuelo más tardío
  void updateEndDateBasedOnLatestFlight(List<Map<String, dynamic>> flights) {
    if (flights.isEmpty) return;

    DateTime latestFlightDate = DateTime.now();
    bool foundValidDate = false;

    // Buscar la fecha del vuelo más tardío
    for (final flight in flights) {
      try {
        final scheduleTimeStr = flight['schedule_time'].toString();
        DateTime flightDateTime;

        // Formato ISO completo con T (ejemplo: 2023-01-01T12:30:00Z)
        if (scheduleTimeStr.contains('T')) {
          flightDateTime = DateTime.parse(scheduleTimeStr);

          // Si es fecha UTC, convertir a local
          if (scheduleTimeStr.endsWith('Z')) {
            flightDateTime = flightDateTime.toLocal();
          }
        }
        // Formato simple HH:MM (ejemplo: 15:30)
        else if (scheduleTimeStr.contains(':')) {
          final parts = scheduleTimeStr.split(':');
          if (parts.length >= 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);

            // Para formato simple, asumimos la fecha actual
            flightDateTime = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              hour,
              minute,
            );

            // Si la hora es anterior a la actual, probablemente sea del día siguiente
            if (flightDateTime.isBefore(DateTime.now())) {
              flightDateTime = flightDateTime.add(const Duration(days: 1));
            }
          } else {
            continue; // Formato inválido, pasar al siguiente vuelo
          }
        } else {
          continue; // Formato no reconocido, pasar al siguiente vuelo
        }

        if (flightDateTime.isAfter(latestFlightDate)) {
          latestFlightDate = flightDateTime;
          foundValidDate = true;
          print(
              'LOG: Found later flight: ${flight['flight_id']} at $flightDateTime');
        }
      } catch (e) {
        print('LOG: Error parsing date for flight: $e');
      }
    }

    // Si encontramos al menos una fecha válida, actualizar la fecha final
    if (foundValidDate) {
      endDate = DateTime(
        latestFlightDate.year,
        latestFlightDate.month,
        latestFlightDate.day,
        23, // Hora 23:59 para incluir todo el día
        59,
      );
      endTime = const TimeOfDay(hour: 23, minute: 59);

      print(
          'LOG: End date filter updated to: ${FlightFilterUtil.dateFormatter.format(endDate)} ${FlightFilterUtil.timeFormatter.format(DateTime(2022, 1, 1, endTime.hour, endTime.minute))}');
    } else {
      // Si no encontramos ninguna fecha válida, usar 7 días como valor predeterminado
      endDate = DateTime.now().add(const Duration(days: 7));
      endTime = const TimeOfDay(hour: 23, minute: 59);
      print(
          'LOG: No valid flight dates found, using default end date (7 days from now)');
    }
  }

  // Mostrar el selector de rango de fecha y hora
  Future<bool> showDateTimeRangePicker(BuildContext context) async {
    DateTime tempStartDate = startDate;
    TimeOfDay tempStartTime = startTime;
    DateTime tempEndDate = endDate;
    TimeOfDay tempEndTime = endTime;
    bool filtersChanged = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Date & Time Range'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('From:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Selector de fecha inicial
                    ListTile(
                      title: Text(
                          FlightFilterUtil.dateFormatter.format(tempStartDate)),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            tempStartDate = picked;
                          });
                        }
                      },
                    ),
                    // Selector de hora inicial
                    ListTile(
                      title: Text(
                          '${tempStartTime.hour.toString().padLeft(2, '0')}:${tempStartTime.minute.toString().padLeft(2, '0')}'),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: tempStartTime,
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            tempStartTime = picked;
                          });
                        }
                      },
                    ),
                    const Divider(),
                    const Text('To:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Selector de fecha final
                    ListTile(
                      title: Text(
                          FlightFilterUtil.dateFormatter.format(tempEndDate)),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempEndDate,
                          firstDate: tempStartDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            tempEndDate = picked;
                          });
                        }
                      },
                    ),
                    // Selector de hora final
                    ListTile(
                      title: Text(
                          '${tempEndTime.hour.toString().padLeft(2, '0')}:${tempEndTime.minute.toString().padLeft(2, '0')}'),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: tempEndTime,
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            tempEndTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Validar que la fecha de inicio no sea posterior a la de fin
                    final startDateTime =
                        timeOfDayToDateTime(tempStartDate, tempStartTime);
                    final endDateTime =
                        timeOfDayToDateTime(tempEndDate, tempEndTime);

                    if (startDateTime.isAfter(endDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Start date cannot be after end date'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // Aplicar cambios
                    startDate = tempStartDate;
                    startTime = tempStartTime;
                    endDate = tempEndDate;
                    endTime = tempEndTime;
                    filtersChanged = true;

                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    return filtersChanged;
  }
}
