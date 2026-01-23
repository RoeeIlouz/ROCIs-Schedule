import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Friend {
  final String uid;
  final String name;
  final String email;
  final String? university;
  final String? gradYear;

  Friend({
    required this.uid,
    required this.name,
    required this.email,
    this.university,
    this.gradYear,
  });

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      university: map['university'],
      gradYear: map['gradYear'],
    );
  }
}

class FriendProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final String uid;

  List<Friend> _friends = [];
  List<Friend> get friends => _friends;

  List<Friend> _pendingRequests = [];
  List<Friend> get pendingRequests => _pendingRequests;

  FriendProvider(this.uid);

  Future<void> sendRequest(String email) async {
    await _firestoreService.sendFriendRequest(uid, email);
  }

  Future<void> acceptRequest(String friendUid) async {
    await _firestoreService.acceptFriendRequest(uid, friendUid);
    await loadFriends();
    await loadRequests();
  }

  Future<void> declineRequest(String friendUid) async {
    await _firestoreService.declineFriendRequest(uid, friendUid);
    await loadRequests();
  }

  Future<void> loadRequests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friend_requests')
        .get();

    final List<Friend> requests = [];
    for (var doc in snapshot.docs) {
      final fromUid = doc.id;
      final profileDoc = await _firestoreService.getProfile(fromUid);
      if (profileDoc.exists) {
        requests.add(Friend.fromMap(profileDoc.data() as Map<String, dynamic>));
      }
    }
    _pendingRequests = requests;
    notifyListeners();
  }

  Future<void> loadFriends() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    final List<Friend> loadedFriends = [];
    for (var doc in query.docs) {
      final friendUid = doc.id;
      final profileDoc = await _firestoreService.getProfile(friendUid);
      if (profileDoc.exists) {
        loadedFriends.add(
          Friend.fromMap(profileDoc.data() as Map<String, dynamic>),
        );
      }
    }
    _friends = loadedFriends;
    notifyListeners();
  }
}
