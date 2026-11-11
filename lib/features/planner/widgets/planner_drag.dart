import 'package:flutter/widgets.dart';

/// What is being dragged in the planner.
sealed class PlannerDrag {
  const PlannerDrag();
}

/// A stop that is already on a day.
class ItemDrag extends PlannerDrag {
  final String itemId;
  final String stopId;
  final String fromDayId;

  const ItemDrag({required this.itemId, required this.stopId, required this.fromDayId});
}

/// A stop from the backlog.
class BacklogDrag extends PlannerDrag {
  final String stopId;

  const BacklogDrag({required this.stopId});
}

/// A group's block on a day: its stops, which move together.
class GroupDrag extends PlannerDrag {
  /// In the day's order.
  final List<String> itemIds;
  final String group;
  final String fromDayId;

  const GroupDrag({required this.itemIds, required this.group, required this.fromDayId});
}

/// A group's stops in the backlog, which go onto a day together.
class BacklogGroupDrag extends PlannerDrag {
  final List<String> stopIds;
  final String group;

  const BacklogGroupDrag({required this.stopIds, required this.group});
}

/// Where a dragged stop would land: on [dayId], before [beforeItemId], or at
/// the end of the day when that's null.
class DropSlot {
  final String dayId;
  final String? beforeItemId;

  const DropSlot(this.dayId, this.beforeItemId);

  @override
  bool operator ==(Object other) =>
      other is DropSlot && other.dayId == dayId && other.beforeItemId == beforeItemId;

  @override
  int get hashCode => Object.hash(dayId, beforeItemId);
}

/// A day's stop list, so the planner can scroll it while a stop is dragged
/// near its top or bottom edge.
class ListHandle {
  final GlobalKey key;
  final ScrollController controller;

  ListHandle(this.key, this.controller);

  Rect? get globalRect {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Shared state of the drag in progress: what is dragged, where the finger
/// is, and which slot it points at.
class PlannerDragState extends ChangeNotifier {
  PlannerDrag? _active;
  Offset? _pointer;
  DropSlot? _slot;

  PlannerDrag? get active => _active;
  Offset? get pointer => _pointer;
  DropSlot? get slot => _slot;

  void start(PlannerDrag drag) {
    _active = drag;
    _slot = null;
    notifyListeners();
  }

  void move(Offset globalPosition) => _pointer = globalPosition;

  set slot(DropSlot? value) {
    if (value == _slot) return;
    _slot = value;
    notifyListeners();
  }

  void end() {
    _active = null;
    _pointer = null;
    _slot = null;
    notifyListeners();
  }
}
