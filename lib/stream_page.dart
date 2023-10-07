import 'package:flutter/material.dart';
import 'dart:async';
// import 'dart:developer';
import 'package:better_player/better_player.dart';
import 'package:wakelock/wakelock.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:IRTwitch/globals.dart' as globals;
import 'package:IRTwitch/components/api_service.dart';
import 'package:IRTwitch/components/emotes.dart';

final apiService = ApiService();
final emoteManager = EmoteManager();
Timer? _timer;

class ChatMessage {
  final String message;
  ChatMessage({required this.message});
}

class StreamPage extends StatefulWidget {
  // ignore: non_constant_identifier_names
  final Map<String, dynamic> DefaultData;
  final String site;
  // ignore: non_constant_identifier_names
  const StreamPage({super.key, required this.DefaultData, required this.site});

  @override
  // ignore: library_private_types_in_public_api
  _StreamPageState createState() {
    return _StreamPageState();
  }
}

Icon iconNotify = const Icon(Icons.notifications);

class _StreamPageState extends State<StreamPage> {
  late BetterPlayerController _betterPlayerController;
  late IO.Socket socket;
  final List<ChatMessage> _messages = [];

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);

      // Delete oldest messages if more than 40 messages
      if (_messages.length > 40) {
        _messages.removeRange(0, _messages.length - 40);
      }
    });

    // Scroll to the bottom of the chat list
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessage(ChatMessage message) {
    // log(message.message);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Html(
          data:
              "<style>img{width:15px;}.img_badge{margin-right: 5px}.message_content img{ width:25px; }</style>${message.message}",
          style: {
            "span.message_content":
                Style(color: Colors.white, fontFamily: 'IRFont'),
          }),
    );
  }

  final ScrollController _scrollController = ScrollController();

  // ignore: non_constant_identifier_names
  void ChatClient() async {
    try {
      final serverUrl = globals.site_url;
      const path = '/chat_service/server';
      final options = <String, dynamic>{
        'path': path,
        'reconnection': true,
        'transports': ['websocket'],
        'connectTimeout': 30000,
        'autoConnect': false, // Set autoConnect to false initially
        'reconnectionAttempts': 10, // Maximum number of reconnection attempts
        'reconnectionDelay': 5000, // Initial reconnection delay in milliseconds
        'reconnectionDelayMax':
            5000, // Maximum reconnection delay in milliseconds
        'randomizationFactor':
            0.5, // Randomization factor for the reconnection delay
      };
      socket = IO.io(serverUrl, options);
      // socket.onConnectError((data) => log('Connect Error: $data'));
      // socket.onConnectTimeout((data) => log('Connect Timeout: $data'));
      // socket.onError((data) => log('Error: $data'));
      // socket.onReconnect((_) => log('Reconnected'));
      // socket.onReconnectError((data) => log('Reconnect Error: $data'));
      // socket.onReconnectFailed((data) => log('Reconnect Failed: $data'));

      // ignore: non_constant_identifier_names
      String StreamerLower =
          widget.DefaultData['twitch_username'].toLowerCase();
      StreamerLower = StreamerLower.toLowerCase();
      String streamerToken = md5
          .convert(
              utf8.encode('${StreamerLower}_${globals.UserToken.toString()}'))
          .toString();

      socket.on('message', (data) {
        try {
          String parsedMessage = emoteManager.parseTwitchEmoji(data);
          // log(parsedMessage);
          final newMessage = ChatMessage(
            message: parsedMessage,
          );
          _addMessage(newMessage);
        } catch (error, stackTrace) {
          // Log the exception to Firebase Crashlytics
          FirebaseCrashlytics.instance.recordError(error, stackTrace);
        }
      });

      socket.onConnect((_) {
        // log('connect');
        socket.emit('login', {
          'username': globals.TwitchUsername,
          'token1': globals.UserToken.toString(),
          'token2': streamerToken,
          'streamer': widget.DefaultData['twitch_username'],
          'device': 'android'
        });
      });
      socket.connect();
    } catch (error, stackTrace) {
      // Log the exception to Firebase Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }

  void notifyButton() async {
    if (globals.UserToken != null) {
      await apiService
          .followStreamer(widget.DefaultData['twitch_userid'].toString());
      if (globals.userFollows.contains(widget.DefaultData['twitch_userid'])) {
        setState(() {
          iconNotify = const Icon(Icons.notifications_off);
        });
      } else {
        setState(() {
          iconNotify = const Icon(Icons.notifications);
        });
      }
    } else {
      Fluttertoast.showToast(
        msg: 'برای دریافت اعلان باید در اپلیکیشن لاگین کنید.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
    }
  }

  final TextEditingController _messageController = TextEditingController();
  void SendMessage() {
    if (globals.UserToken != null) {
      String message = _messageController.text;
      _messageController.clear();
      try {
        socket.emit('message', message);
      } catch (error, stackTrace) {
        // Log the exception to Firebase Crashlytics
        FirebaseCrashlytics.instance.recordError(error, stackTrace);
      }
    } else {
      Fluttertoast.showToast(
        msg: 'برای دسترسی به بخش چت باید در اپلیکیشن لاگین کنید.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
    }
  }

  // ignore: non_constant_identifier_names
  int TotalViewers = 0;
  // ignore: non_constant_identifier_names
  int TwitchViewers = 0;
  // ignore: non_constant_identifier_names
  int IrtwViewers = 0;
  // ignore: non_constant_identifier_names
  bool SocketConnected = false;
  @override
  void initState() {
    Wakelock.toggle(enable: true);
    if (globals.UserToken != null) {
      if (globals.userFollows.contains(widget.DefaultData['twitch_userid'])) {
        setState(() {
          iconNotify = const Icon(Icons.notifications_off);
        });
      } else {
        setState(() {
          iconNotify = const Icon(Icons.notifications);
        });
      }

      SocketConnected = true;
      ChatClient();
      emoteManager.loadEmotes(widget.DefaultData['twitch_userid'].toString());
    } else {
      SocketConnected = false;
      final newMessage = ChatMessage(
        message:
            "<span style='color: #fff; text-align: center;' class='message_content'>برای دسترسی به بخش چت باید در اپلیکیشن لاگین کنید</span>",
      );
      _messages.add(newMessage);
    }

    BetterPlayerControlsConfiguration controlsConfiguration =
        const BetterPlayerControlsConfiguration(
      backgroundColor: Colors.black,
      controlBarColor: Color.fromARGB(150, 42, 15, 89),
      enableAudioTracks: false,
      enablePlayPause: true,
      enableMute: true,
      enableFullscreen: true,
      enableOverflowMenu: true,
      enablePlaybackSpeed: false,
      enableProgressBar: false,
      enableProgressBarDrag: false,
      enableProgressText: false,
      enablePip: false,
      enableSubtitles: false,
      enableRetry: true,
      enableSkips: false,
      enableQualities: true,
    );

    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
            aspectRatio: 16 / 9,
            fit: BoxFit.contain,
            allowedScreenSleep: false,
            autoDispose: true,
            autoPlay: false,
            controlsConfiguration: controlsConfiguration);

    var videoURL =
        '${widget.site}live_streams/stream/${widget.DefaultData['twitch_username']}.m3u8';

    if (globals.LoadServer == 2) {
      videoURL =
          '${widget.site}live_streams/ostream/${widget.DefaultData['twitch_username']}.m3u8';
    }

    try {
      BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoURL,
        liveStream: true,
        cacheConfiguration:
            const BetterPlayerCacheConfiguration(useCache: false),
        videoFormat: BetterPlayerVideoFormat.hls,
      );
      _betterPlayerController =
          BetterPlayerController(betterPlayerConfiguration);
      _betterPlayerController.setupDataSource(dataSource);
      _betterPlayerController.play();
    } catch (e) {
      // Handle any errors that occur during the replay
      // print('Error occurred during video replay: $e');
      // You can display an error message or perform any necessary actions here
    }
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // TotalViewers = widget.DefaultData['twitch_viewers'] +
    setState(() {
      TotalViewers = TotalViewers = widget.DefaultData['twitch_viewers'] +
          widget.DefaultData['irtw_viewers'];
      // // ignore: non_constant_identifier_names
      TwitchViewers = widget.DefaultData['twitch_viewers'];
      // // ignore: non_constant_identifier_names
      IrtwViewers = widget.DefaultData['irtw_viewers'];
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (Timer timer) {
      fetchDataFromAPI();
    });
  }

  Future<void> fetchDataFromAPI() async {
    try {
      final responseData = await apiService
          .getStreamerViews(widget.DefaultData['twitch_username']);
      if (responseData != null) {
        setState(() {
          IrtwViewers = responseData['data']['irtwitch_viewers'];
          TwitchViewers = responseData['data']['twitch_viewers'];
          TotalViewers = responseData['data']['total_views'];
        });
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    globals.analytics.setCurrentScreen(
      screenName: "irTwitch App - ${widget.DefaultData['twitch_username']}",
      screenClassOverride: "StreamView",
    );

    // ignore: non_constant_identifier_names
    return Scaffold(
      backgroundColor: const Color(0xFF0f071c),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '${widget.DefaultData['twitch_username']}',
          style: TextStyle(fontSize: 18.0),
        ),
        backgroundColor: const Color(0xFF35146e),
        actions: [
          IconButton(
            onPressed: () {
              notifyButton();
            },
            icon: iconNotify,
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
          Stack(
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.all(1),
                title: Text(
                  widget.DefaultData['twitch_username'],
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Color(0xFFa057ff),
                    fontFamily: 'Eina',
                    fontSize: 18.0,
                  ),
                ),
                subtitle: Text(
                  widget.DefaultData['twitch_title'],
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'IRFont',
                    fontSize: 8.0,
                  ),
                ),
                leading: CircleAvatar(
                  backgroundImage:
                      NetworkImage(widget.DefaultData['twitch_avatar']),
                  radius: 30,
                  backgroundColor: Colors.black38,
                ),
              ),
              Positioned(
                top: 0.0,
                right: 0.0,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.only(bottomLeft: Radius.circular(5)),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [
                          0.7,
                          0.7,
                          0.7,
                          0.7,
                        ],
                        colors: [
                          Color.fromARGB(200, 0, 0, 0),
                          Color.fromARGB(200, 0, 0, 0),
                          Color.fromARGB(200, 0, 0, 0),
                          Color.fromARGB(200, 0, 0, 0),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2.0,
                        horizontal: 6.0,
                      ),
                      child: Center(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: Text(
                                "$TotalViewers = ",
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Eina',
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/twitch-logo.png',
                              height: 15,
                              width: 15,
                              fit: BoxFit.cover,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: Text(
                                "$TwitchViewers + ",
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Eina',
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/irtw-logo.png',
                              height: 15,
                              width: 15,
                              fit: BoxFit.cover,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: Text(
                                IrtwViewers.toString(),
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Eina',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.43,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessage(_messages[index]);
                      },
                      controller: _scrollController,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            color: Colors.grey[800],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      hintStyle: TextStyle(color: Colors.white70),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal:
                              12), // Adjust the padding values as needed
                    ),
                    onSubmitted: (text) {
                      SendMessage();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    SendMessage();
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.deepPurple,
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (SocketConnected) {
      socket.disconnect();
    }
    _betterPlayerController.dispose();
    _scrollController.dispose();
    // globals.analytics.setCurrentScreen(
    //   screenName: "irTwitch App - Home",
    //   screenClassOverride: "MainActivity",
    // );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _timer?.cancel();
    super.dispose();
  }
}
