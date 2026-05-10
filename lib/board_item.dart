import 'package:flutter_boardview/board_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef OnDropItem = void Function(int? listIndex, int? itemIndex,
    int? oldListIndex, int? oldItemIndex, BoardItemState state);
typedef OnTapItem = void Function(
    int? listIndex, int? itemIndex, BoardItemState state);
typedef OnStartDragItem = void Function(
    int? listIndex, int? itemIndex, BoardItemState state);
typedef OnDragItem = void Function(int oldListIndex, int oldItemIndex,
    int newListIndex, int newItemIndex, BoardItemState state);

class BoardItem extends StatefulWidget {
  final BoardListState? boardList;
  final Widget? item;
  final int? index;
  final OnDropItem? onDropItem;
  final OnTapItem? onTapItem;
  final OnStartDragItem? onStartDragItem;
  final OnDragItem? onDragItem;
  final bool draggable;

  /// Overrides [BoardList.immediateMouseDrag] / [BoardView.immediateMouseDrag].
  /// When resolved true, dragging starts as soon as the primary mouse button moves beyond [kBoardViewImmediateDragThreshold].
  final bool? immediateMouseDrag;

  /// Decorative background around [item].
  final Decoration? itemDecoration;

  /// Decorative background while the pointer hovers over the tile (desktop / web — requires hover support).
  /// Animates from [itemDecoration] on enter/exit.
  final Decoration? itemHoverDecoration;

  final Duration hoverDecorationDuration;

  const BoardItem(
      {Key? key,
      this.boardList,
      this.item,
      this.index,
      this.onDropItem,
      this.onTapItem,
      this.onStartDragItem,
      this.draggable = true,
      this.onDragItem,
      this.immediateMouseDrag,
      this.itemDecoration,
      this.itemHoverDecoration,
      this.hoverDecorationDuration = const Duration(milliseconds: 220)})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardItemState();
  }
}

class BoardItemState extends State<BoardItem>
    with AutomaticKeepAliveClientMixin {
  late double height;
  double? width;

  bool _pointerHovering = false;
  bool _suppressNextTap = false;
  Offset? _lastTapDownLocalPosition;

  bool get _supportsHover => kIsWeb;

  bool get _useLongPressDrag =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  MouseCursor _resolveCursor(bool isSelecting) {
    final boardView = widget.boardList!.widget.boardView!;
    if (boardView.isDragging && !isSelecting) {
      return SystemMouseCursors.grabbing;
    }
    if (isSelecting || !widget.draggable) {
      return SystemMouseCursors.basic;
    }
    return SystemMouseCursors.grab;
  }

  @override
  bool get wantKeepAlive => true;

  void onDropItem(int? listIndex, int? itemIndex) {
    if (widget.onDropItem != null) {
      widget.onDropItem!(
          listIndex,
          itemIndex,
          widget.boardList!.widget.boardView!.startListIndex,
          widget.boardList!.widget.boardView!.startItemIndex,
          this);
    }
    widget.boardList!.widget.boardView!.draggedItemIndex = null;
    widget.boardList!.widget.boardView!.draggedListIndex = null;
    if (widget.boardList!.widget.boardView!.listStates[listIndex!].mounted) {
      widget.boardList!.widget.boardView!.listStates[listIndex].setState(() {});
    }
  }

  void _startDrag(
    Widget item,
    BuildContext context, {
    Offset? localAnchor,
    Offset? globalPointerPosition,
  }) {
    if (widget.boardList!.widget.boardView != null) {
      final boardView = widget.boardList!.widget.boardView!;
      final itemTopLeft = _captureDragGeometry(context);
      final anchor = localAnchor ??
          _lastTapDownLocalPosition ??
          Offset(
            (width ?? 0) / 2,
            height / 2,
          );
      final globalPointer = globalPointerPosition ??
          boardView.pointer?.position ??
          Offset(itemTopLeft.dx + anchor.dx, itemTopLeft.dy + anchor.dy);

      boardView.beginDragFromPosition(
        globalPointerPosition: globalPointer,
        dragOriginTopLeft: itemTopLeft,
        localAnchor: anchor,
      );

      widget.boardList!.widget.boardView!.onDropItem = onDropItem;
      if (widget.boardList!.mounted) {
        widget.boardList!.setState(() {});
      }
      boardView.draggedItemIndex = widget.index;
      boardView.markAnimatedPlaceholderIndex(widget.index);
      boardView
        ..dxInit = null
        ..dyInit = null;
      boardView.height = context.size!.height;
      boardView.draggedWidth = width ?? context.size!.width;
      boardView.draggedListIndex = widget.boardList!.widget.index;
      boardView.startListIndex = widget.boardList!.widget.index;
      boardView.startItemIndex = widget.index;
      boardView.draggedItem = item;
      if (widget.onStartDragItem != null) {
        widget.onStartDragItem!(
            widget.boardList!.widget.index, widget.index, this);
      }
      boardView.run();
      if (boardView.mounted) {
        boardView.setState(() {});
      }
    }
  }

  Offset _captureDragGeometry(BuildContext context) {
    if (!widget.draggable) {
      return Offset.zero;
    }
    RenderBox object = context.findRenderObject() as RenderBox;
    Offset pos = object.localToGlobal(Offset.zero);
    RenderBox box = widget.boardList!.context.findRenderObject() as RenderBox;
    Offset listPos = box.localToGlobal(Offset.zero);
    final bv = widget.boardList!.widget.boardView!;
    bv.leftListX = listPos.dx;
    bv.topListY = listPos.dy;
    bv.topItemY = pos.dy;
    bv.bottomItemY = pos.dy + object.size.height;
    bv.bottomListY = listPos.dy + box.size.height;
    bv.rightListX = listPos.dx + box.size.width;

    bv.initialX = pos.dx;
    bv.initialY = pos.dy;
    return pos;
  }

  void afterFirstLayout(BuildContext context) {
    try {
      height = context.size!.height;
      width = context.size!.width;
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Widget _buildDecoratedItem() {
    final Widget content = widget.item!;
    if (widget.itemHoverDecoration != null) {
      return AnimatedContainer(
        duration: widget.hoverDecorationDuration,
        curve: Curves.easeOutCubic,
        decoration: _pointerHovering
            ? widget.itemHoverDecoration!
            : (widget.itemDecoration ?? const BoxDecoration()),
        child: content,
      );
    }
    if (widget.itemDecoration != null) {
      return DecoratedBox(
        decoration: widget.itemDecoration!,
        child: content,
      );
    }
    return content;
  }

  Widget _buildDragFeedback(BuildContext context) {
    final feedback = _buildDecoratedItem();
    return SizedBox(
      width: width ?? widget.boardList!.widget.boardView!.widget.width,
      child: Material(
        color: Colors.transparent,
        child: feedback,
      ),
    );
  }

  Widget _wrapWithPlatformDraggable(
      BuildContext context, Widget child, bool isSelecting) {
    if (!widget.draggable || isSelecting) {
      return child;
    }
    final boardView = widget.boardList!.widget.boardView!;

    void startNativeDrag() {
      boardView.useNativeDragFeedback = true;
      _startDrag(
        widget,
        context,
        localAnchor: _lastTapDownLocalPosition,
      );
    }

    void updateNativeDrag(DragUpdateDetails details) {
      boardView.updateDragPosition(details.globalPosition);
    }

    if (_useLongPressDrag) {
      return LongPressDraggable<BoardItem>(
        data: widget,
        feedback: _buildDragFeedback(context),
        childWhenDragging: Opacity(opacity: 0.0, child: child),
        onDragStarted: startNativeDrag,
        onDragUpdate: updateNativeDrag,
        child: child,
      );
    }

    return Draggable<BoardItem>(
      data: widget,
      feedback: _buildDragFeedback(context),
      childWhenDragging: Opacity(opacity: 0.0, child: child),
      onDragStarted: startNativeDrag,
      onDragUpdate: updateNativeDrag,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => afterFirstLayout(context));
    if (widget.boardList!.itemStates.length > widget.index!) {
      widget.boardList!.itemStates.removeAt(widget.index!);
    }
    widget.boardList!.itemStates.insert(widget.index!, this);

    final isSelecting = widget.boardList!.widget.boardView!.widget.isSelecting;
    final isDragging = widget.boardList!.widget.boardView!.isDragging;

    final itemGesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (otd) {
        if (isDragging) {
          return;
        }
        _lastTapDownLocalPosition = otd.localPosition;
        _captureDragGeometry(context);
      },
      onTapCancel: () {},
      onTap: () {
        if (isDragging) {
          return;
        }
        if (_suppressNextTap) {
          _suppressNextTap = false;
          return;
        }
        if (widget.onTapItem != null) {
          widget.onTapItem!(
              widget.boardList!.widget.index, widget.index, this);
        }
      },
      child: _buildDecoratedItem(),
    );

    return MouseRegion(
      cursor: _resolveCursor(isSelecting),
      onEnter: (_) {
        if (!_supportsHover) {
          return;
        }
        if (isDragging) {
          if (_pointerHovering && mounted) {
            setState(() => _pointerHovering = false);
          }
          return;
        }
        if (widget.itemHoverDecoration != null && mounted) {
          setState(() => _pointerHovering = true);
        }
      },
      onExit: (_) {
        if (!_supportsHover) {
          return;
        }
        if (mounted) {
          setState(() => _pointerHovering = false);
        }
      },
      child: _wrapWithPlatformDraggable(context, itemGesture, isSelecting),
    );
  }
}
