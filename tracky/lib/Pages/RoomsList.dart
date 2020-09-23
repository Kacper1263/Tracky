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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';
import 'package:tracky/Classes.dart';

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
                  arguments: {
                    "serverInLan": data["serverInLan"],
                    "nickname": data["nickname"]
                  },
                );
              }),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(5, 15, 5, 10),
                                  child: TextField(
                                    keyboardType: TextInputType.text,
                                    controller: roomToSearchController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      contentPadding:
                                          EdgeInsets.fromLTRB(25, 20, 25, 20),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            const Radius.circular(100.0),
                                          ),
                                          borderSide: BorderSide(
                                              color: Colors.grey[200])),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            const Radius.circular(100.0),
                                          ),
                                          borderSide: BorderSide(
                                              color: Colors.grey[600])),
                                      hintText: 'Search room',
                                      hintStyle:
                                          TextStyle(color: Colors.grey[500]),
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
                                  ("ID " +
                                          rooms[index]["id"].toString() +
                                          ": " +
                                          rooms[index]["name"].toString())
                                      .toLowerCase()
                                      .contains(roomToSearch.toLowerCase())
                              ? Card(
                                  color: Colors.grey[700],
                                  child: ExpansionTile(
                                    title: Center(
                                      child: Text(
                                        "ID ${rooms[index]["id"]}: ${rooms[index]["name"]} ",
                                        style: TextStyle(
                                            fontSize: 20, color: Colors.white),
                                      ),
                                    ),
                                    childrenPadding:
                                        EdgeInsets.fromLTRB(10, 0, 10, 10),
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  double.parse(rooms[index]
                                                              ["expiresIn"]) >
                                                          170
                                                      ? "Never expires"
                                                      : "Expires in: ${rooms[index]["expiresIn"]}h",
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.white),
                                                ),
                                                double.parse(rooms[index]
                                                                ["expiresIn"]) >
                                                            170 ||
                                                        double.parse(rooms[
                                                                    index][
                                                                "expiresIn"]) ==
                                                            48
                                                    ? Container()
                                                    : IconButton(
                                                        padding:
                                                            EdgeInsets.all(0),
                                                        iconSize: 26,
                                                        tooltip:
                                                            "Refresh the expiry time",
                                                        icon: Icon(
                                                          Icons
                                                              .refresh_outlined,
                                                          color: Colors.white,
                                                        ),
                                                        onPressed: () {})
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 15),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            itemCount:
                                                rooms[index]["teams"].length,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            itemBuilder: (ct, i) {
                                              return RaisedButton(
                                                  onPressed: () async {
                                                    bool joined =
                                                        await joinRoom(
                                                            rooms[index]["id"],
                                                            rooms[index]
                                                                    ["teams"][i]
                                                                ["name"]);

                                                    if (joined) {
                                                      Navigator
                                                          .pushReplacementNamed(
                                                        context,
                                                        '/gamePage',
                                                        arguments: {
                                                          "roomId": rooms[index]
                                                              ["id"],
                                                          "nickname":
                                                              data["nickname"],
                                                          "team": rooms[index]
                                                                  ["teams"][i]
                                                              ["name"],
                                                          "teamColor":
                                                              rooms[index]
                                                                      ["teams"]
                                                                  [i]["color"],
                                                          "serverInLan": data[
                                                              "serverInLan"],
                                                        },
                                                      );
                                                    }
                                                  },
                                                  padding: EdgeInsets.all(12),
                                                  child: Text(
                                                      "Join: ${rooms[index]["teams"][i]["name"]} (${(rooms[index]["teams"][i]["players"].length)})",
                                                      style: TextStyle(
                                                          fontSize: 17)),
                                                  color: Colors.grey[800],
                                                  textColor: Colors.white,
                                                  disabledColor:
                                                      Colors.grey[800],
                                                  disabledTextColor:
                                                      Colors.grey[700]);
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
    if (data["serverInLan"])
      url = "http://192.168.1.50:5050/api/v1/room/all";
    else
      url = "http://kacpermarcinkiewicz.com:5050/api/v1/room/all";

    try {
      var response = await get(url);

      var json = jsonDecode(response.body);

      if (response.statusCode != 200) {
        Fluttertoast.showToast(
            msg: "Error while loading rooms: ${response.body}",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white);
        return null;
      }

      List<dynamic> rooms = json["rooms"];

      errorWhileLoading = false;
      return rooms;
    } catch (e) {
      errorWhileLoading = true;
      Fluttertoast.showToast(
          msg: "Error while loading rooms: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white);
      return null;
    }
  }

  Future<bool> joinRoom(int id, String team) async {
    String url;
    if (data["serverInLan"])
      url = "http://192.168.1.50:5050/api/v1/room/join/$id";
    else
      url = "http://kacpermarcinkiewicz.com:5050/api/v1/room/join/$id";

    try {
      Fluttertoast.showToast(
        msg: "Joining team: $team. Please wait",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.grey[700],
        textColor: Colors.white,
      );

      var response = await post(url, body: {
        "playerName": data["nickname"],
        "teamName": team,
      });

      if (response.statusCode == 200) {
        return true;
      } else {
        Fluttertoast.showToast(
            msg: "Error while joining team: ${response.body}",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white);
        return false;
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error while joining team: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white);
      return false;
    }
  }
}
