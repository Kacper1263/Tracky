import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';

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

  @override
  void initState() {
    // Check server status
    checkServerStatus();

    super.initState();
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
              controller: nicknameController,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[200])),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600])),
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[200])),
                hintText: 'Enter your nickname',
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
            ),
            SizedBox(height: 12),
            RaisedButton(
                onPressed: serverConnectionStatus != 1
                    ? null
                    : () {
                        if (nicknameController.text.isNotEmpty &&
                            nicknameController.text.length > 2) {
                          Navigator.pushNamed(
                            context,
                            '/roomsList',
                            arguments: {
                              "serverInLan": serverInLan,
                              "nickname": nicknameController.text
                            },
                          );
                        } else {
                          Fluttertoast.showToast(
                              msg:
                                  "Nickname must contains more than 2 characters",
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
                disabledTextColor: Colors.grey[700])
          ],
        ),
      ),
    );
  }

  void checkServerStatus() {
    setState(() => serverConnectionStatus = 0);

    get(
      "http://kacpermarcinkiewicz.com:5050/",
    ).timeout(Duration(seconds: 10)).then((response) {
      setState(() {
        if (response.statusCode == 200) {
          serverConnectionStatus = 1;
          serverInLan = false;
        }
      });
    }).catchError((e) {
      get(
        "http://192.168.1.50:5050/",
      ).timeout(Duration(seconds: 10)).then((r) {
        setState(() {
          if (r.statusCode == 200) {
            serverConnectionStatus = 1;
            serverInLan = true;
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
