import 'package:flutter/foundation.dart';
import 'package:flutter_boardview/board_item.dart';
import 'package:flutter_boardview/boardview.dart';
import 'package:flutter/material.dart';

typedef OnDropList = void Function(int? listIndex, int? oldListIndex);
typedef OnTapList = void Function(int? listIndex);
typedef OnStartDragList = void Function(int? listIndex);

class BoardList extends StatefulWidget {
  final List<Widget>? header;
  final Widget? footer;
  final List<BoardItem>? items;
  final Color? backgroundColor;
  final Color? headerBackgroundColor;
  final BoardViewState? boardView;
  final OnDropList? onDropList;
  final OnTapList? onTapList;
  final OnStartDragList? onStartDragList;
  final BoxScrollView Function(NullableIndexedWidgetBuilder itemBuilder)?
      listBuilder;
  final bool draggable;

  /// When non-null, overrides [BoardView.immediateMouseDrag] for this column.
  /// See [BoardView.immediateMouseDrag].
  final bool? immediateMouseDrag;

  const BoardList({
    Key? key,
    this.header,
    this.items,
    this.footer,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.boardView,
    this.draggable = true,
    this.index,
    this.onDropList,
    this.onTapList,
    this.onStartDragList,
    this.listBuilder,
    this.immediateMouseDrag,
  }) : super(key: key);

  final int? index;

  @override
  State<StatefulWidget> createState() {
    return BoardListState();
  }
}

class BoardListState extends State<BoardList>
    with AutomaticKeepAliveClientMixin {
  List<Widget>? _header;
  List<BoardItemState> itemStates = [];
  ScrollController boardListController = ScrollController();

  Offset? _headerTapDownLocalPosition;

  bool get _useLongPressDrag =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    setState(() {
      _header = widget.header;
    });
    super.initState();
  }

  void updateHeader(List<Widget>? header) {
    setState(() => _header = header);
  }

  void onDropList(int? listIndex) {
    if (widget.onDropList != null) {
      widget.onDropList!(listIndex, widget.boardView!.startListIndex);
    }
    widget.boardView!.draggedListIndex = null;
    if (widget.boardView!.mounted) {
      widget.boardView!.setState(() {});
    }
  }

  bool get _supportsHover => kIsWeb;

  Offset _captureListDragGeometry(BuildContext context) {
    RenderBox object = context.findRenderObject() as RenderBox;
    Offset pos = object.localToGlobal(Offset.zero);
    widget.boardView!.initialX = pos.dx;
    widget.boardView!.initialY = pos.dy;
    widget.boardView!.rightListX = pos.dx + object.size.width;
    widget.boardView!.leftListX = pos.dx;
    return pos;
  }

  void _startDrag(
    Widget item,
    BuildContext context, {
    Offset? localAnchor,
    Offset? globalPointerPosition,
  }) {
    if (widget.boardView != null && widget.draggable) {
      final boardView = widget.boardView!;
      final listTopLeft = _captureListDragGeometry(context);
      final RenderBox object = context.findRenderObject() as RenderBox;
      final anchor = localAnchor ??
          _headerTapDownLocalPosition ??
          Offset(object.size.width / 2, object.size.height / 2);
      final globalPointer = globalPointerPosition ??
          boardView.pointer?.position ??
          Offset(listTopLeft.dx + anchor.dx, listTopLeft.dy + anchor.dy);

      boardView.beginDragFromPosition(
        globalPointerPosition: globalPointer,
        dragOriginTopLeft: listTopLeft,
        localAnchor: anchor,
      );
      boardView.useNativeDragFeedback = true;

      if (widget.onStartDragList != null) {
        widget.onStartDragList!(widget.index);
      }
      boardView.startListIndex = widget.index;
      boardView.height = context.size!.height;
      boardView.draggedWidth = context.size!.width;
      boardView.draggedListIndex = widget.index!;
      boardView.draggedItemIndex = null;
      boardView.draggedItem = item;
      boardView.onDropList = onDropList;
      boardView.run();
      if (boardView.mounted) {
        boardView.setState(() {});
      }
    }
  }

  Widget _wrapHeaderWithPlatformDraggable(
      BuildContext context, Widget child, bool isSelecting) {
    if (!widget.draggable || isSelecting) {
      return child;
    }
    final boardView = widget.boardView!;

    void startNativeDrag() {
      _startDrag(
        widget,
        context,
        localAnchor: _headerTapDownLocalPosition,
      );
    }

    void updateNativeDrag(DragUpdateDetails details) {
      boardView.updateDragPosition(details.globalPosition);
    }

    if (_useLongPressDrag) {
      return LongPressDraggable<BoardList>(
        data: widget,
        feedback: SizedBox(
          width: widget.boardView!.widget.width,
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.0, child: child),
        onDragStarted: startNativeDrag,
        onDragUpdate: updateNativeDrag,
        onDragEnd: (_) {
          boardView.useNativeDragFeedback = false;
        },
        child: child,
      );
    }

    return Draggable<BoardList>(
      data: widget,
      feedback: SizedBox(
        width: widget.boardView!.widget.width,
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.0, child: child),
      onDragStarted: startNativeDrag,
      onDragUpdate: updateNativeDrag,
      onDragEnd: (_) {
        boardView.useNativeDragFeedback = false;
      },
      child: child,
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _itemBuilder(ctx, index) {
    if (widget.items![index].boardList == null ||
        widget.items![index].index != index ||
        widget.items![index].boardList!.widget.index != widget.index ||
        widget.items![index].boardList != this) {
      widget.items![index] = BoardItem(
        boardList: this,
        item: widget.items![index].item,
        draggable: widget.items![index].draggable,
        index: index,
        onDropItem: widget.items![index].onDropItem,
        onTapItem: widget.items![index].onTapItem,
        onDragItem: widget.items![index].onDragItem,
        onStartDragItem: widget.items![index].onStartDragItem,
        immediateMouseDrag: widget.items![index].immediateMouseDrag,
        itemDecoration: widget.items![index].itemDecoration,
        itemHoverDecoration: widget.items![index].itemHoverDecoration,
        hoverDecorationDuration: widget.items![index].hoverDecorationDuration,
      );
    }
    if (widget.boardView!.draggedItemIndex == index &&
        widget.boardView!.draggedListIndex == widget.index &&
        widget.boardView!.isDragOverlayReady) {
      return Opacity(
        opacity: 0.0,
        child: widget.items![index],
      );
    } else {
      return widget.items![index];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    List<Widget> listWidgets = [];
    if (_header != null) {
      Color? headerBackgroundColor =
          Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4);
      if (widget.headerBackgroundColor != null) {
        headerBackgroundColor = widget.headerBackgroundColor;
      }
      final headerContent = Container(
        decoration: BoxDecoration(
          color: headerBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: _header!),
      );
      final isSelecting = widget.boardView!.widget.isSelecting;
      final headerTapArea = GestureDetector(
          onTap: () {
            if (widget.onTapList != null) {
              widget.onTapList!(widget.index);
            }
          },
          onTapDown: (otd) {
            if (widget.draggable) {
              _headerTapDownLocalPosition = otd.localPosition;
              _captureListDragGeometry(context);
            }
          },
          onTapCancel: () {},
          child: headerContent);

      listWidgets.add(MouseRegion(
          cursor: widget.boardView!.isDragging &&
                  !widget.boardView!.widget.isSelecting
              ? SystemMouseCursors.grabbing
              : widget.draggable &&
                      _supportsHover &&
                      !widget.boardView!.widget.isSelecting
                  ? SystemMouseCursors.grab
                  : SystemMouseCursors.basic,
          child: _wrapHeaderWithPlatformDraggable(
            context,
            headerTapArea,
            isSelecting,
          ),
        ));
    }
    if (widget.items != null) {
      if (widget.listBuilder != null) {
        listWidgets.add(Flexible(
            fit: FlexFit.tight, child: widget.listBuilder!(_itemBuilder)));
      } else {
        listWidgets.add(Flexible(
            fit: FlexFit.tight,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              controller: boardListController,
              itemCount: widget.items!.length,
              itemBuilder: _itemBuilder,
            )));
      }
    }

    if (widget.footer != null) {
      listWidgets.add(widget.footer!);
    }

    Color? backgroundColor = Theme.of(context).colorScheme.onInverseSurface;

    if (widget.backgroundColor != null) {
      backgroundColor = widget.backgroundColor;
    }
    if (widget.boardView!.listStates.length > widget.index!) {
      widget.boardView!.listStates.removeAt(widget.index!);
    }
    widget.boardView!.listStates.insert(widget.index!, this);

    return Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: listWidgets,
        ));
  }
}
