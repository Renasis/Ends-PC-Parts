import '../../../core/utils/map_parsing.dart';

/// A review saved at `products/{productId}/reviews/{id}`.
///
/// `adminReply` is written by the admin dashboard (reviews.js).
class Review {
  final String id;
  final String userName;
  final double rating;
  final String comment;
  final String adminReply;

  /// Milliseconds since epoch.
  final int timestamp;

  const Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.adminReply,
    required this.timestamp,
  });

  /// Clamps rating to valid 1-5 range.
  static double _clampRating(num value) {
    final d = value.toDouble();
    if (d < 1) return 1;
    if (d > 5) return 5;
    return d;
  }

  factory Review.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawRating = map['rating'] == null ? 5 : readNumber(map['rating']);
    return Review(
      id: id,
      userName: readText(map['userName'], fallback: 'Anonymous'),
      rating: _clampRating(rawRating),
      comment: readText(map['comment']),
      adminReply: readText(map['adminReply']),
      timestamp: readInt(map['timestamp']),
    );
  }
}