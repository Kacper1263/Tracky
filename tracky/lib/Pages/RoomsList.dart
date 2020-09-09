import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';

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

  @override
  void initState() {
    super.initState();
    data = widget.arguments;
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
          )
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
                    itemBuilder: (BuildContext ctx, int index) {
                      return Card(
                        color: Colors.grey[700],
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: 15),
                              Center(
                                child: Text(
                                  "ID ${rooms[index]["id"]}: ${rooms[index]["name"]}",
                                  style: TextStyle(
                                      fontSize: 20, color: Colors.white),
                                ),
                              ),
                              SizedBox(height: 15),
                              RaisedButton(
                                  onPressed: () async {
                                    bool joined = await joinRoom(
                                        rooms[index]["id"],
                                        rooms[index]["teams"][0]["name"]);

                                    if (joined) {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/gamePage',
                                        arguments: {
                                          "roomId": rooms[index]["id"],
                                          "nickname": data["nickname"],
                                          "team": rooms[index]["teams"][0]
                                              ["name"],
                                          "serverInLan": data["serverInLan"]
                                        },
                                      );
                                    }
                                  },
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                      "Join: ${rooms[index]["teams"][0]["name"]} (${(rooms[index]["teams"][0]["players"].length)})",
                                      style: TextStyle(fontSize: 17)),
                                  color: Colors.grey[800],
                                  textColor: Colors.white,
                                  disabledColor: Colors.grey[800],
                                  disabledTextColor: Colors.grey[700]),
                              RaisedButton(
                                  onPressed: () async {
                                    bool joined = await joinRoom(
                                        rooms[index]["id"],
                                        rooms[index]["teams"][1]["name"]);

                                    if (joined) {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/gamePage',
                                        arguments: {
                                          "roomId": rooms[index]["id"],
                                          "nickname": data["nickname"],
                                          "team": rooms[index]["teams"][1]
                                              ["name"],
                                          "serverInLan": data["serverInLan"]
                                        },
                                      );
                                    }
                                  },
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                      "Join: ${rooms[index]["teams"][1]["name"]} (${(rooms[index]["teams"][1]["players"].length)})",
                                      style: TextStyle(fontSize: 17)),
                                  color: Colors.grey[800],
                                  textColor: Colors.white,
                                  disabledColor: Colors.grey[800],
                                  disabledTextColor: Colors.grey[700]),
                            ],
                          ),
                        ),
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
