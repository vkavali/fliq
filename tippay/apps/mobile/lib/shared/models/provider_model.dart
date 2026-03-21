class ProviderPublicModel {
  final String id;
  final String name;
  final String category;

  ProviderPublicModel({
    required this.id,
    required this.name,
    required this.category,
  });

  factory ProviderPublicModel.fromJson(Map<String, dynamic> json) {
    return ProviderPublicModel(
      id: json['providerId'] as String? ?? json['id'] as String,
      name: json['providerName'] as String? ?? json['name'] as String? ?? 'Provider',
      category: json['category'] as String? ?? 'OTHER',
    );
  }
}
