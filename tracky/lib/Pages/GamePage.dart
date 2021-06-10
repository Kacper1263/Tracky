/*

MIT License

Copyright (c) 2021 Kacper Marcinkiewicz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_screen_wake/flutter_screen_wake.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:background_location/background_location.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import "package:latlong2/latlong.dart";
import 'package:permission_handler/permission_handler.dart';
import 'package:tracky/Dialogs.dart';
import 'package:tracky/GlobalFunctions.dart';
import 'package:tracky/StaticVariables.dart';
import 'package:web_socket_channel/io.dart';

import '../Classes.dart';

class GamePage extends StatefulWidget {
  GamePage({Key key, this.title, this.arguments}) : super(key: key);

  final String title;
  final Object arguments;

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  Map data;

  List<TextMarker> textMarkers = [];
  List<NamedPolygon> polygons = [];

  bool connectionLost = false;

  var thisPlayer = new Player(
    name: "You",
    color: Colors.lightBlue[600],
    icon: "thisPlayer",
    location: LatLng(0, 0),
  );

  var otherPlayers = <Player>[];

  StreamSubscription keyboardVisibilityListener;
  MapController mapController;
  Timer updateTimer;

  // Player settings
  bool hidePlayerOnMap = false;

  //Location/rotation variables
  Location _locationData = null;
  int lastUpdate = 0;
  bool permissionDenied = false;
  bool firstTimeZoomedBefore = false; // change this to true after first time finding GPS location
  Timer compassTimer;
  bool lockMapToPlayer = false;

  // Chat
  bool showChat = false;
  bool chatConnected = false;
  bool chatConnecting = false; // While connecting but not connected
  bool showNewMsgDot = false;
  bool isGlobalChat = false;
  bool hideTopMenu = false;
  FocusNode chatFocusNode = new FocusNode();
  IOWebSocketChannel chatChannel;
  List<ChatMessage> chatMessages = [];
  TextEditingController chatController = TextEditingController();

  /// Run it only on start
  Future<bool> getLocation() async {
    var permissionStatus = await Permission.locationAlways.status;
    print(permissionStatus);
    if (permissionStatus.toString() == "PermissionStatus.undetermined" || permissionStatus.toString() == "PermissionStatus.denied") {
      await Dialogs.infoDialog(
        context,
        titleText: "Permissions, please read carefully!",
        descriptionText:
            'Now you should see a window asking for location permissions. These permissions are needed to run the application. If your Android version is below 11, it is possible that you will be able to choose between "Allow only while using the app" and "Allow all the time", We RECOMMEND to choose "Allow all the time" because it will allow your location to be updated also when you lock the phone, go to the home screen or change the application to another. We will download your location ONLY if you are in a room on the server and the app is running in the background. If you have Android 11 you will need to manually set location permissions to allow background location in Android settings for this app. When you close the app or leave the room, we will not use your location. If you want, you can choose to share your location only while using the app, but it can make your location update only when the screen is unlocked. While the application will be using your location, you will be informed about it by a notification on the bar. \n\nThis setting can be changed later in the Android settings',
        okBtnText: "Ok",
        onOkBtn: () async {
          Navigator.pop(context);
          var permission = await Permission.locationAlways.request();
          if (permission.isGranted) {
            permissionDenied = false;
            startGame();
          } else {
            if (await Permission.location.isGranted) {
              permissionDenied = false;
            } else {
              permissionDenied = true;
              showErrorToast(
                "Without permission enabled your location will not be updated!",
              );
            }

            startGame();
          }
        },
      );
    } else if (permissionStatus.toString() == "PermissionStatus.denied") {
      permissionDenied = true;
      showErrorToast(
        "Without permission enabled your location will not be updated!",
      );
      startGame();
    } else if (permissionStatus.toString() == "PermissionStatus.granted") {
      if (await Permission.locationAlways.isDenied) {
        await Permission.locationAlways.request();
      }
      startGame();
    }

    return true;
  }

  // Call when permissions are granted
  void startGame() async {
    // Check is GPS enabled
    loc.Location _location = loc.Location();
    bool gpsEnabled = await _location.serviceEnabled();
    if (!gpsEnabled) {
      gpsEnabled = await _location.requestService();
      if (!gpsEnabled) {
        showErrorToast(
          "Without GPS enabled your location will not be updated and you will be connected to server only every 20s!",
        );
      }
    }

    updateAndFetchDataFromServer(); // Fetch data once for loading polygons before location update

    BackgroundLocation.setAndroidNotification(
        title: "Tracky - ASG team tracker", message: "I am updating Your location. Tap me to resume the app");
    BackgroundLocation.startLocationService();
    BackgroundLocation.getLocationUpdates((location) {
      _locationData = location;

      if ((DateTime.now().millisecondsSinceEpoch - lastUpdate) < 1000 * 5) {
        print("Not yet");
        return;
      }

      lastUpdate = DateTime.now().millisecondsSinceEpoch;

      updatePlayerLocation();

      if (!firstTimeZoomedBefore && _locationData.latitude != 0) {
        findMe();
        firstTimeZoomedBefore = true;
      }

      updateAndFetchDataFromServer();

      try {
        print(
          "API call. Location: ${_locationData.latitude}, ${_locationData.longitude}",
        );
      } catch (e) {
        print(e);
      }
    });

    // Keep alive system - This will fetch data from server and update lastSeen even if location was not changed in last 20s
    updateTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      if ((DateTime.now().millisecondsSinceEpoch - lastUpdate) < 1000 * 15) {
        // 15 because Timer.periodic is kinda random
        print("Keep alive not needed");
        return;
      }

      lastUpdate = DateTime.now().millisecondsSinceEpoch;
      print("Keep alive was sent");

      updateAndFetchDataFromServer();
    });
  }

  @override
  void initState() {
    FlutterScreenWake.keepOn(true);
    data = widget.arguments;

    thisPlayer.color = HexColor(data["teamColor"]);

    mapController = MapController();

    getLocation();

    chatFocusNode.addListener(chatTextFieldFocusChanged);

    if (StaticVariables.autoChatConnect) connectToChat();

    // Update device rotation
    CompassEvent rotation;
    compassTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      rotation = await FlutterCompass.events.first;
      setState(() {
        thisPlayer?.iconRotation = rotation.heading;
      });
    });

    // Check is keyboard visible (for chat text field unfocus)
    try {
      var keyboardVisibilityController = KeyboardVisibilityController();
      keyboardVisibilityListener = keyboardVisibilityController.onChange.listen((bool visible) {
        try {
          if (!visible) chatFocusNode.unfocus();
        } catch (er) {
          print("Error while checking keyboard visibility! " + er);
        }
      });
    } catch (e) {
      print("Error while subscribing to keyboard visibility listener! " + e);
    }

    super.initState();
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    BackgroundLocation.stopLocationService();
    FlutterScreenWake.keepOn(false);
    chatFocusNode.dispose();
    compassTimer?.cancel();
    keyboardVisibilityListener?.cancel();
    super.dispose();
  }

  void updateAndFetchDataFromServer() {
    String url;
    if (data["serverInLan"])
      url = "${StaticVariables.lanServerIp}:5050/api/v1/room/${data["roomId"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/${data["roomId"]}";
    post(
      Uri.parse(url),
      body: {
        "teamId": data["teamId"],
        "playerName": data["nickname"],
        "latitude": _locationData != null ? _locationData.latitude.toString() : "0",
        "longitude": _locationData != null ? _locationData.longitude.toString() : "0",
        "hideMe": hidePlayerOnMap.toString(),
      },
    ).timeout(Duration(seconds: 20)).then((res) {
      if (connectionLost) {
        connectionLost = false;
        showSuccessToast(
          "Reconnected",
        );
      }

      if (res.statusCode != 200) {
        try {
          var response = jsonDecode(res.body);
          showErrorToast(
            "Error while updating position. ${response["message"]}",
          );
        } catch (e) {
          showErrorToast(
            "Error while updating position. Server returned code ${res.statusCode}",
          );
        }

        return;
      }

      var response = jsonDecode(res.body);
      List<dynamic> teams = response["teams"];
      List<Player> playersToAdd = [];

      if (teams == null) return;

      polygons.clear();
      textMarkers.clear();

      // Load polygons
      response["namedPolygons"].forEach((polygon) {
        polygons.add(NamedPolygon(
          name: polygon["name"],
          color: HexColor(polygon["color"]),
          polygon: Polygon(
            color: HexColor(polygon["polygon"]["color"]),
            points: polygon["polygon"]["points"].map<LatLng>((point) => LatLng(point["latitude"], point["longitude"])).toList(),
          ),
        ));
      });

      // Load text markers
      response["textMarkers"].forEach((marker) {
        TextMarker _markerToAdd = TextMarker(
            text: marker["text"],
            location:
                LatLng(double.parse(marker["location"]["latitude"].toString()), double.parse(marker["location"]["longitude"].toString())));
        _markerToAdd.onClick = () {};
        textMarkers.add(_markerToAdd);
      });

      // Load players
      teams.forEach((team) {
        List<dynamic> players = team["players"];
        players.forEach((player) {
          /*
 player["name"] != data["nickname"]||(player["name"] == data["nickname"] &&
                  team["id"] != data["teamId"])) if ((team["id"] != data["teamId"] && showEnemyTeam) || team["id"] == data["teamId"]
          */
          if (player["name"] != data["nickname"]) {
            playersToAdd.add(
              new Player(
                name: player["name"],
                color: HexColor(team["color"]),
                icon: team["id"] != data["teamId"] // Check is in my team
                    ? "enemy"
                    : "normal",
                location: LatLng(
                  double.parse(player["latitude"]),
                  double.parse(player["longitude"]),
                ),
              ),
            );
          }
        });
      });
      otherPlayers = playersToAdd.sublist(0);
      setState(() {}); // Update locations on screen
    }).catchError((e) {
      if (e.toString().contains("TimeoutException")) {
        connectionLost = true;
        showErrorToast(
          "Connection to server lost. Trying to reconnect",
        );
      } else if (e.toString().contains("Network is unreachable")) {
        showErrorToast(
          "No internet connection!",
        );
      } else {
        showErrorToast(
          "Error: $e",
        );
      }
    });
  }

  void updatePlayerLocation() {
    if (mounted) {
      setState(() {
        try {
          thisPlayer.getMarker().point.latitude = _locationData.latitude;
          thisPlayer.getMarker().point.longitude = _locationData.longitude;

          if (lockMapToPlayer) {
            mapController.move(LatLng(_locationData.latitude, _locationData.longitude), mapController.zoom);
          }
        } catch (e) {
          print(e);
        }
      });
    }
  }

  void findMe() {
    setState(() {
      lockMapToPlayer = !lockMapToPlayer;
    });

    try {
      mapController.move(
        LatLng(_locationData != null ? _locationData.latitude : 0, _locationData != null ? _locationData.longitude : 0),
        mapController.zoom,
      );
    } catch (e) {
      print(e);
    }
  }

  void leaveGame() async {
    String url;
    if (data["serverInLan"])
      url = "${StaticVariables.lanServerIp}:5050/api/v1/room/leave/${data["roomId"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/leave/${data["roomId"]}";

    try {
      var response = await post(Uri.parse(url), body: {
        "playerName": data["nickname"],
        "teamId": data["teamId"],
      });

      var r = jsonDecode(response.body);

      if (response.statusCode != 200) {
        showErrorToast(
          "Error while leaving room: ${r["message"]}",
        );
        return;
      }

      return;
    } catch (e) {
      showErrorToast(
        "Error while leaving room: $e",
      );
      return;
    }
  }

  showPlayerSettings(mainSetState) {
    Dialogs.infoDialogWithWidgetBody(
      context,
      titleText: "Player settings",
      okBtnText: "Close",
      onOkBtn: () {
        Navigator.pop(context);
      },
      descriptionWidgets: [
        StatefulBuilder(
          builder: (context, setState) => Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 10,
            children: [
              Row(
                children: [
                  Switch(
                    value: hidePlayerOnMap,
                    onChanged: (value) {
                      setState(() {
                        hidePlayerOnMap = value;
                      });
                      mainSetState(() {
                        hidePlayerOnMap = value;
                      });
                    },
                  ),
                  Expanded(child: Text("Hide me on map for everyone", style: TextStyle(color: Colors.white))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  chatTextFieldFocusChanged() {
    if (chatFocusNode.hasFocus) {
      setState(() {
        hideTopMenu = true;
      });
    } else {
      setState(() {
        hideTopMenu = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    data = widget.arguments;
    List<Marker> markers = [];
    otherPlayers.forEach((p) => markers.add(p.getMarker()));
    thisPlayer.isHidden = hidePlayerOnMap;
    markers.add(thisPlayer.getMarker());

    try {
      return WillPopScope(
        onWillPop: () {
          if (showChat) {
            setState(() {
              showChat = false;
              hideTopMenu = false;
            });
            FocusScope.of(context).unfocus();
            return Future.value(false);
          }
          updateTimer?.cancel();
          leaveGame();
          chatChannel?.sink?.close();
          BackgroundLocation.stopLocationService();
          return Future.value(true);
        },
        child: Scaffold(
          appBar: !showChat
              ? AppBar(
                  title: Text(widget.title),
                  centerTitle: true,
                  backgroundColor: Colors.grey[700],
                )
              : null,
          body: IndexedStack(
            index: !showChat ? 0 : 1, // Indexed stack for not loosing map data
            children: [
              FlutterMap(
                mapController: mapController,
                layers: [
                  TileLayerOptions(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                    //tileProvider: NonCachingNetworkTileProvider(),
                    maxZoom: 24.0,
                  ),
                  PolygonLayerOptions(polygonCulling: true, polygons: polygons.map((element) => element.polygon).toList()),
                  MarkerLayerOptions(markers: textMarkers.map((tMarker) => tMarker.getMarker()).toList()),
                  MarkerLayerOptions(markers: markers)
                ],
                key: GlobalObjectKey("map-key"),
                options: MapOptions(
                  interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  center: LatLng(0, 0),
                  zoom: 15.0,
                  maxZoom: 19.3,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture == true && lockMapToPlayer == true) {
                      setState(() {
                        lockMapToPlayer = false;
                      });
                    }
                  },
                ),
              ),
              Container(
                color: Colors.grey[900],
                child: SafeArea(
                  child: Column(
                    children: [
                      Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          Container(),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              height: hideTopMenu ? 50 : null,
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: new BorderRadius.only(
                                  bottomLeft: Radius.circular(hideTopMenu ? 0 : 20.0),
                                  bottomRight: Radius.circular(hideTopMenu ? 0 : 20.0),
                                ),
                              ),
                              width: double.maxFinite,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 50, 8, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    hideTopMenu
                                        ? SizedBox.shrink()
                                        : Row(
                                            children: [
                                              Expanded(
                                                child: RaisedButton(
                                                  padding: EdgeInsets.all(12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.only(
                                                      topLeft: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: Text("Team chat", style: TextStyle(fontSize: 17)),
                                                  color: Colors.blueGrey,
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700],
                                                  onPressed: isGlobalChat
                                                      ? () {
                                                          setState(() {
                                                            isGlobalChat = false;
                                                          });
                                                        }
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: RaisedButton(
                                                  padding: EdgeInsets.all(12),
                                                  child: Text("Global chat", style: TextStyle(fontSize: 17)),
                                                  color: Colors.blueGrey,
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700],
                                                  onPressed: !isGlobalChat
                                                      ? () {
                                                          setState(() {
                                                            isGlobalChat = true;
                                                          });
                                                        }
                                                      : null,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.only(
                                                      topRight: Radius.circular(20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    hideTopMenu
                                        ? SizedBox.shrink()
                                        : Row(
                                            children: [
                                              Expanded(
                                                child: RaisedButton(
                                                  padding: EdgeInsets.all(12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.only(
                                                      bottomLeft: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: Text("Connect", style: TextStyle(fontSize: 17)),
                                                  color: Colors.green,
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700],
                                                  onPressed: chatConnected || chatConnecting ? null : connectToChat,
                                                ),
                                              ),
                                              hideTopMenu ? SizedBox.shrink() : SizedBox(width: 10),
                                              Expanded(
                                                child: RaisedButton(
                                                  padding: EdgeInsets.all(12),
                                                  child: Text("Disconnect", style: TextStyle(fontSize: 17)),
                                                  color: Colors.red,
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700],
                                                  onPressed: !chatConnected
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            chatConnected = false;
                                                            chatChannel?.sink?.close();
                                                          });
                                                        },
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.only(
                                                      bottomRight: Radius.circular(20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            child: const Text(
                              "Chat",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 25),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            top: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.grey[600],
                              radius: 15,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                ),
                                color: Colors.white,
                                onPressed: () {
                                  setState(() {
                                    showChat = false;
                                    hideTopMenu = false;
                                    FocusScope.of(context).unfocus();
                                  });
                                  //SchedulerBinding.instance.addPostFrameCallback((_) => findMe());
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.grey[600],
                              radius: 15,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: "Clear",
                                icon: Icon(
                                  Icons.delete_sweep,
                                  size: 20,
                                ),
                                color: Colors.white,
                                onPressed: () {
                                  setState(() {
                                    chatMessages = [];
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                          },
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: chatMessages.length,
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            reverse: true,
                            itemBuilder: (context, index) {
                              return Container(
                                padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      chatMessages[index].type == ChatMessageType.SENT ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  children: [
                                    MessageCard(
                                      message: chatMessages[index].message,
                                      isGlobal: chatMessages[index].isGlobal,
                                      author: chatMessages[index].author,
                                      type: chatMessages[index].type,
                                      teamName: chatMessages[index].teamName,
                                      teamColor: chatMessages[index].teamColor,
                                      dateTime: chatMessages[index].dateTime,
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.only(left: 10, bottom: 10, top: 10),
                        color: Colors.grey[850],
                        height: 60,
                        width: double.infinity,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                enabled: chatConnected,
                                controller: chatController,
                                focusNode: chatFocusNode,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Write message...",
                                  hintStyle: const TextStyle(color: Colors.white),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 15,
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              child: FittedBox(
                                child: FloatingActionButton(
                                  onPressed: !chatConnected
                                      ? null
                                      : () async {
                                          var messageToSend = chatController.text;
                                          if (messageToSend.length <= 0) return;
                                          setState(
                                            () {
                                              chatChannel.sink.add(
                                                json.encode({
                                                  "action": "message",
                                                  "data": {
                                                    "message": messageToSend,
                                                    "destination": isGlobalChat ? "global" : data["teamId"]
                                                  }
                                                }),
                                              );

                                              var teamName = data["team"];
                                              if (teamName.toString().length > 13) {
                                                teamName = teamName.toString().substring(0, 10) + "...";
                                              }

                                              chatMessages.insert(
                                                0,
                                                new ChatMessage(
                                                  ChatMessageType.SENT,
                                                  "$messageToSend",
                                                  isGlobal: isGlobalChat,
                                                  author: "You",
                                                  teamName: teamName,
                                                  teamColor: HexColor(data["teamColor"]),
                                                  dateTime: DateFormat("kk:mm - dd.MM.yyyy").format(DateTime.now()),
                                                ),
                                              );

                                              chatController.clear();
                                            },
                                          );
                                        },
                                  child: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 29,
                                  ),
                                  backgroundColor: Colors.blue,
                                  elevation: 0,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: !showChat
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: "btn1",
                      onPressed: () {
                        showPlayerSettings(setState);
                      },
                      tooltip: 'Player settings',
                      child: const Icon(Icons.account_circle, size: 30),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      backgroundColor: chatConnected ? null : Colors.grey[800],
                      heroTag: "btn2",
                      onPressed: () {
                        setState(() {
                          showChat = true;
                          showNewMsgDot = false;
                        });
                      },
                      tooltip: 'Chat',
                      child: Stack(
                        children: [
                          const Icon(Icons.message),
                          showNewMsgDot
                              ? Positioned(
                                  right: 0,
                                  top: 0,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red,
                                    radius: 5,
                                  ),
                                )
                              : SizedBox.shrink(),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      backgroundColor: lockMapToPlayer ? null : Colors.grey[800],
                      heroTag: "btn3",
                      onPressed: () {
                        setState(() {
                          findMe();
                        });
                      },
                      tooltip: 'Find me',
                      child: const Icon(Icons.gps_fixed),
                    ),
                  ],
                )
              : Container(),
        ),
      );
    } catch (e) {
      showErrorToast(
        "View error: $e",
      );
    }
  }

  connectToChat() async {
    if (chatConnecting) return;
    setState(() => chatConnecting = true);
    var url;
    if (data["serverInLan"])
      url = "${StaticVariables.lanServerIp.replaceAll("http://", "ws://").replaceAll("https://", "wss://")}:5051";
    else
      url = "wss://kacpermarcinkiewicz.com:5051";
    try {
      chatChannel?.sink?.close();
      chatChannel = IOWebSocketChannel.connect(url, pingInterval: Duration(seconds: 10));
      setState(() {
        chatMessages.insert(
          0,
          new ChatMessage(ChatMessageType.OTHER, "[CONNECTING]"),
        );
      });
      chatChannel.sink.add(
        json.encode({
          "action": "join",
          "data": {
            "roomId": data["roomId"],
            "teamId": data["teamId"],
            "teamName": data["team"],
            "nickname": data["nickname"],
            "teamColor": data["teamColor"]
          }
        }),
      );

      chatChannel.stream.listen(
        (message) {
          setState(() {
            var json = jsonDecode(message);

            // Check is user now connected
            if (json["success"] == true && chatConnected == false) {
              setState(() {
                chatConnected = true;
                chatConnecting = false;

                chatMessages.insert(
                  0,
                  new ChatMessage(ChatMessageType.INFO_CONNECTED, "[CONNECTED]"),
                );
              });
              return;
            }

            if (json["messageType"] == "response") {
              setState(() {
                chatMessages.insert(
                  0,
                  new ChatMessage(
                    ChatMessageType.OTHER,
                    "[${json["message"] ?? json}]",
                  ),
                );
              });
            } else if (json["messageType"] == "message") {
              setState(() {
                if (!showChat && !showNewMsgDot) {
                  setState(() {
                    showNewMsgDot = true;
                  });
                }

                var author = json["nickname"];
                //? Replaced in [MessageCard] class
                // if (author.toString().length > 13) {
                //   author = author.toString().substring(0, 10) + "...";
                // }

                var teamName = json["teamName"];
                if (teamName.toString().length > 13) {
                  teamName = teamName.toString().substring(0, 10) + "...";
                }

                chatMessages.insert(
                  0,
                  new ChatMessage(
                    ChatMessageType.RECEIVED,
                    "${json["message"]}",
                    isGlobal: json["isGlobal"],
                    author: author,
                    teamName: teamName,
                    teamColor: HexColor(json["teamColor"]),
                    dateTime: DateFormat("kk:mm - dd.MM.yyyy").format(
                      DateTime.now(),
                    ),
                  ),
                );
              });
            }
          });
        },
        cancelOnError: false,
        onDone: () {
          void onDoneAction() {
            chatConnected = false;
            chatConnecting = false;
            chatMessages.insert(
              0,
              new ChatMessage(ChatMessageType.INFO_DISCONNECTED_OR_ERROR, "[DISCONNECTED]"),
            );
          }

          // To prevent memory leaks
          if (mounted) {
            setState(() {
              onDoneAction();
            });
          } else {
            onDoneAction();
          }
        },
        onError: (e) {
          setState(() {
            chatMessages.insert(
              0,
              new ChatMessage(ChatMessageType.INFO_DISCONNECTED_OR_ERROR, "[ERROR] - $e"),
            );
          });
        },
      );
    } catch (e) {
      setState(() {
        chatMessages.insert(
          0,
          new ChatMessage(ChatMessageType.INFO_DISCONNECTED_OR_ERROR, "[ERROR] - $e"),
        );
      });
    }
  }
}
