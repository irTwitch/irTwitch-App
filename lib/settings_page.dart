import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:IRTwitch/globals.dart' as globals;
// import 'dart:developer';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

enum SingingCharacter { fromIrTwitch, fromTwitch }

class _SettingPageState extends State<SettingPage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  int? _radioSelected = 1;
  bool _disableSSLValidation = false;

  @override
  void initState() {
    _prefs.then((SharedPreferences prefs) {
      setState(() {
        _radioSelected = prefs.getInt('playfrom') ?? 1;
        _disableSSLValidation = prefs.getBool('ssl_validate') ?? false;
      });
      return prefs.getInt('playfrom') ?? 1;
    });
    super.initState();
  }

  Future<void> setSettingPlayerServer(value) async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      prefs.setInt('playfrom', value);
    });
  }

  Future<void> setSSLCertificate(value) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setBool('ssl_validate', value);

    Fluttertoast.showToast(
      msg: 'برای اعمال این تغییر یکبار برنامه را ببندید و مجدد اجرا کنید.',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    globals.analytics.setCurrentScreen(
      screenName: "irTwitch App - Settings",
      screenClassOverride: "SettingsActivity",
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0f071c),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('iRTwitch Settings'),
        backgroundColor: const Color(0xFF35146e),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            const ListTile(
              title: Text(
                'Videos Servers:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
            ),
            ListTile(
              title: const Text(
                'iRTwitch Server',
                style: TextStyle(color: Colors.white),
              ),
              leading: Radio(
                value: 1,
                groupValue: _radioSelected,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _radioSelected = 1;
                    globals.LoadServer = 1;
                  });
                  setSettingPlayerServer(1);
                },
              ),
              onTap: () {
                setState(() {
                  _radioSelected = 1;
                  globals.LoadServer = 1;
                });
                setSettingPlayerServer(1);
              },
            ),
            ListTile(
              title: const Text(
                'Twitch Server',
                style: TextStyle(color: Colors.white),
              ),
              leading: Radio(
                value: 2,
                groupValue: _radioSelected,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _radioSelected = 2;
                    globals.LoadServer = 2;
                  });
                  setSettingPlayerServer(2);
                },
              ),
              onTap: () {
                setState(() {
                  _radioSelected = 2;
                  globals.LoadServer = 2;
                });
                setSettingPlayerServer(2);
              },
            ),
            ListTile(
              title: const Text(
                'Disable SSL Validation',
                style: TextStyle(color: Colors.white),
              ),
              trailing: Switch(
                value: _disableSSLValidation,
                onChanged: (value) {
                  setState(() {
                    globals.ssl_validate = value;
                    _disableSSLValidation = value;
                  });
                  setSSLCertificate(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
