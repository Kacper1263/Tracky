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
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:location/location.dart' as loc;
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
  List<TextMarker> textMarkers = List<TextMarker>();
  List<NamedPolygon> polygons = List<NamedPolygon>();

  MapController mapController;

  bool addingNewElement = false;
  Type newElementToAdd;

  NamedPolygon newPolygon = NamedPolygon();
  TextMarker newTextMarker = TextMarker();

  //Location variables
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
  void startEditor() async {
    // Check is GPS enabled
    loc.Location _location = loc.Location();
    bool gpsEnabled = await _location.serviceEnabled();
    if (!gpsEnabled) {
      gpsEnabled = await _location.requestService();
      if (!gpsEnabled) {
        Fluttertoast.showToast(
          msg: "Without GPS enabled your location will not be updated!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
          fontSize: 14,
        );
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => getDataFromServer());

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
          // Save data to API
          updateDataOnServerAndQuit();
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
                  if (addingNewElement) {
                    if (newElementToAdd == TextMarker) {
                      setState(() {
                        TextMarker _tm = TextMarker(
                          text: newTextMarker.text,
                          location: tapLocation,
                        );
                        _tm.onClick = () => textMarkerOnClick(_tm);
                        textMarkers.add(_tm);
                        setState(() {
                          addingNewElement = false;
                          newElementToAdd = null;
                        });
                      });
                    } else if (newElementToAdd == NamedPolygon) {
                      setState(() {
                        tempMarkers.add(
                          Marker(
                            width: 150.0,
                            height: 80.0,
                            point: tapLocation,
                            builder: (ctx) => Container(
                              child: Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 35,
                              ),
                            ),
                          ),
                        );
                      });
                    }
                  } else {
                    Geodesy geodesy = Geodesy();
                    List<ClickableMapObject> itemsInThisPlace = new List<ClickableMapObject>();
                    for (NamedPolygon poly in polygons) {
                      if (geodesy.isGeoPointInPolygon(tapLocation, poly.polygon.points)) {
                        itemsInThisPlace.add(ClickableMapObject(
                          name: poly.name,
                          object: poly,
                        ));
                      }
                    }

                    if (itemsInThisPlace.length <= 0) return;

                    // Show dialog with option to select element to edit
                    if (itemsInThisPlace.length > 1) {
                      Dialogs.infoDialogWithWidgetBody(
                        context,
                        titleText: "Edit element",
                        onOkBtn: () => Navigator.pop(context),
                        okBtnText: "Cancel",
                        descriptionWidgets: <Widget>[
                          Text("Which element do you want to edit?", style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                          SizedBox(height: 10),
                          Container(
                            child: ListView.builder(
                              itemCount: itemsInThisPlace.length,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemBuilder: (ct, i) {
                                return Padding(
                                  padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                                  child: RaisedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (itemsInThisPlace[i].object.runtimeType == NamedPolygon) {
                                        TextEditingController _te = TextEditingController();
                                        // Set old data for editing
                                        _te.text = itemsInThisPlace[i].name;
                                        newPolygon = NamedPolygon();
                                        newPolygon.color = itemsInThisPlace[i].object.color;
                                        polygonPopup(_te, oldPolygon: itemsInThisPlace[i].object);
                                      }
                                    },
                                    padding: EdgeInsets.all(12),
                                    child: Text(itemsInThisPlace[i].name, style: TextStyle(fontSize: 17)),
                                    color: Colors.grey[700],
                                    textColor: Colors.white,
                                    disabledColor: Colors.grey[800],
                                    disabledTextColor: Colors.grey[700],
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      );
                    }
                    // Only 1 element here
                    else {
                      if (itemsInThisPlace[0].object.runtimeType == NamedPolygon) {
                        TextEditingController _te = TextEditingController();
                        // Set old data for editing
                        _te.text = itemsInThisPlace[0].name;
                        newPolygon = NamedPolygon();
                        newPolygon.color = itemsInThisPlace[0].object.color;
                        polygonPopup(_te, oldPolygon: itemsInThisPlace[0].object);
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
                PolygonLayerOptions(polygonCulling: true, polygons: polygons.map((element) => element.polygon).toList()),
                MarkerLayerOptions(markers: textMarkers.map((tMarker) => tMarker.getMarker()).toList()),
                MarkerLayerOptions(markers: markers),
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
                      addingNewElement = !addingNewElement;
                    });
                    if (addingNewElement) {
                      Dialogs.infoDialogWithWidgetBody(
                        context,
                        okBtnText: "Cancel",
                        onOkBtn: () {
                          setState(() {
                            addingNewElement = false;
                            newElementToAdd = null;
                          });
                          Navigator.pop(context);
                        },
                        titleText: "Add new element",
                        descriptionWidgets: <Widget>[
                          Text(
                            "What do you want to add?",
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10),
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                            child: RaisedButton(
                              padding: EdgeInsets.all(12),
                              child: Text("Text"),
                              color: Colors.grey[700],
                              textColor: Colors.white,
                              disabledColor: Colors.grey[800],
                              disabledTextColor: Colors.grey[700],
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  newElementToAdd = TextMarker;
                                });

                                // Add new text
                                TextEditingController _newTextController = TextEditingController();
                                textMarkerPopup(_newTextController);
                              },
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                            child: RaisedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  newElementToAdd = NamedPolygon;
                                });

                                // Add new polygon
                                TextEditingController _newTextController = TextEditingController();
                                newPolygon = NamedPolygon();
                                polygonPopup(_newTextController);
                              },
                              padding: EdgeInsets.all(12),
                              child: Text("Polygon"),
                              color: Colors.grey[700],
                              textColor: Colors.white,
                              disabledColor: Colors.grey[800],
                              disabledTextColor: Colors.grey[700],
                            ),
                          ),
                        ],
                      );
                    } else {
                      if (newElementToAdd == NamedPolygon) {
                        if (tempMarkers.length <= 0) return;
                        List<LatLng> pointsOfPolygon = tempMarkers.map((e) => e.point).toList();
                        tempMarkers.clear();
                        polygons.add(
                          NamedPolygon(
                            name: newPolygon.name,
                            color: newPolygon.color,
                            polygon: Polygon(
                              color: newPolygon.color.withOpacity(0.5),
                              points: pointsOfPolygon,
                            ),
                          ),
                        );
                        setState(() {
                          newElementToAdd = null;
                        });
                      } else if (newElementToAdd == TextMarker) {
                        setState(() {
                          addingNewElement = false;
                          newElementToAdd = null;
                        });
                      }
                    }
                  },
                  tooltip: addingNewElement
                      ? newElementToAdd == TextMarker
                          ? "Cancel"
                          : "Save"
                      : 'New element',
                  child: Icon(
                    addingNewElement
                        ? newElementToAdd == TextMarker
                            ? Icons.cancel
                            : Icons.save
                        : Icons.add,
                  ),
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

  /// Get all data about namedPolygons and textMarkers on server
  getDataFromServer() async {
    Dialogs.loadingDialog(context, titleText: "Updating map", descriptionText: "Downloading map data from server. Please wait...");
    String url;
    if (data["serverInLan"])
      url = "http://192.168.1.50:5050/api/v1/room/${data["roomID"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/${data["roomID"]}";

    try {
      Response response;

      response = await get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);

        json["namedPolygons"].forEach((polygon) {
          polygons.add(NamedPolygon(
            name: polygon["name"],
            color: HexColor(polygon["color"]),
            polygon: Polygon(
              color: HexColor(polygon["polygon"]["color"]),
              points: polygon["polygon"]["points"].map<LatLng>((point) => LatLng(point["latitude"], point["longitude"])).toList(),
            ),
          ));
        });

        json["textMarkers"].forEach((marker) {
          TextMarker _markerToAdd = TextMarker(
              text: marker["text"],
              location: LatLng(
                  double.parse(marker["location"]["latitude"].toString()), double.parse(marker["location"]["longitude"].toString())));
          _markerToAdd.onClick = () => textMarkerOnClick(_markerToAdd);
          textMarkers.add(_markerToAdd);
        });

        Fluttertoast.showToast(
          msg: "Map data loaded!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        Navigator.pop(context); // Pop loading
        return;
      } else {
        Fluttertoast.showToast(
          msg: "Error while loading map data: ${jsonDecode(response.body)["message"]}",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        BackgroundLocation.stopLocationService();
        Navigator.pop(context); // Pop loading
        Navigator.pop(context); // Pop map to rooms list
        return;
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error while loading map data: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      BackgroundLocation.stopLocationService();
      Navigator.pop(context); // Pop loading
      Navigator.pop(context); // Pop map to rooms list
      return;
    }
  }

  updateDataOnServerAndQuit() async {
    Dialogs.loadingDialog(context, titleText: "Updating map", descriptionText: "Updating map on server. Please wait...");
    String url;
    if (data["serverInLan"])
      url = "http://192.168.1.50:5050/api/v1/room/map/${data["roomID"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/map/${data["roomID"]}";

    try {
      Response response;
      List<dynamic> textMarkersForServer = List<dynamic>();
      List<dynamic> polygonsForServer = List<dynamic>();

      // Data for json.encode
      textMarkers.forEach((element) {
        textMarkersForServer.add({
          "text": element.text,
          "location": {"latitude": element.location.latitude, "longitude": element.location.longitude}
        });
      });
      polygons.forEach((element) {
        polygonsForServer.add({
          "name": element.name,
          "color": element.color.value.toRadixString(16),
          "polygon": {
            "color": element.polygon.color.value.toRadixString(16),
            "points": element.polygon.points.map((e) => {"latitude": e.latitude, "longitude": e.longitude}).toList()
          },
        });
      });

      response = await post(
        url,
        body: {
          "hardwareID": data["hardwareID"],
          "textMarkers": json.encode(textMarkersForServer),
          "namedPolygons": json.encode(polygonsForServer),
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);

        Fluttertoast.showToast(
          msg: "Map data updated!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        Navigator.pop(context); // Pop loading
        Navigator.pop(context); // Pop map
        BackgroundLocation.stopLocationService();
        Navigator.pushReplacementNamed(
          context,
          '/roomsList',
          arguments: {
            "serverInLan": data["serverInLan"],
            "nickname": data["nickname"],
            "hardwareID": data["hardwareID"],
            "searchBarText": "ID " + (data["roomID"].toString() + ": " + data["roomName"])
          },
        );
        return;
      } else {
        Fluttertoast.showToast(
            msg: "Error while updating data: ${jsonDecode(response.body)["message"]}",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white);
        Navigator.pop(context);
        return;
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error while updating data: $e", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.red, textColor: Colors.white);
      Navigator.pop(context);
      return;
    }
  }

  /// To edit set reference to [oldPolygon] and use [newPolygon] to edit variables
  polygonPopup(TextEditingController _newTextController, {NamedPolygon oldPolygon}) {
    Dialogs.infoDialogWithWidgetBody(
      context,
      titleText: oldPolygon == null ? "New polygon" : "Edit polygon",
      okBtnText: "Cancel",
      onOkBtn: () {
        setState(() {
          addingNewElement = false;
          newElementToAdd = null;
        });
        Navigator.pop(context);
      },
      descriptionWidgets: [
        TextField(
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          controller: _newTextController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
            hintText: 'Polygon name',
            hintStyle: TextStyle(color: Colors.grey[500]),
          ),
        ),
        SizedBox(height: 10),
        StatefulBuilder(
          builder: (context, setState) => Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 10,
            children: [
              FloatingActionButton(
                heroTag: "1-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.green;
                  });
                },
                backgroundColor: Colors.green,
                shape: CircleBorder(
                  side: newPolygon.color == Colors.green || newPolygon.color == HexColor(Colors.green.value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.yellow,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
              FloatingActionButton(
                heroTag: "2-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.red;
                  });
                },
                backgroundColor: Colors.red,
                shape: CircleBorder(
                  side: newPolygon.color == Colors.red || newPolygon.color == HexColor(Colors.red.value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.yellow,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
              FloatingActionButton(
                heroTag: "3-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.blue;
                  });
                },
                backgroundColor: Colors.blue,
                shape: CircleBorder(
                  side: newPolygon.color == Colors.blue || newPolygon.color == HexColor(Colors.blue.value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.yellow,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
              FloatingActionButton(
                heroTag: "4-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.purple;
                  });
                },
                backgroundColor: Colors.purple,
                shape: CircleBorder(
                  side: newPolygon.color == Colors.purple || newPolygon.color == HexColor(Colors.purple.value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.yellow,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
              FloatingActionButton(
                heroTag: "5-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.black;
                  });
                },
                backgroundColor: Colors.black,
                shape: CircleBorder(
                  side: newPolygon.color == Colors.black || newPolygon.color == HexColor(Colors.black.value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.yellow,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
              FloatingActionButton(
                heroTag: "6-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.pink[300];
                  });
                },
                backgroundColor: Colors.pink[300],
                shape: CircleBorder(
                  side: newPolygon.color == Colors.pink[300] || newPolygon.color == HexColor(Colors.pink[300].value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.yellow,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
              FloatingActionButton(
                heroTag: "7-Color",
                onPressed: () {
                  setState(() {
                    newPolygon.color = Colors.yellow;
                  });
                },
                backgroundColor: Colors.yellow,
                shape: CircleBorder(
                  side: newPolygon.color == Colors.yellow || newPolygon.color == HexColor(Colors.yellow.value.toRadixString(16))
                      ? BorderSide(
                          color: Colors.red,
                          width: 3,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, 5),
          child: RaisedButton(
            onPressed: () {
              if (newPolygon.color == null) {
                Fluttertoast.showToast(
                  msg: "You need to set color",
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  gravity: ToastGravity.BOTTOM,
                  fontSize: 12,
                );
                return;
              }

              Navigator.pop(context);

              if (oldPolygon == null) {
                Fluttertoast.showToast(
                  msg: "Tap on map to add polygon points, then click save",
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.grey,
                  textColor: Colors.white,
                  gravity: ToastGravity.BOTTOM,
                  fontSize: 12,
                );

                newPolygon.name = _newTextController.text.length > 0 ? _newTextController.text : "Polygon " + DateTime.now().toString();
              } else {
                int index = polygons.indexOf(oldPolygon);
                setState(() {
                  polygons[index].name =
                      _newTextController.text.length > 0 ? _newTextController.text : "Polygon " + DateTime.now().toString();
                  polygons[index].color = newPolygon.color;
                  polygons[index].polygon.color = newPolygon.color.withOpacity(0.5);
                });
              }
            },
            padding: EdgeInsets.all(12),
            child: Text("Continue"),
            color: Colors.green,
            textColor: Colors.white,
            disabledColor: Colors.grey[800],
            disabledTextColor: Colors.grey[700],
          ),
        ),
        oldPolygon == null
            ? Container()
            : Padding(
                padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                child: RaisedButton(
                  onPressed: () {
                    Dialogs.confirmDialog(
                      context,
                      titleText: "Delete polygon",
                      descriptionText: "Are you sure you want to delete this polygon?",
                      onCancel: () {
                        Navigator.pop(context);
                      },
                      onSend: () {
                        setState(() {
                          polygons.remove(oldPolygon);
                        });

                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    );
                  },
                  padding: EdgeInsets.all(12),
                  child: Text("Delete polygon"),
                  color: Colors.red,
                  textColor: Colors.white,
                  disabledColor: Colors.grey[800],
                  disabledTextColor: Colors.grey[700],
                ),
              ),
      ],
    );
  }

  textMarkerPopup(TextEditingController _newTextController) {
    Dialogs.infoDialogWithWidgetBody(
      context,
      titleText: "New text",
      okBtnText: "Cancel",
      onOkBtn: () {
        setState(() {
          addingNewElement = false;
          newElementToAdd = null;
        });
        Navigator.pop(context);
      },
      descriptionWidgets: [
        TextField(
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          controller: _newTextController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
            hintText: 'Content',
            hintStyle: TextStyle(color: Colors.grey[500]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
          child: RaisedButton(
            onPressed: () {
              if (_newTextController.text.length <= 0) {
                Fluttertoast.showToast(
                  msg: "Text must have 1 or more characters",
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  gravity: ToastGravity.BOTTOM,
                  fontSize: 12,
                );
                return;
              }

              newTextMarker.text = _newTextController.text;

              Fluttertoast.showToast(
                msg: "Tap on place where you want to add this text",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: Colors.grey,
                textColor: Colors.white,
                gravity: ToastGravity.BOTTOM,
                fontSize: 12,
              );

              Navigator.pop(context);
            },
            padding: EdgeInsets.all(12),
            child: Text("Add this text"),
            color: Colors.grey[700],
            textColor: Colors.white,
            disabledColor: Colors.grey[800],
            disabledTextColor: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// [_tm] - marker
  textMarkerOnClick(_tm) {
    // If adding something return and tond run edit
    if (newElementToAdd != null) return;

    int index = textMarkers.indexOf(_tm);
    TextEditingController _newTextController = TextEditingController();
    _newTextController.text = textMarkers[index].text;

    Dialogs.infoDialogWithWidgetBody(
      context,
      titleText: "Edit text",
      okBtnText: "Cancel",
      onOkBtn: () {
        Navigator.pop(context);
      },
      descriptionWidgets: [
        TextField(
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          controller: _newTextController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
            hintText: 'New content',
            hintStyle: TextStyle(color: Colors.grey[500]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
          child: RaisedButton(
            onPressed: () {
              if (_newTextController.text.length <= 0) {
                Fluttertoast.showToast(
                  msg: "Text must have 1 or more characters",
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  gravity: ToastGravity.BOTTOM,
                  fontSize: 12,
                );
              } else {
                setState(() {
                  textMarkers[index].text = _newTextController.text;
                });

                Navigator.pop(context);
              }
            },
            padding: EdgeInsets.all(12),
            child: Text("Update text on marker"),
            color: Colors.green,
            textColor: Colors.white,
            disabledColor: Colors.grey[800],
            disabledTextColor: Colors.grey[700],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
          child: RaisedButton(
            onPressed: () {
              Dialogs.confirmDialog(context,
                  titleText: "Delete marker", descriptionText: "This will delete this text marker. Are you sure?", onCancel: () {
                Navigator.pop(context);
              }, onSend: () {
                setState(() {
                  textMarkers.remove(_tm);
                });

                Navigator.pop(context);
                Navigator.pop(context);
              });
            },
            padding: EdgeInsets.all(12),
            child: Text("Delete text marker"),
            color: Colors.red,
            textColor: Colors.white,
            disabledColor: Colors.grey[800],
            disabledTextColor: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
