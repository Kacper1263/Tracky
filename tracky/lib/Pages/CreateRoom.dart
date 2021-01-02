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
import 'package:tracky/Dialogs.dart';

class CreateRoom extends StatefulWidget {
  final Object arguments;

  CreateRoom({Key key, this.arguments});

  @override
  _CreateRoomState createState() => _CreateRoomState();
}

class _CreateRoomState extends State<CreateRoom> {
  Map data;
  TextEditingController roomNameController = new TextEditingController();
  List<TextEditingController> textControllers = new List<TextEditingController>();
  bool showEnemyTeam = false;
  bool sending = false;
  List teams = [];

  @override
  void initState() {
    data = widget.arguments;
    if (data["editRoom"] == true) {
      roomNameController.text = data["roomName"];
      showEnemyTeam = data["showEnemyTeam"] == "true";
      List<dynamic> _teams = data["teams"];
      for (int i = 0; i < _teams.length; i++) {
        teams.add({
          "name": _teams[i]["name"],
          "color": _teams[i]["color"],
          "players": [],
        });
      }
    }

    super.initState();
  }

  void addTeam() {
    teams.add({
      "name": "",
      "color": "",
      "players": [],
    });
  }

  bool validateData() {
    bool noProblems = true;

    if (teams.length < 1) noProblems = false;

    teams.forEach((team) {
      if (team["name"].toString().isEmpty || team["color"].toString().isEmpty) {
        noProblems = false;
        return false;
      }
    });

    return noProblems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tracky"),
        centerTitle: true,
        backgroundColor: Colors.grey[850],
      ),
      body: Container(
        color: Colors.grey[900],
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: ListView(
          children: [
            SizedBox(height: 15),
            Text("Room name ", style: TextStyle(color: Colors.white)),
            SizedBox(height: 5),
            TextField(
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Colors.white),
              controller: roomNameController,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                hintText: 'Enter room name',
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
            ),
            Row(
              children: [
                Switch(
                  value: showEnemyTeam,
                  inactiveTrackColor: Colors.grey[700],
                  onChanged: (value) {
                    setState(() {
                      showEnemyTeam = value;
                    });
                  },
                ),
                Text("Show enemy team ", style: TextStyle(color: Colors.white)),
              ],
            ),
            SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Teams: ", style: TextStyle(color: Colors.white, fontSize: 20)),
                IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        addTeam();
                      });
                    })
              ],
            ),
            Divider(color: Colors.white, indent: 8, endIndent: 8),
            SizedBox(height: 15),
            ListView.builder(
              itemCount: teams.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                if (textControllers.length < teams.length) textControllers.add(new TextEditingController());
                return Card(
                  color: Colors.grey[700],
                  child: ExpansionTile(
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    onExpansionChanged: (value) {
                      setState(() {
                        textControllers[index].text = teams[index]["name"];
                      });
                    },
                    childrenPadding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                    title: Center(
                      child: Text(
                        "${index + 1})  ${teams[index]["name"]} ",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ),
                    children: [
                      TextField(
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        controller: textControllers[index],
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
                          border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                          hintText: 'Enter team name',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        onChanged: (value) {
                          setState(() {
                            teams[index]["name"] = value;
                          });
                        },
                      ),
                      SizedBox(height: 15),
                      Center(
                        child: Text(
                          "Select team color",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 15),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          FloatingActionButton(
                            heroTag: "1-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.green.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.green,
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.green.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: "2-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.red.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.red,
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.red.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: "3-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.blue.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.blue,
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.blue.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: "4-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.purple.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.purple,
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.purple.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: "5-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.black.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.black,
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.black.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: "6-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.pink[300].value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.pink[300],
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.pink[300].value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: "7-$index",
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] = Colors.yellow.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.yellow,
                            shape: CircleBorder(
                              side: teams[index]["color"] == Colors.yellow.value.toRadixString(16)
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
                      SizedBox(height: 20),
                      RaisedButton(
                          onPressed: () {
                            setState(() {
                              teams.removeAt(index);
                              textControllers.removeAt(index);
                            });
                          },
                          padding: EdgeInsets.all(12),
                          child: Text("Delete this team", style: TextStyle(fontSize: 20)),
                          color: Colors.red,
                          textColor: Colors.white,
                          disabledColor: Colors.grey[800],
                          disabledTextColor: Colors.grey[700])
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            sending
                ? CircularProgressIndicator()
                : RaisedButton(
                    onPressed: () async {
                      setState(() => sending = true);
                      String url;
                      if (data["serverInLan"])
                        url = data["editRoom"] == true
                            ? "http://192.168.1.50:5050/api/v1/room/update"
                            : "http://192.168.1.50:5050/api/v1/room/create";
                      else
                        url = data["editRoom"] == true
                            ? "https://kacpermarcinkiewicz.com:5050/api/v1/room/update"
                            : "https://kacpermarcinkiewicz.com:5050/api/v1/room/create";

                      if (!validateData()) {
                        Fluttertoast.showToast(
                            msg: "One or more teams have empty name or unselected color or you don't create any team",
                            toastLength: Toast.LENGTH_LONG,
                            backgroundColor: Colors.red,
                            textColor: Colors.white);
                        setState(() => sending = false);
                        return;
                      } else {
                        Fluttertoast.showToast(
                          msg: data["editRoom"] == true ? "Updating room. Please wait" : "Creating room. Please wait",
                          toastLength: Toast.LENGTH_LONG,
                          backgroundColor: Colors.grey[700],
                          textColor: Colors.white,
                        );

                        try {
                          Response response;
                          if (data["editRoom"] == true) {
                            response = await patch(url, body: {
                              "roomID": data["roomID"].toString(),
                              "roomName": roomNameController.text,
                              "showEnemyTeam": showEnemyTeam.toString(),
                              "teams": json.encode(teams),
                              "hardwareID": data["hardwareID"]
                            }).timeout(Duration(seconds: 10));
                          } else {
                            response = await post(url, body: {
                              "roomName": roomNameController.text,
                              "showEnemyTeam": showEnemyTeam.toString(),
                              "ownerHardwareID": data["hardwareID"],
                              "teams": json.encode(teams)
                            }).timeout(Duration(seconds: 10));
                          }

                          if (response.statusCode == 200) {
                            var json = jsonDecode(response.body);

                            Fluttertoast.showToast(
                              msg: data["editRoom"] == true ? "Room updated!" : "Room created!",
                              toastLength: Toast.LENGTH_LONG,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                            );
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(
                              context,
                              '/roomsList',
                              arguments: {
                                "serverInLan": data["serverInLan"],
                                "nickname": data["nickname"],
                                "hardwareID": data["hardwareID"],
                                "searchBarText": "ID " +
                                    (data["editRoom"] == true ? data["roomID"].toString() : json["newRoomId"].toString()) +
                                    ": " +
                                    roomNameController.text
                              },
                            );
                            return;
                          } else {
                            Fluttertoast.showToast(
                                msg: data["editRoom"] == true
                                    ? "Error while updating room: ${jsonDecode(response.body)["message"]}"
                                    : "Error while creating room: ${jsonDecode(response.body)["message"]}",
                                toastLength: Toast.LENGTH_LONG,
                                backgroundColor: Colors.red,
                                textColor: Colors.white);
                            setState(() => sending = false);
                            return;
                          }
                        } catch (e) {
                          Fluttertoast.showToast(
                              msg: data["editRoom"] == true ? "Error while updating room: $e" : "Error while creating room: $e",
                              toastLength: Toast.LENGTH_LONG,
                              backgroundColor: Colors.red,
                              textColor: Colors.white);
                          setState(() => sending = false);
                          return;
                        }
                      }
                    },
                    padding: EdgeInsets.all(12),
                    child: Text(data["editRoom"] == true ? "Update room" : "Create room", style: TextStyle(fontSize: 20)),
                    color: Colors.lightGreen,
                    textColor: Colors.white,
                    disabledColor: Colors.grey[800],
                    disabledTextColor: Colors.grey[700],
                  ),
            SizedBox(height: 10),
            data["editRoom"] == true
                ? RaisedButton(
                    onPressed: () {
                      Dialogs.confirmDialog(
                        context,
                        titleText: "Delete room",
                        descriptionText: "Do you want to delete this room? This action cannot be undone!",
                        onSend: () async {
                          try {
                            Navigator.pop(context);
                            Fluttertoast.showToast(
                              msg: "Deleting room. Please wait",
                              toastLength: Toast.LENGTH_SHORT,
                              backgroundColor: Colors.grey[700],
                              textColor: Colors.white,
                            );
                            String url;
                            if (data["serverInLan"])
                              url = "http://192.168.1.50:5050/api/v1/room/${data["roomID"]}?hardwareID=${data["hardwareID"]}";
                            else
                              url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/${data["roomID"]}?hardwareID=${data["hardwareID"]}";

                            var response = await delete(url);

                            if (response.statusCode == 200) {
                              Fluttertoast.showToast(
                                msg: "Room deleted!",
                                toastLength: Toast.LENGTH_LONG,
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                              );
                            } else {
                              Fluttertoast.showToast(
                                msg: "Error while deleting room: ${jsonDecode(response.body)["message"]}",
                                toastLength: Toast.LENGTH_LONG,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                          } catch (e) {
                            Fluttertoast.showToast(
                              msg: "Error while deleting room: $e",
                              toastLength: Toast.LENGTH_LONG,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                          }
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                            context,
                            '/roomsList',
                            arguments: {
                              "serverInLan": data["serverInLan"],
                              "nickname": data["nickname"],
                              "hardwareID": data["hardwareID"],
                              "searchBarText": ""
                            },
                          );
                        },
                        onCancel: () {
                          Navigator.pop(context);
                        },
                      );
                    },
                    padding: EdgeInsets.all(12),
                    child: Text("Delete room", style: TextStyle(fontSize: 20)),
                    color: Colors.red,
                    textColor: Colors.white,
                    disabledColor: Colors.grey[800],
                    disabledTextColor: Colors.grey[700],
                  )
                : Container(),
            SizedBox(height: 10)
          ],
        ),
      ),
    );
  }
}
