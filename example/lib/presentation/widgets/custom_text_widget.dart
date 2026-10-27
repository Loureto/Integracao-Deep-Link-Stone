import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  const CustomText._({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    this.color,
  });

  factory CustomText.small(String text, {fontWeight = FontWeight.w500, Color? color}) {
    return CustomText._(
      text: text,
      fontSize: 14.0,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
    );
  }

  factory CustomText.medium(String text, {fontWeight = FontWeight.w500, Color? color}) {
    return CustomText._(
      text: text,
      fontSize: 16.0,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
    );
  }

  factory CustomText.large(String text, {fontWeight = FontWeight.bold, Color? color}) {
    return CustomText._(
      text: text,
      fontSize: 18.0,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}
