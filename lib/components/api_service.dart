import 'dart:convert';
// import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:IRTwitch/globals.dart' as globals;

const secureStorage = FlutterSecureStorage();

class ApiService {
  Future<Map<String, dynamic>?> getAllStreams() async {
    try {
      final response = await http.get(Uri.parse(
          '${globals.site_url}free_api.php?all=true&app_version=${globals.AppVersionAPI}'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        return null;
      }
    } catch (error) {
      return null;
    }
  }

  Future<dynamic> getStreamerViews(username) async {
    try {
      final response = await http.get(
          Uri.parse('${globals.site_url}/free_api.php?streamer=$username'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData;
      }
    } catch (e) {}

    return null;
  }

  Future<List<dynamic>> followStreamer(String? streamerID) async {
    if (streamerID == null ||
        globals.UserToken == null ||
        globals.TwitchUserID == '') {
      return globals.userFollows;
    }
    try {
      final url = '${globals.site_url}/app_api/follow-streamer';

      // Create the request body
      Map<String, String> body = {
        'streamer_id': streamerID,
      };

      // Encode the body as JSON
      String encodedBody = json.encode(body);

      // Send the HTTP POST request
      http.Response response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${globals.UserToken}',
          'UserID': globals.TwitchUserID,
          'AppVersion': globals.AppVersionAPI.toString(),
          'ClientId': globals.appClientID,
        },
        body: encodedBody,
      );

      final responseBody = await json.decode(response.body);
      if (responseBody.containsKey('code')) {
        final code = responseBody['code'];
        if (code == 1005) {
          setLogoutData();
          return globals.userFollows;
        } else if (code == 1006) {
          Fluttertoast.showToast(
            msg: 'امکان فعال کردن اعلان برای این استریمر وجود ندارد.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey[800],
            textColor: Colors.white,
          );
          return globals.userFollows;
        } else if (code == 2000) {
          // follow
          globals.userFollows = List<dynamic>.from(responseBody['follows']);
          Fluttertoast.showToast(
            msg: 'دریافت اعلان برای این استریمر فعال شد.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey[800],
            textColor: Colors.white,
          );
          return globals.userFollows;
        } else if (code == 2001) {
          // unfollow
          Fluttertoast.showToast(
            msg: 'دریافت اعلان برای این استریمر غیرفعال شد.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey[800],
            textColor: Colors.white,
          );
          globals.userFollows = List<dynamic>.from(responseBody['follows']);
          return globals.userFollows;
        }
      }
    } catch (e) {}
    return globals.userFollows;
  }

  Future<void> getUserFollows() async {
    if (globals.UserToken == null || globals.TwitchUserID == '') {
      return;
    }

    final url = '${globals.site_url}/app_api/user-follows';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer ${globals.UserToken}',
        'UserID': globals.TwitchUserID,
        'AppVersion': globals.AppVersionAPI.toString(),
        'ClientId': globals.appClientID,
      });

      var responseBody = jsonDecode(response.body);
      if (responseBody.containsKey('code')) {
        final code = responseBody['code'];
        if (code == 1005) {
          setLogoutData();
          return;
        } else if (code == 2000 && responseBody.containsKey('follows')) {
          globals.userFollows = List<dynamic>.from(responseBody['follows']);
          return;
        }
      }
    } catch (e) {}
  }

  Future<bool> updateFCMToken(String? fcmToken) async {
    if (fcmToken == null ||
        globals.UserToken == null ||
        globals.TwitchUserID == '') {
      return false;
    }

    try {
      final url = '${globals.site_url}/app_api/update-fcm-token';

      // Create the request body
      Map<String, String> body = {
        'fcm_token': fcmToken,
      };

      // Encode the body as JSON
      String encodedBody = json.encode(body);

      // Send the HTTP POST request
      http.Response response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${globals.UserToken}',
          'UserID': globals.TwitchUserID,
          'AppVersion': globals.AppVersionAPI.toString(),
          'ClientId': globals.appClientID,
        },
        body: encodedBody,
      );

      final responseBody = await json.decode(response.body);
      if (responseBody.containsKey('code')) {
        final code = responseBody['code'];
        if (code == 1005) {
          setLogoutData();
          return false;
        } else if (code == 2000) {
          return true;
        }
      }
    } catch (e) {}
    return false;
  }

  Future<void> setLogoutData() async {
    globals.TwitchUserID = '';
    globals.TwitchUsername = '';
    globals.UserToken = null;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('TwitchUsername');
    prefs.remove('TwitchUserID');
    await secureStorage.delete(key: 'userToken');
  }

  Future<bool> logout() async {
    if (globals.UserToken == null || globals.TwitchUserID == '') {
      return true;
    }

    final url = '${globals.site_url}/app_api/logout';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${globals.UserToken}',
          'UserID': globals.TwitchUserID,
          'AppVersion': globals.AppVersionAPI.toString(),
          'ClientId': globals.appClientID,
        },
      );

      final responseBody = await json.decode(response.body);

      if (responseBody.containsKey('code')) {
        final code = responseBody['code'];
        if (code == 1005 || code == 2000) {
          Fluttertoast.showToast(
            msg: 'شما با موفقیت از حساب کاربری خود خارج شدید',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey[800],
            textColor: Colors.white,
          );
          return true;
        } else {
          Fluttertoast.showToast(
            msg: 'مشکلی بوجود آمده است، مجدد تلاش کنید',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey[800],
            textColor: Colors.white,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: 'مشکلی بوجود آمده است، مجدد تلاش کنید',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'مشکلی بوجود آمده است، مجدد تلاش کنید',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
    }
    return false;
  }
}
