import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import "package:latlong/latlong.dart";
import 'package:tracky/CustomWidgets/OutlineText.dart';

import 'Classes.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracky',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Tracky'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer timer;

  var thisPlayer = new Player(
    name: "You",
    color: Colors.lightBlue[600],
    location: LatLng(49.952403, 19.878666),
  );

  var otherPlayers = <Player>[
    Player(
      name: "Player 1",
      color: Colors.green[600],
      location: LatLng(49.952403, 19.868555),
    ),
  ];

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
    mapController = MapController();
    timer = Timer.periodic(
      Duration(seconds: 15),
      (Timer t) {
        // TODO: Send request to API with user location
        updatePlayerLocation();
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
    super.dispose();
  }

  void updatePlayerLocation() {
    setState(() {
      thisPlayer.getMarker().point.latitude = _locationData.latitude;
      thisPlayer.getMarker().point.longitude = _locationData.longitude;
    });
  }

  void _refresh() {
    setState(() {
      updatePlayerLocation();
      // TODO: Update other players location
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
    List<Marker> markers = List<Marker>();
    otherPlayers.forEach((p) => markers.add(p.getMarker()));
    markers.add(thisPlayer.getMarker());

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
          ),
          layers: [
            TileLayerOptions(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
              tileProvider: NonCachingNetworkTileProvider(),
            ),
            MarkerLayerOptions(markers: markers)
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
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
              onPressed: () {
                setState(() {
                  getLocation();
                  findMe();
                });
              },
              tooltip: 'Find me',
              child: Icon(Icons.gps_fixed),
            ),
            SizedBox(
              height: 10,
            ),
            FloatingActionButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              child: Icon(Icons.refresh),
            ),
          ],
        ));
  }
}
