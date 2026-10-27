enum ReviewFilter { all, fiveStars, verified, hidden }

class PatientReview {
  const PatientReview({
    required this.id,
    required this.patientName,
    required this.rating,
    required this.isPinned,
    required this.isVerified,
    required this.isVisible,
    required this.createdAt,
    this.reviewText,
  });
  final String id;
  final String patientName;
  final int rating;
  final String? reviewText;
  final bool isPinned;
  final bool isVerified;
  final bool isVisible;
  final DateTime createdAt;
  PatientReview copyWith({bool? isPinned, bool? isVisible}) => PatientReview(
    id: id,
    patientName: patientName,
    rating: rating,
    reviewText: reviewText,
    isPinned: isPinned ?? this.isPinned,
    isVerified: isVerified,
    isVisible: isVisible ?? this.isVisible,
    createdAt: createdAt,
  );
}

class ReviewStats {
  const ReviewStats({
    required this.total,
    required this.averageRating,
    required this.verified,
    required this.pinned,
    this.starCounts = const [0, 0, 0, 0, 0],
  });
  final int total;
  final double averageRating;
  final int verified;
  final int pinned;

  /// Reviews per star level: index 0 = 1★ … index 4 = 5★.
  final List<int> starCounts;

  int countFor(int stars) => starCounts[stars - 1];

  /// Counts 1–5★ ratings into [starCounts] order.
  static List<int> countStars(Iterable<int> ratings) {
    final counts = List.filled(5, 0);
    for (final rating in ratings) {
      if (rating >= 1 && rating <= 5) counts[rating - 1]++;
    }
    return List.unmodifiable(counts);
  }
}
