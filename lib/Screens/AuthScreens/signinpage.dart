import 'package:baata/Screens/AuthScreens/enter_otp.dart';
import 'package:baata/Screens/AuthScreens/phone_number_screen.dart';
import 'package:baata/Screens/AuthScreens/welcome.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class SignInPage extends StatefulWidget {
  FirebaseAuth authinstance;
  SignInPage({Key? key, required this.authinstance}) : super(key: key);
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String? otp;
  String? err;

  late String VerificationId;
  PageController ScreenMaster = PageController(initialPage: 0);

  void otpSetter(str) {
    setState(() {
      otp = str;
    });
  }

  void verify() {
    verifyotp(VerificationId);
  }

  void verifyotp(String verificationId) {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: otp!);
    // Sign the user in (or link) with the credential
    widget.authinstance.signInWithCredential(credential);
  }

  void startmobileverification(PhoneNumber) {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: PhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          err = e.code;
          ScreenMaster.animateToPage(1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn);
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        // TODO: replace with proper logging
        ScreenMaster.animateToPage(
          2,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeIn,
        ); // changes page to enter otp
        setState(() {
          VerificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // TODO: replace with proper logging
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      children: [
        WelcomeScreen(ScreenMaster: ScreenMaster),
        enterPhoneNumberScreene(
          Error: err,
          startVerification: startmobileverification,
        ),
        EnterOtp(
          setter: otpSetter,
          verifyfunc: verify,
        ),
      ],
      controller: ScreenMaster,
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}
