import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukupaja_app/utils/order_status.dart';

void main() {
  group('orderProgress', () {
    test('increases monotonically through the normal order lifecycle', () {
      const steps = [
        'pending',
        'confirmed',
        'assigned',
        'accepted',
        'preparing',
        'in_transit',
      ];
      for (var i = 1; i < steps.length; i++) {
        expect(
          orderProgress(steps[i]),
          greaterThan(orderProgress(steps[i - 1])),
          reason: '${steps[i]} should be further along than ${steps[i - 1]}',
        );
      }
    });

    test('completed and delivered are fully progressed', () {
      expect(orderProgress('completed'), 1);
      expect(orderProgress('delivered'), 1);
    });

    test('unknown status falls back to a small non-zero value', () {
      expect(orderProgress('something_unexpected'), .1);
    });
  });

  group('orderStatusColor', () {
    test('cancelled and refunded are red', () {
      expect(orderStatusColor('cancelled'), Colors.red);
      expect(orderStatusColor('refunded'), Colors.red);
    });

    test('completed and delivered are gold', () {
      expect(orderStatusColor('completed'), const Color(0xFFC49000));
      expect(orderStatusColor('delivered'), const Color(0xFFC49000));
    });
  });

  group('displayDate', () {
    test('formats an ISO date as dd/mm/yyyy', () {
      expect(displayDate('2026-03-05T10:00:00Z'), '05/03/2026');
    });

    test('returns the raw value when it cannot be parsed', () {
      expect(displayDate('not-a-date'), 'not-a-date');
    });

    test('handles a null value', () {
      expect(displayDate(null), '');
    });
  });
}
