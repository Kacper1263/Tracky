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
import 'package:background_location/background_location.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geodesy/geodesy.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import "package:latlong/latlong.dart";
import 'package:screen/screen.dart';
import 'package:tracky/Dialogs.dart';

import '../Classes.dart';

class EditMap extends StatefulWidget {
  EditMap({Key key, this.title, this.arguments}) : super(key: key);

  final String title;
  final Object arguments;

  @override
  _EditMapState createState() => _EditMapState();
}

class _EditMapState extends State<EditMap> {
  Map data;

  var thisPlayer = new Player(
    name: "You",
    color: Colors.lightBlue[600],
    icon: "thisPlayer",
    location: LatLng(0, 0),
  );

  List<Marker> tempMarkers = List<Marker>();
  List<NamedPolygon> polygons = List<NamedPolygon>();

  MapController mapController;

  //Location variables
  bool addingNewPolygon = false;
  NamedPolygon newPolygon;
  Location _locationData = null;
  bool firstTimeZoomedBefore = false;

  /// Run it only on start
  Future<bool> getLocation() async {
    var permissionStatus = await BackgroundLocation.checkPermissions();
    print(permissionStatus);
    if (permissionStatus.toString() == "PermissionStatus.undetermined" || permissionStatus.toString() == "PermissionStatus.denied") {
      Dialogs.infoDialog(
        context,
        titleText: "Permissions, read carefully!",
        descriptionText:
            'Now you should see a window asking for location permissions. These permissions are needed to run the application. It is possible that you will be able to choose between "Allow only while using the app" and "Allow all the time", We RECOMMEND to choose "Allow all the time" because it will allow your location to be updated also when you lock the phone, go to the home screen or change the application to another. We will download your location ONLY if you are in a room on the server and the app is running in the background. When you close the app or leave the room, we will not use your location. If you want, you can choose to share your location only while using the app, but it can make your location update only when the screen is unlocked. While the application will be using your location, you will be informed about it by a notification on the bar. \n\nThis setting can be changed later in the system settings.',
        okBtnText: "Ok",
        onOkBtn: () {
          Navigator.pop(context);
          BackgroundLocation.getPermissions(
            onGranted: () {
              startEditor();
            },
            onDenied: () {
              Navigator.pop(context);
            },
          );
        },
      );
    } else if (permissionStatus.toString() == "PermissionStatus.granted") {
      startEditor();
    } else {
      Navigator.pop(context);
    }

    return true;
  }

  // Call when permissions are granted
  void startEditor() {
    BackgroundLocation.setAndroidNotification(
        title: "Tracky - ASG team tracker",
        message: "I am updating Your location in map editor (I am not sending it to the server). Tap me to resume the app");
    BackgroundLocation.startLocationService();
    BackgroundLocation.getLocationUpdates((location) {
      _locationData = location;

      updatePlayerLocation();

      if (!firstTimeZoomedBefore && _locationData.latitude != 0) {
        findMe();
        firstTimeZoomedBefore = true;
      }

      try {
        print(
          "API call. Location: ${_locationData.latitude}, ${_locationData.longitude}",
        );
      } catch (e) {
        print(e);
      }
    });
  }

  @override
  void initState() {
    Screen.keepOn(true);

    data = widget.arguments;

    mapController = MapController();

    getLocation();

    super.initState();
  }

  @override
  void dispose() {
    Screen.keepOn(false);
    super.dispose();
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
        LatLng(_locationData.latitude, _locationData.longitude),
        mapController.zoom,
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    data = widget.arguments;
    List<Marker> markers = List<Marker>();
    tempMarkers.forEach((p) => markers.add(p));
    markers.add(thisPlayer.getMarker());

    try {
      return WillPopScope(
        onWillPop: () {
          // TODO: Save data to API
          BackgroundLocation.stopLocationService();
          return Future.value(true);
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              centerTitle: true,
              backgroundColor: Colors.grey[700],
            ),
            body: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: LatLng(0, 0),
                zoom: 15.0,
                maxZoom: 19.3,
                onTap: (tapLocation) {
                  if (addingNewPolygon) {
                    setState(() {
                      tempMarkers.add(
                        Marker(
                          width: 150.0,
                          height: 80.0,
                          point: tapLocation,
                          builder: (ctx) => Container(
                            child: Icon(
                              Icons.location_pin,
                              color: Colors.red, // TODO: Polygon color
                              size: 35,
                            ),
                          ),
                        ),
                      );
                    });
                  } else {
                    Geodesy geodesy = Geodesy();
                    for (NamedPolygon poly in polygons) {
                      if (geodesy.isGeoPointInPolygon(tapLocation, poly.polygon.points)) {
                        Fluttertoast.showToast(
                          msg: "Tapped on polygon. TODO: Edit polygon info", // TODO: Edit polygon info
                          toastLength: Toast.LENGTH_LONG,
                          backgroundColor: Colors.grey,
                          textColor: Colors.white,
                          gravity: ToastGravity.BOTTOM,
                          fontSize: 12,
                        );
                        break; // Break to not show overlapping polygons
                      }
                    }
                  }
                },
              ),
              layers: [
                TileLayerOptions(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                  tileProvider: NonCachingNetworkTileProvider(), // CachedNetworkTileProvider()
                  maxZoom: 24.0,
                ),
                MarkerLayerOptions(markers: markers),
                PolygonLayerOptions(polygonCulling: true, polygons: polygons.map((element) => element.polygon).toList()),
              ],
            ),
            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                SizedBox(
                  height: 20,
                ),
                FloatingActionButton(
                  heroTag: "btn4",
                  onPressed: () {
                    setState(() {
                      addingNewPolygon = !addingNewPolygon;
                    });
                    if (addingNewPolygon) {
                      // TODO: Popup with settings of the new polygon
                    } else {
                      // TODO: Save new polygon to list
                      if (tempMarkers.length <= 0) return;
                      List<LatLng> pointsOfPolygon = tempMarkers.map((e) => e.point).toList();
                      tempMarkers.clear();
                      polygons.add(
                        NamedPolygon(
                          name: "Poly",
                          polygon: Polygon(
                            color: Colors.red.withOpacity(0.5), // TODO: Polygon color
                            points: pointsOfPolygon,
                          ),
                        ),
                      );
                    }
                  },
                  tooltip: addingNewPolygon ? "Save polygon" : 'New polygon',
                  child: Icon(addingNewPolygon ? Icons.save : Icons.add),
                ),
              ],
            )),
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
