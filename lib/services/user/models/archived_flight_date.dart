/// Estructura para organizar vuelos por fecha
class ArchivedFlightDate {
  final String date; // Formato "yyyy-MM-dd"
  final int count; // Número de vuelos en esa fecha

  ArchivedFlightDate({required this.date, required this.count});

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'count': count,
    };
  }

  factory ArchivedFlightDate.fromMap(Map<String, dynamic> map) {
    return ArchivedFlightDate(
      date: map['date'] ?? '',
      count: map['count'] ?? 0,
    );
  }
}
