import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/logger.dart';

import '../storage/flights_firestore_service.dart';
import '../storage/flights_local_storage.dart';
import '../storage/flights_cache_service.dart';
import 'user_flights_helpers.dart';
import '../models/archived_flight_date.dart';

class ArchivedFlightsService {
  static Future<bool> archiveFlight(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final result =
            await FlightsFirestoreService.archiveFlight(user.uid, docId);
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }
        return result;
      } else {
        final result = await FlightsLocalStorage.archiveFlight(docId);
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }
        return result;
      }
    } catch (e) {
      AppLogger.error('ArchivedFlights: error archiveFlight', e);
      return false;
    }
  }

  static Future<bool> restoreUserFlight(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final result =
            await FlightsFirestoreService.restoreFlight(user.uid, docId);
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }
        return result;
      } else {
        final result = await FlightsLocalStorage.restoreFlight(docId);
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }
        return result;
      }
    } catch (e) {
      AppLogger.error('ArchivedFlights: error restoreFlight', e);
      return false;
    }
  }

  static Future<bool> permanentlyDeleteFlight(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final result = await FlightsFirestoreService.permanentlyDeleteFlight(
            user.uid, docId);
        if (result) {
          await FlightsCacheService.invalidateArchivedCache();
        }
        return result;
      } else {
        final result = await FlightsLocalStorage.permanentlyDeleteFlight(docId);
        if (result) {
          await FlightsCacheService.invalidateArchivedCache();
        }
        return result;
      }
    } catch (e) {
      AppLogger.error('ArchivedFlights: error delete', e);
      return false;
    }
  }

  static Future<List<ArchivedFlightDate>> getUserArchivedFlightDates(
      {bool forceRefresh = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (!forceRefresh) {
        final cached = await FlightsCacheService.loadArchivedDatesFromCache();
        if (cached.isNotEmpty) return cached;
      }
      if (user == null) {
        final local =
            await UserFlightsHelpers.getArchivedDatesFromLocalStorage();
        if (local.isNotEmpty) {
          await FlightsCacheService.saveArchivedDatesToCache(local);
        }
        return local;
      }
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('archived_flights');
      final snapshot = await ref.get();
      if (snapshot.docs.isEmpty) return [];
      final Map<String, int> map = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['archived_at'] ?? DateTime.now().toIso8601String();
        final dateOnly = dateStr.split('T')[0];
        map[dateOnly] = (map[dateOnly] ?? 0) + 1;
      }
      final dates = map.entries
          .map((e) => ArchivedFlightDate(date: e.key, count: e.value))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (dates.isNotEmpty) {
        await FlightsCacheService.saveArchivedDatesToCache(dates);
      }
      return dates;
    } catch (e) {
      AppLogger.error('ArchivedFlights: error getDates', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserArchivedFlightsByDate(
      String date,
      {bool forceRefresh = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (!forceRefresh) {
        final cached =
            await FlightsCacheService.loadArchivedFlightsByDateFromCache(date);
        if (cached.isNotEmpty) return cached;
      }
      if (user == null) {
        final local =
            await UserFlightsHelpers.getArchivedFlightsByDateFromLocalStorage(
                date);
        if (local.isNotEmpty) {
          await FlightsCacheService.saveArchivedFlightsByDateToCache(
              date, local);
        }
        return local;
      }
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('archived_flights');
      final snapshot = await ref.get();
      if (snapshot.docs.isEmpty) return [];
      final refs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'doc_id': doc.id};
      }).where((flight) {
        final flightDate = flight['archived_date'] ??
            (flight['archived_at'] != null
                ? flight['archived_at'].split('T')[0]
                : '');
        return flightDate == date;
      }).toList()
        ..sort((a, b) {
          final aDate = a['archived_at'] ?? '';
          final bDate = b['archived_at'] ?? '';
          return bDate.compareTo(aDate);
        });
      final complete = await UserFlightsHelpers.getCompleteFlightData(refs);
      final processed =
          complete.map(UserFlightsHelpers.processFlightForUI).toList();
      if (processed.isNotEmpty) {
        await FlightsCacheService.saveArchivedFlightsByDateToCache(
            date, processed);
      }
      return processed;
    } catch (e) {
      AppLogger.error('ArchivedFlights: error getByDate', e);
      return [];
    }
  }
}
