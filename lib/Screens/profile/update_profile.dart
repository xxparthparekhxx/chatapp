import 'dart:io';
import 'package:baata/consts.dart';
import 'package:baata/Settings/image_crop_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

class UpdatePfp extends StatefulWidget {
  final String Name;
  final User user;
  final String JWT;

  const UpdatePfp(
      {Key? key, required this.Name, required this.user, required this.JWT});

  @override
  _UpdatePfpState createState() => _UpdatePfpState();
}

enum AppState {
  free,
  picked,
  cropped,
}

class _UpdatePfpState extends State<UpdatePfp> {
  void _cropImage() async {
    final croppedPath = await cropImage(imgPath!);
    if (croppedPath != null) {
      imgPath = croppedPath;
      setState(() {});
    }
  }

  InputDecoration inputDecor(label, hintText) {
    return InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
        hintText: "   " + hintText);
  }

  String? imgPath;
  void SelectImage() async {
    showModalBottomSheet(
        context: context,
        builder: (c) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                onTap: () async {
                  XFile? Img =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (Img != null) {
                    setState(() {
                      imgPath = Img.path;
                    });
                    Navigator.pop(context);
                  }
                },
                leading: const Icon(Icons.camera),
                title: const Text("Camera"),
              ),
              ListTile(
                onTap: () async {
                  XFile? Img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (Img != null) {
                    setState(() {
                      imgPath = Img.path;
                    });
                    Navigator.pop(context);
                  }
                },
                leading: const Icon(Icons.photo),
                title: const Text("Gallery"),
              )
            ],
          );
        });
  }

  void getStatus() async {
    var res = await http.get(Uri.parse(
        "${URL}status/get/jwt=${widget.JWT}&uid=${widget.user.phoneNumber}"));
    setState(() {
      Status = jsonDecode(res.body)['status'];
    });
  }

  @override
  void initState() {
    getStatus();
    super.initState();
  }

  final TextEditingController NameController = TextEditingController();
  final TextEditingController StatusController = TextEditingController();

  String? Status;
  @override
  Widget build(BuildContext context) {
    var sw = MediaQuery.of(context).size;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(children: [
                imgPath == null
                    ? CircleAvatar(
                        foregroundImage: NetworkImage(
                          "${URL}contact/get/jwt=${widget.JWT}&pno=${widget.user.phoneNumber}",
                        ),
                        maxRadius: sw.width * 0.3,
                      )
                    : CircleAvatar(
                        foregroundImage: FileImage(File(imgPath!)),
                        maxRadius: sw.width * 0.3,
                      ),
                SizedBox(
                  height: sw.height * 0.3,
                  width: sw.width * 0.6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(40)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(40),
                              onTap: () => SelectImage(),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.edit),
                              ),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
                if (imgPath != null)
                  SizedBox(
                    height: sw.height * 0.3,
                    width: sw.width * 0.6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(40)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(40),
                                onTap: () => _cropImage(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.crop_sharp),
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  )
              ]),
            ],
          ),
          SizedBox(
            height: sw.height * 0.05,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: sw.width * 0.6),
                  child: TextField(
                    controller: NameController,
                    decoration: inputDecor(widget.Name, "Name"),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: sw.width * 0.6),
                  child: TextField(
                    controller: StatusController,
                    decoration: inputDecor(Status ?? '', "Status"),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 10, right: (sw.width * 0.2)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.orange),
                  child: InkWell(
                      onTap: () async {
                        setState(() {});
                        Map<String, Object> data = {
                          "hasImage": imgPath != null,
                          "hasName": NameController.text != "",
                          "hasStatus": StatusController.text != "",
                          "Name": NameController.text,
                          "Status": StatusController.text
                        };
                        var request = http.MultipartRequest(
                          'POST',
                          Uri.parse("${URL}UpdateProfile"),
                        );

                        Map<String, String> headers = {
                          "Content-type": "multipart/form-data",
                          "jwt": widget.JWT
                        };

                        request.fields['data'] = jsonEncode(data);
                        if (imgPath != null) {
                          request.files.add(http.MultipartFile(
                              'image',
                              File(imgPath!).readAsBytes().asStream(),
                              File(imgPath!).lengthSync(),
                              filename: ''));
                        }
                        request.headers.addAll(headers);
                        var res = await request.send();
                        http.Response response =
                            await http.Response.fromStream(res);
                        if (response.statusCode == 200) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: const Icon(Icons.upload_sharp)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
