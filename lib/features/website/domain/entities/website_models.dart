import 'dart:typed_data';

class WebsiteSettings {
  const WebsiteSettings({
    required this.slug,
    required this.heroHeadlineLine1,
    required this.heroHeadlineLine2,
    required this.heroDescription,
    required this.theme,
    required this.showAbout,
    required this.showServices,
    required this.showGallery,
    required this.showReviews,
    required this.showBlog,
    required this.showClinicDetails,
    required this.showOnlineConsultation,
    required this.bookingAdvanceDays,
    required this.maxPerSlot,
    required this.cancellationCutoffHours,
    required this.autoConfirm,
    required this.bufferMinutes,
    required this.onlineFee,
    required this.onlineDuration,
    required this.whatsappNumber,
    required this.whatsappMessage,
    this.heroPhotoUrl,
    this.heroLocationLabel = 'Clinic Location',
    this.heroHoursLabel = 'Consultation',
    this.heroPrimaryButtonLabel = 'Book Appointment',
    this.heroSecondaryButtonLabel = 'Call Now',
    this.heroDirectionsLabel = 'Get Directions',
    this.heroStatText = '',
    this.heroStatIcon = 'Star',
    this.showHeroStatBadge = true,
    this.showQuickStats = true,
    this.quickStats = defaultQuickStats,
    this.showPackages = true,
    this.requirePayment = false,
    this.videoProvider = 'zoom',
    this.seoTitle = '',
    this.seoDescription = '',
    this.seoKeywords = '',
    this.socialFacebook = '',
    this.socialInstagram = '',
    this.socialYoutube = '',
    this.socialLinkedin = '',
    this.googleAnalyticsId = '',
  });
  final String slug;
  final String heroHeadlineLine1;
  final String heroHeadlineLine2;
  final String heroDescription;
  final String theme;
  final String? heroPhotoUrl;
  final String heroLocationLabel;
  final String heroHoursLabel;
  final String heroPrimaryButtonLabel;
  final String heroSecondaryButtonLabel;
  final String heroDirectionsLabel;
  final String heroStatText;
  final String heroStatIcon;
  final bool showHeroStatBadge;
  final bool showQuickStats;
  final List<WebsiteQuickStat> quickStats;
  final bool showAbout;
  final bool showServices;
  final bool showGallery;
  final bool showReviews;
  final bool showBlog;
  final bool showClinicDetails;
  final bool showOnlineConsultation;
  final bool showPackages;
  final int bookingAdvanceDays;
  final int maxPerSlot;
  final int cancellationCutoffHours;
  final bool autoConfirm;
  final int bufferMinutes;
  final bool requirePayment;
  final double onlineFee;
  final int onlineDuration;
  final String videoProvider;
  final String whatsappNumber;
  final String whatsappMessage;
  final String seoTitle;
  final String seoDescription;
  final String seoKeywords;
  final String socialFacebook;
  final String socialInstagram;
  final String socialYoutube;
  final String socialLinkedin;
  final String googleAnalyticsId;

  WebsiteSettings copyWith({
    String? heroHeadlineLine1,
    String? heroHeadlineLine2,
    String? heroDescription,
    String? theme,
    String? heroPhotoUrl,
    bool clearHeroPhoto = false,
    String? heroLocationLabel,
    String? heroHoursLabel,
    String? heroPrimaryButtonLabel,
    String? heroSecondaryButtonLabel,
    String? heroDirectionsLabel,
    String? heroStatText,
    String? heroStatIcon,
    bool? showHeroStatBadge,
    bool? showQuickStats,
    List<WebsiteQuickStat>? quickStats,
    bool? showAbout,
    bool? showServices,
    bool? showGallery,
    bool? showReviews,
    bool? showBlog,
    bool? showClinicDetails,
    bool? showOnlineConsultation,
    bool? showPackages,
    int? bookingAdvanceDays,
    int? maxPerSlot,
    int? cancellationCutoffHours,
    bool? autoConfirm,
    int? bufferMinutes,
    bool? requirePayment,
    double? onlineFee,
    int? onlineDuration,
    String? videoProvider,
    String? whatsappNumber,
    String? whatsappMessage,
    String? seoTitle,
    String? seoDescription,
    String? seoKeywords,
    String? socialFacebook,
    String? socialInstagram,
    String? socialYoutube,
    String? socialLinkedin,
    String? googleAnalyticsId,
  }) => WebsiteSettings(
    slug: slug,
    heroHeadlineLine1: heroHeadlineLine1 ?? this.heroHeadlineLine1,
    heroHeadlineLine2: heroHeadlineLine2 ?? this.heroHeadlineLine2,
    heroDescription: heroDescription ?? this.heroDescription,
    theme: theme ?? this.theme,
    heroPhotoUrl: clearHeroPhoto ? null : heroPhotoUrl ?? this.heroPhotoUrl,
    heroLocationLabel: heroLocationLabel ?? this.heroLocationLabel,
    heroHoursLabel: heroHoursLabel ?? this.heroHoursLabel,
    heroPrimaryButtonLabel:
        heroPrimaryButtonLabel ?? this.heroPrimaryButtonLabel,
    heroSecondaryButtonLabel:
        heroSecondaryButtonLabel ?? this.heroSecondaryButtonLabel,
    heroDirectionsLabel: heroDirectionsLabel ?? this.heroDirectionsLabel,
    heroStatText: heroStatText ?? this.heroStatText,
    heroStatIcon: heroStatIcon ?? this.heroStatIcon,
    showHeroStatBadge: showHeroStatBadge ?? this.showHeroStatBadge,
    showQuickStats: showQuickStats ?? this.showQuickStats,
    quickStats: quickStats ?? this.quickStats,
    showAbout: showAbout ?? this.showAbout,
    showServices: showServices ?? this.showServices,
    showGallery: showGallery ?? this.showGallery,
    showReviews: showReviews ?? this.showReviews,
    showBlog: showBlog ?? this.showBlog,
    showClinicDetails: showClinicDetails ?? this.showClinicDetails,
    showOnlineConsultation:
        showOnlineConsultation ?? this.showOnlineConsultation,
    showPackages: showPackages ?? this.showPackages,
    bookingAdvanceDays: bookingAdvanceDays ?? this.bookingAdvanceDays,
    maxPerSlot: maxPerSlot ?? this.maxPerSlot,
    cancellationCutoffHours:
        cancellationCutoffHours ?? this.cancellationCutoffHours,
    autoConfirm: autoConfirm ?? this.autoConfirm,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    requirePayment: requirePayment ?? this.requirePayment,
    onlineFee: onlineFee ?? this.onlineFee,
    onlineDuration: onlineDuration ?? this.onlineDuration,
    videoProvider: videoProvider ?? this.videoProvider,
    whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    whatsappMessage: whatsappMessage ?? this.whatsappMessage,
    seoTitle: seoTitle ?? this.seoTitle,
    seoDescription: seoDescription ?? this.seoDescription,
    seoKeywords: seoKeywords ?? this.seoKeywords,
    socialFacebook: socialFacebook ?? this.socialFacebook,
    socialInstagram: socialInstagram ?? this.socialInstagram,
    socialYoutube: socialYoutube ?? this.socialYoutube,
    socialLinkedin: socialLinkedin ?? this.socialLinkedin,
    googleAnalyticsId: googleAnalyticsId ?? this.googleAnalyticsId,
  );
}

class WebsiteQuickStat {
  const WebsiteQuickStat({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    required this.active,
  });
  final String id;
  final String label;
  final String value;
  final String icon;
  final bool active;
  WebsiteQuickStat copyWith({
    String? label,
    String? value,
    String? icon,
    bool? active,
  }) => WebsiteQuickStat(
    id: id,
    label: label ?? this.label,
    value: value ?? this.value,
    icon: icon ?? this.icon,
    active: active ?? this.active,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'value': value,
    'icon': icon,
    'active': active,
  };
}

const defaultQuickStats = <WebsiteQuickStat>[
  WebsiteQuickStat(
    id: 'patients',
    label: 'Patients Treated',
    value: '5,000+',
    icon: 'Users',
    active: true,
  ),
  WebsiteQuickStat(
    id: 'experience',
    label: 'Years Experience',
    value: '',
    icon: 'Award',
    active: true,
  ),
  WebsiteQuickStat(
    id: 'success',
    label: 'Success Rate',
    value: '98%',
    icon: 'ThumbsUp',
    active: true,
  ),
  WebsiteQuickStat(
    id: 'booking',
    label: 'Online Booking',
    value: '24/7',
    icon: 'Headset',
    active: true,
  ),
];

class WebsiteService {
  const WebsiteService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.type,
    required this.durationMinutes,
    required this.active,
    required this.sortOrder,
  });
  final String id;
  final String name;
  final String description;
  final double price;
  final String type;
  final int durationMinutes;
  final bool active;
  final int sortOrder;
  WebsiteService copyWith({
    String? name,
    String? description,
    double? price,
    String? type,
    int? durationMinutes,
    bool? active,
    int? sortOrder,
  }) => WebsiteService(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    type: type ?? this.type,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    active: active ?? this.active,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

class WebsitePackage {
  const WebsitePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
    required this.active,
    required this.isPopular,
    required this.sortOrder,
    this.tagline = '',
    this.originalPrice,
    this.duration = '',
    this.slotsAvailable,
  });
  final String id;
  final String name;
  final String tagline;
  final double price;
  final double? originalPrice;
  final String duration;
  final List<String> features;
  final int? slotsAvailable;
  final bool active;
  final bool isPopular;
  final int sortOrder;
  WebsitePackage copyWith({
    String? name,
    String? tagline,
    double? price,
    double? originalPrice,
    bool clearOriginalPrice = false,
    String? duration,
    List<String>? features,
    int? slotsAvailable,
    bool clearSlotsAvailable = false,
    bool? active,
    bool? isPopular,
    int? sortOrder,
  }) => WebsitePackage(
    id: id,
    name: name ?? this.name,
    tagline: tagline ?? this.tagline,
    price: price ?? this.price,
    originalPrice: clearOriginalPrice
        ? null
        : originalPrice ?? this.originalPrice,
    duration: duration ?? this.duration,
    features: features ?? this.features,
    slotsAvailable: clearSlotsAvailable
        ? null
        : slotsAvailable ?? this.slotsAvailable,
    active: active ?? this.active,
    isPopular: isPopular ?? this.isPopular,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

class WorkingHour {
  const WorkingHour({
    required this.dayOfWeek,
    required this.isOpen,
    this.id,
    this.startTime,
    this.endTime,
    this.startTime2,
    this.endTime2,
  });
  final String? id;
  final int dayOfWeek;
  final bool isOpen;
  final String? startTime;
  final String? endTime;
  final String? startTime2;
  final String? endTime2;
  WorkingHour copyWith({
    bool? isOpen,
    String? startTime,
    String? endTime,
    String? startTime2,
    String? endTime2,
    bool clearSecond = false,
  }) => WorkingHour(
    id: id,
    dayOfWeek: dayOfWeek,
    isOpen: isOpen ?? this.isOpen,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    startTime2: clearSecond ? null : startTime2 ?? this.startTime2,
    endTime2: clearSecond ? null : endTime2 ?? this.endTime2,
  );
}

class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.photoUrl,
    required this.sortOrder,
    this.caption,
  });
  final String id;
  final String photoUrl;
  final int sortOrder;
  final String? caption;
  GalleryPhoto copyWith({String? caption}) => GalleryPhoto(
    id: id,
    photoUrl: photoUrl,
    sortOrder: sortOrder,
    caption: caption,
  );
}

class WebsiteReview {
  const WebsiteReview({
    required this.id,
    required this.patientName,
    required this.rating,
    required this.isVisible,
    required this.isPinned,
    required this.createdAt,
    this.reviewText,
  });
  final String id;
  final String patientName;
  final int rating;
  final String? reviewText;
  final bool isVisible;
  final bool isPinned;
  final DateTime createdAt;
  WebsiteReview copyWith({bool? isVisible, bool? isPinned}) => WebsiteReview(
    id: id,
    patientName: patientName,
    rating: rating,
    reviewText: reviewText,
    isVisible: isVisible ?? this.isVisible,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt,
  );
}

class WebsiteClinic {
  const WebsiteClinic({
    required this.fullName,
    required this.specialization,
    required this.qualifications,
    required this.experienceYears,
    required this.phone,
    required this.clinicName,
    required this.city,
    required this.state,
    required this.address,
    required this.consultationFee,
    required this.registrationNumber,
    required this.clinicEmail,
  });
  final String fullName;
  final String specialization;
  final String qualifications;
  final int experienceYears;
  final String phone;
  final String clinicName;
  final String city;
  final String state;
  final String address;
  final double consultationFee;
  final String registrationNumber;
  final String clinicEmail;
  WebsiteClinic copyWith({
    String? fullName,
    String? specialization,
    String? qualifications,
    int? experienceYears,
    String? phone,
    String? clinicName,
    String? city,
    String? state,
    String? address,
    double? consultationFee,
    String? registrationNumber,
    String? clinicEmail,
  }) => WebsiteClinic(
    fullName: fullName ?? this.fullName,
    specialization: specialization ?? this.specialization,
    qualifications: qualifications ?? this.qualifications,
    experienceYears: experienceYears ?? this.experienceYears,
    phone: phone ?? this.phone,
    clinicName: clinicName ?? this.clinicName,
    city: city ?? this.city,
    state: state ?? this.state,
    address: address ?? this.address,
    consultationFee: consultationFee ?? this.consultationFee,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    clinicEmail: clinicEmail ?? this.clinicEmail,
  );
}

class WebsiteSnapshot {
  const WebsiteSnapshot({
    required this.settings,
    required this.services,
    required this.workingHours,
    this.packages = const [],
    this.gallery = const [],
    this.reviews = const [],
    this.clinic,
  });
  final WebsiteSettings settings;
  final List<WebsiteService> services;
  final List<WebsitePackage> packages;
  final List<WorkingHour> workingHours;
  final List<GalleryPhoto> gallery;
  final List<WebsiteReview> reviews;
  final WebsiteClinic? clinic;
  WebsiteSnapshot copyWith({
    WebsiteSettings? settings,
    List<WebsiteService>? services,
    List<WebsitePackage>? packages,
    List<WorkingHour>? workingHours,
    List<GalleryPhoto>? gallery,
    List<WebsiteReview>? reviews,
    WebsiteClinic? clinic,
  }) => WebsiteSnapshot(
    settings: settings ?? this.settings,
    services: services ?? this.services,
    packages: packages ?? this.packages,
    workingHours: workingHours ?? this.workingHours,
    gallery: gallery ?? this.gallery,
    reviews: reviews ?? this.reviews,
    clinic: clinic ?? this.clinic,
  );
}

class WebsiteImageUpload {
  const WebsiteImageUpload({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });
  final String fileName;
  final Uint8List bytes;
  final String? mimeType;
}
