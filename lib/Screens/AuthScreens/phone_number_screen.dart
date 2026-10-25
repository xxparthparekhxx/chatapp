import 'package:baata/Screens/AuthScreens/countryselect.dart';
import 'package:flutter/material.dart';

class enterPhoneNumberScreene extends StatefulWidget {
  final Function startVerification;
  final String? Error;
  const enterPhoneNumberScreene({
    this.Error,
    required this.startVerification,
    Key? key,
  }) : super(key: key);

  @override
  State<enterPhoneNumberScreene> createState() =>
      _enterPhoneNumberScreeneState();
}

class _enterPhoneNumberScreeneState extends State<enterPhoneNumberScreene> {
  Map<String, String>? countrySelected;
  String phonenumber = '';
  void promptToSelectCountry(BuildContext context) {
    showBottomSheet(
        context: context,
        builder: (ctx) {
          return CountrySelect(CountryListTile: CountryListTile);
        });
  }

  Widget CountryListTile(Map<String, String> Data, ss, bool recivetap) {
    void updateselectedCountry(context, Data) {
      setState(() {
        countrySelected = Data;
      });
      Navigator.pop(context);
    }

    return ListTile(
      onTap: recivetap ? () => updateselectedCountry(context, Data) : null,
      leading: Container(
        decoration: BoxDecoration(
            color: recivetap ? Colors.orange : Theme.of(context).canvasColor,
            borderRadius: BorderRadius.circular(20)),
        width: ss.width * 0.25,
        height: ss.height * 0.05,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: ss.width * 0.1,
              child: Image.asset("flags/${Data["isoCode"]!}.jpg"),
            ),
            Text(Data['dialCode'] as String,
                style: TextStyle(
                    color: recivetap ? Colors.black : null,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      title: Text(Data['name'] as String),
    );
  }

  Widget NumKey(String text) {
    return InkWell(
      borderRadius: BorderRadius.circular(180),
      onTap: () {
        setState(() {
          if (phonenumber.length < 10) phonenumber += text;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.08 -
                MediaQuery.of(context).viewInsets.bottom,
            vertical: MediaQuery.of(context).size.width * 0.06 -
                MediaQuery.of(context).viewInsets.bottom * 10),
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

  bool Verificationstarted = false;

  @override
  Widget build(BuildContext context) {
    var ss = MediaQuery.of(context).size;
    return OverflowBox(
      maxHeight: ss.height,
      maxWidth: ss.width,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ss.width * 0.030, vertical: ss.width * 0.030),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Enter Your",
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "mobile number",
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      Text("We will send you a confirmation code"),
                    ],
                  ),
                ),
                ElevatedButton(
                    onPressed: () => promptToSelectCountry(context),
                    child: countrySelected != null
                        ? CountryListTile(countrySelected!, ss, false)
                        : const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Select Your Country"),
                          )),
                if (widget.Error != null) Text(widget.Error ?? '')
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        countrySelected != null
                            ? countrySelected!['dialCode']! + " " + phonenumber
                            : "",
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
                                if (phonenumber.isNotEmpty) {
                                  phonenumber = phonenumber.substring(
                                      0, phonenumber.length - 1);
                                }
                              });
                            },
                            onLongPress: () => setState(() {
                                  phonenumber = "";
                                }),
                            borderRadius: BorderRadius.circular(180),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: (MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.05) -
                                      MediaQuery.of(context).viewInsets.bottom *
                                          10,
                                  vertical: (MediaQuery.of(context).size.width *
                                          0.04) -
                                      MediaQuery.of(context).viewInsets.bottom *
                                          10),
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
                            if (countrySelected != null &&
                                phonenumber.length == 10 &&
                                !Verificationstarted) {
                              setState(() {
                                Verificationstarted = !Verificationstarted;
                              });
                              widget.startVerification(
                                  countrySelected!['dialCode'].toString() +
                                      phonenumber);
                            }
                          },
                          borderRadius: BorderRadius.circular(180),
                          child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: (MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.050) -
                                      MediaQuery.of(context).viewInsets.bottom *
                                          10,
                                  vertical: (MediaQuery.of(context).size.width *
                                          0.050) -
                                      MediaQuery.of(context).viewInsets.bottom *
                                          10),
                              decoration:
                                  const BoxDecoration(shape: BoxShape.circle),
                              child: !Verificationstarted
                                  ? Icon(
                                      Icons.check_circle,
                                      size: 40,
                                      color: phonenumber.length < 10
                                          ? Colors.blueGrey
                                          : Colors.orange,
                                    )
                                  : const SizedBox(
                                      height: 40,
                                      width: 40,
                                      child: CircularProgressIndicator(
                                        backgroundColor: Colors.orange,
                                        color: Colors.black,
                                        semanticsLabel: "Loading",
                                      ),
                                    )),
                        )
                      ],
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
