import 'package:infinite_scroll_pagination/src/bidirectional/controller/bidirectional_paging_controller.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/model/bidirectional_paging_status.dart';

class BidirectionalPagingState<PageKeyType, ItemType> {
  const BidirectionalPagingState({
    this.previousPageKey,
    this.nextPageKey,
    this.itemList,
    this.error,
    required this.direction,
  });

  /// List with all items loaded so far.
  final List<ItemType>? itemList;

  /// The current error, if any.
  final dynamic error;

  /// The key for the next page to be fetched.
  final PageKeyType? nextPageKey;

  /// The key for the next page to be fetched.
  final PageKeyType? previousPageKey;

  /// The current direction of the pagination.
  final PageDirection direction;

  /// The current pagination status.
  BidirectionalPagingStatus get status {
    if (_isLoadingNextPage) {
      return BidirectionalPagingStatus.loadingNextPage;
    }

    if (_isLoadingPreviousPage) {
      return BidirectionalPagingStatus.loadingPreviousPage;
    }

    if (_isPreviousCompleted) {
      return BidirectionalPagingStatus.previousCompleted;
    }

    if (_isNextCompleted) {
      return BidirectionalPagingStatus.nextCompleted;
    }

    if (_isCompleted) {
      return BidirectionalPagingStatus.completed;
    }

    if (_isLoadingFirstPage) {
      return BidirectionalPagingStatus.loadingFirstPage;
    }

    if (_hasNextPageError) {
      return BidirectionalPagingStatus.nextPageError;
    }

    if (_hasPreviousPageError) {
      return BidirectionalPagingStatus.previousPageError;
    }

    if (_isEmpty) {
      return BidirectionalPagingStatus.noItemsFound;
    } else {
      return BidirectionalPagingStatus.firstPageError;
    }
  }

  @override
  String toString() => 'PagingState(itemList: \u2524'
      '$itemList\u251C, error: $error, nextPageKey: $nextPageKey)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BidirectionalPagingState &&
        other.itemList == itemList &&
        other.error == error &&
        other.nextPageKey == nextPageKey;
  }

  @override
  int get hashCode => Object.hash(
        itemList.hashCode,
        error.hashCode,
        nextPageKey.hashCode,
      );

  int? get _itemCount => itemList?.length;

  bool get _hasNextPage => nextPageKey != null;

  bool get _hasPreviousPage => previousPageKey != null;

  bool get _hasItems {
    final itemCount = _itemCount;
    return itemCount != null && itemCount > 0;
  }

  bool get _hasError => error != null;

  bool get _isPreviousCompleted => _hasItems && !_hasPreviousPage;

  bool get _isNextCompleted => _hasItems && !_hasNextPage;

  bool get _isCompleted => _isPreviousCompleted && _isNextCompleted;

  bool get _isLoadingFirstPage => _itemCount == null && !_hasError;

  bool get _isNextListingUnfinished => _hasItems && _hasNextPage;

  bool get _isLoadingNextPage =>
      (direction == PageDirection.initial || direction == PageDirection.next) &&
      _isNextListingUnfinished &&
      !_hasError;

  bool get _hasNextPageError =>
      (direction == PageDirection.initial || direction == PageDirection.next) &&
      _isNextListingUnfinished &&
      _hasError;

  bool get _isPreviousListingUnfinished => _hasItems && _hasPreviousPage;

  bool get _isLoadingPreviousPage =>
      direction == PageDirection.previous &&
      _isPreviousListingUnfinished &&
      !_hasError;

  bool get _hasPreviousPageError =>
      direction == PageDirection.previous &&
      _isPreviousListingUnfinished &&
      _hasError;

  bool get _isEmpty => _itemCount != null && _itemCount == 0;
}
