class UserStatus {
  final String uuid;
  String username;  // ← Remove final
  String? currentSong;
  String? currentArtist;
  DateTime lastSeen;  // ← Add default
  bool isOnline;

  UserStatus({
    required this.uuid,
    required this.username,  // ← Fixed constructor
    this.currentSong,
    this.currentArtist,
    DateTime? lastSeen,     // ← Make nullable
    this.isOnline = false,
  }) : lastSeen = lastSeen ?? DateTime.now();  // ← Default value

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'username': username,
    'currentSong': currentSong,
    'currentArtist': currentArtist,
    'lastSeen': lastSeen.toIso8601String(),
    'isOnline': isOnline,
  };

  factory UserStatus.fromJson(Map<String, dynamic> json) => UserStatus(
    uuid: json['uuid'],
    username: json['username'],
    currentSong: json['currentSong'],
    currentArtist: json['currentArtist'],
    lastSeen: DateTime.parse(json['lastSeen']),
    isOnline: json['isOnline'] ?? false,
  );
}
