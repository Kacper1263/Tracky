import 'package:flutter/material.dart';

class OutlineText extends StatefulWidget {
  final String text;
  final Color textColor;
  final Color outlineColor;
  final double fontSize;
  final double outlineThickness;

  const OutlineText(
    this.text, {
    this.textColor = Colors.white,
    this.outlineColor = Colors.black,
    this.fontSize = 18,
    this.outlineThickness = 2,
  });

  @override
  _OutlineTextState createState() => _OutlineTextState();
}

class _OutlineTextState extends State<OutlineText> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Outline
        Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = widget.outlineThickness
              ..color = widget.outlineColor,
          ),
        ),
        // Main text
        Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: widget.textColor,
          ),
        ),
      ],
    );
  }
}
