import 'package:flutter/material.dart';

class EnterOtp extends StatefulWidget {
  Function setter;
  Function verifyfunc;
  EnterOtp({Key? key, required this.setter, required this.verifyfunc})
      : super(key: key);

  @override
  State<EnterOtp> createState() => _EnterOtpState();
}

class _EnterOtpState extends State<EnterOtp> {
  TextEditingController opttext = TextEditingController();
  String OTP = "";

  Widget NumKey(String text) {
    return InkWell(
      borderRadius: BorderRadius.circular(180),
      onTap: () {
        setState(() {
          if (OTP.length < 6) OTP += text;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.08,
            vertical: MediaQuery.of(context).size.width * 0.06),
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Text(
          text,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget ThreeNumberRowTiles(a, b, c) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [NumKey(a), NumKey(b), NumKey(c)]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Row(
                children: [
                  Text(
                    "Enter The ",
                    style: Theme.of(context).primaryTextTheme.displayLarge,
                  ),
                  Text(
                    "OTP",
                    style: Theme.of(context).primaryTextTheme.titleLarge,
                  )
                ],
              )
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      OTP,
                      style: Theme.of(context)
                          .primaryTextTheme
                          .titleLarge!
                          .copyWith(fontSize: 40),
                    )
                  ],
                ),
              ),
              Column(
                children: [
                  ThreeNumberRowTiles("1", "2", "3"),
                  ThreeNumberRowTiles("4", "5", "6"),
                  ThreeNumberRowTiles("7", "8", "9"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      InkWell(
                          onTap: () {
                            setState(() {
                              if (OTP.isNotEmpty) {
                                OTP = OTP.substring(0, OTP.length - 1);
                              }
                            });
                          },
                          onLongPress: () => setState(() {
                                OTP = "";
                              }),
                          borderRadius: BorderRadius.circular(180),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.08,
                                vertical:
                                    MediaQuery.of(context).size.width * 0.06),
                            decoration:
                                const BoxDecoration(shape: BoxShape.circle),
                            child: const Icon(
                              Icons.backspace_rounded,
                              size: 32,
                            ),
                          )),
                      NumKey("0"),
                      InkWell(
                        onTap: () {
                          if (OTP.length == 6) {
                            widget.setter(OTP);
                            widget.verifyfunc();
                          }
                        },
                        borderRadius: BorderRadius.circular(180),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.08,
                              vertical:
                                  MediaQuery.of(context).size.width * 0.06),
                          decoration:
                              const BoxDecoration(shape: BoxShape.circle),
                          child: Icon(
                            Icons.check_circle,
                            size: 40,
                            color: OTP.length < 6
                                ? Colors.blueGrey
                                : Colors.orange,
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              )
            ],
          )
        ],
      ),
    ));
  }
}
