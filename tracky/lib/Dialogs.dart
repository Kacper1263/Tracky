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

import 'package:flutter/material.dart';

class Dialogs {
  static oneInputDialog(TextEditingController textCtrl, context,
      {titleText, descriptionText, hintText, onCancel, onSend, sendText: "Send", cancelText: "Cancel"}) {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[800],
            title: Center(child: Text(titleText, style: TextStyle(color: Colors.white))),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(descriptionText, style: TextStyle(color: Colors.white)),
                  SizedBox(height: 20),
                  TextField(
                    keyboardType: TextInputType.visiblePassword,
                    style: TextStyle(color: Colors.white),
                    controller: textCtrl,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600])),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200])),
                      hintText: hintText,
                      hintStyle: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(cancelText, style: TextStyle(color: Colors.white)),
                onPressed: onCancel,
              ),
              FlatButton(
                child: Text(
                  sendText,
                  style: TextStyle(color: Colors.white),
                ),
                color: Colors.lightGreen,
                onPressed: onSend,
              )
            ],
          );
        });
  }

  static confirmDialog(context, {titleText, descriptionText, onCancel, onSend}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Center(child: Text(titleText, style: TextStyle(color: Colors.white))),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(descriptionText, style: TextStyle(color: Colors.white)),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text(
                "No",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: onCancel,
            ),
            FlatButton(
              child: Text(
                "Yes",
                style: TextStyle(color: Colors.white),
              ),
              color: Colors.lightGreen,
              onPressed: onSend,
            )
          ],
        );
      },
    );
  }

  static infoDialog(context, {titleText, descriptionText, onOkBtn, String okBtnText}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Center(child: Text(titleText, style: TextStyle(color: Colors.white))),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                SelectableText(descriptionText, style: TextStyle(color: Colors.white)),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text(
                okBtnText,
                style: TextStyle(color: Colors.white),
              ),
              color: Colors.lightGreen,
              onPressed: onOkBtn,
            )
          ],
        );
      },
    );
  }

  static infoDialogWithWidgetBody(context, {titleText, List<Widget> descriptionWidgets, onOkBtn, String okBtnText}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        descriptionWidgets.add(SizedBox(height: 20));
        return AlertDialog(
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          insetPadding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          backgroundColor: Colors.grey[800],
          title: Center(child: Text(titleText, style: TextStyle(color: Colors.white))),
          content: Container(
            width: double.maxFinite, // This will fix errors while adding ListView.builder as a child
            child: SingleChildScrollView(
              child: ListBody(
                children: descriptionWidgets,
              ),
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text(
                okBtnText,
                style: TextStyle(color: Colors.white),
              ),
              color: Colors.lightGreen,
              onPressed: onOkBtn,
            )
          ],
        );
      },
    );
  }

  static loadingDialog(context, {titleText, descriptionText}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () {},
          child: AlertDialog(
            backgroundColor: Colors.grey[800],
            title: Center(child: Text(titleText, style: TextStyle(color: Colors.white))),
            content: SingleChildScrollView(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 20, 0),
                    child: CircularProgressIndicator(),
                  ),
                  Flexible(child: Text(descriptionText, style: TextStyle(color: Colors.white))),
                ],
              ),
            )),
          ),
        );
      },
    );
  }
}
