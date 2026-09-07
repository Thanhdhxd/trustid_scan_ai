class ConsumerPartner {
  final String id;
  final String name;
  final String? logo;

  ConsumerPartner({required this.id, required this.name, this.logo});

  factory ConsumerPartner.fromJson(Map<String, dynamic> json) {
    return ConsumerPartner(
      id: json['id'].toString(),
      name: json['name'],
      logo: json['logo'],
    );
  }
}

class PaginatedPartners {
  final List<ConsumerPartner> items;
  final int total;
  final int page;
  final int limit;

  PaginatedPartners({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory PaginatedPartners.fromJson(Map<String, dynamic> json) {
    return PaginatedPartners(
      items:
          (json['items'] as List?)
              ?.map((e) => ConsumerPartner.fromJson(e))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
    );
  }
}

class FeaturedProduct {
  final String id;
  final String name;
  final String price;
  final String image;
  final String coop;
  final String? badge;

  FeaturedProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.coop,
    this.badge,
  });

  factory FeaturedProduct.fromJson(Map<String, dynamic> json) {
    return FeaturedProduct(
      id: json['id'].toString(),
      name: json['name'],
      price:
          json['price']?.toString() ?? 'Unknown', // Backend might return number
      image: json['image'],
      coop: json['coop'],
      badge: json['badge'],
    );
  }
}

class SafetyAlert {
  final int id;
  final String level;
  final String message;

  SafetyAlert({required this.id, required this.level, required this.message});

  factory SafetyAlert.fromJson(Map<String, dynamic> json) {
    return SafetyAlert(
      id: json['id'],
      level: json['level'],
      message: json['message'],
    );
  }
}

class TransparencyStats {
  final double score;
  final int totalFarms;
  final int monthlyScans;

  TransparencyStats({
    required this.score,
    required this.totalFarms,
    required this.monthlyScans,
  });

  factory TransparencyStats.fromJson(Map<String, dynamic> json) {
    return TransparencyStats(
      score: (json['score'] as num).toDouble(),
      totalFarms: json['totalFarms'],
      monthlyScans: json['monthlyScans'],
    );
  }
}

class ShopCategory {
  final String categoryId;
  final String categoryName;
  final List<FeaturedProduct> products;

  ShopCategory({
    required this.categoryId,
    required this.categoryName,
    required this.products,
  });

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    var rawProducts = json['products'] as List? ?? [];
    List<FeaturedProduct> productList = rawProducts
        .map((e) => FeaturedProduct.fromJson(e))
        .toList();

    return ShopCategory(
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? '',
      products: productList,
    );
  }
}

class ProductDetail {
  final String id;
  final String name;
  final double price;
  final List<String> images;
  final String description;
  final String tenantName;
  final Map<String, dynamic> attributes;

  ProductDetail({
    required this.id,
    required this.name,
    required this.price,
    required this.images,
    required this.description,
    required this.tenantName,
    required this.attributes,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    try {
      var rawAttributes = json['attributes'];
      Map<String, dynamic> parsedAttributes = {};
      if (rawAttributes is Map<String, dynamic>) {
        parsedAttributes = rawAttributes;
      } else if (rawAttributes is Map) {
        parsedAttributes = Map<String, dynamic>.from(rawAttributes);
      }

      var rawImages = json['images'];
      List<String> parsedImages = [];
      if (rawImages is List) {
        parsedImages = rawImages.map((e) => e.toString()).toList();
      }

      return ProductDetail(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        price: _parsePrice(json['price']),
        images: parsedImages,
        description: json['description'] ?? '',
        tenantName: json['tenantName'] ?? '',
        attributes: parsedAttributes,
      );
    } catch (e, stack) {
      print('Error parsing ProductDetail: $e');
      print(stack);
      rethrow;
    }
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove any non-numeric chars except dot if needed, or just tryParse
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class EnterpriseDetail {
  final String id;
  final String name;
  final String? logo;
  final String description;
  final String address;
  final List<FeaturedProduct> products;

  EnterpriseDetail({
    required this.id,
    required this.name,
    this.logo,
    required this.description,
    required this.address,
    required this.products,
  });

  factory EnterpriseDetail.fromJson(Map<String, dynamic> json) {
    var rawProducts = json['products'] as List? ?? [];
    List<FeaturedProduct> productList = rawProducts
        .map((e) => FeaturedProduct.fromJson(e))
        .toList();

    return EnterpriseDetail(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      products: productList,
    );
  }
}

class WeatherAlert {
  final String type;
  final String severity;
  final String title;
  final String message;

  WeatherAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      type: json['type']?.toString() ?? 'rain',
      severity: json['severity']?.toString() ?? 'good',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class WeatherSummary {
  final String provider;
  final bool fromCache;
  final String cachedAt;
  final String locationName;
  final double lat;
  final double lon;
  final double temp;
  final String description;
  final String icon;
  final int humidity;
  final int windSpeed;
  final int rainChance;
  final int next6hRainProb;
  final List<WeatherAlert> topAlerts;

  WeatherSummary({
    required this.provider,
    required this.fromCache,
    required this.cachedAt,
    required this.locationName,
    required this.lat,
    required this.lon,
    required this.temp,
    required this.description,
    this.icon = 'sunny',
    required this.humidity,
    required this.windSpeed,
    required this.rainChance,
    required this.next6hRainProb,
    required this.topAlerts,
  });

  factory WeatherSummary.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final current = (json['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawAlerts = (json['top_alerts'] as List?) ?? [];

    return WeatherSummary(
      provider: json['provider']?.toString() ?? 'open_meteo',
      fromCache: json['_from_cache'] == true,
      cachedAt: json['cached_at']?.toString() ?? '',
      locationName: location['name']?.toString() ?? '',
      lat: (location['lat'] as num?)?.toDouble() ?? 0,
      lon: (location['lon'] as num?)?.toDouble() ?? 0,
      temp: (current['temp'] as num?)?.toDouble() ?? 0,
      description: current['description']?.toString() ?? '',
      icon: current['icon']?.toString() ?? 'sunny',
      humidity: (current['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (current['wind_speed'] as num?)?.toInt() ?? 0,
      rainChance: (current['rain_chance'] as num?)?.toInt() ?? 0,
      next6hRainProb: (json['next_6h_rain_prob'] as num?)?.toInt() ?? 0,
      topAlerts: rawAlerts
          .map((e) => WeatherAlert.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class WeatherDetail {
  final String provider;
  final bool fromCache;
  final String cachedAt;
  final String locationName;
  final Map<String, dynamic> current;
  final int next6hRainProb;
  final List<Map<String, dynamic>> hourly;
  final List<Map<String, dynamic>> daily;
  final List<Map<String, dynamic>> farmAdvice;
  final List<WeatherAlert> alerts;

  WeatherDetail({
    required this.provider,
    required this.fromCache,
    required this.cachedAt,
    required this.locationName,
    required this.current,
    this.next6hRainProb = 0,
    required this.hourly,
    required this.daily,
    required this.farmAdvice,
    required this.alerts,
  });

  factory WeatherDetail.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final current = (json['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawHourly = (json['hourly'] as List?) ?? [];
    final rawDaily = (json['daily'] as List?) ?? [];
    final rawAdvice = (json['farm_advice'] as List?) ?? [];
    final rawAlerts = (json['alerts'] as List?) ?? [];

    return WeatherDetail(
      provider: json['provider']?.toString() ?? 'open_meteo',
      fromCache: json['_from_cache'] == true,
      cachedAt: json['cached_at']?.toString() ?? '',
      locationName: location['name']?.toString() ?? '',
      current: current,
      next6hRainProb: (json['next_6h_rain_prob'] as num?)?.toInt() ?? 0,
      hourly: rawHourly.map((e) => (e as Map).cast<String, dynamic>()).toList(),
      daily: rawDaily.map((e) => (e as Map).cast<String, dynamic>()).toList(),
      farmAdvice: rawAdvice
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      alerts: rawAlerts
          .map((e) => WeatherAlert.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class WeatherFavoriteLocation {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String ward;
  final String district;
  final String province;
  final String address;
  final String createdAt;

  const WeatherFavoriteLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.ward = '',
    this.district = '',
    this.province = '',
    this.address = '',
    this.createdAt = '',
  });

  static WeatherFavoriteLocation get hanoi => WeatherFavoriteLocation(
    id: 'default-hanoi',
    name: 'Hà Nội',
    lat: 21.0285,
    lon: 105.8542,
    ward: '',
    district: '',
    province: 'Thành phố Hà Nội',
    address: 'Hà Nội, Việt Nam',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
  );

  factory WeatherFavoriteLocation.fromJson(Map<String, dynamic> json) {
    return WeatherFavoriteLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vị trí đã lưu',
      lat: (json['lat'] as num?)?.toDouble() ?? 21.0285,
      lon: (json['lon'] as num?)?.toDouble() ?? 105.8542,
      ward: json['ward']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      createdAt:
          json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lon': lon,
      'ward': ward,
      'district': district,
      'province': province,
      'address': address,
      'createdAt': createdAt,
    };
  }
}

class WeatherReverseGeocode {
  final String ward;
  final String district;
  final String province;
  final String formattedAddress;

  String get city => province;

  WeatherReverseGeocode({
    required this.ward,
    required this.district,
    required this.province,
    required this.formattedAddress,
  });

  factory WeatherReverseGeocode.fromJson(Map<String, dynamic> json) {
    return WeatherReverseGeocode(
      ward: json['ward']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      formattedAddress: json['formatted_address']?.toString() ?? '',
    );
  }
}
