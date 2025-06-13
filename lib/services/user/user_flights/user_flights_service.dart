import 'active_flights_service.dart';
import 'archived_flights_service.dart';
import '../models/archived_flight_date.dart';
import '../storage/flights_firestore_service.dart';

/// Fachada que mantiene la API pública original delegando la lógica en
/// servicios especializados con menos líneas de código.
class UserFlightsService {
  // ======== VUELOS ACTIVOS ========
  static Future<bool> saveFlight(Map<String, dynamic> flight) =>
      ActiveFlightsService.saveFlight(flight);

  static Future<List<Map<String, dynamic>>> getUserFlights(
          {bool forceRefresh = false}) =>
      ActiveFlightsService.getUserFlights(forceRefresh: forceRefresh);

  static Future<bool> removeFlight(String docId) =>
      ActiveFlightsService.removeFlight(docId);

  static Future<bool> isFlightSaved(String flightId) =>
      ActiveFlightsService.isFlightSaved(flightId);

  static Future<bool> deleteUserFlight(String docId) =>
      ActiveFlightsService.deleteUserFlight(docId);

  // ======== VUELOS ARCHIVADOS ========
  static Future<bool> archiveFlight(String docId) =>
      ArchivedFlightsService.archiveFlight(docId);

  static Future<List<ArchivedFlightDate>> getUserArchivedFlightDates(
          {bool forceRefresh = false}) =>
      ArchivedFlightsService.getUserArchivedFlightDates(
          forceRefresh: forceRefresh);

  static Future<List<Map<String, dynamic>>> getUserArchivedFlightsByDate(
          String date,
          {bool forceRefresh = false}) =>
      ArchivedFlightsService.getUserArchivedFlightsByDate(date,
          forceRefresh: forceRefresh);

  static Future<bool> permanentlyDeleteFlight(String docId) =>
      ArchivedFlightsService.permanentlyDeleteFlight(docId);

  static Future<bool> restoreUserFlight(String docId) =>
      ArchivedFlightsService.restoreUserFlight(docId);

  /// Método proxy para mantener compatibilidad con llamadas existentes
  static Future<bool> restoreArchivedFlight(String docId) =>
      restoreUserFlight(docId);

  /// Información de usuario en Firestore – permanece aquí porque depende sólo
  /// de `FlightsFirestoreService`.
  static Future<void> updateUserInfo() =>
      FlightsFirestoreService.updateUserInfo();
}
