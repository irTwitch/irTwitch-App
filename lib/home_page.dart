import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:IRTwitch/stream_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:IRTwitch/globals.dart' as globals;
import 'package:IRTwitch/components/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'dart:developer';

const secureStorage = FlutterSecureStorage();

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ignore: non_constant_identifier_names
  List<String> Streamers = [];
  // ignore: non_constant_identifier_names
  List<dynamic> StreamersData = [];

  final apiService = ApiService();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  @override
  void initState() {
    _prefs.then((SharedPreferences prefs) {
      setState(() {
        globals.LoadServer = prefs.getInt('playfrom') ?? 1;
        globals.ssl_validate = prefs.getBool('ssl_validate') ?? false;
        globals.TwitchUsername = prefs.getString('TwitchUsername') ?? "";
        globals.TwitchUserID = prefs.getString('TwitchUserID') ?? "";
      });
      return prefs.getInt('playfrom') ?? 1;
    });

    secureStorage.read(key: 'userToken').then((value) {
      setState(() {
        globals.UserToken = value;
      });
    }).catchError((error) {});

    super.initState();

    Timer.periodic(const Duration(seconds: 60), (Timer timer) {
      refreshList(false);
    });

    refreshListFast();
  }

  Future refreshListFast() async {
    refreshList(true);
  }

  void openURLAfterDelay() {
    Future.delayed(const Duration(seconds: 10), () {
      final Uri url = Uri.parse(globals.telegram_url);
      launchUrl(url, mode: LaunchMode.externalApplication);
    });
  }

  Future refreshList(bool clearFirst) async {
    try {
      if (clearFirst) {
        setState(() {
          StreamersData.clear();
          Streamers.clear();
        });
      }

      Map<String, dynamic>? map = await apiService.getAllStreams();
      if (!clearFirst) {
        setState(() {
          StreamersData.clear();
          Streamers.clear();
        });
      }

      if (map == null) {
        Fluttertoast.showToast(
          msg: 'مشکلی در ارتباط با سرور بوجود آمده است.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
      } else if (map!.containsKey('streamers')) {
        List<dynamic> streamers = map["streamers"];
        StreamersData.clear();
        Streamers.clear();
        StreamersData = streamers;
        globals.site_url = map['site'];
        setState(() {
          StreamersData = streamers;
          Streamers = streamers.map<String>((item) {
            return item['twitch_username'];
          }).toList();
        });
      } else if (clearFirst &&
          map!.containsKey('error_code') &&
          map["error_code"] == 99) {
        Fluttertoast.showToast(
          msg:
              'نسخه جدید نرم افزار منتشر شده است، لطفا نسبت به نصب نسخه جدید اقدام کنید',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
        openURLAfterDelay();
      } else if (clearFirst) {
        Fluttertoast.showToast(
          msg: 'مشکلی در دریافت اطلاعات وجود آمده است',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      // print("Getting Data Error!");
    }
  }

  @override
  Widget build(BuildContext context) {
    globals.analytics.setCurrentScreen(
      screenName: "irTwitch App - Home",
      screenClassOverride: "MainActivity",
    );

    return RefreshIndicator(
      onRefresh: refreshListFast,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: Streamers.length,
        itemBuilder: (context, index) {
          final streamTitle = StreamersData[index]['twitch_title'];
          final videoThumbnail = StreamersData[index]
                  ['twitch_video_thumbnail'] +
              "#" +
              DateTime.now().minute.toString();

          // ignore: non_constant_identifier_names
          final StreamerName = StreamersData[index]['twitch_username'];
          // ignore: non_constant_identifier_names
          final StreamerAvatar = StreamersData[index]['twitch_avatar'];
          // ignore: non_constant_identifier_names
          final TotalViewers = StreamersData[index]['twitch_viewers'] +
              StreamersData[index]['irtw_viewers'];
          // final TwitchViewers = StreamersData[index]['twitch_viewers'];
          // final IrtwViewers = StreamersData[index]['irtw_viewers'];
          final gameTitle = StreamersData[index]['game_title'];
          final totalViews = TotalViewers < 1000
              ? TotalViewers.toString()
              : '${(TotalViewers / 1000).toStringAsFixed(1)}K';
          final defaultData = StreamersData[index];
          return GestureDetector(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0, top: 15.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => StreamPage(
                      DefaultData: defaultData,
                      site: globals.site_url,
                    ),
                  ));
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 120.0,
                      height: 70.0,
                      child: Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(3.0)),
                            child: FadeInImage.memoryNetwork(
                              placeholder: kTransparentImage,
                              image: videoThumbnail,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 3.0,
                            left: 3.0,
                            child: Row(
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Container(
                                    color: Colors.red,
                                    width: 10.0,
                                    height: 10.0,
                                  ),
                                ),
                                const SizedBox(width: 5.0),
                                Text(
                                  totalViews,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13.0,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  height: 20.0,
                                  width: 20.0,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(15),
                                    ),
                                    child: FadeInImage.memoryNetwork(
                                      placeholder: kTransparentImage,
                                      image: StreamerAvatar,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 5.0,
                                ),
                                Text(
                                  StreamerName,
                                  style: const TextStyle(
                                    fontFamily: 'Eina',
                                    fontSize: 16.0,
                                    color: Colors.purple,
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 5.0),
                            Text(
                              streamTitle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9.0,
                                color: Colors.white,
                                fontFamily: 'IRFont',
                              ),
                            ),
                            Text(
                              gameTitle,
                              style: TextStyle(
                                fontSize: 13.0,
                                color: Colors.grey[700],
                                fontFamily: 'Shapiro',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
