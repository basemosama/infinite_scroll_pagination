import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/controller/bidirectional_paging_controller.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/layouts/bidirectional_build_scrollable_list.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/layouts/bidirectional_paged_layout_builder.dart';
import 'package:infinite_scroll_pagination/src/core/paged_child_builder_delegate.dart';

/// A [SliverList] with pagination capabilities.
///
/// To include separators, use [PagedSliverList.separated].
///
/// Similar to [PagedListView] but needs to be wrapped by a
/// [CustomScrollView] when added to the screen.
/// Useful for combining multiple scrollable pieces in your UI or if you need
/// to add some widgets preceding or following your paged list.
class BidirectionalPagedScrollableList<PageKeyType, ItemType>
    extends StatelessWidget {
  const BidirectionalPagedScrollableList({
    Key? key,
    required this.pagingController,
    required this.builderDelegate,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.itemExtent,
    this.prototypeItem,
    this.semanticIndexCallback,
    this.shrinkWrapFirstPageIndicators = false,
  })  : assert(
          itemExtent == null || prototypeItem == null,
          'You can only pass itemExtent or prototypeItem, not both',
        ),
        super(key: key);

  /// Matches [PagedLayoutBuilder.pagingController].
  final BidirectionalPagingController<PageKeyType, ItemType>? pagingController;

  /// Matches [PagedLayoutBuilder.builderDelegate].
  final PagedChildBuilderDelegate<ItemType> builderDelegate;

  /// Matches [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// Matches [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// Matches [SliverChildBuilderDelegate.semanticIndexCallback].
  final SemanticIndexCallback? semanticIndexCallback;

  /// Matches [SliverFixedExtentList.itemExtent].
  ///
  /// If this is not null, [prototypeItem] must be null, and vice versa.
  final double? itemExtent;

  /// Matches [SliverPrototypeExtentList.prototypeItem].
  ///
  /// If this is not null, [itemExtent] must be null, and vice versa.
  final Widget? prototypeItem;

  /// Matches [PagedLayoutBuilder.shrinkWrapFirstPageIndicators].
  final bool shrinkWrapFirstPageIndicators;

  @override
  Widget build(BuildContext context) =>
      BidirectionalPagedLayoutBuilder<PageKeyType, ItemType>(
        layoutProtocol: PagedLayoutProtocol.sliver,
        pagingController: pagingController,
        builderDelegate: builderDelegate,
        completedListingBuilder: (
          context,
          itemBuilder,
          itemCount,
          noMoreItemsIndicatorBuilder,
        ) =>
            BuildScrollableList(
          itemBuilder: itemBuilder,
          itemCount: itemCount,
          pagingController: pagingController,
          statusIndicatorBuilder: noMoreItemsIndicatorBuilder,
        ),
        loadingListingBuilder: (
          context,
          itemBuilder,
          itemCount,
          progressIndicatorBuilder,
          hasNextPage,
          hasPreviousPage,
        ) =>
            BuildScrollableList(
          itemBuilder: itemBuilder,
          itemCount: itemCount,
          pagingController: pagingController,
          statusIndicatorBuilder: progressIndicatorBuilder,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
        ),
        errorListingBuilder: (
          context,
          itemBuilder,
          itemCount,
          errorIndicatorBuilder,
          hasNextPage,
          hasPreviousPage,
        ) =>
            BuildScrollableList(
          itemBuilder: itemBuilder,
          itemCount: itemCount,
          pagingController: pagingController,
          statusIndicatorBuilder: errorIndicatorBuilder,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
        ),
      );
}
