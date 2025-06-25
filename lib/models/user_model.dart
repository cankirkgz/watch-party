class UserModel {
  final String id;
  final String? name;
  final DateTime createdAt;

  UserModel({
    required this.id,
    this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
