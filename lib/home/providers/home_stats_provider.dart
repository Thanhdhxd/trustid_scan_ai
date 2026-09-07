import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/home_stats_repository.dart';
import '../data/consumer_models.dart';

final homeStatsProvider = FutureProvider.autoDispose<HomeStatsData>((ref) async {
  final repo = ref.read(homeStatsRepositoryProvider);
  return repo.getHomeStats();
});

final topPartnersProvider = FutureProvider.autoDispose<List<ConsumerPartner>>((ref) async {
  return ref.read(homeStatsRepositoryProvider).getTopPartners();
});

final featuredProductsProvider = FutureProvider.autoDispose<List<FeaturedProduct>>((ref) async {
  return ref.read(homeStatsRepositoryProvider).getFeaturedProducts();
});
