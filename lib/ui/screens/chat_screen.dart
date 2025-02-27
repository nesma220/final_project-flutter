import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_chat_custom/dash_chat_custom.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_recorder/audio_encoder_type.dart';
import 'package:social_media_recorder/screen/social_media_recorder.dart';
import 'package:voice_message_package/voice_message_package.dart';
import 'package:widget_zoom_pro/widget_zoom_pro.dart';
import 'package:just_audio/just_audio.dart';

class ChatDetailScreen extends StatefulWidget {
  final String receiverId;
  const ChatDetailScreen({required this.receiverId});

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String currentUserId;
  ChatUser? currentUser;
  late ChatUser otherUser;
  List<ChatMessage> messages = [];
  StreamSubscription? _messagesSubscription;
  List<File> imageFile = [];
  File? docFile;
  bool isReloading = false;
  bool isWriting = false;
  bool isRecording = false;
  bool canStop = false;

  List<File> audioFiles = [];
  @override
  void initState() {
    super.initState();

    currentUserId = _auth.currentUser?.uid ?? '';
    loadUsers();
    markMessagesAsRead();
  }

  Future<void> loadUsers() async {
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    DocumentSnapshot otherUserDoc =
        await _firestore.collection('users').doc(widget.receiverId).get();

    setState(() {
      currentUser = ChatUser(
        id: currentUserId,
        firstName: currentUserDoc['fullName'],
      );

      otherUser = ChatUser(
        id: widget.receiverId,
        firstName: otherUserDoc['fullName'],
      );
    });

    // بعد تحميل المستخدمين، استمع للرسائل
    listenForMessages();
  }

  Future<void> markMessagesAsRead() async {
    String chatId = currentUserId.hashCode <= widget.receiverId.hashCode
        ? "${currentUserId}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUserId";

    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount_$currentUserId': 0, // تصفير عدد الرسائل غير المقروءة
    });
  }

  void listenForMessages() {
    if (currentUser == null || otherUser == null) return;

    String chatId = currentUserId.hashCode <= widget.receiverId.hashCode
        ? "${currentUserId}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUserId";

    _messagesSubscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      List<ChatMessage> newMessages = snapshot.docs.map((doc) {
        List<ChatMedia> media = [];

        if (doc['images'] != null && doc['images'].isNotEmpty) {
          doc['images'].forEach((imageUrl) {
            media.add(
              ChatMedia(
                url: imageUrl,
                fileName: "",
                type: MediaType.image,
              ),
            );
          });
        }
        if (doc['voice'] != null && doc['voice'].isNotEmpty) {
          doc['voice'].forEach((voice) {
            media.add(
              ChatMedia(
                  url: voice,
                  fileName: "",
                  type: MediaType.file,
                  customProperties: {"duration": doc['message']}),
            );
          });
        }

        return ChatMessage(
          text: media.isNotEmpty
              ? media[0].type == MediaType.file
                  ? ''
                  : doc['message']
              : doc['message'],
          user: doc['senderId'] == currentUserId
              ? currentUser ?? ChatUser(id: "", firstName: "")
              : otherUser,
          medias: media,
          createdAt: (doc['timestamp'] != null)
              ? (doc['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          messages = newMessages;
        });
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    AudioPlayer().dispose();
    super.dispose();
  }

  upload(File file) async {
    String fileName = file.path.split('/').last;
    String extension = fileName.split('.').last;
    String uniqueFileName =
        '${DateTime.now().millisecondsSinceEpoch}.$extension';
    String downloadUrl = await FirebaseStorage.instance
        .ref('files/$uniqueFileName')
        .putFile(file)
        .then((snapshot) => snapshot.ref.getDownloadURL());
    return downloadUrl;
  }

  Future<void> sendMessage(ChatMessage message) async {
    List<String> urlImages = [];
    List<String> urlAudio = [];

    if (imageFile.isNotEmpty) {
      List<File>? files = imageFile;
      imageFile = [];

      isReloading = true;
      setState(() {});
      for (int i = 0; i < files.length; i++) {
        String url = await upload(files[i]);
        urlImages.add(url);
      }
    } else if (audioFiles.isNotEmpty) {
      List<File>? files = audioFiles;
      audioFiles = [];

      isReloading = true;
      setState(() {});
      for (int i = 0; i < files.length; i++) {
        String url = await upload(files[i]);
        urlAudio.add(url);
      }
    }

    String chatId = currentUserId.hashCode <= widget.receiverId.hashCode
        ? "${currentUserId}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUserId";

    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);

    await chatRef.collection('messages').add({
      'senderId': currentUserId,
      'receiverId': widget.receiverId,
      'message': message.text,
      'images': urlImages,
      'voice': urlAudio,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });

    await chatRef.set({
      'users': [currentUserId, widget.receiverId],
      'lastMessage': urlAudio.isNotEmpty
          ? "Voice Message"
          : urlImages.isNotEmpty
              ? "Message Image [${urlImages.length}]"
              : message.text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_${widget.receiverId}': FieldValue.increment(1),
    }, SetOptions(merge: true));

    isReloading = false;
    imageFile = [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("المحادثة")),
      body: currentUser == null
          ? Center(child: CircularProgressIndicator())
          : DashChat(
              messageListOptions: MessageListOptions(
                  chatFooterBuilder: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Column(
                  children: [
                    if (imageFile.isEmpty)
                      Align(
                        alignment: AlignmentDirectional.bottomEnd,
                        child: SocialMediaRecorder(
                          sendButtonIcon: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: Color(0xFF7210FF),
                                  borderRadius: BorderRadius.circular(50)),
                              child: Icon(
                                Icons.send,
                                size: 16,
                                color: Colors.white,
                              )),
                          initRecordPackageWidth: 45,
                          fullRecordPackageHeight: 40,
                          startRecording: () async {
                            debugPrint("Recording started");

                            setState(() {
                              isRecording = true;
                              canStop = false;
                            });

                            await Future.delayed(Duration(milliseconds: 500));
                            canStop = true;
                          },
                          stopRecording: (time) {
                            if (!canStop) {
                              debugPrint("Ignoring stop request (too fast)");
                              return; // منع الإيقاف السريع
                            }
                            debugPrint("Recording stopped after $time seconds");
                            setState(() {
                              isRecording = false;
                            });
                          },
                          recordIcon: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: Color(0xFF7210FF),
                                  borderRadius: BorderRadius.circular(50)),
                              child: Icon(
                                Icons.mic,
                                size: 16,
                                color: Colors.white,
                              )),
                          sendRequestFunction: (soundFile, text) {
                            isRecording = false;
                            setState(() {});
                            audioFiles.add(soundFile);
                            print(text);
                            sendMessage(ChatMessage(
                                text: text,
                                user: currentUser!,
                                createdAt: DateTime.now()));
                          },
                          encode: AudioEncoderType.AAC,
                        ),
                      ),
                    if (imageFile.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 130,
                        child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: Stack(
                                    alignment: AlignmentDirectional.topEnd,
                                    children: [
                                      SizedBox(
                                        width: 130,
                                        height: 100,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Image.file(
                                            imageFile[index],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            imageFile.removeAt(index);
                                            setState(() {});
                                          },
                                          icon: Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          )),
                                    ],
                                  ),
                                ),
                              );
                            },
                            itemCount: imageFile.length),
                      ),
                    SizedBox(
                      height: 10,
                    ),
                  ],
                ),
              )),
              inputOptions: InputOptions(
                inputDisabled: isRecording,
                onTextChange: (value) {
                  if (value.isNotEmpty) {
                    isWriting = true;
                  } else {
                    isWriting = false;
                  }
                  setState(() {});
                },
                inputDecoration: InputDecoration(
                  hintStyle: TextStyle(color: Color(0xffBEBEBE)),
                  hintText: "Message",
                  filled: true,
                  fillColor: Color(
                    0xffFAFAFA,
                  ),
                  // 0xffF4ceff        //
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide:
                          BorderSide(color: Color(0xFF7210FF), width: 2)),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Color(
                        0xffFAFAFA,
                      )),
                      borderRadius: BorderRadius.circular(25)),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Color(
                        0xffFAFAFA,
                      )),
                      borderRadius: BorderRadius.circular(25)),
                  suffixIcon: !isRecording
                      ? IconButton(
                          onPressed: () => pickImage(context),
                          icon: Icon(
                            Icons.image,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                          ))
                      : null,
                ),
                alwaysShowSend: true,
                showTraillingBeforeSend: true,
                sendButtonBuilder: isReloading
                    ? (val) => const CircularProgressIndicator()
                    : isWriting
                        ? (send) {
                            return IconButton(
                                onPressed: () {
                                  send();
                                },
                                icon: Icon(
                                  Icons.send,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.3),
                                ));
                          }
                        : (vale) {
                            return Container();
                          },
              ),
              messageOptions: MessageOptions(
                  currentUserContainerColor: Color(0xFF7210FF),
                  messageMediaBuilder: (message, previousMessage, nextMessage) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: message.medias!.map<Widget>((toElement) {
                        if (toElement.type == MediaType.image) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: WidgetZoomPro(
                                  zoomWidget: Image.network(
                                    fit: BoxFit.fill,
                                    toElement.url,
                                    width: 100,
                                    height: 100,
                                  ),
                                  heroAnimationTag: 'tag',
                                ),
                              ),
                            ),
                          );
                        } else if (toElement.type == MediaType.file) {
                          print(toElement.customProperties?['duration']);
                          List<String> parts = toElement
                              .customProperties?['duration']
                              .split(":");

                          return VoiceMessageView(
                            circlesColor: Color(0xFF7210FF),
                            controller: VoiceController(
                              audioSrc: toElement.url,
                              onComplete: () {
                                AudioPlayer().dispose();
                              },
                              onPause: () {
                                /// do something on pause
                              },
                              onPlaying: () {
                                /// do something on playing
                              },
                              onError: (err) {
                                AudioPlayer().dispose();
                              },
                              maxDuration: Duration(
                                  minutes: int.parse(parts[0]),
                                  seconds: int.parse(parts[1])),
                              isFile: false,
                            ),
                            innerPadding: 12,
                            cornerRadius: 20,
                          );
                        } else {
                          return SizedBox();
                        }
                      }).toList(),
                    );
                  }),
              currentUser: currentUser!,
              messages: messages,
              onSend: sendMessage,
            ),
    );
  }

  Future<File?> pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    return showModalBottomSheet<File?>(
      context: context,
      builder: (BuildContext bc) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Pick From Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> image = await picker.pickMultiImage();
                if (image.isNotEmpty) {
                  setState(() {
                    imageFile = image.map((e) => File(e.path)).toList();
                    isWriting = true;
                    print(imageFile.length);
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }
}
