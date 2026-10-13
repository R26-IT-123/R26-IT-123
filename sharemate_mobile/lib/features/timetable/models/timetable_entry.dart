/// A single scheduled (or frequency-based) public bus service between two
/// towns. Sourced from bustimetable.lk (there's no public timetable API for
/// Sri Lanka) and refreshed daily into Firestore's `bus_timetables`
/// collection — the app always reads from Firestore, never live from the
/// site.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.routeNumber,
    required this.origin,
    required this.destination,
    required this.operator,
    required this.busType,
    required this.departureTime,
    required this.days,
    this.intervalNote,
    this.notes,
    this.source,
    this.sourceUrl,
  });

  final String id;
  final String routeNumber;
  final String origin;
  final String destination;
  final String operator; // SLTB / Private
  final String busType; // Normal / Semi-Luxury / Luxury A/C / Super Luxury
  final String departureTime; // "HH:MM", first departure of the day
  final String? intervalNote; // e.g. "every 15-20 min"
  final List<String> days; // ["daily"] or specific weekdays
  final String? notes;
  final String? source; // e.g. "bustimetable.lk"
  final String? sourceUrl;

  bool get isFrequent => (intervalNote ?? '').isNotEmpty;

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'] as String? ?? '',
      routeNumber: json['route_number'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      operator: json['operator'] as String? ?? '',
      busType: json['bus_type'] as String? ?? '',
      departureTime: json['departure_time'] as String? ?? '',
      intervalNote: json['interval_note'] as String?,
      days: List<String>.from(json['days'] as List? ?? const ['daily']),
      notes: json['notes'] as String?,
      source: json['source'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }
}
