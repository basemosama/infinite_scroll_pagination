import 'dart:math';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/model/bidirectional_paging_state.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/model/bidirectional_paging_status.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

enum PageDirection {
  initial,
  next,
  previous,
}

typedef BidirectionalPageRequestListener<PageKeyType> = Future<void> Function(
  PageKeyType pageKey,
  PageDirection direction,
);

typedef BidirectionalPagingStatusListener = void Function(
  BidirectionalPagingStatus status,
);

typedef PageBuildListener = void Function(
  int itemCount,
  bool hasNextPage,
  bool hasPreviousPage,
);

class BidirectionalPagingController<PageKeyType, ItemType>
    extends ValueNotifier<BidirectionalPagingState<PageKeyType, ItemType>> {
  ItemScrollController scrollController = ItemScrollController();
  ItemPositionsListener positionListener = ItemPositionsListener.create();

  PageKeyType firstPageKey;
  PageKeyType? firstPreviousPageKey;
  final int invisibleNextItemsThreshold;
  final int invisiblePreviousItemsThreshold;

  int currentScrollIndex = 0;

  final _pagesBeingFetched = <PageKeyType>{};
  int _currentStateVersion = 0;

  BidirectionalPagingController({
    required this.firstPageKey,
    this.firstPreviousPageKey,
    this.invisibleNextItemsThreshold = 30,
    this.invisiblePreviousItemsThreshold = 5,
  }) : super(
          BidirectionalPagingState<PageKeyType, ItemType>(
            nextPageKey: firstPageKey,
            previousPageKey: firstPreviousPageKey,
            direction: PageDirection.initial,
          ),
        ) {
    initScrollController();
  }

  /// List with all items loaded so far. Initially `null`.
  List<ItemType>? get itemList => value.itemList;

  ObserverList<BidirectionalPagingStatusListener>? _statusListeners =
      ObserverList<BidirectionalPagingStatusListener>();

  ObserverList<BidirectionalPageRequestListener<PageKeyType>>?
      _pageRequestListeners =
      ObserverList<BidirectionalPageRequestListener<PageKeyType>>();

  ObserverList<PageBuildListener>? _pageBuildCompletedListener =
      ObserverList<PageBuildListener>();

  bool _canRequestNewPage = false;

  /// The loaded items count.
  int get itemCount => itemList?.length ?? 0;

  /// Tells whether there's a next page to request.
  bool get hasNextPage => nextPageKey != null;

  /// Tells whether there's a previous page to request.
  bool get hasPreviousPage => previousPageKey != null;

  set itemList(List<ItemType>? newItemList) {
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      error: error,
      itemList: newItemList,
      nextPageKey: nextPageKey,
      previousPageKey: previousPageKey,
      direction: direction,
      version: _currentStateVersion,
    );
  }

  /// The current error, if any. Initially `null`.
  dynamic get error => value.error;

  set error(dynamic newError) {
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      error: newError,
      itemList: itemList,
      nextPageKey: nextPageKey,
      previousPageKey: previousPageKey,
      direction: direction,
      version: _currentStateVersion,
    );
  }

  /// The key for the next page to be fetched.
  ///
  /// Initialized with the same value as [firstPageKey], received in the
  /// constructor.
  PageKeyType? get nextPageKey => value.nextPageKey;

  PageDirection get direction => value.direction;

  set nextPageKey(PageKeyType? newNextPageKey) {
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      error: error,
      itemList: itemList,
      nextPageKey: newNextPageKey,
      direction: direction,
      version: _currentStateVersion,
    );
  }

  /// The key for the previous page to be fetched.
  ///
  /// Initialized with the same value as [firstPageKey], received in the
  /// constructor.
  PageKeyType? get previousPageKey => value.previousPageKey;

  set previousPageKey(PageKeyType? newPreviousPageKey) {
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      error: error,
      itemList: itemList,
      nextPageKey: nextPageKey,
      previousPageKey: newPreviousPageKey,
      direction: direction,
      version: _currentStateVersion,
    );
  }

  /// Corresponding to [ValueNotifier.value].
  @override
  set value(BidirectionalPagingState<PageKeyType, ItemType> newValue) {
    if (value.status != newValue.status) {
      notifyStatusListeners(newValue.status);
    }
    super.value = newValue;
    if (value.status == BidirectionalPagingStatus.loadingNextPage ||
        value.status == BidirectionalPagingStatus.loadingPreviousPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkNextPageRequest(
          currentScrollIndex,
        );
        _checkPreviousPageRequest(
          currentScrollIndex,
        );
      });
    }
  }

  /// Appends [newItems] to the previously loaded ones and replaces
  /// the next page's key.
  void appendPage({
    required List<ItemType> items,
    PageKeyType? nextPageKey,
    PageKeyType? previousPageKey,
  }) {
    final previousItems = value.itemList ?? [];
    final itemList = previousItems + items;
    _lastPrependedItmsCount = 0;
    updateLoadingState();
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      itemList: itemList,
      nextPageKey: nextPageKey,
      previousPageKey: previousPageKey ?? this.previousPageKey,
      direction: previousItems.isEmpty && previousPageKey != null
          ? PageDirection.initial
          : PageDirection.next,
      version: _currentStateVersion,
    );
  }

  /// Prepends [newItems] to the previously loaded ones and sets the next page
  /// key to `null`.
  void appendLastPage(List<ItemType> newItems) => appendPage(items: newItems);

  int _lastPrependedItmsCount = 0;

  /// Appends [newItems] to the previously loaded ones and replaces
  /// the previous page's key.
  Future<void> prependPage({
    required List<ItemType> items,
    PageKeyType? nextPageKey,
    PageKeyType? previousPageKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final previousItems = value.itemList ?? [];
    final itemList = items + previousItems;
    _lastPrependedItmsCount = items.length;
    updateLoadingState(shouldScroll: true);
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      itemList: itemList,
      previousPageKey: previousPageKey,
      nextPageKey: nextPageKey ?? this.nextPageKey,
      direction: PageDirection.previous,
      version: _currentStateVersion,
    );
  }

  void scrollToCurrentIndex() {
    scrollToIndex(index: currentScrollIndex - 1, animate: false);
  }

  /// Prepends [items] to the previously loaded ones and sets the previous page
  /// key to `null`.
  void prependFirstPage(List<ItemType> items) => prependPage(
        items: items,
      );

  /// Erases the current error.
  void retryLastFailedRequest() {
    error = null;
  }

  void cancelPageRequest() {
    _pageRequestOperation?.cancel();
    _pageRequestOperation = null;
    _canRequestNewPage = true;
  }

  /// Resets [value] to its initial state.
  void refresh({PageKeyType? key}) {
    cancelPageRequest();
    if (key != null) firstPageKey = key;
    _pagesBeingFetched.clear();
    currentScrollIndex = 0;
    _lastPrependedItmsCount = 0;
    resetList();
    value = BidirectionalPagingState<PageKeyType, ItemType>(
      nextPageKey: firstPageKey,
      direction: PageDirection.initial,
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
  void addStatusListener(BidirectionalPagingStatusListener listener) {
    assert(_debugAssertNotDisposed());
    _statusListeners!.add(listener);
  }

  /// Stops calling the listener every time the status of the pagination
  /// changes.
  ///
  /// Listeners can be added with [addStatusListener].
  void removeStatusListener(BidirectionalPagingStatusListener listener) {
    assert(_debugAssertNotDisposed());
    _statusListeners!.remove(listener);
  }

  /// Calls all the status listeners.
  ///
  /// If listeners are added or removed during this function, the modifications
  /// will not change which listeners are called during this iteration.
  void notifyStatusListeners(BidirectionalPagingStatus status) {
    assert(_debugAssertNotDisposed());

    if (_statusListeners!.isEmpty) {
      return;
    }

    final localListeners =
        List<BidirectionalPagingStatusListener>.from(_statusListeners!);
    for (final listener in localListeners) {
      if (_statusListeners!.contains(listener)) {
        listener(status);
      }
    }
  }

  /// Calls listener every time new items are needed.
  ///
  /// Listeners can be removed with [removePageRequestListener].
  void addPageRequestListener(
      BidirectionalPageRequestListener<PageKeyType> listener) {
    assert(_debugAssertNotDisposed());
    _pageRequestListeners!.add(listener);
  }

  /// Stops calling the listener every time new items are needed.
  ///
  /// Listeners can be added with [addPageRequestListener].
  void removePageRequestListener(
      BidirectionalPageRequestListener<PageKeyType> listener) {
    assert(_debugAssertNotDisposed());
    _pageRequestListeners!.remove(listener);
  }

  void addPageBuildListener(PageBuildListener listener) {
    assert(_debugAssertNotDisposed());
    _pageBuildCompletedListener!.add(listener);
  }

  void removePageBuildListener(PageBuildListener listener) {
    assert(_debugAssertNotDisposed());
    _pageBuildCompletedListener!.remove(listener);
  }

  CancelableOperation<void>? _pageRequestOperation;

  /// Calls all the page request listeners.
  ///
  /// If listeners are added or removed during this function, the modifications
  /// will not change which listeners are called during this iteration.
  Future<void> notifyPageRequestListeners(
    PageKeyType pageKey,
    PageDirection direction,
  ) async {
    assert(_debugAssertNotDisposed());

    if (_pageRequestListeners?.isEmpty ?? true) {
      return;
    }

    if (_pagesBeingFetched.contains(pageKey)) {
      return;
    }

    final localListeners =
        List<BidirectionalPageRequestListener<PageKeyType>>.from(
            _pageRequestListeners!);

    for (final listener in localListeners) {
      if (_pageRequestListeners!.contains(listener)) {
        _pagesBeingFetched.add(pageKey);
        _pageRequestOperation =
            CancelableOperation.fromFuture(listener(pageKey, direction));
      }
    }
  }

  void _checkPreviousPageRequest(
    int index,
  ) {
    final previousPageRequestTriggerIndex =
        max(0, invisiblePreviousItemsThreshold);
    final isBuildingPreviousTriggerIndexItem =
        index <= previousPageRequestTriggerIndex;

    if (hasPreviousPage && isBuildingPreviousTriggerIndexItem) {
      // Schedules the request for the end of this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previousPageKey != null) {
          notifyPageRequestListeners(
            previousPageKey as PageKeyType,
            PageDirection.previous,
          );
        }
      });
      _canRequestNewPage = false;
    }
  }

  void checkNextPageRequest(
    int index,
  ) {
    final newPageRequestTriggerIndex =
        max(0, itemCount - invisibleNextItemsThreshold);

    final isBuildingTriggerIndexItem = index >= newPageRequestTriggerIndex;

    if (hasNextPage && isBuildingTriggerIndexItem) {
      // Schedules the request for the end of this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyPageRequestListeners(
          nextPageKey as PageKeyType,
          PageDirection.next,
        );
      });
      _canRequestNewPage = false;
    }
  }

  @override
  void dispose() {
    assert(_debugAssertNotDisposed());
    cancelPageRequest();
    _statusListeners = null;
    _pageRequestListeners = null;
    _pageBuildCompletedListener = null;
    super.dispose();
  }

  void scrollToIndex({required int index, required bool animate}) {
    final itemIndex = index + (previousPageKey != null ? 1 : 0);

    if (itemIndex < itemCount && itemIndex >= 0) {
      currentScrollIndex = itemIndex;

      final bool isLastItemVisible = (lastVisibleIndex ?? -1) >= itemCount - 1;
      final bool isScrollingToLastItemVisible =
          itemIndex >= (firstVisibleIndex ?? -1) &&
              itemIndex <= (lastVisibleIndex ?? -1);

      //Animate if the last item is visible to avoid unnecessary jump
      final shouldAnimate =
          animate || (isLastItemVisible && isScrollingToLastItemVisible);

      if (shouldAnimate) {
        scrollController.scrollTo(
          index: itemIndex,
          duration: const Duration(milliseconds: 150),
        );
      } else {
        scrollController.jumpTo(
          index: itemIndex,
        );
      }
    }
  }

  Iterable<ItemPosition> get itemPositions =>
      positionListener.itemPositions.value;

  int? get lastVisibleIndex {
    final lastPositions =
        itemPositions.where((element) => element.itemTrailingEdge >= 0);

    return lastPositions.isEmpty
        ? null
        : lastPositions
            .reduce(
              (value, element) =>
                  value.itemTrailingEdge > element.itemTrailingEdge
                      ? value
                      : element,
            )
            .index;
  }

  int? get firstVisibleIndex {
    final positions =
        itemPositions.where((element) => element.itemLeadingEdge <= 1);

    final index = positions.isEmpty
        ? null
        : positions
            .reduce(
              (value, element) =>
                  value.itemLeadingEdge < element.itemLeadingEdge
                      ? value
                      : element,
            )
            .index;

    return index;
  }

  int? get lastVisibleScrollIndex {
    final lastPositions =
        itemPositions.where((element) => element.itemTrailingEdge < 1);

    return lastPositions.isEmpty
        ? null
        : lastPositions
            .reduce(
              (value, element) =>
                  value.itemTrailingEdge > element.itemTrailingEdge
                      ? value
                      : element,
            )
            .index;
  }

  int? get firstVisibleScrollIndex {
    final positions = itemPositions.where(
      (element) => element.itemLeadingEdge < 1 && element.itemLeadingEdge > 0,
    );

    final index = positions.isEmpty
        ? null
        : positions
            .reduce(
              (value, element) =>
                  value.itemLeadingEdge < element.itemLeadingEdge
                      ? value
                      : element,
            )
            .index;

    return index;
  }

  void initScrollController() {
    positionListener.itemPositions.addListener(listenToScrollIndex);
  }

  void listenToScrollIndex() {
    if (firstVisibleIndex != null) {
      currentScrollIndex = firstVisibleIndex!;
      if (_canRequestNewPage) {
        _checkPreviousPageRequest(firstVisibleIndex!);
      }
    }
    if (_canRequestNewPage && lastVisibleIndex != null) {
      checkNextPageRequest(lastVisibleIndex!);
    }
  }

  Key? listKey = UniqueKey();

  int? forceToExecuteInitIndex;

  void updateLoadingState({bool shouldScroll = false}) {
    if (!shouldScroll) {
      _canRequestNewPage = true;
      return;
    }

    if (firstVisibleIndex != null) {
      final int firstIndex = firstVisibleIndex!;
      final index = _lastPrependedItmsCount + firstIndex;
      currentScrollIndex = index;
      resetList();
    }
    _canRequestNewPage = true;
  }

  void resetList() {
    positionListener.itemPositions.removeListener(listenToScrollIndex);
    positionListener = ItemPositionsListener.create();
    scrollController = ItemScrollController();
    initScrollController();
    listKey = UniqueKey();
  }

  void onBuildCompleted({
    required int itemCount,
    required bool hasNextPage,
    required bool hasPreviousPage,
  }) {
    if (_pageBuildCompletedListener?.isEmpty ?? true) {
      return;
    }

    final localListeners =
        List<PageBuildListener>.from(_pageBuildCompletedListener!);

    for (final listener in localListeners) {
      if (_pageBuildCompletedListener!.contains(listener)) {
        listener(itemCount, hasNextPage, hasPreviousPage);
      }
    }
  }

  String itemKey(int index) {
    return itemList?[index]?.toString() ?? index.toString();
  }
}
