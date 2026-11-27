import 'package:flutter/widgets.dart';

/// Observer toàn cục theo dõi điều hướng `GoRouter` để các màn hình danh sách
/// (như `OrderListScreen`) tự động làm mới khi quay về từ route con.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
