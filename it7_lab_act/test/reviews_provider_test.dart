import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/features/reviews/models/review.dart';
import 'package:it7_lab_act/features/reviews/providers/reviews_provider.dart';

void main() {
  group('Review', () {
    test('fromMap reads all fields', () {
      final review = Review.fromMap('r1', {
        'userId': 'u1',
        'userName': 'John Doe',
        'rating': 4.5,
        'comment': 'Great product!',
        'adminReply': 'Thank you!',
        'timestamp': 1704067200000,
      });

      expect(review.id, 'r1');
      expect(review.userName, 'John Doe');
      expect(review.rating, 4.5);
      expect(review.comment, 'Great product!');
      expect(review.adminReply, 'Thank you!');
      expect(review.timestamp, 1704067200000);
    });

    test('fromMap handles missing rating (defaults to 5)', () {
      final review = Review.fromMap('r2', {
        'userId': 'u1',
        'userName': 'John',
        'comment': 'Nice',
      });

      expect(review.rating, 5);
    });

    test('fromMap clamps rating to 1-5 range', () {
      final review1 = Review.fromMap('r3', {
        'userId': 'u1',
        'userName': 'John',
        'rating': 6,
        'comment': 'Test',
      });
      expect(review1.rating, 5); // clamped to max

      final review2 = Review.fromMap('r4', {
        'userId': 'u1',
        'userName': 'John',
        'rating': 0,
        'comment': 'Test',
      });
      expect(review2.rating, 1); // clamped to min

      final review3 = Review.fromMap('r5', {
        'userId': 'u1',
        'userName': 'John',
        'rating': -1,
        'comment': 'Test',
      });
      expect(review3.rating, 1); // clamped to min
    });

    test('fromMap handles missing userName (defaults to Anonymous)', () {
      final review = Review.fromMap('r6', {
        'userId': 'u1',
        'comment': 'Test',
      });

      expect(review.userName, 'Anonymous');
    });

    test('fromMap handles missing adminReply', () {
      final review = Review.fromMap('r7', {
        'userId': 'u1',
        'userName': 'John',
        'rating': 4,
        'comment': 'Test',
      });

      expect(review.adminReply, '');
    });

    test('fromMap handles text numbers for rating', () {
      final review = Review.fromMap('r8', {
        'userId': 'u1',
        'userName': 'John',
        'rating': '4.5', // string number
        'comment': 'Test',
      });

      expect(review.rating, 4.5);
    });
  });

  group('ReviewEligibility', () {
    test('has correct values', () {
      expect(ReviewEligibility.values, [ReviewEligibility.allowed, ReviewEligibility.notPurchased, ReviewEligibility.failed]);
    });
  });
}