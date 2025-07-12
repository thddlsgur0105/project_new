import 'package:flutter/material.dart';

class Study {
  final int index;
  final String title;
  final String description;
  final String descriptionMore;
  final String author;
  final List<Map<String, dynamic>> comments;

  Study({
    required this.index,
    required this.title,
    required this.description,
    required this.descriptionMore,
    required this.author,
    required this.comments,
  });

  // JSON Map에서 Study 객체를 생성하는 팩토리 생성자
  factory Study.fromJson(Map<String, dynamic> json) {
    return Study(
      index: json['study_index'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      descriptionMore: json['description_more'] as String,
      author: json['author'] as String,
      comments: List<Map<String, dynamic>>.from(json['comments'] ?? []),
    );
  }

  // Study 객체를 JSON Map으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'study_index': index,
      'title': title,
      'description': description,
      'description_more': descriptionMore,
      'author': author,
      'comments': comments,
    };
  }
}
