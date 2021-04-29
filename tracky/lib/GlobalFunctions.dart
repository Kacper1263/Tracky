import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

showErrorToast(message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    backgroundColor: Colors.red,
    textColor: Colors.white,
  );
}

/// Shows green success toast
showSuccessToast(message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    backgroundColor: Colors.lightGreen,
    textColor: Colors.white,
  );
}

showInfoToast(message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    backgroundColor: Colors.grey[700],
    textColor: Colors.white,
  );
}
