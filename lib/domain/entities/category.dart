import 'package:flutter/material.dart';

import 'json_helpers.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.colorValue,
    required this.icon,
    this.active = true,
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final IconData icon;
  final bool active;

  Color get color => Color(colorValue);

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    IconData? icon,
    bool? active,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'iconCodePoint': icon.codePoint,
      'active': active,
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFF607A5A).toARGB32(),
      icon: iconFromCodePoint(json['iconCodePoint'], Icons.label_rounded),
      active: json['active'] as bool? ?? true,
    );
  }
}
