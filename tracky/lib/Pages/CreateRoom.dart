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
import 'dart:io';
import 'dart:typed_data';
import 'package:binary_codec/binary_codec.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tracky/Classes.dart';
import 'package:tracky/CustomWidgets/ColorPicker.dart';
import 'package:tracky/Dialogs.dart';
import 'package:tracky/GlobalFunctions.dart';
import 'package:uuid/uuid.dart';

import '../StaticVariables.dart';

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
  List<TextEditingController> teamPasswordControllers = new List<TextEditingController>();
  bool showEnemyTeam = false;
  bool sending = false;
  List teams = [];

  @override
  void initState() {
    data = widget.arguments;
    if (data["editRoom"] == true) {
      roomNameController.text = data["roomName"].toString();
      showEnemyTeam = data["showEnemyTeam"] == "true";
      List<dynamic> _teams = data["teams"];
      for (int i = 0; i < _teams.length; i++) {
        try {
          teams.add({
            "id": _teams[i]["id"].toString(),
            "name": _teams[i]["name"].toString(),
            "color": _teams[i]["color"],
            "players": [],
            "canSeeEveryone": _teams[i]["canSeeEveryone"] ?? "false",
            "showForEveryone": _teams[i]["showForEveryone"] ?? "false",
            "passwordRequired": _teams[i]["passwordRequired"] ?? "false",
            "teamPassword": "",
          });
        } catch (e) {
          showErrorToast(
            "Error while loading team data: $e",
          );
        }
      }
    }

    super.initState();
  }

  void addTeam() {
    HapticFeedback.vibrate();
    teams.add({
      "id": Uuid().v4().toString(),
      "name": "",
      "color": null,
      "players": [],
      "canSeeEveryone": "false",
      "showForEveryone": "false",
      "passwordRequired": "false",
      "teamPassword": "",
    });
  }

  bool validateTeamColors() {
    bool noProblems = true;

    teams.forEach((team) {
      if (team["color"].toString().isEmpty || team["color"] == null) {
        noProblems = false;
        return false;
      }
    });

    return noProblems;
  }

  bool validateTeamNameNotEmpty() {
    bool noProblems = true;

    teams.forEach((team) {
      if (team["name"].toString().isEmpty) {
        noProblems = false;
        return false;
      }
    });

    return noProblems;
  }

  bool validateTeamNamesLength() {
    bool noProblems = true;

    if (teams.length < 1) noProblems = false;

    teams.forEach((team) {
      if (team["name"].toString().length > 35) {
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
        title: const Text("Tracky"),
        centerTitle: true,
        backgroundColor: Colors.grey[850],
      ),
      body: Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: ListView(
          children: [
            SizedBox(height: 15),
            RaisedButton(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(data["editRoom"] == true ? Icons.save : Icons.input),
                  SizedBox(width: 10),
                  Text(data["editRoom"] == true ? "Export room" : "Import room", style: TextStyle(fontSize: 20))
                ],
              ),
              color: Colors.blueGrey,
              textColor: Colors.white,
              disabledColor: Colors.grey[800],
              disabledTextColor: Colors.grey[700],
              onPressed: () {
                data["editRoom"] == true ? exportRoom() : importRoom();
              },
            ),
            SizedBox(height: 25),
            const Text("Room name ", style: TextStyle(color: Colors.white)),
            SizedBox(height: 5),
            TextField(
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Colors.white),
              maxLength: 40,
              maxLengthEnforced: false,
              controller: roomNameController,
              decoration: InputDecoration(
                counterStyle: TextStyle(fontSize: 0),
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
                const Text("Show enemy team ", style: TextStyle(color: Colors.white)),
              ],
            ),
            SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Teams: ", style: TextStyle(color: Colors.white, fontSize: 20)),
                IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        addTeam();
                      });
                    })
              ],
            ),
            const Divider(color: Colors.white, indent: 8, endIndent: 8),
            SizedBox(height: 15),
            ListView.builder(
              itemCount: teams.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                if (textControllers.length < teams.length) textControllers.add(new TextEditingController());
                if (teamPasswordControllers.length < teams.length) teamPasswordControllers.add(new TextEditingController());
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
                        style: const TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ),
                    children: [
                      TextField(
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        controller: textControllers[index],
                        style: TextStyle(color: Colors.white),
                        maxLength: 35,
                        maxLengthEnforced: false,
                        decoration: InputDecoration(
                          counterStyle: TextStyle(fontSize: 0),
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
                        child: const Text(
                          "Team password (optional - can be empty)",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 15),
                      teams[index]["passwordRequired"] == "false"
                          ? TextField(
                              keyboardType: TextInputType.visiblePassword,
                              textCapitalization: TextCapitalization.none,
                              controller: teamPasswordControllers[index],
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
                                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                                hintText: 'Leave empty if no password',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  teams[index]["teamPassword"] = value;
                                });
                              },
                            )
                          : RaisedButton(
                              padding: EdgeInsets.all(12),
                              child: const Text("Delete old team password", style: TextStyle(fontSize: 20)),
                              color: Colors.blueGrey,
                              textColor: Colors.white,
                              disabledColor: Colors.grey[800],
                              disabledTextColor: Colors.grey[700],
                              onPressed: () {
                                Dialogs.confirmDialog(
                                  context,
                                  titleText: "Info about passwords",
                                  descriptionText:
                                      "All teams passwords stored on server are encrypted so if you want to change password first you must delete it. This action will delete old password. Continue?",
                                  onCancel: () {
                                    Navigator.pop(context);
                                  },
                                  onSend: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      teams[index]["passwordRequired"] = "false";
                                    });
                                  },
                                );
                              },
                            ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Switch(
                            value: teams[index]["canSeeEveryone"] == "true",
                            inactiveTrackColor: Colors.grey[800],
                            onChanged: (value) {
                              setState(() {
                                teams[index]["canSeeEveryone"] = value.toString();
                              });
                            },
                          ),
                          Expanded(child: const Text("Can see everyone ", style: TextStyle(color: Colors.white))),
                        ],
                      ),
                      Row(
                        children: [
                          Switch(
                            value: teams[index]["showForEveryone"] == "true",
                            inactiveTrackColor: Colors.grey[800],
                            onChanged: (value) {
                              setState(() {
                                teams[index]["showForEveryone"] = value.toString();
                              });
                            },
                          ),
                          Expanded(child: const Text("Can be seen by everyone ", style: TextStyle(color: Colors.white))),
                        ],
                      ),
                      SizedBox(height: 15),
                      Center(
                        child: const Text(
                          "Select team color",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 15),
                      ColorPicker(
                        heroTagOffset: index,
                        oldColor: teams[index]["color"] == null ? null : HexColor(teams[index]["color"]),
                        onColorChanged: (color) {
                          setState(() {
                            teams[index]["color"] = color.value.toRadixString(16);
                          });
                        },
                      ),
                      SizedBox(height: 20),
                      RaisedButton(
                          onPressed: () {
                            setState(() {
                              teams.removeAt(index);
                              textControllers.removeAt(index);
                              teamPasswordControllers.removeAt(index);
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
                      if (roomNameController.text.length > 40) {
                        showErrorToast(
                          "Room name length must be lower than 41",
                        );
                        return;
                      } else if (roomNameController.text.length <= 3) {
                        showErrorToast(
                          "Room name length must be higher than 3",
                        );
                        return;
                      }
                      setState(() => sending = true);
                      String url;
                      if (data["serverInLan"])
                        url = data["editRoom"] == true
                            ? "http://${StaticVariables.lanServerIp}:5050/api/v1/room/update"
                            : "http://${StaticVariables.lanServerIp}:5050/api/v1/room/create";
                      else
                        url = data["editRoom"] == true
                            ? "https://kacpermarcinkiewicz.com:5050/api/v1/room/update"
                            : "https://kacpermarcinkiewicz.com:5050/api/v1/room/create";

                      if (teams.length <= 0) {
                        showErrorToast(
                          "You need to create one or more teams",
                        );
                        setState(() => sending = false);
                        return;
                      } else if (!validateTeamNameNotEmpty()) {
                        showErrorToast(
                          "One or more teams have empty name",
                        );
                        setState(() => sending = false);
                        return;
                      } else if (!validateTeamNamesLength()) {
                        showErrorToast(
                          "One or more teams have name longer than 35",
                        );
                        setState(() => sending = false);
                        return;
                      } else if (!validateTeamColors()) {
                        showErrorToast(
                          "One or more teams have unselected color",
                        );
                        setState(() => sending = false);
                        return;
                      } else {
                        showInfoToast(
                          data["editRoom"] == true ? "Updating room. Please wait" : "Creating room. Please wait",
                        );

                        // Hash passwords before sending if needed
                        try {
                          teams.forEach((team) {
                            if (team["teamPassword"].toString().isNotEmpty) {
                              var plainTextPassword = team["teamPassword"];
                              var bytes = utf8.encode(plainTextPassword);
                              var hashedPassword = sha256.convert(bytes).toString();
                              team["teamPassword"] = hashedPassword;
                              team["passwordRequired"] = "true";
                            } else if (team["passwordRequired"] != "true") {
                              team["passwordRequired"] = "false";
                            }
                          });
                        } catch (e) {
                          showErrorToast(
                            "Error while hashing team password. $e",
                          );
                          setState(() => sending = false);
                          return;
                        }

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

                            showSuccessToast(
                              data["editRoom"] == true ? "Room updated!" : "Room created!",
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
                            showErrorToast(
                              data["editRoom"] == true
                                  ? "Error while updating room: ${jsonDecode(response.body)["message"]}"
                                  : "Error while creating room: ${jsonDecode(response.body)["message"]}",
                            );
                            setState(() => sending = false);
                            return;
                          }
                        } catch (e) {
                          showErrorToast(
                            data["editRoom"] == true ? "Error while updating room: $e" : "Error while creating room: $e",
                          );
                          setState(() => sending = false);
                          return;
                        }
                      }
                    },
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(data["editRoom"] == true ? "Update room" : "Create room", style: TextStyle(fontSize: 20)),
                        data["editRoom"] == true
                            ? Text("NOTE: Updating room will kick all players", style: TextStyle(fontSize: 14))
                            : Container(),
                      ],
                    ),
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
                            Dialogs.loadingDialog(
                              context,
                              titleText: "Delete room",
                              descriptionText: "Deleting room. Please wait...",
                            );
                            String url;
                            if (data["serverInLan"])
                              url =
                                  "http://${StaticVariables.lanServerIp}:5050/api/v1/room/${data["roomID"]}?hardwareID=${data["hardwareID"]}";
                            else
                              url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/${data["roomID"]}?hardwareID=${data["hardwareID"]}";

                            var response = await delete(url);

                            if (response.statusCode == 200) {
                              Navigator.pop(context); // Pop loading
                              showSuccessToast(
                                "Room deleted!",
                              );
                            } else {
                              Navigator.pop(context); // Pop loading
                              showErrorToast(
                                "Error while deleting room: ${jsonDecode(response.body)["message"]}",
                              );
                            }
                          } catch (e) {
                            Navigator.pop(context); // Pop loading
                            showErrorToast(
                              "Error while deleting room: $e",
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

  /// Save room data on device
  exportRoom() async {
    String url;
    if (data["serverInLan"])
      url = "http://${StaticVariables.lanServerIp}:5050/api/v1/room/export/${data["roomID"]}";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/export/${data["roomID"]}";

    Dialogs.loadingDialog(
      context,
      titleText: "Export room",
      descriptionText: "Downloading room data. Please wait...",
    );

    try {
      Response response;
      response = await get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        Navigator.pop(context); // Pop loading

        // Check permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
          status = await Permission.storage.status;
          if (!status.isGranted) {
            showErrorToast(
              "Cannot save file without permission!",
            );
            return;
          }
        }

        String path = await FilePicker.platform.getDirectoryPath();
        // await FilesystemPicker.open(
        //   title: 'Save to folder',
        //   context: context,
        //   rootDirectory: Directory((await getApplicationDocumentsDirectory()).toString()),
        //   //rootDirectory: Directory("/storage/emulated/0/"),
        //   fsType: FilesystemType.folder,
        //   pickText: 'Save file to this folder',
        //   folderIconColor: Colors.teal,
        // );
        if (path == null) return;

        path = path + "/${json["room"]["name"]} ${DateTime.now().millisecondsSinceEpoch}.trd"; //? trd - Tracky Room Data :)

        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        var dataToSave = {};
        dataToSave["room"] = json["room"];
        var encodedJson = encoder.convert(dataToSave);

        var binDataToSave = binaryCodec.encode(encodedJson);
        if (encodedJson.toString() != binaryCodec.decode(binDataToSave).toString()) {
          showErrorToast(
            "Error while creating save file. Data mismatch",
          );
        }

        File file = File(path);
        await file.writeAsString(binDataToSave.toString());

        Navigator.pop(context);
        Navigator.pushReplacementNamed(
          context,
          '/roomsList',
          arguments: {
            "serverInLan": data["serverInLan"],
            "nickname": data["nickname"],
            "hardwareID": data["hardwareID"],
            "searchBarText": "ID " + data["roomID"].toString() + ": " + data["roomName"].toString()
          },
        );
        showSuccessToast(
          "Room exported to: " + path,
        );
        return;
      } else {
        Navigator.pop(context); // Pop loading
        showErrorToast(
          "Error while creating room: ${jsonDecode(response.body)["message"]}",
        );
        return;
      }
    } catch (e) {
      Navigator.pop(context); // Pop loading
      showErrorToast(
        "Error while creating room: $e",
      );
      return;
    }
  }

  /// Load room data from device
  importRoom() async {
    // Check permission
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
      status = await Permission.storage.status;
      if (!status.isGranted) {
        showErrorToast(
          "Cannot save file without permission!",
        );
        return;
      }
    }

    String path =
        (await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['trd', 'txt', 'bin']))?.files?.single?.path;
    // await FilesystemPicker.open(
    //   title: 'Open file',
    //   context: context,
    //   rootDirectory: Directory((await getExternalStorageDirectory()).toString()),
    //   // rootDirectory: Directory("/storage/emulated/0/Download/"),
    //   fsType: FilesystemType.file,
    //   folderIconColor: Colors.teal,
    //   allowedExtensions: ['.trd'],
    //   fileTileSelectMode: FileTileSelectMode.wholeTile,
    // );

    if (path == null) return;

    String url;
    if (data["serverInLan"])
      url = "http://${StaticVariables.lanServerIp}:5050/api/v1/room/import/new";
    else
      url = "https://kacpermarcinkiewicz.com:5050/api/v1/room/import/new";

    Dialogs.loadingDialog(
      context,
      titleText: "Import room",
      descriptionText: "Sending room data. Please wait...",
    );

    try {
      File file = File(path);
      dynamic fileString = await file.readAsString();

      var fileContent;
      try {
        fileContent = json.decode(
          binaryCodec.decode(
            Uint8List.fromList(
              List<int>.from(
                json.decode(fileString), //decode string to List<dynamic>
              ), // List<dynamic> to List<int>
            ),
          ),
        );
      } catch (e) {
        showErrorToast(
          "Error. This file is not valid room save",
        );
        Navigator.pop(context); // pop loading
        return;
      }

      var _body = {};
      _body["room"] = fileContent["room"];
      _body["ownerHardwareID"] = data["hardwareID"];

      var response = await dio.Dio().post(url, data: _body).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        var json = response.data;

        Navigator.pop(context); // Pop loading
        showSuccessToast(
          "Room created!",
        );
        Navigator.pop(context);
        Navigator.pushReplacementNamed(
          context,
          '/roomsList',
          arguments: {
            "serverInLan": data["serverInLan"],
            "nickname": data["nickname"],
            "hardwareID": data["hardwareID"],
            "searchBarText": "ID " + (json["newRoomId"].toString()) + ": " + json["newRoomName"].toString()
          },
        );
        return;
      } else {
        Navigator.pop(context); // Pop loading
        showErrorToast(
          "Error while creating room: ${jsonDecode(response.data)["message"]}",
        );
        return;
      }
    } catch (e) {
      Navigator.pop(context); // Pop loading
      showErrorToast(
        "Error while creating room: $e",
      );
      return;
    }
  }
}
