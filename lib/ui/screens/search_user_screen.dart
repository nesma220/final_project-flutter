import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/ui/screens/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SearchUsersScreen extends StatefulWidget {
  @override
  _SearchUsersScreenState createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  /// جلب جميع المستخدمين من Firebase
  Future<void> fetchUsers() async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();
    List<Map<String, dynamic>> userList = snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .where((user) => user['uid'] != _auth.currentUser!.uid)
        .toList();

    setState(() {
      users = userList;
      filteredUsers = users;
    });
  }

  /// تحديث قائمة البحث
  void searchUser(String query) {
    setState(() {
      filteredUsers = users
          .where((user) =>
              user['fullName'].toLowerCase().contains(query.toLowerCase()) ||
              user['email'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  /// بدء محادثة جديدة عند تحديد مستخدم
  void startChat(String receiverId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(receiverId: receiverId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("البحث عن مستخدم")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: searchUser,
              decoration: InputDecoration(
                hintText: "ابحث عن مستخدم...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(child: Text("لا يوجد مستخدمون مطابقون"))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      var user = filteredUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['profilePicture'] != null
                              ? NetworkImage(user['profilePicture'])
                              : null,
                          child: user['profilePicture'] == null
                              ? Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user['fullName']),
                        subtitle: Text(user['email']),
                        onTap: () => startChat(user['uid']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
