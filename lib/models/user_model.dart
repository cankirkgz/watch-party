import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String preferredLanguage;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.preferredLanguage = 'tr',
    this.countryCode = '',
    this.translationLanguage = 'tr',
    this.autoTranslate = false,
    required this.createdAt,
  });

  final String countryCode;
  final String translationLanguage;
  final bool autoTranslate;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'preferredLanguage': preferredLanguage,
        'countryCode': countryCode,
        'translationLanguage': translationLanguage,
        'autoTranslate': autoTranslate,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    return UserModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Guest',
      email: map['email'] as String?,
      preferredLanguage: map['preferredLanguage'] as String? ?? 'tr',
      countryCode: map['countryCode'] as String? ?? '',
      translationLanguage: map['translationLanguage'] as String? ??
          map['preferredLanguage'] as String? ??
          'tr',
      autoTranslate: map['autoTranslate'] as bool? ?? false,
      createdAt: rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
