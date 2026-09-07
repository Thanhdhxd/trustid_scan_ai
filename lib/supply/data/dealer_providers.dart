import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dealer_repository.dart';

// -----------------------------------------
// Dashboard Providers
// -----------------------------------------
final dealerDashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getDashboardStats();
});

final dealerPendingReceivesProvider = FutureProvider.autoDispose.family<List<dynamic>, bool>((ref, showAll) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getPendingReceives(all: showAll);
});

final dealerShipmentDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getShipmentDetail(id);
});

final dealerTopProductsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getTopProducts();
});

final dealerActivityProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getRecentActivity();
});

final dealerSalesHistoryProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, page) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getSalesHistory(page: page, limit: 20);
});

// -----------------------------------------
// POS Cart State
// -----------------------------------------
class CartItem {
  final String serialNumber;
  final String qrCode;
  final Map<String, dynamic> productInfo;
  double price;
  double basePrice;
  double discountPercent;
  int quantity;
  bool isBag;
  List<dynamic> packets;

  CartItem({
    required this.serialNumber,
    required this.qrCode,
    required this.productInfo,
    required this.price,
    this.basePrice = 0,
    this.discountPercent = 0,
    this.quantity = 1,
    this.isBag = false,
    this.packets = const [],
  });
}

class DealerCartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  void addItem(CartItem item) {
    if (!state.any((e) => e.serialNumber == item.serialNumber)) {
      state = [...state, item];
    }
  }

  void updatePrice(String serialNumber, double newPrice) {
    state = state.map((e) {
      if (e.serialNumber == serialNumber) {
        return CartItem(
          serialNumber: e.serialNumber,
          qrCode: e.qrCode,
          productInfo: e.productInfo,
          price: newPrice,
          basePrice: e.basePrice,
          discountPercent: e.discountPercent,
          quantity: e.quantity,
          isBag: e.isBag,
          packets: e.packets,
        );
      }
      return e;
    }).toList();
  }

  void removeItem(String serialNumber) {
    state = state.where((e) => e.serialNumber != serialNumber).toList();
  }

  void clearCart() {
    state = [];
  }
}

final dealerCartProvider = NotifierProvider<DealerCartNotifier, List<CartItem>>(() {
  return DealerCartNotifier();
});

// -----------------------------------------
// POS Customer State
// -----------------------------------------
enum CustomerType { retail, loyalty }

class CheckoutState {
  final CustomerType type;
  final Map<String, dynamic>? selectedCustomer;
  final double discountAmount;
  final String paymentMethod;
  final bool autoPrint;

  CheckoutState({
    this.type = CustomerType.retail,
    this.selectedCustomer,
    this.discountAmount = 0.0,
    this.paymentMethod = 'cash',
    this.autoPrint = true,
  });

  CheckoutState copyWith({
    CustomerType? type,
    Map<String, dynamic>? selectedCustomer,
    double? discountAmount,
    String? paymentMethod,
    bool? autoPrint,
  }) {
    return CheckoutState(
      type: type ?? this.type,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      discountAmount: discountAmount ?? this.discountAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      autoPrint: autoPrint ?? this.autoPrint,
    );
  }
}

class DealerCheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    return CheckoutState();
  }

  void setType(CustomerType type) {
    state = state.copyWith(type: type);
    if (type == CustomerType.retail) {
      state = state.copyWith(selectedCustomer: null, discountAmount: 0.0);
    }
  }

  void setCustomer(Map<String, dynamic>? customer) {
    if (customer == null) {
      state = CheckoutState(
        type: state.type,
        selectedCustomer: null,
        discountAmount: state.discountAmount,
        paymentMethod: state.paymentMethod,
        autoPrint: state.autoPrint,
      );
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setAutoPrint(bool print) {
    state = state.copyWith(autoPrint: print);
  }

  void clear() {
    state = CheckoutState();
  }
}

final dealerCheckoutProvider = NotifierProvider<DealerCheckoutNotifier, CheckoutState>(() {
  return DealerCheckoutNotifier();
});
