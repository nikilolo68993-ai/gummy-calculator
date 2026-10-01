import 'package:flutter/material.dart';

@immutable
class Flavor {
  const Flavor({
    required this.name,
    required this.label,
    required this.accent,
    required this.light,
    required this.deep,
    required this.operatorColor,
    required this.orb,
  });
  final String name;
  final String label;
  final Color accent;
  final Color light;
  final Color deep;
  final Color operatorColor;
  final Color orb;

  static const ink = Color(0xFF3B3146);
  static const muted = Color(0xFF938997);
  static const paper = Color(0xFFFAF7F2);
  static const all = [
    Flavor(
      name: 'Ягодный',
      label: 'BERRY JELLY',
      accent: Color(0xFFE88396),
      light: Color(0xFFFFE4E9),
      deep: Color(0xFFA45168),
      operatorColor: Color(0xFFE1D4F2),
      orb: Color(0xFFBAA0E1),
    ),
    Flavor(
      name: 'Лавандовый',
      label: 'LAVENDER JELLY',
      accent: Color(0xFFA597DB),
      light: Color(0xFFEEE7FF),
      deep: Color(0xFF6B59A4),
      operatorColor: Color(0xFFD4E6EE),
      orb: Color(0xFFAAD7DD),
    ),
    Flavor(
      name: 'Мятный',
      label: 'MINT JELLY',
      accent: Color(0xFF80BFAA),
      light: Color(0xFFDEF3E8),
      deep: Color(0xFF477F6B),
      operatorColor: Color(0xFFF1DED3),
      orb: Color(0xFFE9B9A5),
    ),
  ];
}
