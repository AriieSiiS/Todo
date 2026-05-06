import 'package:flutter/material.dart';

import 'enums.dart';
import 'json_helpers.dart';

class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.concept,
    required this.amount,
    required this.categoryId,
    this.paymentMethodId,
    this.projectIds = const <String>[],
    this.note,
    this.isRecurringInstance = false,
    this.fixedPaymentId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime date;
  final String concept;
  final double amount;
  final String categoryId;
  final String? paymentMethodId;
  final List<String> projectIds;
  final String? note;
  final bool isRecurringInstance;
  final String? fixedPaymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense copyWith({
    String? id,
    DateTime? date,
    String? concept,
    double? amount,
    String? categoryId,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    List<String>? projectIds,
    String? note,
    bool clearNote = false,
    bool? isRecurringInstance,
    String? fixedPaymentId,
    bool clearFixedPaymentId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      date: date ?? this.date,
      concept: concept ?? this.concept,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      paymentMethodId:
          clearPaymentMethodId ? null : paymentMethodId ?? this.paymentMethodId,
      projectIds: projectIds ?? this.projectIds,
      note: clearNote ? null : note ?? this.note,
      isRecurringInstance: isRecurringInstance ?? this.isRecurringInstance,
      fixedPaymentId:
          clearFixedPaymentId ? null : fixedPaymentId ?? this.fixedPaymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date.toIso8601String(),
      'concept': concept,
      'amount': amount,
      'categoryId': categoryId,
      'paymentMethodId': paymentMethodId,
      'projectIds': projectIds,
      'note': note,
      'isRecurringInstance': isRecurringInstance,
      'fixedPaymentId': fixedPaymentId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      concept: json['concept'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      categoryId: json['categoryId'] as String? ?? '',
      paymentMethodId: json['paymentMethodId'] as String?,
      projectIds: stringList(json['projectIds']),
      note: json['note'] as String?,
      isRecurringInstance: json['isRecurringInstance'] as bool? ?? false,
      fixedPaymentId: json['fixedPaymentId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.icon,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int colorValue;
  final IconData icon;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);

  ExpenseCategory copyWith({
    String? id,
    String? name,
    int? colorValue,
    IconData? icon,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconCodePoint': icon.codePoint,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFF70835D).toARGB32(),
      icon: iconFromCodePoint(json['iconCodePoint'], Icons.label_rounded),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final IconData icon;
  final int colorValue;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);

  PaymentMethodModel copyWith({
    String? id,
    String? name,
    IconData? icon,
    int? colorValue,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'colorValue': colorValue,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: iconFromCodePoint(json['iconCodePoint'], Icons.credit_card_rounded),
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFF6C7B8E).toARGB32(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class FixedPayment {
  const FixedPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    this.paymentMethodId,
    this.frequency = FixedPaymentFrequency.monthly,
    this.customInterval,
    required this.nextPaymentDate,
    this.isActive = true,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double amount;
  final String categoryId;
  final String? paymentMethodId;
  final FixedPaymentFrequency frequency;
  final String? customInterval;
  final DateTime nextPaymentDate;
  final bool isActive;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  FixedPayment copyWith({
    String? id,
    String? name,
    double? amount,
    String? categoryId,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    FixedPaymentFrequency? frequency,
    String? customInterval,
    bool clearCustomInterval = false,
    DateTime? nextPaymentDate,
    bool? isActive,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FixedPayment(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      paymentMethodId:
          clearPaymentMethodId ? null : paymentMethodId ?? this.paymentMethodId,
      frequency: frequency ?? this.frequency,
      customInterval:
          clearCustomInterval ? null : customInterval ?? this.customInterval,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      isActive: isActive ?? this.isActive,
      note: clearNote ? null : note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'paymentMethodId': paymentMethodId,
      'frequency': frequency.name,
      'customInterval': customInterval,
      'nextPaymentDate': nextPaymentDate.toIso8601String(),
      'isActive': isActive,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FixedPayment.fromJson(Map<String, dynamic> json) {
    return FixedPayment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      categoryId: json['categoryId'] as String? ?? '',
      paymentMethodId: json['paymentMethodId'] as String?,
      frequency: enumByName(FixedPaymentFrequency.values,
          json['frequency'] as String?, FixedPaymentFrequency.monthly),
      customInterval: json['customInterval'] as String?,
      nextPaymentDate:
          DateTime.tryParse(json['nextPaymentDate'] as String? ?? '') ??
              DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
