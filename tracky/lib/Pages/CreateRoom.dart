import 'package:flutter/material.dart';

class CreateRoom extends StatefulWidget {
  final Object arguments;

  CreateRoom({Key key, this.arguments});

  @override
  _CreateRoomState createState() => _CreateRoomState();
}

class _CreateRoomState extends State<CreateRoom> {
  TextEditingController serverNameController = new TextEditingController();
  List<TextEditingController> textControllers =
      new List<TextEditingController>();
  bool showEnemyTeam = false;
  List teams = [];

  void addTeam() {
    teams.add({
      "name": "",
      "color": "",
      "players": [],
    });
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
            Text("Server name ", style: TextStyle(color: Colors.white)),
            SizedBox(height: 5),
            TextField(
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Colors.white),
              controller: serverNameController,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[200])),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600])),
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[200])),
                hintText: 'Enter server name',
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
                Text("Teams: ",
                    style: TextStyle(color: Colors.white, fontSize: 20)),
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
                if (textControllers.length < teams.length)
                  textControllers.add(new TextEditingController());
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
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[200])),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600])),
                          border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[200])),
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
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] =
                                    Colors.green.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.green,
                            shape: CircleBorder(
                              side: teams[index]["color"] ==
                                      Colors.green.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] =
                                    Colors.red.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.red,
                            shape: CircleBorder(
                              side: teams[index]["color"] ==
                                      Colors.red.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] =
                                    Colors.blue.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.blue,
                            shape: CircleBorder(
                              side: teams[index]["color"] ==
                                      Colors.blue.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] =
                                    Colors.purple.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.purple,
                            shape: CircleBorder(
                              side: teams[index]["color"] ==
                                      Colors.purple.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] =
                                    Colors.black.value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.black,
                            shape: CircleBorder(
                              side: teams[index]["color"] ==
                                      Colors.black.value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                teams[index]["color"] =
                                    Colors.pink[300].value.toRadixString(16);
                              });
                            },
                            backgroundColor: Colors.pink[300],
                            shape: CircleBorder(
                              side: teams[index]["color"] ==
                                      Colors.pink[300].value.toRadixString(16)
                                  ? BorderSide(
                                      color: Colors.yellow,
                                      width: 3,
                                      style: BorderStyle.solid,
                                    )
                                  : BorderSide.none,
                            ),
                          )
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
                          child: Text("Delete this team",
                              style: TextStyle(fontSize: 20)),
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
            RaisedButton(
                onPressed: () {
                  print(textControllers.length);
                },
                padding: EdgeInsets.all(12),
                child: Text("Create room", style: TextStyle(fontSize: 20)),
                color: Colors.lightGreen,
                textColor: Colors.white,
                disabledColor: Colors.grey[800],
                disabledTextColor: Colors.grey[700])
          ],
        ),
      ),
    );
  }
}
