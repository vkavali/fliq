class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String type;
  final String kycStatus;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    required this.type,
    required this.kycStatus,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      type: json['type'] as String,
      kycStatus: json['kycStatus'] as String,
    );
  }

  bool get isProvider => type == 'PROVIDER' || type == 'ADMIN';
  bool get isCustomer => type == 'CUSTOMER';
}
