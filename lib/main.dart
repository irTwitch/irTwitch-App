import 'dart:io';
import 'dart:developer';

import 'package:IRTwitch/stream_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock/wakelock.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:IRTwitch/home_page.dart';
import 'package:IRTwitch/settings_page.dart';
import 'package:IRTwitch/globals.dart' as globals;

final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();
const secureStorage = FlutterSecureStorage();

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> _handleIncomingMessage(RemoteMessage message) async {
  try {
    if (message.data.containsKey('title') && message.data.containsKey('body')) {
      final data = message.data;
      var title = data['title'];
      var body = data['body'];
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'IrTWStreamerLiveNotify',
        'StreamerLiveNotify',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      // Show the notification
      await _notificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
        payload: '',
      );
    }
  } catch (e) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Wakelock.enable();
  Wakelock.toggle(enable: true);
  final SharedPreferences prefs = await _prefs;
  globals.LoadServer = prefs.getInt('playfrom') ?? 1;
  globals.TwitchUsername = prefs.getString('TwitchUsername') ?? '';
  globals.TwitchUserID = prefs.getString('TwitchUserID') ?? '';
  globals.ssl_validate = prefs.getBool('ssl_validate') ?? false;

  if (globals.ssl_validate) {
    HttpOverrides.global = DevHttpOverrides();
  }

  globals.UserToken = await secureStorage.read(key: 'userToken');
  apiService.getUserFollows();

  await Firebase.initializeApp();
  globals.analytics = FirebaseAnalytics.instance;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Request permission for receiving notifications (optional)
  NotificationSettings settings = await _firebaseMessaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  // Handle incoming messages when the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _handleIncomingMessage(message);
  });

  // Handle incoming messages when the app is in the background
  FirebaseMessaging.onBackgroundMessage(_handleIncomingMessage);
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  globals.fcmToken = await messaging.getToken();
  apiService.updateFCMToken(globals.fcmToken);

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    globals.fcmToken = newToken;
    apiService.updateFCMToken(globals.fcmToken);
  });

  runApp(const IrtwApp());
}

class IrtwApp extends StatelessWidget {
  const IrtwApp({Key? key});

  @override
  Widget build(BuildContext context) {
    globals.analytics.setCurrentScreen(
      screenName: 'irTwitch App - Home',
      screenClassOverride: 'MainActivity',
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool isLoggedIn = false;
  @override
  void initState() {
    super.initState();
  }

  // ignore: non_constant_identifier_names
  Future<void> storeLoginData(
    String userToken,
    String twitchUsername,
    String twitchUserID,
  ) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString('TwitchUsername', twitchUsername);
    prefs.setString('TwitchUserID', twitchUserID);

    await secureStorage.write(key: 'userToken', value: userToken);

    await apiService.updateFCMToken(globals.fcmToken);
    await apiService.getUserFollows();
  }

  Future<void> authenticateWithTwitch() async {
    final redirectUri = '${globals.site_url}login_app.php';
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: redirectUri,
        callbackUrlScheme: 'irtwapp',
      );
      final userToken = Uri.parse(result).queryParameters['token'].toString();
      final twitchUsername =
          Uri.parse(result).queryParameters['twitch_username'].toString();
      final twitchUserID =
          Uri.parse(result).queryParameters['twitch_userid'].toString();
      setState(() {
        globals.TwitchUserID = twitchUserID;
        globals.TwitchUsername = twitchUsername;
        globals.UserToken = userToken;
      });

      storeLoginData(userToken, twitchUsername, twitchUserID);
    } catch (e) {
      // log('ERROR: $e');
    }
  }

  Future<void> logoutTwitch() async {
    final logoutStatus = await apiService.logout();
    if (logoutStatus) {
      setState(() {
        globals.TwitchUserID = '';
        globals.TwitchUsername = '';
        globals.UserToken = null;
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.remove('TwitchUsername');
      prefs.remove('TwitchUserID');
      await secureStorage.delete(key: 'userToken');
    }
  }

  @override
  Widget build(BuildContext context) {
    isLoggedIn = globals.UserToken != null;

    // ignore: non_constant_identifier_names
    ListTile LoginBTN = ListTile(
      leading: const Icon(
        Icons.login,
        color: Colors.white,
      ),
      title: const Text(
        "Login",
        style: TextStyle(color: Colors.white),
      ),
      onTap: () {
        authenticateWithTwitch();
      },
    );

    if (globals.UserToken != null) {
      isLoggedIn = true;
      LoginBTN = ListTile(
        leading: const Icon(
          Icons.logout,
          color: Colors.white,
        ),
        title: const Text(
          "Logout",
          style: TextStyle(color: Colors.white),
        ),
        onTap: () {
          logoutTwitch();
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f071c),
      appBar: AppBar(
        centerTitle: true,
        title: const Text("iRTwitch - Live Streams"),
        backgroundColor: const Color(0xFF35146e),
      ),
      body: const HomePage(),
      drawer: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF0c061a),
        ),
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF35146e),
                ),
                child: Text(
                  'iRTwitch [Beta]',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.language,
                  color: Colors.white,
                ),
                title: const Text(
                  "iRTwitch Website",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  final Uri url = Uri.parse(globals.site_url);
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              LoginBTN,
              ListTile(
                leading: const Icon(
                  Icons.message,
                  color: Colors.white,
                ),
                title: const Text(
                  "Telegram Channel",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  final Uri url = Uri.parse(globals.telegram_url);
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.discord,
                  color: Colors.white,
                ),
                title: const Text(
                  "Discord Server",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  final Uri url = Uri.parse(globals.discord_url);
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings,
                  color: Colors.white,
                ),
                title: const Text(
                  "Settings",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const SettingPage(),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
