class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? religion;
  final String? companionType;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.religion,
    this.companionType,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? religion,
    String? companionType,
  }) {
    return UserModel(
      id: this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      religion: religion ?? this.religion,
      companionType: companionType ?? this.companionType,
    );
  }
}
