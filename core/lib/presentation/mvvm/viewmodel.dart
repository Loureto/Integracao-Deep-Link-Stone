import 'package:dependencies/dependencies.dart';
import 'package:flutter/material.dart';

import 'viewmodel_state.dart';

/// A view model that is used by [ViewMixin] to handle application states and
/// interact with use cases
abstract class ViewModel<State extends ViewModelState> extends BlocBase<State>
    implements Disposable {
  /// If view model is initialized
  bool isInitialized = false;

  /// Creates a [ViewModel]
  ViewModel(super.initialState) {
    initViewModel();
  }

  /// Called when the [ViewModel] is created
  @mustCallSuper
  void initViewModel() {
    assert(
      !isInitialized,
      'View Model has already been initialized! The initialization occurs automatically on life cycle, so you should not call initViewModel manually.',
    );
    isInitialized = true;
  }

  @override
  void emit(State state) {
    if (!isClosed) super.emit(state);
  }

  @override
  Future<void> onDispose() => super.close();
}
