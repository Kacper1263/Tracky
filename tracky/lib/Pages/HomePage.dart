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
import 'package:flutter_udid/flutter_udid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';
import 'package:tracky/StaticVariables.dart';

import '../Dialogs.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// -1 - Error (cant connect)
  ///
  ///  0 - Connecting
  ///
  ///  1 - Connected
  int serverConnectionStatus = 0;
  bool serverInLan = false;

  // Info from server
  String infoTitle = "";
  String infoMessage = "";
  String serverMinRequiredAppVersion = "0.0.0";

  @override
  void initState() {
    // Check server status
    checkServerStatus();

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => Dialogs.infoDialog(context,
            titleText: "IMPORTANT NOTE!",
            descriptionText: '''WARNING: This is beta version of this app, it may contain bugs etc.

You can scroll this page, if it does not fit on the screen.


We require you to provide us with certain personally identifiable information, including but not limited to user location, user nickname and hardware ID. This data will be deleted from our server (except hardware ID, it will be deleted when user delete it owned rooms) when the player leaves the room or will be inactive for 5 minutes (time is only checked when someone refreshes the list of rooms or will try to join the room).


For now app is working in background but this solution is still tested by me and may not work on some devices (if You have problem, let me know). Our roadmap is available on GitHub ( https://github.com/users/Kacper1263/projects/1 )  

By clicking agree and using this app you agree to privacy policy available on Google Play Store (on our app page).
              ''',
            okBtnText: "Ok, I agree!", onOkBtn: () {
          Navigator.pop(context);
        }));
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController nicknameController = new TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text("Tracky"),
        centerTitle: true,
        backgroundColor: Colors.grey[850],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => checkServerStatus(),
            tooltip: "Refresh connection",
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () => showAboutDialog(
              context: context,
              applicationIcon: GestureDetector(
                onLongPress: () async {
                  String hardwareID = await FlutterUdid.udid;
                  Dialogs.infoDialogWithWidgetBody(
                    context,
                    titleText: "Developer options",
                    descriptionWidgets: <Widget>[
                      SelectableText("Your hardware ID: $hardwareID", style: TextStyle(color: Colors.white)),
                      SizedBox(height: 20),
                      // Wrap(
                      //   crossAxisAlignment: WrapCrossAlignment.center,
                      //   children: [
                      //     Text("Enable map editor (preview) ", style: TextStyle(color: Colors.white)),
                      //     StatefulBuilder(
                      //       builder: (context, StateSetter setState) {
                      //         // Needed to change state of dialog
                      //         return Switch(
                      //           value: StaticVariables.mapEditor,
                      //           onChanged: (val) {
                      //             setState(() {
                      //               StaticVariables.mapEditor = val;
                      //             });
                      //           },
                      //         );
                      //       },
                      //     )
                      //   ],
                      // )
                    ],
                    okBtnText: "Close",
                    onOkBtn: () => Navigator.pop(context),
                  );
                },
                child: Image.asset(
                  "images/logo.png",
                  scale: 3,
                ),
              ),
              applicationName: "Tracky",
              applicationVersion: "${StaticVariables.version.appVersionCode}_beta",
              applicationLegalese:
                  "Tracky - ASG team tracker \nby Kacper Marcinkiewicz \n\nLicence: MIT \nSource on github: Kacper1263/tracky",
            ),
            tooltip: "About app",
          )
        ],
      ),
      body: Container(
        color: Colors.grey[900],
        padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: ListView(
          children: <Widget>[
            SizedBox(height: 40),
            //? Server status text
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15),
                  children: <TextSpan>[
                    TextSpan(text: "Server status: "),
                    TextSpan(
                        text: serverConnectionStatus == 1
                            ? "Online"
                            : serverConnectionStatus == 0
                                ? "Trying to connect to server"
                                : "Can't connect to server",
                        style: serverConnectionStatus == 1
                            ? TextStyle(color: Colors.lightGreen)
                            : serverConnectionStatus == 0
                                ? TextStyle(color: Colors.yellow)
                                : TextStyle(color: Colors.red))
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
            TextField(
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Colors.white),
              maxLength: 25,
              maxLengthEnforced: false,
              controller: nicknameController,
              decoration: InputDecoration(
                counterStyle: TextStyle(fontSize: 0),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                hintText: 'Enter your nickname',
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
            ),
            SizedBox(height: 12),
            RaisedButton(
              onPressed: serverConnectionStatus != 1 || !StaticVariables.version.isCompatible(serverMinRequiredAppVersion)
                  ? null
                  : () {
                      if (nicknameController.text.length > 25) {
                        Fluttertoast.showToast(
                            msg: "Nickname must contains less than 26 characters",
                            toastLength: Toast.LENGTH_LONG,
                            fontSize: 16,
                            backgroundColor: Colors.red,
                            textColor: Colors.white);

                        return;
                      }
                      if (nicknameController.text.isNotEmpty && nicknameController.text.length > 2) {
                        FlutterUdid.udid.then((udid) {
                          String hardwareID = udid;
                          Navigator.pushNamed(
                            context,
                            '/roomsList',
                            arguments: {
                              "serverInLan": serverInLan,
                              "nickname": nicknameController.text,
                              "hardwareID": hardwareID,
                            },
                          );
                        });
                      } else {
                        Fluttertoast.showToast(
                            msg: "Nickname must contains more than 2 characters",
                            toastLength: Toast.LENGTH_LONG,
                            fontSize: 16,
                            backgroundColor: Colors.red,
                            textColor: Colors.white);
                      }
                    },
              padding: EdgeInsets.all(12),
              child: Text("Server list", style: TextStyle(fontSize: 17)),
              color: Colors.grey[800],
              textColor: Colors.white,
              disabledColor: Colors.grey[800],
              disabledTextColor: Colors.grey[700],
            ),
            SizedBox(height: 15),
            StaticVariables.version.isCompatible(serverMinRequiredAppVersion)
                ? Container()
                : Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(7),
                      ),
                      color: Colors.red,
                    ),
                    child: Text(
                      "Your app version is not compatible with this server! Your app version is '${StaticVariables.version.appVersionCode}' but server requires '$serverMinRequiredAppVersion' or higher",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
            SizedBox(height: 85),
            infoTitle.isNotEmpty || infoMessage.isNotEmpty
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(7),
                      ),
                      color: Colors.grey[700],
                    ),
                    padding: EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(infoTitle, style: TextStyle(color: Colors.white, fontSize: 25)),
                        SizedBox(height: 15),
                        Text(infoMessage, style: TextStyle(color: Colors.white), textAlign: TextAlign.justify),
                      ],
                    ),
                  )
                : Container()
          ],
        ),
      ),
    );
  }

  void checkServerStatus() {
    setState(() {
      serverConnectionStatus = 0;
      infoTitle = "";
      infoMessage = "";
      serverMinRequiredAppVersion = "0.0.0";
    });

    get(
      "https://kacpermarcinkiewicz.com:5050/ping",
    ).timeout(Duration(seconds: 10)).then((response) {
      setState(() {
        if (response.statusCode == 200) {
          serverConnectionStatus = 1;
          serverInLan = false;

          var json = jsonDecode(response.body);
          infoTitle = json["title"];
          infoMessage = json["message"];
          serverMinRequiredAppVersion = json["minRequiredAppVersion"];
        }
      });
    }).catchError((e) {
      print(e);
      if (e.toString().contains("WRONG_VERSION_NUMBER")) {
        Fluttertoast.showToast(
            msg: "Cannot connect to the server. Probably the SSL certificate has expired. Please contact us at slowcast.dev@gmail.com.",
            toastLength: Toast.LENGTH_LONG,
            fontSize: 16,
            backgroundColor: Colors.red,
            textColor: Colors.white);
      }
      get(
        "http://192.168.1.50:5050/ping",
      ).timeout(Duration(seconds: 10)).then((r) {
        setState(() {
          if (r.statusCode == 200) {
            serverConnectionStatus = 1;
            serverInLan = true;

            var json = jsonDecode(r.body);
            infoTitle = json["title"];
            infoMessage = json["message"];
            serverMinRequiredAppVersion = json["minRequiredAppVersion"];
          } else
            serverConnectionStatus = -1;
        });
      }).catchError((er) {
        setState(() {
          serverConnectionStatus = -1;
        });
      });
    });
  }
}
