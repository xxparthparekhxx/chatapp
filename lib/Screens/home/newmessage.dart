import 'dart:convert';

import 'package:baata/consts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class newMessageStart extends StatefulWidget {
  var data;
  String Token;
  Function updatehome;
  newMessageStart(
      {Key? key, this.data, required this.Token, required this.updatehome})
      : super(key: key);

  @override
  _newMessageStartState createState() => _newMessageStartState();
}

class _newMessageStartState extends State<newMessageStart> {
  List? ChatMessages;
  String? chatState;
  String? chatid;
  String selfUid = FirebaseAuth.instance.currentUser!.uid;
  TextEditingController Message = TextEditingController();

  void GetMessages() async {
    // TODO: replace with proper logging
    var data = await get(
        Uri.parse('${URL}GetChatFromUid/uid=${widget.data['uid']}'),
        headers: {"jwt": widget.Token});
    // TODO: replace with proper logging

    if (data.body == "notFound") {
      chatState = 'New';
    } else {
      chatState = 'Existing';
      Map ddData = jsonDecode(data.body);
      chatid = ddData['_id'];
      ChatMessages = ddData['messages'];
    }
    setState(() {});
  }

  @override
  void initState() {
    GetMessages();
    super.initState();
  }

  void UpdateMessagesWithId(id) async {
    Response res = await post(Uri.parse('${URL}getMessageFormid'),
        headers: {"jwt": widget.Token}, body: jsonEncode({"id": id}));
    ChatMessages = jsonDecode(res.body);
    chatState = "E";
    chatid = id;
    setState(() {});
  }

  void StartMessaging(Map message) async {
    Response res = await post(Uri.parse('${URL}StartMessagingWithNewContact'),
        headers: {"jwt": widget.Token}, body: jsonEncode(message));
    widget.updatehome();
    UpdateMessagesWithId(res.body);
  }

  void sendMessageToId(
      {required String id,
      required String textmessage,
      required bool isMedia}) async {
    Response res = await post(Uri.parse('${URL}postMessageToId'),
        headers: {"jwt": widget.Token},
        body: jsonEncode({
          "id": id,
          "Sender": selfUid,
          "messageTime": DateTime.now().millisecondsSinceEpoch,
          "MessageText": textmessage,
          "isMedia": isMedia
        }));
    UpdateMessagesWithId(id);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: replace with proper logging
    return Scaffold(
        appBar: AppBar(
            title: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          CircleAvatar(
            foregroundImage: NetworkImage(
                "${URL}contact/get/jwt=${widget.Token}&pno=${widget.data['phonenumber']}"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(widget.data['name'] ?? "NPC"),
          ),
        ])),
        body: chatState == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  chatState != "New" && ChatMessages != null
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: (MediaQuery.of(context).size.height -
                                      MediaQuery.of(context)
                                          .viewInsets
                                          .bottom) -
                                  170),
                          child: ListView.builder(
                            itemCount: ChatMessages!.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Row(
                                mainAxisAlignment:
                                    ChatMessages![index]['Sender'] == selfUid
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                children: [
                                  Container(
                                    color: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                          ChatMessages![index]['MessageText'] ??
                                              ChatMessages![index]
                                                  ["messageText"],
                                          style: const TextStyle(
                                              color: Colors.black)),
                                    ),
                                  )
                                ],
                              );
                            },
                          ),
                        )
                      : const Center(child: Text("Start  Messaging")),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: Message,
                        decoration: InputDecoration(
                            constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 80,
                        )),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            if (chatid == null) {
                              StartMessaging({
                                "contactUid": widget.data['uid'],
                                "selfUid": selfUid,
                                "ismedia": false,
                                "messageText": Message.text
                              });
                            } else if (chatid != null) {
                              sendMessageToId(
                                  id: chatid!,
                                  textmessage: Message.text,
                                  isMedia: false);
                            }
                            Message.text = '';
                            //todo implement sendind data
                            // text will have sender_uid,Text,time, and it will retrive the new chat id and messages then ss
                          },
                          child: const Icon(Icons.send))
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  )
                ],
              ));
  }
}
