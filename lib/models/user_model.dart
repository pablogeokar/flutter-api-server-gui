class UserModel {
  final int? id;
  final String name;
  final String email;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int?,
        name: json['name'] as String,
        email: json['email'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toDatabase() => {
        'id': id,
        'name': name,
        'email': email,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory UserModel.fromDatabase(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        email: map['email'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        createdAt: createdAt ?? this.createdAt,
      );

  bool isValidEmail() {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool isValid() {
    return name.trim().isNotEmpty && email.trim().isNotEmpty && isValidEmail();
  }
}
