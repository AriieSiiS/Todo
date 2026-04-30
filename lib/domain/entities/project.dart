import 'package:flutter/material.dart';

import 'enums.dart';
import 'json_helpers.dart';

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.colorValue,
    required this.icon,
    this.status = ProjectStatus.active,
    this.categoryIds = const <String>[],
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final IconData icon;
  final ProjectStatus status;
  final List<String> categoryIds;

  Color get color => Color(colorValue);

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    IconData? icon,
    ProjectStatus? status,
    List<String>? categoryIds,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'iconCodePoint': icon.codePoint,
      'status': status.name,
      'categoryIds': categoryIds,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFF607A5A).toARGB32(),
      icon: iconFromCodePoint(json['iconCodePoint'], Icons.folder_open_rounded),
      status: enumByName(ProjectStatus.values, json['status'] as String?,
          ProjectStatus.active),
      categoryIds: stringList(json['categoryIds']),
    );
  }
}
