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

import 'package:flutter/material.dart';
import 'package:tracky/Pages/CreateRoom.dart';
import 'package:tracky/Pages/HomePage.dart';
import 'package:tracky/Pages/RoomsList.dart';

import 'Pages/GamePage.dart';

void main() {
  runApp(MaterialApp(
    title: 'Tracky',
    color: Colors.grey[850],
    theme: ThemeData(
      primarySwatch: Colors.blue,
      // This makes the visual density adapt to the platform that you run
      // the app on. For desktop platforms, the controls will be smaller and
      // closer together (more dense) than on mobile platforms.
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: TextTheme(
        bodyText1: TextStyle(color: Colors.white),
      ),
    ),
    initialRoute: '/',
    onGenerateRoute: (RouteSettings settings) {
      print('build route for ${settings.name}');
      var routes = <String, WidgetBuilder>{
        '/': (context) => HomePage(),
        '/roomsList': (context) => RoomsList(arguments: settings.arguments),
        '/gamePage': (context) =>
            GamePage(title: "Tracky", arguments: settings.arguments),
        '/createRoom': (context) => CreateRoom(arguments: settings.arguments),
      };
      WidgetBuilder builder = routes[settings.name];
      return MaterialPageRoute(builder: (ctx) => builder(ctx));
    },
  ));
}
