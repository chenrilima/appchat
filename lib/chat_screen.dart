import 'dart:io';

import 'package:chat_app/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}


class _ChatScreenState extends State<ChatScreen> {

  final GoogleSignIn googleSignIn = GoogleSignIn(); // objeto GoogleSignIn
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  FirebaseUser _currentUser;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.onAuthStateChanged.listen((user) {
     setState(() {
       _currentUser = user;
     });
    });

  }

 Future<FirebaseUser> _getUser() async { // a função _getUser verifica se estou logado ou não

    if(_currentUser != null) return _currentUser;
          // se for nulo, eu faço o login

    try {
        final GoogleSignInAccount  googleSignInAccount = await googleSignIn.signIn(); // fazendo o login com google
        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;
        
        final AuthCredential credential = GoogleAuthProvider.getCredential(
            idToken: googleSignInAuthentication.idToken,
            accessToken: googleSignInAuthentication.accessToken,
        );

        final AuthResult authResult =
        await FirebaseAuth.instance.signInWithCredential(credential);

        final FirebaseUser user = authResult.user;

        return user;

    } catch (error) {
      return null;

    }
  }

  void _sendMessage({String text, File imgFile}) async { // sempre que eu escrever algo e apertar o botão, ele vai chamar o sendmessage

    final FirebaseUser user = await _getUser();

    if(user == null) {
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(
              content: Text('is not possible to sign in, try again!'),
              backgroundColor: Colors.deepPurple,
            )
        );
    }

    Map<String, dynamic> data = {
      "uid": user.uid,
      "senderName": user.displayName,
      "senderPhotoUrl": user.photoUrl,
      "time": Timestamp.now(),
    }; // colocando as infos do usuário

        if(imgFile != null) { // coloca uma imagem, caso tenha
          StorageUploadTask task = FirebaseStorage.instance.ref().child(
           user.uid + DateTime.now().millisecondsSinceEpoch.toString()
          ).putFile(imgFile);

          setState(() {
            _isLoading = true;
          });

         StorageTaskSnapshot taskSnapshot = await task.onComplete;
         String url = await taskSnapshot.ref.getDownloadURL();
          data['imgUrl'] = url;
        }

    setState(() {
      _isLoading = false;
    });

        if(text != null) data['text'] = text; // coloca um texto, caso tenha

    Firestore.instance.collection('messages').add(data); // adiciono tudo na minha coleção de mensagens

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _currentUser !=null ? 'Hello, ${_currentUser.displayName}' : 'Chat App' ,
        style: TextStyle(color: Colors.white),),
        centerTitle: true,
        elevation: 0,
        actions: [
          _currentUser != null ? IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () {
                FirebaseAuth.instance.signOut();
                googleSignIn.signOut();
         _scaffoldKey.currentState.showSnackBar(
          SnackBar(
          content: Text('You got out from Chat!'),

          )
          );
            },
          ) : Container (),
        ],
    ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder <QuerySnapshot> ( // stream me retorna dados, sempre que há modificação
              stream: Firestore.instance.collection('messages').orderBy('time').snapshots(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  default:
                    List<DocumentSnapshot> documents = snapshot.data.documents.reversed.toList();

                    return ListView.builder(
                        itemCount: documents.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          return ChatMessage(documents[index].data,
                          documents[index].data['uid'] == _currentUser?.uid
                          );
                        }
                    );
                }
              },
            ),
          ),
      _isLoading ? LinearProgressIndicator() : Container(),
      TextComposer(_sendMessage),
      ],
      ),
      );
  }
}
