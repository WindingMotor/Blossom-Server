class UserStatus {
  final String uuid;
  String username;  
  String? currentSong;
  String? currentArtist;
  String? albumArt;   
  DateTime lastSeen;  
  bool isOnline;

  UserStatus({
    required this.uuid,
    required this.username,  
    this.currentSong,
    this.currentArtist,
    this.albumArt, 
    DateTime? lastSeen,    
    this.isOnline = false,
  }) : lastSeen = lastSeen ?? DateTime.now(); 

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'username': username,
    'currentSong': currentSong,
    'currentArtist': currentArtist,
    'albumArt': albumArt, // ← NEW
    'lastSeen': lastSeen.toIso8601String(),
    'isOnline': isOnline,
  };

  factory UserStatus.fromJson(Map<String, dynamic> json) => UserStatus(
    uuid: json['uuid'],
    username: json['username'],
    currentSong: json['currentSong'],
    currentArtist: json['currentArtist'],
    albumArt: json['albumArt'], // ← NEW
    lastSeen: DateTime.parse(json['lastSeen']),
    isOnline: json['isOnline'] ?? false,
  );
}
