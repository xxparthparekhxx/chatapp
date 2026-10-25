import 'package:baata/Screens/home/logedin_page_root.dart';
import 'package:baata/Screens/AuthScreens/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Settings/manager.dart';

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  SharedPreferences? prefs;
  ThemeMode currentTheme = ThemeMode.system;
  void getSavedThemeMode() async {
    prefs = await SharedPreferences.getInstance();
    String? userTheme = prefs!.getString("CurrentTheme");

    if (userTheme == null) {
      currentTheme = ThemeMode.system;
    } else if (userTheme == "l") {
      currentTheme = ThemeMode.light;
    } else if (userTheme == 'd') {
      currentTheme = ThemeMode.dark;
    }
    setState(() {});
  }

  @override
  void initState() {
    getSavedThemeMode();
    super.initState();
  }

  void updateTheme(ThemeMode mode) async {
    setState(() {
      currentTheme = mode;
    });
    String theme = '';
    if (mode == ThemeMode.light) {
      theme = 'l';
    }
    if (mode == ThemeMode.dark) {
      theme = 'd';
    }

    await prefs!.setString("CurrentTheme", theme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.orange,
            primaryTextTheme: const TextTheme(
                displayLarge: TextStyle(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
                titleLarge: TextStyle(fontSize: 24, color: Colors.orange))),
        /* light theme settings */

        darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.orange,
            primaryTextTheme: const TextTheme(
                displayLarge: TextStyle(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
                titleLarge: TextStyle(fontSize: 24, color: Colors.orange)),
            /* dark theme settings */
            appBarTheme: const AppBarTheme(
                color: Colors.orange,
                titleTextStyle: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24))),
        themeMode: currentTheme,
        home: LoginFlow(themeSetter: updateTheme, ct: currentTheme));
  }
}

class LoginFlow extends StatefulWidget {
  final Function themeSetter;
  final ThemeMode ct;
  const LoginFlow({Key? key, required this.themeSetter, required this.ct})
      : super(key: key);

  @override
  LoginFlowState createState() => LoginFlowState();
}

class LoginFlowState extends State<LoginFlow> {
  FirebaseAuth auth = FirebaseAuth.instance;
  User? x;
  uManager? settings;

  @override
  Widget build(BuildContext context) {
    auth.authStateChanges().listen((User? user) {
      if (user != null && x == null) {
        setState(() {
          x = user;
          settings = uManager(person: user, auth: auth);
        });
      } else if (user == null && x != null) {
        setState(() {
          x = null;
        });
      }
    });
    return Scaffold(
        body: x != null
            ? loggedinPage(
                profile: x!,
                Settings: settings!,
                ThemeSetter: widget.themeSetter,
                ct: widget.ct,
                updatehome: () {},
              )
            : SignInPage(authinstance: auth));
  }
}
