import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() {
  runApp(MyApp());
}

final ThemeData IOSTheme =
    ThemeData(primarySwatch: Colors.orange, primaryColor: Colors.grey[100], primaryColorBrightness: Brightness.light);

final ThemeData defaultTheme = ThemeData(primarySwatch: Colors.purple, accentColor: Colors.orangeAccent[400]);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

final String MENSAGENS = "mensagens";
final String TEXT = "text";
final String IMG_URL = "imgUrl";
final String SENDER_NAME = "senderName";
final String SENDER_PHOTO_URL = "senderPhotoUrl";

Future<Null> _ensureLoggedIn() async {
  /** 1º Realiza a Autenticação no Google */
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) user = await googleSignIn.signInSilently();
  if (user == null) user = await googleSignIn.signIn();

  /** 2º Realiza a Autenticação no FireBase */
  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

_handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

_sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection(MENSAGENS).add({
    TEXT: text,
    IMG_URL: imgUrl,
    SENDER_NAME: googleSignIn.currentUser.displayName,
    SENDER_PHOTO_URL: googleSignIn.currentUser.photoUrl
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat App",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS ? IOSTheme : defaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Permite ignorar as barras de cima e de baixo
      bottom: true,
      top: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
          centerTitle: true,
          elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.00 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                  stream: Firestore.instance.collection(MENSAGENS).snapshots(),
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        int size = snapshot.data.documents.length;
                        return ListView.builder(
                            reverse: true,
                            itemCount: size,
                            itemBuilder: (context, index) {
                              List listReverse = snapshot.data.documents.reversed.toList();
                              return ChatMessage(listReverse[index].data);
                              //return ChatMessage(snapshot.data.documents[index].data);
                            });
                    }
                  }),
            ),
            /*Expanded(
              child: ListView(
                children: <Widget>[ChatMessage(), ChatMessage(), ChatMessage()],
              ),
            ),*/
            Divider(
              height: 1.0,
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposser(),
            )
          ],
        ),
      ),
    );
  }
}

class TextComposser extends StatefulWidget {
  @override
  _TextComposserState createState() => _TextComposserState();
}

class _TextComposserState extends State<TextComposser> {
  final _textController = TextEditingController();

  bool _isComposing = false;

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        // Borda apenas no IOS
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey)))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                  icon: Icon(Icons.photo_camera),
                  onPressed: () async {
                    await _ensureLoggedIn();
                    File imgFile = await ImagePicker.pickImage(source: ImageSource.camera);
                    if (imgFile == null) return;
                    StorageUploadTask task = FirebaseStorage.instance
                        .ref()
                        .child("photos")
                        .child(
                            googleSignIn.currentUser.id.toString() + DateTime.now().millisecondsSinceEpoch.toString())
                        .putFile(imgFile);
                    String downloadUrl;
                    await task.onComplete.then((s) async {
                      downloadUrl = await s.ref.getDownloadURL();
                    });
                    _sendMessage(imgUrl: downloadUrl);
                  }),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmitted(text);
                  _reset();
                },
              ),
            ),
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text("Enviar"),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textController.text);
                                _reset();
                              }
                            : null,
                      )
                    : IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textController.text);
                                _reset();
                              }
                            : null))
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  ChatMessage(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data[SENDER_PHOTO_URL]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data[SENDER_NAME],
                  style: Theme.of(context).textTheme.subhead,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: data[IMG_URL] != null
                      ? Image.network(
                          data[IMG_URL],
                          width: 250.0,
                        )
                      : Text(data[TEXT]),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

void leitura() async {
  /** Gravar
      // Firestore.instance.collection("teste").document("teste1").setData({"teste2" : "teste3"});
      // Firestore.instance.collection("teste2").document().setData({"teste2" : "teste3"}); // Gera nome aleatório
   */

  /** Leitura simples
      DocumentSnapshot snapshot = await Firestore.instance.collection("teste").document("teste1").get();
      print(snapshot.data);
      print(snapshot.documentID);
   */

  /** Leitura query única
      QuerySnapshot query = await Firestore.instance.collection("teste").getDocuments();
      print(query.documents);

      for (DocumentSnapshot doc in query.documents) {
      print(doc.documentID);
      }
   */

  /**
      Firestore.instance.collection("teste").snapshots().listen((query) {
      print(query.documents);
      for (DocumentSnapshot doc in query.documents) {
      print('data ' + doc.data.toString() + ' ' + doc.documentID);
      }
      });
   */
}
