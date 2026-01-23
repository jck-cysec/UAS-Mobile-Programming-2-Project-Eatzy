class MenuModel {
  final String id;
  final String canteenId;
  final String name;
  final String description;
  final int price;
  final int prepTime;
  final bool isAvailable;
  final String category; // 'makanan' | 'minuman'
  final String imageUrl; // empty string if none
  final bool isDeleted; // soft-delete flag
  final DateTime? deletedAt;

  MenuModel({
    required this.id,
    required this.canteenId,
    required this.name,
    required this.description,
    required this.price,
    required this.prepTime,
    required this.isAvailable,
    required this.category,
    required this.imageUrl,
    required this.isDeleted,
    this.deletedAt,
  });

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDeletedAt;
    if (map['deleted_at'] != null) {
      try {
        parsedDeletedAt = DateTime.tryParse(map['deleted_at'].toString());
      } catch (_) {
        parsedDeletedAt = null;
      }
    }

    return MenuModel(
      id: map['id'],
      // tolerate null canteen_id coming from DB (e.g., created without canteen)
      canteenId: map['canteen_id'] ?? '',
      name: map['name'],
      description: map['description'] ?? '',
      price: map['price'],
      prepTime: map['prep_time'],
      isAvailable: map['is_available'] ?? true,
      category: (map['category'] as String?) ?? 'makanan',
      imageUrl: (map['image_url'] as String?) ?? '',
      isDeleted: map['is_deleted'] ?? false,
      deletedAt: parsedDeletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canteen_id': canteenId,
      'name': name,
      'description': description,
      'price': price,
      'prep_time': prepTime,
      'is_available': isAvailable,
      'category': category,
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
} 
