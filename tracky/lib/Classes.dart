import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import "package:latlong/latlong.dart";

import 'CustomWidgets/OutlineText.dart';

class Player {
  String name;
  Color color;
  LatLng location;

  Player({
    this.name,
    this.color,
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
              Icons.radio_button_checked,
              color: this.color,
              size: 35,
            ),
          ],
        ),
      ),
    );
  }
}
