library my_app.globals;

import 'package:firebase_analytics/firebase_analytics.dart';

// ignore: non_constant_identifier_names
int LoadServer = 1;
// ignore: non_constant_identifier_names
String AppVersionAPI = '2.0.0';

String appClientID = "BLABLA";
// ignore: non_constant_identifier_names
String site_url = "https://DOMAIN.COM/";
// ignore: non_constant_identifier_names
String discord_url = "https://discord.gg/vYGQQaqG5X";
// ignore: non_constant_identifier_names
String telegram_url = "https://t.me/irtwitch";

// ignore: non_constant_identifier_names
String? UserToken = null;
// ignore: non_constant_identifier_names
String TwitchUsername = "";
// ignore: non_constant_identifier_names
String TwitchUserID = "";

String? fcmToken;

List<dynamic> userFollows = [];

// ignore: non_constant_identifier_names
bool ssl_validate = false;

late FirebaseAnalytics analytics;
