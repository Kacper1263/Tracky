import 'package:flutter/material.dart';
import 'package:tracky/Pages/HomePage.dart';
import 'package:tracky/Pages/RoomsList.dart';

import 'Pages/GamePage.dart';

// class MyHttpOverrides extends HttpOverrides {
//   @override
//   HttpClient createHttpClient(SecurityContext securityContext) {
//     return new HttpClient()
//       ..badCertificateCallback =
//           (X509Certificate cert, String host, int port) => true;
//   }
// }

void main() {
  //HttpOverrides.global = new MyHttpOverrides(); // Fix cert errors
  runApp(MaterialApp(
    title: 'Tracky',
    theme: ThemeData(
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          bodyText1: TextStyle(color: Colors.white),
          bodyText2: TextStyle(color: Colors.white),
        )),
    initialRoute: '/',
    // routes: {
    //   '/': (context) => HomePage(),
    //   '/roomsList': (context) => RoomsList(),
    //   '/gamePage': (context) => GamePage(title: "Tracky"),
    // },
    onGenerateRoute: (RouteSettings settings) {
      print('build route for ${settings.name}');
      var routes = <String, WidgetBuilder>{
        '/': (context) => HomePage(),
        '/roomsList': (context) => RoomsList(arguments: settings.arguments),
        '/gamePage': (context) =>
            GamePage(title: "Tracky", arguments: settings.arguments),
      };
      WidgetBuilder builder = routes[settings.name];
      return MaterialPageRoute(builder: (ctx) => builder(ctx));
    },
  ));
}
