class CrimeReport {
  final double lat;
  final double lng;
  final String type;
  final String description;
  final int timestamp;

  CrimeReport({
    required this.lat,
    required this.lng,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  // Convert to Firebase JSON
  Map<String, dynamic> toMap() {
    return {
      "lat": lat,
      "lng": lng,
      "type": type,
      "description": description,
      "timestamp": timestamp,
    };
  }

  // (for later use)
  factory CrimeReport.fromMap(Map data) {
    return CrimeReport(
      lat: data["lat"],
      lng: data["lng"],
      type: data["type"],
      description: data["description"] ?? "",
      timestamp: data["timestamp"],
    );
  }
}