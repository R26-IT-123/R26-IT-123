class TrustRating {
  final int rating;
  final String comment;
  final String createdAt;

  const TrustRating({
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory TrustRating.fromJson(Map<String, dynamic> json) => TrustRating(
        rating: (json['rating'] as num).toInt(),
        comment: json['comment'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}

class TrustProfile {
  final String uid;
  final double avgRating;
  final int totalRatings;
  final double shopperAvg;
  final int shopperCount;
  final double requesterAvg;
  final int requesterCount;
  final int completedTrips;
  final List<String> badges;
  final List<TrustRating> recentRatings;

  const TrustProfile({
    required this.uid,
    required this.avgRating,
    required this.totalRatings,
    required this.shopperAvg,
    required this.shopperCount,
    required this.requesterAvg,
    required this.requesterCount,
    required this.completedTrips,
    required this.badges,
    required this.recentRatings,
  });

  factory TrustProfile.fromJson(Map<String, dynamic> json) => TrustProfile(
        uid: json['uid'] as String,
        avgRating: (json['avg_rating'] as num).toDouble(),
        totalRatings: (json['total_ratings'] as num).toInt(),
        shopperAvg: (json['shopper_avg'] as num).toDouble(),
        shopperCount: (json['shopper_count'] as num).toInt(),
        requesterAvg: (json['requester_avg'] as num).toDouble(),
        requesterCount: (json['requester_count'] as num).toInt(),
        completedTrips: (json['completed_trips'] as num).toInt(),
        badges: (json['badges'] as List<dynamic>).cast<String>(),
        recentRatings: (json['recent_ratings'] as List<dynamic>)
            .map((e) => TrustRating.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get hasAnyData => totalRatings > 0 || completedTrips > 0;
}
