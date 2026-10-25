import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactCollector extends StatefulWidget {
  final Function Updater;
  const ContactCollector({Key? key, required this.Updater}) : super(key: key);

  @override
  _ContactCollectorState createState() => _ContactCollectorState();
}

class _ContactCollectorState extends State<ContactCollector> {
  void getcontacts() async {
    final PermissionStatus permissionStatus =
        await FlutterContacts.permissions.request(PermissionType.readWrite);
    if (permissionStatus == PermissionStatus.granted) {
      widget.Updater();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Allow Contacts To Find Your Friends"),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(50),
              child: ElevatedButton(
                  onPressed: () {
                    getcontacts();
                  },
                  child: const Text("Give Contacts")),
            ),
          ],
        )
      ],
    );
  }
}
