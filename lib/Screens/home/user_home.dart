import 'dart:async';
import 'dart:convert';

import 'package:baata/Screens/home/drawer.dart';
import 'package:baata/Screens/home/messagePage.dart';
import 'package:baata/consts.dart';
import 'package:baata/providers/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserHome extends StatefulWidget {
  final User user;
  final Function ThemeSetter;
  final ThemeMode ct;
  final bool? updateHome;
  const UserHome({
    Key? key,
    required this.user,
    required this.ThemeSetter,
    required this.ct,
    this.updateHome,
  }) : super(key: key);

  @override
  _UserHomeState createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  List? MessageList;
  String? token;
  String? newinitialId;
  void FetchuserMessages() async {
    var instance = await SharedPreferences.getInstance();
    MessageList = jsonDecode(
        instance.getString(FirebaseAuth.instance.currentUser!.uid) ?? "[]");
    setState(() {});
    bool updateDone = false;

    while (!updateDone) {
      try {
        token = await FirebaseAuth.instance.currentUser!.getIdToken();
        http.Response res = await http
            .get(Uri.parse("${URL}profile/getMessage/metadata/jwt=$token"));

        MessageList = jsonDecode(res.body);
        setState(() {});
        await instance.setString(
            FirebaseAuth.instance.currentUser!.uid, res.body);
        if (res.statusCode == 200) {
          updateDone = true;
        } else {
          Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        // TODO: replace with proper logging
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  void getToken() async {
    token = await FirebaseAuth.instance.currentUser!.getIdToken();
    setState(() {});
    Timer.periodic(const Duration(minutes: 10), (timer) async {
      token = await FirebaseAuth.instance.currentUser!.getIdToken();
      setState(() {});
    });
  }

  void updateMessagingToken() async {
    final String messagingtoken = await messaging.getToken() ?? "";
    final http.Response res = await http.post(
        Uri.parse("${URL}profile/SetFmcToken"),
        body: jsonEncode({"Fmc": messagingtoken}),
        headers: {"jwt": token!});
  }

  @override
  void initState() {
    getToken();
    FetchuserMessages();
    updateMessagingToken();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      FetchuserMessages();
    });
    return Scaffold(
      drawer: Drawer(
          child: CustomDrawer(
        user: widget.user,
        ThemeSetter: widget.ThemeSetter,
        ct: widget.ct,
        updatehome: FetchuserMessages,
      )),
      appBar: AppBar(
        actions: const [
          // Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 10.0),
          //   child: Icon(Icons.search_sharp),
          // ),
        ],
      ),
      body: MessageList == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: ListView.builder(
                reverse: true,
                itemCount: MessageList!.length,
                itemBuilder: (context, index) {
                  final String sender =
                      MessageList![index]['u1'] == widget.user.uid
                          ? MessageList![index]['u2']
                          : MessageList![index]['u1'];
                  final String senderName =
                      MessageList![index]['u1'] == widget.user.uid
                          ? MessageList![index]['n2']
                          : MessageList![index]['n1'];
                  final String UserNumber =
                      MessageList![index]['u1'] == widget.user.uid ? "1" : "2";
                  final DateTime DT = DateTime.fromMillisecondsSinceEpoch(
                      MessageList![index]['lastMessageTime']);
                  final String Time = DateFormat("h:mma").format(DT);
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (c) {
                          return MessagePage(
                            message: MessageList![index],
                            Senderuid: sender,
                            SenderName: senderName,
                            Token: token!,
                          );
                        })).then((value) => FetchuserMessages());
                      },
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.black,
                                  foregroundImage: NetworkImage(
                                      "${URL}profile/get/jwt=$token&uid=$sender",
                                      headers: {"Keep-Alive": "timeout=10"}),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Text(
                                    senderName,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Time),
                                if (MessageList![index]['unReadMessages']
                                        ['u' + UserNumber] !=
                                    0)
                                  Text(MessageList![index]['unReadMessages']
                                          ['u' + UserNumber]
                                      .toString()),
                              ],
                            )
                          ]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
