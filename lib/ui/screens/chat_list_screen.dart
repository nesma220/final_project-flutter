import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/ui/screens/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'search_user_screen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid ?? '';
  }

  /// جلب المحادثات السابقة
  Stream<List<Map<String, dynamic>>> getUserChats() {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('hh:mm a').format(date); // عرض الوقت فقط إذا كان اليوم
    } else {
      return DateFormat('dd/MM/yyyy').format(date); // عرض التاريخ لباقي الأيام
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("الرسائل"),
        actions: [],
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.search),
          shape: CircleBorder(),
          backgroundColor: Color(0xFF7210FF),
          foregroundColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchUsersScreen()),
            );
          }),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getUserChats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("لا توجد رسائل حتى الآن"));
          }
          var chats = snapshot.data!;
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              var chat = chats[index];
              String otherUserId = chat['users'].firstWhere(
                (id) => id != currentUserId,
              );

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text("تحميل..."),
                      subtitle: Text(""),
                    );
                  }
                  var user = userSnapshot.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['profilePicture'] != null &&
                              user['profilePicture'] != ''
                          ? NetworkImage(user['profilePicture'])
                          : null,
                      child: user['profilePicture'] == null ||
                              user['profilePicture'] == ''
                          ? Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      user['fullName'],
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      formatTimestamp(chat['lastMessageTime']),
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(child: Text("${chat['lastMessage']}")),
                        if (chat['unreadCount_$currentUserId'] != null &&
                            chat['unreadCount_$currentUserId'] > 0)
                          Container(
                            padding: EdgeInsets.all(6),
                            margin: EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF7210FF),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${chat['unreadCount_$currentUserId']}",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            receiverId: otherUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
