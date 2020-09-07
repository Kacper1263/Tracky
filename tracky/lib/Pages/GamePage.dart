import 'dart:async';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import "package:latlong/latlong.dart";
import 'package:screen/screen.dart';

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

  Timer timer;
  bool connectionLost = false;

  var thisPlayer = new Player(
    name: "You",
    color: Colors.lightBlue[600],
    location: LatLng(49.952403, 19.878666),
  );

  var otherPlayers = <Player>[];

  MapController mapController;

  //Location variables
  Location location = new Location();
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;
  LocationData _locationData = null;

  /// Run it only on start
  Future<bool> getLocation() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        _locationData = null;
        return false;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        _locationData = null;
        return false;
      }
    }

    _locationData = await location.getLocation();
    updatePlayerLocation();
    return true;
  }

  @override
  void initState() {
    Screen.keepOn(true);

    data = widget.arguments;

    mapController = MapController();
    timer = Timer.periodic(
      Duration(seconds: 5),
      (Timer t) async {
        updatePlayerLocation();

        String url;
        if (data["serverInLan"])
          url = "http://192.168.1.50:5050/api/v1/room/${data["roomId"]}";
        else
          url =
              "http://kacpermarcinkiewicz.com:5050/api/v1/room/${data["roomId"]}";
        post(
          url,
          body: {
            "teamName": data["team"],
            "playerName": data["nickname"],
            "latitude": _locationData.latitude.toString(),
            "longitude": _locationData.longitude.toString()
          },
        ).timeout(Duration(seconds: 5)).then((res) {
          var response = jsonDecode(res.body);
          List<dynamic> teams = response["teams"];
          List<Player> playersToAdd = new List<Player>();

          teams.forEach((team) {
            List<dynamic> players = team["players"];
            players.forEach((player) {
              if (player["name"] != data["nickname"] ||
                  (player["name"] == data["nickname"] &&
                      team["name"] != data["team"]))
                playersToAdd.add(
                  new Player(
                    name: player["name"],
                    color: team["name"] != data["team"]
                        ? Colors.red
                        : Colors.green,
                    location: LatLng(
                      double.parse(player["latitude"]),
                      double.parse(player["longitude"]),
                    ),
                  ),
                );
            });
          });
          otherPlayers = playersToAdd.sublist(0);

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

        print(
          "API call. Location: ${_locationData.latitude}, ${_locationData.longitude}",
        );
      },
    );

    getLocation().then((success) {
      if (success) {
        location.onLocationChanged.listen((LocationData currentLocation) {
          _locationData = currentLocation;
          updatePlayerLocation();
        });
        findMe();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    Screen.keepOn(false);
    super.dispose();
  }

  void updatePlayerLocation() {
    setState(() {
      thisPlayer.getMarker().point.latitude = _locationData.latitude;
      thisPlayer.getMarker().point.longitude = _locationData.longitude;
    });
  }

  void findMe() {
    mapController.move(
      LatLng(_locationData.latitude, _locationData.longitude),
      mapController.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    data = widget.arguments;
    List<Marker> markers = List<Marker>();
    otherPlayers.forEach((p) => markers.add(p.getMarker()));
    markers.add(thisPlayer.getMarker());

    try {
      return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            centerTitle: true,
            backgroundColor: Colors.grey[700],
          ),
          body: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: LatLng(49.952403, 19.878666),
              zoom: 15.0,
              maxZoom: 19.3,
            ),
            layers: [
              TileLayerOptions(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
                tileProvider: NonCachingNetworkTileProvider(),
                maxZoom: 24.0,
              ),
              MarkerLayerOptions(markers: markers)
            ],
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: "btn1",
                onPressed: () {
                  setState(() {
                    thisPlayer.name = "You";
                    thisPlayer.color = Colors.lightBlue[600];
                  });
                },
                tooltip: 'Revive me',
                child: Icon(Icons.sentiment_satisfied),
              ),
              SizedBox(
                height: 10,
              ),
              FloatingActionButton(
                heroTag: "btn2",
                onPressed: () {
                  setState(() {
                    thisPlayer.name = "You (dead)";
                    thisPlayer.color = Colors.red;
                  });
                },
                tooltip: 'Kill me',
                child: Icon(Icons.sentiment_very_dissatisfied),
              ),
              SizedBox(
                height: 20,
              ),
              FloatingActionButton(
                heroTag: "btn3",
                onPressed: () {
                  setState(() {
                    getLocation();
                    findMe();
                  });
                },
                tooltip: 'Find me',
                child: Icon(Icons.gps_fixed),
              ),
            ],
          ));
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 12);
    }
  }
}