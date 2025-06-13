import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../utils/logger.dart';
import '../../../utils/airline_helper.dart';
import '../models/archived_flight_date.dart';

class UserFlightsHelpers {
  static const String userArchivedFlightsKey = 'user_archived_flights';

  static Map<String, dynamic> processFlightForStorage(
      Map<String, dynamic> flight) {
    final Map<String, dynamic> processed = {};
    flight.forEach((key, value) {
      if (value is Color) {
        processed[key] = value.value;
      } else {
        processed[key] = value;
      }
    });
    return processed;
  }

  static Map<String, dynamic> processFlightForUI(Map<String, dynamic> flight) {
    final processed = Map<String, dynamic>.from(flight);
    if (flight['color'] is int) {
      processed['color'] = Color(flight['color']);
    }
    return processed;
  }

  static Future<List<Map<String, dynamic>>> getCompleteFlightDataBatch(
      List<Map<String, dynamic>> refs) async {
    final List<Map<String, dynamic>> complete = [];
    try {
      if (refs.isEmpty) return [];
      AppLogger.info('Helpers: batch request ${refs.length} flights');
      const batchSize = 30;
      List<String> current = [];
      List<Future<QuerySnapshot>> queries = [];
      final ids = refs.map((r) => r['flight_ref'] as String).toList();
      for (int i = 0; i < ids.length; i++) {
        current.add(ids[i]);
        if (current.length == batchSize || i == ids.length - 1) {
          queries.add(FirebaseFirestore.instance
              .collection('flights')
              .where(FieldPath.documentId, whereIn: current)
              .get());
          current = [];
        }
      }
      final results = await Future.wait(queries);
      final Map<String, Map<String, dynamic>> map = {};
      for (final snap in results) {
        for (final doc in snap.docs) {
          map[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }
      for (final ref in refs) {
        final id = ref['flight_ref'] as String;
        if (map.containsKey(id)) {
          final data = map[id]!;
          final merged = {
            ...data,
            'id': id,
            'original_id': id,
            'saved_at': ref['saved_at'],
            'doc_id': ref['doc_id'] ?? '',
          };
          if (!merged.containsKey('color')) {
            merged['color'] =
                AirlineHelper.getAirlineColor(merged['airline'] ?? '').value;
          }
          complete.add(merged);
        } else {
          complete.add({
            ...ref,
            'id': id,
            'flight_removed': true,
            'airport': 'Unknown',
            'gate': 'N/A',
            'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
            'schedule_time': 'N/A',
          });
        }
      }
    } catch (e) {
      AppLogger.error('Helpers batch error', e);
    }
    return complete;
  }

  /// Versión individual (compatibilidad histórica para archivados)
  static Future<List<Map<String, dynamic>>> getCompleteFlightData(
      List<Map<String, dynamic>> refs) async {
    final List<Map<String, dynamic>> complete = [];
    for (final ref in refs) {
      try {
        final flightId = ref['flight_ref'];
        final doc = await FirebaseFirestore.instance
            .collection('flights')
            .doc(flightId)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final merged = {
            ...data,
            'id': flightId,
            'original_id': flightId,
            'saved_at': ref['saved_at'],
            'doc_id': ref['doc_id'],
          };
          if (!merged.containsKey('color')) {
            merged['color'] =
                AirlineHelper.getAirlineColor(merged['airline'] ?? '').value;
          }
          complete.add(merged);
        } else {
          complete.add({
            ...ref,
            'id': flightId,
            'flight_removed': true,
            'airport': 'Unknown',
            'gate': 'N/A',
            'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
            'schedule_time': 'N/A',
          });
        }
      } catch (e) {
        AppLogger.error('Helpers: error individual flight', e);
      }
    }
    return complete;
  }

  static Future<List<ArchivedFlightDate>>
      getArchivedDatesFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonFlights = prefs.getString(userArchivedFlightsKey);
      if (jsonFlights == null) return [];
      final flights = (jsonDecode(jsonFlights) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((f) => f['archived'] == true)
          .toList();
      final Map<String, int> map = {};
      for (final f in flights) {
        final date = f['archived_date'] ??
            (f['archived_at'] != null
                ? f['archived_at'].split('T')[0]
                : DateTime.now().toIso8601String().split('T')[0]);
        map[date] = (map[date] ?? 0) + 1;
      }
      final list = map.entries
          .map((e) => ArchivedFlightDate(date: e.key, count: e.value))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      AppLogger.error('Helpers local dates error', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
      getArchivedFlightsByDateFromLocalStorage(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonFlights = prefs.getString(userArchivedFlightsKey);
      if (jsonFlights == null) return [];
      final flights = (jsonDecode(jsonFlights) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final filtered = flights.where((f) {
        final d = f['archived_date'] ??
            (f['archived_at'] != null ? f['archived_at'].split('T')[0] : '');
        return f['archived'] == true && d == date;
      }).toList();
      filtered.sort((a, b) {
        final aD = a['archived_at'] ?? '';
        final bD = b['archived_at'] ?? '';
        return bD.compareTo(aD);
      });
      return filtered;
    } catch (e) {
      AppLogger.error('Helpers local flights error', e);
      return [];
    }
  }
}
