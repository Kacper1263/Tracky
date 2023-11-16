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

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    required this.onColorChanged,
    this.oldColor = null,
    this.heroTagOffset = -1,
  });

  final ColorSelectedCallback onColorChanged;

  /// Initial color - default null
  final Color? oldColor;

  /// Optional - set this if you are using more than one [ColorPicker]. Just increment the number starting from 0 so if you are adding second [ColorPicker] set this to 0
  final int heroTagOffset;

  @override
  _ColorPickerState createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  Color? selectedColor;

  @override
  initState() {
    setState(() {
      selectedColor = widget.oldColor;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 10,
      children: [
        FloatingActionButton(
          heroTag: "1-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.green);
            setState(() => selectedColor = Colors.green);
          },
          backgroundColor: Colors.green,
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.green.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.yellow,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
        FloatingActionButton(
          heroTag: "2-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.red);
            setState(() => selectedColor = Colors.red);
          },
          backgroundColor: Colors.red,
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.red.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.yellow,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
        FloatingActionButton(
          heroTag: "3-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.blue);
            setState(() => selectedColor = Colors.blue);
          },
          backgroundColor: Colors.blue,
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.blue.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.yellow,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
        FloatingActionButton(
          heroTag: "4-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.purple);
            setState(() => selectedColor = Colors.purple);
          },
          backgroundColor: Colors.purple,
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.purple.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.yellow,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
        FloatingActionButton(
          heroTag: "5-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.black);
            setState(() => selectedColor = Colors.black);
          },
          backgroundColor: Colors.black,
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.black.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.yellow,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
        FloatingActionButton(
          heroTag: "6-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.pink[300]!);
            setState(() => selectedColor = Colors.pink[300]);
          },
          backgroundColor: Colors.pink[300],
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.pink[300]!.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.yellow,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
        FloatingActionButton(
          heroTag: "7-color-${widget.heroTagOffset}",
          onPressed: () {
            widget.onColorChanged(Colors.yellow);
            setState(() => selectedColor = Colors.yellow);
          },
          backgroundColor: Colors.yellow,
          shape: CircleBorder(
            side: selectedColor?.value.toRadixString(16) == Colors.yellow.value.toRadixString(16)
                ? BorderSide(
                    color: Colors.red,
                    width: 3,
                    style: BorderStyle.solid,
                  )
                : BorderSide.none,
          ),
        ),
      ],
    );
  }
}

typedef ColorSelectedCallback = void Function(Color color);
