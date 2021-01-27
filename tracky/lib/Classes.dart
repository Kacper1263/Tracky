import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import "package:latlong/latlong.dart";

import 'CustomWidgets/OutlineText.dart';

class Player {
  String name;
  Color color;
  String icon;
  LatLng location;

  Player({
    this.name,
    this.color,
    this.icon,
    this.location,
  });

  Marker getMarker() {
    return Marker(
      width: 350.0,
      height: 80.0,
      point: this.location,
      builder: (ctx) => Container(
        child: Column(
          children: [
            Container(
              child: OutlineText(this.name),
            ),
            Icon(
              NamedIcons.getIconByName(this.icon),
              color: this.color,
              size: 35,
            ),
          ],
        ),
      ),
    );
  }
}

class NamedPolygon {
  String name;
  Polygon polygon;
  Color color;

  NamedPolygon({
    this.name,
    this.polygon,
    this.color,
  });
}

class TextMarker {
  String text;
  LatLng location;
  Function onClick = null;

  TextMarker({this.text, this.location, this.onClick});

  Marker getMarker() {
    return Marker(
      width: 200.0,
      height: 1000.0,
      point: this.location,
      builder: (ctx) => GestureDetector(
        onTap: onClick,
        child: Center(
          child: OutlineText(this.text),
        ),
      ),
    );
  }
}

class ClickableMapObject {
  String name;
  dynamic object;

  ClickableMapObject({
    this.name,
    this.object,
  });
}

class ServerRoom {
  int id;
  String name;
  String expiresAt;
  List<ServerTeam> teams;

  ServerRoom({
    this.id,
    this.name,
    this.expiresAt,
    this.teams,
  });
}

class ServerTeam {}

class NamedIcons {
  static var icons = <String, IconData>{
    "thisPlayer": Icons.arrow_drop_down_circle,
    "normal": Icons.radio_button_checked,
    "enemy": Icons.radio_button_unchecked,
    "dead": Icons.sentiment_very_dissatisfied,
  };

  static IconData getIconByName(final String iconName) {
    return icons[iconName];
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}

enum ChatMessageType {
  RECEIVED,
  SENT,
  INFO_CONNECTED,
  INFO_DISCONNECTED_OR_ERROR,
  OTHER,
}

class ChatMessage {
  final isGlobal;
  final ChatMessageType type;
  final String message;
  final String author;
  final String teamName;
  final Color teamColor;

  ChatMessage(this.type, this.message, {this.author, this.teamName, this.teamColor, this.isGlobal = false});
}

class MessageCard extends StatefulWidget {
  final String author;
  final String message;
  final bool isGlobal;
  final ChatMessageType type;
  final String teamName;
  final Color teamColor;

  const MessageCard({
    Key key,
    @required this.author,
    @required this.message,
    @required this.isGlobal,
    @required this.type,
    @required this.teamName,
    @required this.teamColor,
  }) : super(key: key);

  @override
  _MessageCardState createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      decoration: BoxDecoration(
        color: widget.author != null ? Colors.grey[800] : Colors.grey[900],
        borderRadius: new BorderRadius.all(
          const Radius.circular(10.0),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: widget.author != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Global/Team icon
                    widget.type == ChatMessageType.SENT || widget.type == ChatMessageType.RECEIVED
                        ? Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: Icon(widget.isGlobal ? Icons.public : Icons.public_off, color: Colors.blueGrey[300], size: 20),
                          )
                        : SizedBox.shrink(),

                    // Team
                    Text(
                      "[${widget.teamName}]",
                      style: TextStyle(color: widget.teamColor, fontSize: 14),
                    ),

                    // Author //? Expanded and overflow are for overflow protection on smaller devices
                    Expanded(
                      child: Text(
                        " - " + widget.author,
                        style: TextStyle(color: Colors.blueGrey[300], fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: widget.type == ChatMessageType.INFO_CONNECTED
                          ? Colors.green
                          : widget.type == ChatMessageType.INFO_DISCONNECTED_OR_ERROR
                              ? Colors.red
                              : widget.type == ChatMessageType.OTHER
                                  ? Colors.blue
                                  : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            )
          //? System messages like connected
          : Row(
              children: [
                //? Expanded will fix text overflow
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.type == ChatMessageType.INFO_CONNECTED
                          ? Colors.green
                          : widget.type == ChatMessageType.INFO_DISCONNECTED_OR_ERROR
                              ? Colors.red
                              : widget.type == ChatMessageType.OTHER
                                  ? Colors.blue
                                  : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
