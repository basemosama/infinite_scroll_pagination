import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/src/model/paging_state.dart';
import 'package:infinite_scroll_pagination/src/model/paging_status.dart';

typedef PageRequestListener<PageKeyType> = Future<void> Function(
  PageKeyType pageKey,
);
typedef PagingStatusListener = void Function(
  PagingStatus status,
);

/// A controller for a paged widget.
///
/// If you modify the [itemList], [error] or [nextPageKey] properties, the
/// paged widget will be notified and will update itself appropriately.
///
/// The [itemList], [error] or [nextPageKey] properties can be set from within
/// a listener added to this controller. If more than one property need to be
/// changed then the controller's [value] should be set instead.
///
/// This object should generally have a lifetime longer than the widgets
/// itself; it should be reused each time a paged widget constructor is called.
class PagingController<PageKeyType, ItemType>
    extends ValueNotifier<PagingState<PageKeyType, ItemType>> {
  PagingController({
    required this.firstPageKey,
    this.invisibleItemsThreshold,
  }) : super(
          PagingState<PageKeyType, ItemType>(nextPageKey: firstPageKey),
        );

  final _pagesBeingFetched = <PageKeyType>{};

  int _currentStateVersion = 0;

  /// Creates a controller from an existing [PagingState].
  ///
  /// [firstPageKey] is the key to be used in case of a [refresh].
  PagingController.fromValue(
    PagingState<PageKeyType, ItemType> value, {
    required this.firstPageKey,
    this.invisibleItemsThreshold,
  }) : super(value);

  ObserverList<PagingStatusListener>? _statusListeners =
      ObserverList<PagingStatusListener>();

  ObserverList<PageRequestListener<PageKeyType>>? _pageRequestListeners =
      ObserverList<PageRequestListener<PageKeyType>>();

  /// The number of remaining invisible items that should trigger a new fetch.
  final int? invisibleItemsThreshold;

  /// The key for the first page to be fetched.
  final PageKeyType firstPageKey;

  /// List with all items loaded so far. Initially `null`.
  List<ItemType>? get itemList => value.itemList;

  set itemList(List<ItemType>? newItemList) {
    value = PagingState<PageKeyType, ItemType>(
      error: error,
      itemList: newItemList,
      nextPageKey: nextPageKey,
      version: _currentStateVersion,
    );
  }

  /// The current error, if any. Initially `null`.
  dynamic get error => value.error;

  set error(dynamic newError) {
    value = PagingState<PageKeyType, ItemType>(
      error: newError,
      itemList: itemList,
      nextPageKey: nextPageKey,
      version: _currentStateVersion,
    );
  }

  /// The key for the next page to be fetched.
  ///
  /// Initialized with the same value as [firstPageKey], received in the
  /// constructor.
  PageKeyType? get nextPageKey => value.nextPageKey;

  set nextPageKey(PageKeyType? newNextPageKey) {
    value = PagingState<PageKeyType, ItemType>(
      error: error,
      itemList: itemList,
      nextPageKey: newNextPageKey,
      version: _currentStateVersion,
    );
  }

  /// Corresponding to [ValueNotifier.value].
  @override
  set value(PagingState<PageKeyType, ItemType> newValue) {
    if (value.status != newValue.status) {
      notifyStatusListeners(newValue.status);
    }
    super.value = newValue;
  }

  /// Appends [newItems] to the previously loaded ones and replaces
  /// the next page's key.
  void appendPage(List<ItemType> newItems, PageKeyType? nextPageKey) {
    final previousItems = value.itemList ?? [];
    final itemList = previousItems + newItems;
    value = PagingState<PageKeyType, ItemType>(
      itemList: itemList,
      error: null,
      nextPageKey: nextPageKey,
      version: _currentStateVersion,
    );
  }

  /// Appends [newItems] to the previously loaded ones and sets the next page
  /// key to `null`.
  void appendLastPage(List<ItemType> newItems) => appendPage(newItems, null);

  /// Erases the current error.
  void retryLastFailedRequest() {
    error = null;
  }

  void cancelPageRequest() {
    _pageRequestOperation?.cancel();
    _pageRequestOperation = null;
  }

  /// Resets [value] to its initial state.
  void refresh({PageKeyType? key}) {
    cancelPageRequest();
    _pagesBeingFetched.clear();
    value = PagingState<PageKeyType, ItemType>(
      nextPageKey: firstPageKey,
      error: null,
      itemList: null,
      version: ++_currentStateVersion,
    );
  }

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_pageRequestListeners == null || _statusListeners == null) {
        throw Exception(
          'A PagingController was used after being disposed.\nOnce you have '
          'called dispose() on a PagingController, it can no longer be '
          'used.\nIf you’re using a Future, it probably completed after '
          'the disposal of the owning widget.\nMake sure dispose() has not '
          'been called yet before using the PagingController.',
        );
      }
      return true;
    }());
    return true;
  }

  /// Calls listener every time the status of the pagination changes.
  ///
  /// Listeners can be removed with [removeStatusListener].
  void addStatusListener(PagingStatusListener listener) {
    assert(_debugAssertNotDisposed());
    _statusListeners?.add(listener);
  }

  /// Stops calling the listener every time the status of the pagination
  /// changes.
  ///
  /// Listeners can be added with [addStatusListener].
  void removeStatusListener(PagingStatusListener listener) {
    assert(_debugAssertNotDisposed());
    _statusListeners?.remove(listener);
  }

  /// Calls all the status listeners.
  ///
  /// If listeners are added or removed during this function, the modifications
  /// will not change which listeners are called during this iteration.
  void notifyStatusListeners(PagingStatus status) {
    assert(_debugAssertNotDisposed());

    if (_statusListeners?.isEmpty ?? true) {
      return;
    }

    final localListeners = List<PagingStatusListener>.from(_statusListeners!);
    for (final listener in localListeners) {
      if (_statusListeners!.contains(listener)) {
        listener(status);
      }
    }
  }

  /// Calls listener every time new items are needed.
  ///
  /// Listeners can be removed with [removePageRequestListener].
  void addPageRequestListener(PageRequestListener<PageKeyType> listener) {
    assert(_debugAssertNotDisposed());
    _pageRequestListeners?.add(listener);
  }

  /// Stops calling the listener every time new items are needed.
  ///
  /// Listeners can be added with [addPageRequestListener].
  void removePageRequestListener(PageRequestListener<PageKeyType> listener) {
    assert(_debugAssertNotDisposed());
    _pageRequestListeners?.remove(listener);
  }

  CancelableOperation<void>? _pageRequestOperation;

  /// Calls all the page request listeners.
  ///
  /// If listeners are added or removed during this function, the modifications
  /// will not change which listeners are called during this iteration.
  Future<void> notifyPageRequestListeners(
    PageKeyType pageKey,
  ) async {
    assert(_debugAssertNotDisposed());

    if (_pageRequestListeners?.isEmpty ?? true) {
      return;
    }

    if (_pagesBeingFetched.contains(pageKey)) {
      return;
    }

    final localListeners =
        List<PageRequestListener<PageKeyType>>.from(_pageRequestListeners!);

    for (final listener in localListeners) {
      if (_pageRequestListeners!.contains(listener)) {
        _pagesBeingFetched.add(pageKey);
        final request = listener(pageKey);
        _pageRequestOperation = CancelableOperation.fromFuture(request);
      }
    }
  }

  @override
  void dispose() {
    assert(_debugAssertNotDisposed());
    cancelPageRequest();
    _statusListeners = null;
    _pageRequestListeners = null;
    super.dispose();
  }

  String itemKey(int index) {
    return itemList?[index]?.toString() ?? index.toString();
  }
}
