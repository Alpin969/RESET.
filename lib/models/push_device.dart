class PushDevice {
  final String id;
  final String endpoint;
  final String? deviceName;
  final String? userAgent;
  final DateTime? lastSuccessAt;
  final DateTime? createdAt;

  const PushDevice({
    required this.id,
    required this.endpoint,
    this.deviceName,
    this.userAgent,
    this.lastSuccessAt,
    this.createdAt,
  });

  factory PushDevice.fromMap(Map<String, dynamic> map) {
    return PushDevice(
      id: map['id'] as String,
      endpoint: map['endpoint'] as String,
      deviceName: map['device_name'] as String?,
      userAgent: map['user_agent'] as String?,
      lastSuccessAt: DateTime.tryParse(map['last_success_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'endpoint': endpoint,
      'device_name': deviceName,
      'user_agent': userAgent,
      'last_success_at': lastSuccessAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
