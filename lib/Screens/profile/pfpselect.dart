import 'dart:io';
import 'package:baata/consts.dart';
import 'package:baata/providers/auth.dart';
import 'package:baata/Settings/image_crop_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class Pfp extends StatefulWidget {
  final String userName;
  final User profile;
  final PageController controller;
  const Pfp(
      {Key? key,
      required this.userName,
      required this.profile,
      required this.controller});

  @override
  _PfpState createState() => _PfpState();
}

enum AppState {
  free,
  picked,
  cropped,
}

class _PfpState extends State<Pfp> {
  late AppState state;
  File? imageFile;

  @override
  void initState() {
    super.initState();
    state = AppState.free;
  }

  void _uploadFile() async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$URL/profile/upload"),
    );
    Map<String, String> headers = {
      "Content-type": "multipart/form-data",
      "jwt": Provider.of<Auth>(context, listen: false).token!
    };
    request.files.add(http.MultipartFile(
        'image', imageFile!.readAsBytes().asStream(), imageFile!.lengthSync(),
        filename: widget.userName +
            "|||DeLimitMe|||" +
            imageFile!.path.split('/').last.split('.').last));
    request.headers.addAll(headers);
    // TODO: replace with proper logging
    var res = await request.send();
    http.Response response = await http.Response.fromStream(res);
    if (response.statusCode == 200) {
      widget.controller.animateToPage(2,
          duration: const Duration(milliseconds: 500), curve: Curves.ease);
    }
  }

  Widget customButton(String text, Color c, Color tc, bool pic) {
    return ElevatedButton(
        onPressed: pic
            ? () => imageFile == null ? _pickImage() : _uploadFile()
            : () {
                setState(() {
                  imageFile = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("You are Need To upload a Photo")));
              },
        child: pic
            ? Text(text)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(text),
              ),
        style: ElevatedButton.styleFrom(backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
            imageFile != null
                ? SizedBox(
                    height: 200,
                    width: 200,
                    child: Stack(children: [
                      CircleAvatar(
                        foregroundImage: FileImage(imageFile!),
                        radius: 200,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(100),
                                      color: Colors.orange),
                                  child: InkWell(
                                    radius: 100,
                                    onTap: () {
                                      _cropImage();
                                    },
                                    child: const Icon(Icons.crop_free_sharp),
                                  )),
                            ],
                          ),
                        ],
                      )
                    ]),
                  )
                : Container(
                    child: const CircleAvatar(
                      foregroundImage: NetworkImage(
                          "https://upload.wikimedia.org/wikipedia/en/1/1b/NPC_wojak_meme.png"),
                      radius: 100,
                    ),
                  ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(widget.userName),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text("Add a Profile Photo"),
                ),
                customButton(
                    imageFile == null
                        ? "Custom Profile Photo"
                        : "Select This Photo",
                    Colors.orange,
                    Colors.black,
                    true),
                const Padding(padding: EdgeInsets.all(10)),
                // customButton(imageFile == null ? "Remain a NPC" : "Reset",
                //     Colors.black, Colors.white, false),
              ],
            ),
          ])),
    );
  }

  Future<void> _pickImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    imageFile = pickedImage != null ? File(pickedImage.path) : imageFile;
    if (imageFile != null) {
      setState(() {
        state = AppState.picked;
      });
      _cropImage();
    }
  }

  Future<void> _cropImage() async {
    final croppedPath = await cropImage(imageFile!.path);
    if (croppedPath != null) {
      imageFile = File(croppedPath);
      setState(() {
        state = AppState.cropped;
      });
    }
  }

  void _clearImage() {
    imageFile = null;
    setState(() {
      state = AppState.free;
    });
  }
}
