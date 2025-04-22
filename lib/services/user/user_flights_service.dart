import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/airline_helper.dart';

/// Service to manage user's saved flights
class UserFlightsService {
  static const String _userFlightsKey = 'user_flights';

  /// Save a flight to user's saved flights list
  /// Returns true if the flight was added, false if it was already in the list
  static Future<bool> saveFlight(Map<String, dynamic> flight) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      // Prepare basic saved flight data (only reference)
      final Map<String, dynamic> savedFlightData = {
        'flight_ref': flight['id'], // Reference to original flight document
        'flight_id': flight['flight_id'], // Keep flight ID for easier queries
        'saved_at': DateTime.now().toIso8601String(),
      };

      // If user is logged in, add user info
      if (user != null) {
        savedFlightData['saved_by_user'] = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        };

        // Save to Firestore with reference approach
        return await _saveFlightToFirestore(user.uid, savedFlightData);
      } else {
        // For local storage, we still need all flight details
        // but we'll ensure we have the reference for future compatibility
        final processedFlight = _processFlightForStorage(flight);
        processedFlight['flight_ref'] = flight['id']; // Add reference
        return await _saveFlightToLocalStorage(processedFlight);
      }
    } catch (e) {
      print('LOG: Error saving flight: $e');
      return false;
    }
  }

  /// Get user's saved flights
  static Future<List<Map<String, dynamic>>> getUserFlights() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      List<Map<String, dynamic>> userFlightRefs;
      if (user != null) {
        // If user is logged in, get refs from Firestore
        userFlightRefs = await _getFlightRefsFromFirestore(user.uid);
      } else {
        // If user is not logged in, get from SharedPreferences
        userFlightRefs = await _getFlightsFromLocalStorage();
      }

      // Get full flight data from references
      final List<Map<String, dynamic>> completeFlights =
          await _getCompleteFlightData(userFlightRefs);

      // Process flights for use in UI (convert integers back to Color objects, etc.)
      return completeFlights.map(_processFlightForUI).toList();
    } catch (e) {
      print('LOG: Error getting user flights: $e');
      return [];
    }
  }

  /// Get complete and updated flight data from references
  static Future<List<Map<String, dynamic>>> _getCompleteFlightData(
      List<Map<String, dynamic>> flightRefs) async {
    final List<Map<String, dynamic>> completeFlights = [];

    // Process each flight reference
    for (final ref in flightRefs) {
      try {
        // Get the flight document from main collection using the reference
        final flightId = ref['flight_ref'];

        // Get the flight document from main collection
        final flightDoc = await FirebaseFirestore.instance
            .collection('flights')
            .doc(flightId)
            .get();

        if (flightDoc.exists) {
          // Create combined data with user metadata and updated flight info
          final flightData = flightDoc.data() as Map<String, dynamic>;
          final completeData = {
            ...flightData,
            'id': flightDoc.id,
            'saved_at': ref['saved_at'],
            'doc_id': ref['doc_id'], // Keep reference to user's saved document
          };

          // Add airline color if not present
          if (!completeData.containsKey('color')) {
            final airline = completeData['airline'] ?? '';
            completeData['color'] =
                AirlineHelper.getAirlineColor(airline).value;
          }

          completeFlights.add(completeData);
        } else {
          // Flight no longer exists, add a flag and use basic reference data
          print(
              'LOG: Flight ${ref['flight_id']} no longer exists, using reference data');
          final basicData = {
            ...ref,
            'flight_removed': true,
            'airport': 'Unknown',
            'gate': 'N/A',
            'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
            'schedule_time': 'N/A',
          };

          // Add a color for display
          if (!basicData.containsKey('color')) {
            basicData['color'] = Colors.grey.value;
          }

          completeFlights.add(basicData);
        }
      } catch (e) {
        print(
            'LOG: Error getting complete flight data for ${ref['flight_id']}: $e');
        // Add a minimal reference as fallback with error flag
        completeFlights.add({
          ...ref,
          'data_error': true,
          'airport': 'Error',
          'gate': 'Error',
          'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
          'schedule_time': 'Error',
          'color': Colors.red.value,
        });
      }
    }

    return completeFlights;
  }

  /// Remove a flight from user's saved flights
  static Future<bool> removeFlight(String flightId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // If user is logged in, remove from Firestore
        return await _removeFlightFromFirestore(user.uid, flightId);
      } else {
        // If user is not logged in, remove from SharedPreferences
        return await _removeFlightFromLocalStorage(flightId);
      }
    } catch (e) {
      print('LOG: Error removing flight: $e');
      return false;
    }
  }

  /// Check if a flight is already saved by the user
  static Future<bool> isFlightSaved(String flightId) async {
    try {
      final flights = await getUserFlights();
      // Check both 'id' and 'flight_id' fields to ensure proper matching
      return flights.any((flight) =>
          (flight['id'] != null && flight['id'] == flightId) ||
          (flight['flight_id'] != null && flight['flight_id'] == flightId));
    } catch (e) {
      print('LOG: Error checking if flight is saved: $e');
      return false;
    }
  }

  /// Process flight data for storage
  /// Converts incompatible types (like Color) to storable formats
  static Map<String, dynamic> _processFlightForStorage(
      Map<String, dynamic> flight) {
    final Map<String, dynamic> processedFlight = {};

    // Process each field in the flight map
    flight.forEach((key, value) {
      if (value is Color) {
        // Convert Color to integer
        processedFlight[key] = value.value;
        print('LOG: Converted Color to int: ${value.value} for field $key');
      } else if (value == null) {
        // Skip null values or provide default values if needed
        processedFlight[key] = value;
      } else {
        // Keep other values as is
        processedFlight[key] = value;
      }
    });

    return processedFlight;
  }

  /// Process flight data for UI display
  /// Converts stored formats back to usable types (like int to Color)
  static Map<String, dynamic> _processFlightForUI(Map<String, dynamic> flight) {
    final Map<String, dynamic> processedFlight = Map.from(flight);

    // Convert color field from int to Color if it exists
    if (flight['color'] is int) {
      processedFlight['color'] = Color(flight['color']);
      print('LOG: Converted int to Color for flight ${flight['flight_id']}');
    }

    return processedFlight;
  }

  // Private methods for Firestore operations
  static Future<bool> _saveFlightToFirestore(
      String userId, Map<String, dynamic> flightData) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      // First, ensure the user document exists with readable information
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Set user data for better readability in Firebase console
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'email': user.email,
          'displayName': user.displayName,
          'last_active': FieldValue.serverTimestamp(),
          // Don't overwrite existing data
        }, SetOptions(merge: true));
      }

      // Check if flight already exists by flight_ref or flight_id
      QuerySnapshot? existingFlights;

      // First try to check by 'flight_ref' if available
      if (flightData['flight_ref'] != null) {
        existingFlights = await userFlightsRef
            .where('flight_ref', isEqualTo: flightData['flight_ref'])
            .get();

        if (existingFlights.docs.isNotEmpty) {
          // Flight already saved by reference
          return false;
        }
      }

      // Then check by 'flight_id' as backup
      if (flightData['flight_id'] != null) {
        existingFlights = await userFlightsRef
            .where('flight_id', isEqualTo: flightData['flight_id'])
            .get();

        if (existingFlights.docs.isNotEmpty) {
          // Flight already saved by flight_id
          return false;
        }
      }

      // Add flight to Firestore
      await userFlightsRef.add({
        ...flightData,
        'saved_at_server': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('LOG: Error saving flight to Firestore: $e');
      throw e;
    }
  }

  static Future<List<Map<String, dynamic>>> _getFlightRefsFromFirestore(
      String userId) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      // Get all saved flights, ordered by saved_at timestamp
      final QuerySnapshot flightsSnapshot =
          await userFlightsRef.orderBy('saved_at', descending: true).get();

      // Convert to List<Map<String, dynamic>>
      return flightsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Add doc id as a field
        return {
          ...data,
          'doc_id': doc.id,
        };
      }).toList();
    } catch (e) {
      print('LOG: Error getting flight refs from Firestore: $e');
      throw e;
    }
  }

  static Future<bool> _removeFlightFromFirestore(
      String userId, String flightId) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      // Try to find the flight document by 'id' first
      QuerySnapshot flightDocs =
          await userFlightsRef.where('id', isEqualTo: flightId).get();

      // If not found by 'id', try by 'flight_id'
      if (flightDocs.docs.isEmpty) {
        flightDocs =
            await userFlightsRef.where('flight_id', isEqualTo: flightId).get();
      }

      if (flightDocs.docs.isEmpty) {
        // Flight not found by either field
        return false;
      }

      // Delete the flight document
      await userFlightsRef.doc(flightDocs.docs.first.id).delete();
      return true;
    } catch (e) {
      print('LOG: Error removing flight from Firestore: $e');
      throw e;
    }
  }

  // Private methods for SharedPreferences operations
  static Future<bool> _saveFlightToLocalStorage(
      Map<String, dynamic> flight) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await _getFlightsFromLocalStorage();

      // Check if flight already exists by 'id' or 'flight_id'
      if (flights.any((f) =>
          (f['id'] != null &&
              flight['id'] != null &&
              f['id'] == flight['id']) ||
          (f['flight_id'] != null &&
              flight['flight_id'] != null &&
              f['flight_id'] == flight['flight_id']))) {
        // Flight already saved
        return false;
      }

      // Add flight to list
      flights.add({
        ...flight,
      });

      // Save updated list
      final flightsJson = flights.map((f) => jsonEncode(f)).toList();
      await prefs.setStringList(_userFlightsKey, flightsJson);

      return true;
    } catch (e) {
      print('LOG: Error saving flight to local storage: $e');
      throw e;
    }
  }

  static Future<List<Map<String, dynamic>>>
      _getFlightsFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get saved flights list
      final flightsJson = prefs.getStringList(_userFlightsKey) ?? [];

      // Convert to List<Map<String, dynamic>>
      return flightsJson.map((flightJson) {
        return Map<String, dynamic>.from(jsonDecode(flightJson));
      }).toList();
    } catch (e) {
      print('LOG: Error getting flights from local storage: $e');
      throw e;
    }
  }

  static Future<bool> _removeFlightFromLocalStorage(String flightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await _getFlightsFromLocalStorage();

      // Remove flight from list by checking both 'id' and 'flight_id' fields
      final originalLength = flights.length;
      flights.removeWhere((flight) =>
          (flight['id'] != null && flight['id'] == flightId) ||
          (flight['flight_id'] != null && flight['flight_id'] == flightId));

      if (flights.length == originalLength) {
        // No flight was removed
        return false;
      }

      // Save updated list
      final flightsJson = flights.map((f) => jsonEncode(f)).toList();
      await prefs.setStringList(_userFlightsKey, flightsJson);

      return true;
    } catch (e) {
      print('LOG: Error removing flight from local storage: $e');
      throw e;
    }
  }

  /// Update user information in Firestore
  /// This helps improve readability in the Firebase console
  static Future<void> updateUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update user document with latest information
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? 'Usuario sin nombre',
          'photoURL': user.photoURL,
          'last_login': FieldValue.serverTimestamp(),
          'user_readable_id': user.email?.split('@')[0] ??
              'unknown', // Create a readable ID from email
        }, SetOptions(merge: true));

        print(
            'LOG: User info updated in Firestore for better console readability');
      }
    } catch (e) {
      print('LOG: Error updating user info: $e');
      // Non-critical error, don't throw
    }
  }
}
