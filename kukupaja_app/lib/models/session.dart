class Session {
  final String token;
  final int userId;
  final String name;
  final String role;

  const Session(this.token, this.userId, this.name, this.role);

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'name': name,
    'role': role,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    '${j['token']}',
    j['userId'] as int,
    '${j['name']}',
    '${j['role']}',
  );
}
