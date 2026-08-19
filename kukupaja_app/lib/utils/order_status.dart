import 'package:flutter/material.dart';

import '../core/app_theme.dart';

String orderStatusLabel(String status) => switch (status) {
  'pending' => tr('Imepokelewa', 'Received'),
  'confirmed' => tr('Imethibitishwa', 'Confirmed'),
  'assigned' => tr('Broker amechaguliwa', 'Broker assigned'),
  'accepted' => tr('Broker amekubali', 'Broker accepted'),
  'preparing' => tr('Inaandaliwa', 'Preparing'),
  'in_transit' => tr('Inasafirishwa', 'In transit'),
  'delivered' => tr('Imewasilishwa', 'Delivered'),
  'completed' => tr('Imekamilika', 'Completed'),
  'cancelled' => tr('Imefutwa', 'Cancelled'),
  'refunded' => tr('Fedha imerejeshwa', 'Refunded'),
  _ => status,
};

Color orderStatusColor(String status) => switch (status) {
  'cancelled' || 'refunded' => Colors.red,
  'completed' || 'delivered' => const Color(0xFFC49000),
  'in_transit' => Colors.blue,
  'preparing' || 'accepted' || 'assigned' => Colors.orange,
  _ => green,
};

double orderProgress(String status) => switch (status) {
  'pending' => .12,
  'confirmed' => .25,
  'assigned' => .4,
  'accepted' => .52,
  'preparing' => .65,
  'in_transit' => .82,
  'delivered' || 'completed' => 1,
  'cancelled' || 'refunded' => 1,
  _ => .1,
};

/// Mirrors the backend's state machine so the admin UI can offer the right
/// next steps — the server re-validates regardless, this is just for the UI.
List<String> nextOrderStatuses(String status) => switch (status) {
  'pending' => const ['confirmed', 'cancelled'],
  'confirmed' => const ['preparing', 'cancelled'],
  'assigned' => const ['cancelled'],
  'accepted' => const ['preparing', 'cancelled'],
  'preparing' => const ['in_transit', 'cancelled'],
  'in_transit' => const ['delivered', 'cancelled'],
  'delivered' => const ['completed'],
  _ => const [],
};

String displayDate(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}');
  if (date == null) return '${value ?? ''}';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
