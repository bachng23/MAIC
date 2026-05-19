class UserProfileInfo {
  const UserProfileInfo({
    this.name = '',
    this.age,
    this.address = '',
    this.bloodType = '',
    this.allergies = '',
    this.medicalConditions = '',
  });

  final String name;
  final int? age;
  final String address;
  final String bloodType;
  final String allergies;
  final String medicalConditions;

  static const bloodTypeOptions = <String>[
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  bool get hasAnyData =>
      name.trim().isNotEmpty ||
      age != null ||
      address.trim().isNotEmpty ||
      bloodType.trim().isNotEmpty ||
      allergies.trim().isNotEmpty ||
      medicalConditions.trim().isNotEmpty;

  String displayOrDash(String value) {
    final t = value.trim();
    return t.isEmpty ? '—' : t;
  }

  String get displayAge => age == null ? '—' : '$age';

  UserProfileInfo copyWith({
    String? name,
    int? age,
    bool clearAge = false,
    String? address,
    String? bloodType,
    String? allergies,
    String? medicalConditions,
  }) {
    return UserProfileInfo(
      name: name ?? this.name,
      age: clearAge ? null : (age ?? this.age),
      address: address ?? this.address,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'address': address,
        'blood_type': bloodType,
        'allergies': allergies,
        'medical_conditions': medicalConditions,
      };

  factory UserProfileInfo.fromJson(Map<String, dynamic> json) {
    final rawAge = json['age'];
    int? age;
    if (rawAge is int) {
      age = rawAge;
    } else if (rawAge is String && rawAge.isNotEmpty) {
      age = int.tryParse(rawAge);
    }
    return UserProfileInfo(
      name: json['name'] as String? ?? '',
      age: age,
      address: json['address'] as String? ?? '',
      bloodType: json['blood_type'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      medicalConditions: json['medical_conditions'] as String? ?? '',
    );
  }
}
