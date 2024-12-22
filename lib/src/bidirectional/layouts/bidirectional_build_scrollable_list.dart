import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/src/bidirectional/controller/bidirectional_paging_controller.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class BuildScrollableList extends StatelessWidget {
  final BidirectionalPagingController? pagingController;
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final WidgetBuilder? statusIndicatorBuilder;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const BuildScrollableList({
    Key? key,
    this.pagingController,
    required this.itemBuilder,
    required this.itemCount,
    this.statusIndicatorBuilder,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  }) : super(key: key);

  int get count => statusIndicatorBuilder == null
      ? itemCount
      : hasNextPage && hasPreviousPage
          ? itemCount + 2
          : itemCount + 1;

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
      itemCount: statusIndicatorBuilder != null ? itemCount + 1 : itemCount,
      itemBuilder: statusIndicatorBuilder == null
          ? itemBuilder
          : (context, index) {
              if (statusIndicatorBuilder == null) {
                return itemBuilder(context, index);
              }
              if (hasPreviousPage && index == 0) {
                return statusIndicatorBuilder!(context);
              }
              if (hasNextPage && index == count - 1) {
                return statusIndicatorBuilder!(context);
              }

              return itemBuilder(
                context,
                hasPreviousPage ? index - 1 : index,
              );
            },
      initialScrollIndex: pagingController?.currentScrollIndex ?? 0,
      itemScrollController: pagingController?.scrollController,
      itemPositionsListener: pagingController?.positionListener,
      key: pagingController?.listKey,
    );
  }
}
