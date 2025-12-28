class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? religion;
  final String? culture;
  final String? hobby;
  final int? age;
  final String? gender;
  final List<String> preferences;
  final String? companionType;
  final String? introduction;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.religion,
    this.culture,
    this.hobby,
    this.age,
    this.gender,
    this.preferences = const [],
    this.companionType,
    this.introduction,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? religion,
    String? culture,
    String? hobby,
    int? age,
    String? gender,
    List<String>? preferences,
    String? companionType,
    String? introduction,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      religion: religion ?? this.religion,
      culture: culture ?? this.culture,
      hobby: hobby ?? this.hobby,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      preferences: preferences ?? this.preferences,
      companionType: companionType ?? this.companionType,
      introduction: introduction ?? this.introduction,
    );
  }
}
