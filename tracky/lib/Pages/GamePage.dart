/*

MIT License

Copyright (c) 2020 Kacper Marcinkiewicz

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
import 'package:location/location.dart' as loc;
import 'package:background_location/background_location.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import "package:latlong/latlong.dart";
import 'package:screen/screen.dart';
import 'package:tracky/Dialogs.dart';

import '../Classes.dart';

class GamePage extends StatefulWidget {
  GamePage({Key key, this.title, this.arguments}) : super(key: key);

  final String title;
  final Object arguments;

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  Map data;

  List<TextMarker> textMarkers = List<TextMarker>();
  List<NamedPolygon> polygons = List<NamedPolygon>();

  bool connectionLost = false;

  var thisPlayer = new Player(
    name: "You",
    color: Colors.lightBlue[600],
    icon: "thisPlayer",
    location: LatLng(0, 0),
  );

  var otherPlayers = <Player>[];

  MapController mapController;
  Timer updateTimer;

  //Location variables
  Location _locationData = null;
  int lastUpdate = 0;
  bool permissionDenied = false;
  bool firstTimeZoomedBefore = false; // change this to true after first time finding GPS location
  bool showChat = false;

  /// Run it only on start
  Future<bool> getLocation() async {
    var permissionStatus = await BackgroundLocation.checkPermissions();
    print(permissionStatus);
    if (permissionStatus.toString() == "PermissionStatus.undetermined" || permissionStatus.toString() == "PermissionStatus.denied") {
      await Dialogs.infoDialog(
        context,
        titleText: "Permissions, read carefully!",
        descriptionText:
            'Now you should see a window asking for location permissions. These permissions are needed to run the application. It is possible that you will be able to choose between "Allow only while using the app" and "Allow all the time", We RECOMMEND to choose "Allow all the time" because it will allow your location to be updated also when you lock the phone, go to the home screen or change the application to another. We will download your location ONLY if you are in a room on the server and the app is running in the background. When you close the app or leave the room, we will not use your location. If you want, you can choose to share your location only while using the app, but it can make your location update only when the screen is unlocked. While the application will be using your location, you will be informed about it by a notification on the bar. \n\nThis setting can be changed later in the system settings.',
        okBtnText: "Ok",
        onOkBtn: () {
          Navigator.pop(context);
          BackgroundLocation.getPermissions(
            onGranted: () {
              permissionDenied = false;
              startGame();
            },
            onDenied: () {
              permissionDenied = true;
              Fluttertoast.showToast(
                msg: "Without permission enabled your location will not be updated!",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                gravity: ToastGravity.BOTTOM,
                fontSize: 14,
              );
              startGame();
            },
          );
        },
      );
    } else if (permissionStatus.toString() == "PermissionStatus.denied") {
      permissionDenied = true;
      Fluttertoast.showToast(
        msg: "Without permission enabled your location will not be updated!",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
        fontSize: 14,
      );
      startGame();
    } else if (permissionStatus.toString() == "PermissionStatus.granted") {
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
        Fluttertoast.showToast(
          msg: "Without GPS enabled your location will not be updated and you will be connected to server only every 20s!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 14,
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
    Screen.keepOn(true);

    data = widget.arguments;

    thisPlayer.color = HexColor(data["teamColor"]);

    mapController = MapController();

    getLocation();

    super.initState();
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    BackgroundLocation.stopLocationService();
    Screen.keepOn(false);
    super.dispose();
  }

  void updateAndFetchDataFromServer() {
    String url;
    if (data["serverInLan"])
      url = "http://192.168.1.50:5050/api/v1/room/${data["roomId"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/${data["roomId"]}";
    post(
      url,
      body: {
        "teamName": data["team"],
        "playerName": data["nickname"],
        "latitude": _locationData != null ? _locationData.latitude.toString() : "0",
        "longitude": _locationData != null ? _locationData.longitude.toString() : "0"
      },
    ).timeout(Duration(seconds: 20)).then((res) {
      if (connectionLost) {
        connectionLost = false;
        Fluttertoast.showToast(
          msg: "Reconnected",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.lightGreen,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 14,
        );
      }

      if (res.statusCode != 200) {
        try {
          var response = jsonDecode(res.body);
          Fluttertoast.showToast(
            msg: "Error while updating position. ${response["message"]}",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            gravity: ToastGravity.BOTTOM,
            fontSize: 12,
          );
        } catch (e) {
          Fluttertoast.showToast(
            msg: "Error while updating position. Server returned code ${res.statusCode}",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            gravity: ToastGravity.BOTTOM,
            fontSize: 12,
          );
        }

        return;
      }

      var response = jsonDecode(res.body);
      List<dynamic> teams = response["teams"];
      bool showEnemyTeam = response["showEnemyTeam"] == "true" ? true : false;
      List<Player> playersToAdd = new List<Player>();

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
          if (player["name"] != data["nickname"] ||
              (player["name"] == data["nickname"] &&
                  team["name"] != data["team"])) if ((team["name"] != data["team"] && showEnemyTeam) || team["name"] == data["team"]) {
            playersToAdd.add(
              new Player(
                name: player["name"],
                color: HexColor(team["color"]),
                icon: team["name"] != data["team"] // Check is in my team
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
        Fluttertoast.showToast(
          msg: "Connection to server lost. Trying to reconnect",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 12,
        );
      } else if (e.toString().contains("Network is unreachable")) {
        Fluttertoast.showToast(
          msg: "No internet connection!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 14,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Error: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 12,
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
        } catch (e) {
          print(e);
        }
      });
    }
  }

  void findMe() {
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
      url = "http://192.168.1.50:5050/api/v1/room/leave/${data["roomId"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/leave/${data["roomId"]}";

    try {
      var response = await post(url, body: {
        "playerName": data["nickname"],
        "teamName": data["team"],
      });

      if (response.statusCode != 200) {
        Fluttertoast.showToast(
            msg: "Error while leaving room: ${response.body}",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white);
        return;
      }

      return;
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error while leaving room: $e", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.red, textColor: Colors.white);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    data = widget.arguments;
    List<Marker> markers = List<Marker>();
    otherPlayers.forEach((p) => markers.add(p.getMarker()));
    markers.add(thisPlayer.getMarker());

    List<String> messages = [
      "Message 1",
      "Message 2",
      "Message 3",
      "Message 4",
      "Message 5",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
      "Message 6",
    ];
    try {
      return WillPopScope(
        onWillPop: () {
          updateTimer?.cancel();
          leaveGame();
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
          body: Stack(
            children: [
              !showChat
                  ? FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        center: LatLng(0, 0),
                        zoom: 15.0,
                        maxZoom: 19.3,
                      ),
                      layers: [
                        TileLayerOptions(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                          tileProvider: NonCachingNetworkTileProvider(), // CachedNetworkTileProvider()
                          maxZoom: 24.0,
                        ),
                        PolygonLayerOptions(polygonCulling: true, polygons: polygons.map((element) => element.polygon).toList()),
                        MarkerLayerOptions(markers: textMarkers.map((tMarker) => tMarker.getMarker()).toList()),
                        MarkerLayerOptions(markers: markers)
                      ],
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: SafeArea(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(),
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    color: Colors.grey[850],
                                    width: double.maxFinite,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text("Chat", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 25)),
                                          SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: RaisedButton(
                                                  padding: EdgeInsets.all(12),
                                                  child: Text("Connect", style: TextStyle(fontSize: 17)),
                                                  color: Colors.green,
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700],
                                                  onPressed: () {},
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: RaisedButton(
                                                  padding: EdgeInsets.all(12),
                                                  child: Text("Disconnect", style: TextStyle(fontSize: 17)),
                                                  color: Colors.red,
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700],
                                                  onPressed: () {},
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
                                        });
                                        SchedulerBinding.instance.addPostFrameCallback((_) => findMe());
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: messages.length,
                                padding: EdgeInsets.only(top: 10, bottom: 10),
                                itemBuilder: (context, index) {
                                  return Container(
                                    padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
                                    child: Text(messages[index]),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.only(left: 10, bottom: 10, top: 10),
                              height: 60,
                              width: double.infinity,
                              color: Colors.grey[850],
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                          hintText: "Write message...",
                                          hintStyle: TextStyle(color: Colors.white),
                                          border: InputBorder.none),
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
                                        onPressed: () {},
                                        child: Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 18,
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
                        setState(() {
                          showChat = true;
                        });
                      },
                      tooltip: 'Chat',
                      child: Icon(Icons.message),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "btn3",
                      onPressed: () {
                        setState(() {
                          findMe();
                        });
                      },
                      tooltip: 'Find me',
                      child: Icon(Icons.gps_fixed),
                    ),
                  ],
                )
              : Container(),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
          msg: "View error: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 12);
    }
  }
}
