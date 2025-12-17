class Friend {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  const Friend({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName';
}