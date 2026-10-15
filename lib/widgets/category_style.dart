import 'package:flutter/material.dart';
import '../models/models.dart';

/// Иконка и фирменный цвет категории — единые для списка операций,
/// выбора категории в форме и инфографики.
class CategoryStyle {
  CategoryStyle._();

  static IconData icon(Category category) {
    switch (category) {
      case Category.food:
        return Icons.restaurant_rounded;
      case Category.transport:
        return Icons.directions_bus;
      case Category.salary:
        return Icons.monetization_on;
      case Category.entertainment:
        return Icons.movie;
      case Category.health:
        return Icons.medical_services;
      case Category.shopping:
        return Icons.shopping_bag;
      case Category.subscriptions:
        return Icons.subscriptions;
      case Category.freelance:
        return Icons.laptop_mac;
      case Category.investments:
        return Icons.trending_up;
      case Category.transfers:
        return Icons.swap_horiz;
      case Category.cashback:
        return Icons.savings;
      case Category.sales:
        return Icons.sell;
      case Category.other:
        return Icons.category;
    }
  }

  static Color color(Category category) {
    switch (category) {
      case Category.food:
        return const Color(0xFFF97316);
      case Category.transport:
        return const Color(0xFF3B82F6);
      case Category.salary:
        return const Color(0xFF0F766E);
      case Category.entertainment:
        return const Color(0xFFA855F7);
      case Category.health:
        return const Color(0xFFEF4444);
      case Category.shopping:
        return const Color(0xFFEC4899);
      case Category.subscriptions:
        return const Color(0xFF6366F1);
      case Category.freelance:
        return const Color(0xFFD97706);
      case Category.investments:
        return const Color(0xFF10B981);
      case Category.transfers:
        return const Color(0xFF06B6D4);
      case Category.cashback:
        return const Color(0xFF14B8A6);
      case Category.sales:
        return const Color(0xFFEA580C);
      case Category.other:
        return const Color(0xFF64748B);
    }
  }
}
