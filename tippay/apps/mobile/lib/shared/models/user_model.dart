class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String type; // CUSTOMER, PROVIDER, ADMIN
  final String kycStatus; // PENDING, BASIC, FULL
  final String? languagePreference;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.type,
    required this.kycStatus,
    this.languagePreference,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      type: json['type'] as String,
      kycStatus: json['kycStatus'] as String,
      languagePreference: json['languagePreference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'type': type,
      'kycStatus': kycStatus,
      'languagePreference': languagePreference,
    };
  }

  bool get isProvider => type == 'PROVIDER' || type == 'ADMIN';
  bool get isCustomer => type == 'CUSTOMER';

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? type,
    String? kycStatus,
    String? languagePreference,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      type: type ?? this.type,
      kycStatus: kycStatus ?? this.kycStatus,
      languagePreference: languagePreference ?? this.languagePreference,
    );
  }
}
