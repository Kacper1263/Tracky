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

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:http/http.dart';
import 'package:tracky/Dialogs.dart';
import 'package:tracky/GlobalFunctions.dart';
import 'package:tracky/StaticVariables.dart';

class RoomsList extends StatefulWidget {
  final Object arguments;

  RoomsList({Key key, this.arguments});
  @override
  _RoomsListState createState() => _RoomsListState();
}

class _RoomsListState extends State<RoomsList> {
  Map data = {};
  List rooms;
  bool errorWhileLoading = false;

  String roomToSearch = "";
  TextEditingController roomToSearchController = new TextEditingController();

  @override
  void initState() {
    super.initState();
    data = widget.arguments;

    // If page is getting text to paste in search bar, use this text
    if (data["searchBarText"].toString().isNotEmpty) {
      setState(() {
        roomToSearch = data["searchBarText"];
        roomToSearchController.text = data["searchBarText"];
      });
    } else {
      roomToSearch = "";
      roomToSearchController.text = "";
    }

    getRooms().then((value) {
      setState(() {
        rooms = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    data = widget.arguments;

    return Scaffold(
      appBar: AppBar(
        title: Text("Tracky"),
        centerTitle: true,
        backgroundColor: Colors.grey[850],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                rooms = null;
                errorWhileLoading = false;
              });
              getRooms().then((value) {
                setState(() {
                  rooms = value;
                });
              });
            },
            tooltip: "Refresh connection",
          ),
          IconButton(
            icon: Icon(Icons.add_circle),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/createRoom',
                arguments: {"serverInLan": data["serverInLan"], "nickname": data["nickname"], "hardwareID": data["hardwareID"]},
              );
            },
            tooltip: "Add room",
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[900],
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: (rooms == null && errorWhileLoading)
            ? Center(
                child: Text(
                "Error",
                style: TextStyle(color: Colors.red, fontSize: 25),
              ))
            : (rooms == null && !errorWhileLoading)
                ? Center(
                    child: Text(
                    "Loading data...",
                    style: TextStyle(color: Colors.yellow, fontSize: 25),
                  ))
                : ListView.builder(
                    itemCount: rooms.length,
                    shrinkWrap: false,
                    itemBuilder: (BuildContext ctx, int index) {
                      return Column(
                        children: [
                          // If index == 0 add search bar to list
                          index == 0
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(5, 15, 5, 10),
                                  child: TextField(
                                    keyboardType: TextInputType.text,
                                    controller: roomToSearchController,
                                    textCapitalization: TextCapitalization.sentences,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.fromLTRB(25, 20, 25, 20),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            const Radius.circular(100.0),
                                          ),
                                          borderSide: BorderSide(color: Colors.grey[200])),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            const Radius.circular(100.0),
                                          ),
                                          borderSide: BorderSide(color: Colors.grey[600])),
                                      hintText: 'Search room',
                                      hintStyle: TextStyle(color: Colors.grey[500]),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        roomToSearch = value;
                                      });
                                    },
                                  ),
                                )
                              : Container(),
                          // If search box is not empty or text on room card includes text from search box show this room
                          roomToSearch == null ||
                                  roomToSearch.isEmpty ||
                                  // Join room id with room name (add ID text and ":")
                                  ("ID " + rooms[index]["id"].toString() + ": " + rooms[index]["name"].toString())
                                      .toLowerCase()
                                      .contains(roomToSearch.toLowerCase())
                              ? Card(
                                  color: Colors.grey[700],
                                  child: ExpansionTile(
                                    title: Center(
                                      child: Text(
                                        "ID ${rooms[index]["id"]}: ${rooms[index]["name"]}",
                                        style: TextStyle(fontSize: 20, color: Colors.white),
                                      ),
                                    ),
                                    childrenPadding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  double.parse(rooms[index]["expiresIn"]) == -1
                                                      ? "Refreshing"
                                                      : double.parse(rooms[index]["expiresIn"]) > 170
                                                          ? "Never expires"
                                                          : "Expires in: ${rooms[index]["expiresIn"]}h",
                                                  style: TextStyle(fontSize: 14, color: Colors.white),
                                                ),
                                                double.parse(rooms[index]["expiresIn"]) == -1 ||
                                                        (double.parse(rooms[index]["expiresIn"]) > 170 ||
                                                            double.parse(rooms[index]["expiresIn"]) == 48)
                                                    ? Container()
                                                    : IconButton(
                                                        padding: EdgeInsets.all(0),
                                                        iconSize: 26,
                                                        tooltip: "Refresh the expiry time",
                                                        icon: Icon(
                                                          Icons.refresh,
                                                          color: Colors.white,
                                                        ),
                                                        onPressed: () {
                                                          var before = rooms[index]["expiresIn"];
                                                          setState(() {
                                                            rooms[index]["expiresIn"] = "-1";
                                                          });
                                                          refreshRoomTime(rooms[index]["id"], index, before);
                                                        })
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 15),
                                          rooms[index]["isOwner"] == "true"
                                              ? Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: RaisedButton(
                                                        padding: EdgeInsets.all(12),
                                                        child: Text("Edit room", style: TextStyle(fontSize: 17)),
                                                        color: Colors.grey[850],
                                                        textColor: Colors.white,
                                                        disabledColor: Colors.grey[800],
                                                        disabledTextColor: Colors.grey[700],
                                                        onPressed: () {
                                                          Navigator.pushNamed(
                                                            context,
                                                            "/createRoom",
                                                            arguments: {
                                                              "serverInLan": data["serverInLan"],
                                                              "nickname": data["nickname"],
                                                              "hardwareID": data["hardwareID"],
                                                              "editRoom": true,
                                                              "roomID": rooms[index]["id"],
                                                              "roomName": rooms[index]["name"],
                                                              "showEnemyTeam": rooms[index]["showEnemyTeam"],
                                                              "teams": rooms[index]["teams"]
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    SizedBox(width: 5),
                                                    Expanded(
                                                      child: RaisedButton(
                                                        padding: EdgeInsets.all(12),
                                                        child: Text("Edit map", style: TextStyle(fontSize: 17)),
                                                        color: Colors.grey[850],
                                                        textColor: Colors.white,
                                                        disabledColor: Colors.grey[800],
                                                        disabledTextColor: Colors.grey[700],
                                                        onPressed: () {
                                                          Navigator.pushNamed(
                                                            context,
                                                            "/editMap",
                                                            arguments: {
                                                              "nickname": data["nickname"],
                                                              "serverInLan": data["serverInLan"],
                                                              "hardwareID": data["hardwareID"],
                                                              "roomID": rooms[index]["id"],
                                                              "roomName": rooms[index]["name"],
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Container(),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: rooms[index]["teams"].length,
                                            physics: NeverScrollableScrollPhysics(),
                                            itemBuilder: (ct, i) {
                                              return RaisedButton(
                                                  onPressed: () async {
                                                    bool canceled = true;
                                                    TextEditingController _password = new TextEditingController();
                                                    if (rooms[index]["teams"][i]["passwordRequired"] == "true") {
                                                      await Dialogs.oneInputDialog(
                                                        _password,
                                                        context,
                                                        onCancel: () => Navigator.pop(context),
                                                        onSend: () {
                                                          canceled = false;
                                                          Navigator.pop(context);
                                                        },
                                                        cancelText: "Cancel",
                                                        sendText: "Join",
                                                        titleText: "Team password",
                                                        descriptionText: "You need to enter team password",
                                                        hintText: "Password",
                                                      );
                                                    } else {
                                                      canceled = false;
                                                      _password.text = "";
                                                    }
                                                    if (canceled) return;

                                                    bool joined;
                                                    try {
                                                      joined = await joinRoom(
                                                          rooms[index]["id"], rooms[index]["teams"][i]["id"], _password.text);
                                                    } catch (e) {
                                                      showErrorToast(
                                                        "Error while joining team: $e",
                                                      );
                                                      return;
                                                    }

                                                    if (joined) {
                                                      Navigator.pushReplacementNamed(
                                                        context,
                                                        '/gamePage',
                                                        arguments: {
                                                          "roomId": rooms[index]["id"],
                                                          "nickname": data["nickname"],
                                                          "team": rooms[index]["teams"][i]["name"],
                                                          "teamId": rooms[index]["teams"][i]["id"],
                                                          "teamColor": rooms[index]["teams"][i]["color"],
                                                          "serverInLan": data["serverInLan"],
                                                        },
                                                      );
                                                    }
                                                  },
                                                  padding: EdgeInsets.all(12),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      rooms[index]["teams"][i]["passwordRequired"] == "true"
                                                          ? Padding(padding: EdgeInsets.fromLTRB(0, 0, 5, 0), child: Icon(Icons.lock))
                                                          : Container(),
                                                      Flexible(
                                                        child: Text(
                                                            "Join: ${rooms[index]["teams"][i]["name"]} (${(rooms[index]["teams"][i]["players"].length)})",
                                                            style: TextStyle(fontSize: 17)),
                                                      ),
                                                    ],
                                                  ),
                                                  color: Colors.grey[800],
                                                  textColor: Colors.white,
                                                  disabledColor: Colors.grey[800],
                                                  disabledTextColor: Colors.grey[700]);
                                            },
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : Container(),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Future<List> getRooms() async {
    String url;
    String hardwareID = await FlutterUdid.udid;
    if (data["serverInLan"])
      url = "http://${StaticVariables.lanServerIp}:5050/api/v1/room/all?hardwareID=$hardwareID";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/all?hardwareID=$hardwareID";

    try {
      var response = await get(url).timeout(Duration(seconds: 20));

      var json = jsonDecode(response.body);

      if (response.statusCode != 200) {
        showErrorToast(
          "Error while loading rooms: ${response.body}",
        );
        return null;
      }

      List<dynamic> rooms = json["rooms"];

      setState(() => errorWhileLoading = false);
      return rooms;
    } catch (e) {
      setState(() => errorWhileLoading = true);
      showErrorToast(
        "Error while loading rooms: $e",
      );
      return null;
    }
  }

  Future<bool> joinRoom(int id, String team, String password) async {
    String url;
    if (data["serverInLan"])
      url = "http://${StaticVariables.lanServerIp}:5050/api/v1/room/join/$id";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/join/$id";

    try {
      showInfoToast(
        "Joining team. Please wait",
      );

      var response = await post(url, body: {
        "playerName": data["nickname"],
        "teamId": team,
        "teamPassword": sha256.convert(utf8.encode(password)).toString(),
      });

      if (response.statusCode == 200) {
        return true;
      } else {
        showErrorToast(
          "Error while joining team: ${jsonDecode(response.body)["message"]}",
        );
        return false;
      }
    } catch (e) {
      showErrorToast(
        "Error while joining team: $e",
      );
      return false;
    }
  }

  Future<bool> refreshRoomTime(int id, int indexOfRoom, String timeBefore) async {
    String url;
    if (data["serverInLan"])
      url = "http://${StaticVariables.lanServerIp}:5050/api/v1/room/refresh/$id";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/refresh/$id";

    showInfoToast(
      "Refreshing room time. Please wait",
    );

    try {
      var response = await post(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        showSuccessToast(
          "Room expiry time refreshed!",
        );
        setState(() {
          rooms[indexOfRoom]["expiresIn"] = "48";
        });
        return true;
      } else {
        showErrorToast(
          "Error while refreshing room time: ${response.body}",
        );
        setState(() {
          rooms[indexOfRoom]["expiresIn"] = timeBefore;
        });
        return false;
      }
    } catch (e) {
      showErrorToast(
        "Error while refreshing room time: $e",
      );
      setState(() {
        rooms[indexOfRoom]["expiresIn"] = timeBefore;
      });
      return false;
    }
  }
}
