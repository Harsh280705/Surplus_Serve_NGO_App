class ChatRoom {
  final String id;
  final String donationId;
  final String donationTitle;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? otherUserNickname; // New field
  final String? otherUserLocation; // New field (location name, not coordinates)

  ChatRoom({
    required this.id,
    required this.donationId,
    required this.donationTitle,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.otherUserNickname,
    this.otherUserLocation,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donationId': donationId,
      'donationTitle': donationTitle,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'otherUserNickname': otherUserNickname,
      'otherUserLocation': otherUserLocation,
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> data) {
    return ChatRoom(
      id: data['id'] ?? '',
      donationId: data['donationId'] ?? '',
      donationTitle: data['donationTitle'] ?? '',
      otherUserId: data['otherUserId'] ?? '',
      otherUserName: data['otherUserName'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(data['lastMessageTime'] ?? 0),
      unreadCount: data['unreadCount'] ?? 0,
      otherUserNickname: data['otherUserNickname'],
      otherUserLocation: data['otherUserLocation'],
    );
  }
}