import 'package:flutter_riverpod/flutter_riverpod.dart';

class StateController<T> extends Notifier<T> {
  final T Function(Ref ref) _init;
  StateController(this._init);

  @override
  T build() => _init(ref);

  @override
  set state(T value) => super.state = value;

  void update(T Function(T state) cb) => super.state = cb(super.state);
}

NotifierProvider<StateController<T>, T> StateProvider<T>(T Function(Ref ref) create) {
  return NotifierProvider<StateController<T>, T>(() => StateController<T>(create));
}
