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
      width: 150.0,
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
      height: 80.0,
      point: this.location,
      builder: (ctx) => GestureDetector(
        onTap: onClick,
        child: Container(
          child: Column(
            children: [
              Container(
                child: OutlineText(this.text),
              ),
            ],
          ),
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
