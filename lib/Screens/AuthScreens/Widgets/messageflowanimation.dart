import 'dart:math';

import 'package:flutter/material.dart';

class MessageBubbleAnimaton extends StatelessWidget {
  const MessageBubbleAnimaton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MyHomePage(title: "Baata");
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  bool _counter = false;
  Color BoxColor = Colors.white;
  Color Textcolor = Colors.black;

  void _incrementCounter(BuildContext context) {
    setState(() {
      _counter = !_counter;
      if (BoxColor == Colors.orange) {
        BoxColor = Theme.of(context).canvasColor;
        Textcolor = Theme.of(context).textTheme.bodyLarge!.color!;
      } else if (BoxColor == Colors.white) {
        BoxColor = Colors.orange;
        Textcolor = Colors.orange;
      }
    });
  }

  Widget _message() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Random().nextInt(20).toDouble()),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          color: BoxColor),
      width: 100,
      height: 50,
      child: Center(
          child: Text(
        getMessage,
        style: TextStyle(color: Textcolor),
        overflow: TextOverflow.fade,
      )),
    );
  }

  String get getMessage {
    const List Worlds = [
      "Aalst",
      "Aalto",
      "AAM",
      "AAMSI",
      "Aandahl",
      "abbreviately",
      "abbreviates",
      "abbreviating",
      "abbreviation",
      "abbreviations",
      "Aberdonian",
      "aberduvine",
      "Aberfan",
      "Aberglaube",
      "Aberia",
      "Aberystwyth",
      "Abernant",
      "Abernathy",
      "abernethy",
      "Abernon",
      "aberr",
      "aberrance",
      "aberrancy",
    ];
    return Worlds[Random().nextInt(Worlds.length)];
  }

  Widget _animatedmessage({
    required double top,
    required Duration Speed,
  }) {
    final sWidth = MediaQuery.of(context).size;
    final int messages = (sWidth.width ~/ 120);
    final int columns = (sWidth.height * 0.4 ~/ 66);

    return AnimatedPositioned(
        top: top,
        right: _counter ? 0 - sWidth.width * 9.2 : sWidth.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < columns; i++)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    for (int i = 0; i < (messages * 10); i++) _message(),
                  ],
                ),
              ),
          ],
        ),
        onEnd: () {
          _incrementCounter(context);
        },
        duration: Speed);
  }

  void animationstarter() async {
    if (mounted) {
      Future.delayed(const Duration(seconds: 1),
          () => mounted ? _incrementCounter(context) : () {});
    }
  }

  bool startanimation = false;
  @override
  Widget build(BuildContext context) {
    if (!startanimation && mounted) {
      animationstarter();
      setState(() {
        startanimation = true;
      });
    }
    return Center(
        child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.45,
          color: Colors.orange,
        ),
        _animatedmessage(
          top: MediaQuery.of(context).size.height * 0.025,
          Speed: _counter
              ? const Duration(microseconds: 1)
              : const Duration(seconds: 150),
        ),
      ],
    ));
  }
}
