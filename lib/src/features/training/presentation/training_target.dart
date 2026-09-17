import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trainingTargetRegistryProvider = Provider<TrainingTargetRegistry>(
  (_) => TrainingTargetRegistry(),
);

/// Keeps duplicate anchors separate (shell branches and embedded track cards).
class TrainingTargetRegistry {
  final Map<String, List<GlobalKey>> _keys = {};
  final Map<String, Map<GlobalKey, VoidCallback>> _actions = {};

  void register(String id, GlobalKey key, {VoidCallback? onActivate}) {
    final keys = _keys.putIfAbsent(id, () => []);
    if (!keys.contains(key)) keys.add(key);
    if (onActivate != null) {
      (_actions[id] ??= {})[key] = onActivate;
    } else {
      _actions[id]?.remove(key);
    }
  }

  void unregister(String id, GlobalKey key) {
    _actions[id]?.remove(key);
    if (_actions[id]?.isEmpty == true) _actions.remove(id);
    final keys = _keys[id];
    keys?.remove(key);
    if (keys?.isEmpty == true) _keys.remove(id);
  }

  /// Only explicitly registered navigation/view actions may run during a tour.
  /// Never infer an action from a descendant button or synthesize pointer input.
  VoidCallback? activationFor(String id, BuildContext expectedContext) {
    if (!identical(contextFor(id), expectedContext)) return null;
    for (final entry in (_actions[id] ?? <GlobalKey, VoidCallback>{}).entries) {
      if (identical(entry.key.currentContext, expectedContext)) {
        return entry.value;
      }
    }
    return null;
  }

  BuildContext? contextFor(String id) {
    for (final key in (_keys[id] ?? <GlobalKey>[]).reversed) {
      final context = key.currentContext;
      if (context == null || !context.mounted) continue;
      final route = ModalRoute.of(context);
      var visible = route == null || (route.isCurrent && !route.offstage);
      context.visitAncestorElements((element) {
        if (element.widget case Offstage(offstage: true)) {
          visible = false;
        }
        // A root-navigator sheet also obscures routes in nested shell navigators.
        if (element.widget is Navigator) {
          final outerRoute = ModalRoute.of(element);
          if (outerRoute != null &&
              (!outerRoute.isCurrent || outerRoute.offstage)) {
            visible = false;
          }
        }
        return visible;
      });
      if (visible && context.findRenderObject()?.attached == true) {
        return context;
      }
    }
    return null;
  }
}

class TrainingTarget extends StatefulWidget {
  final String id;
  final Widget child;

  /// Existing handler for opening/closing a view. Omit for saves, submissions,
  /// selections, external pickers, clipboard operations and other user decisions.
  final VoidCallback? onActivate;

  const TrainingTarget({
    super.key,
    required this.id,
    required this.child,
    this.onActivate,
  });

  @override
  State<TrainingTarget> createState() => _TrainingTargetState();
}

class _TrainingTargetState extends State<TrainingTarget> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) => TrainingTargetBindings(
    targets: {widget.id: _key},
    actions: {if (widget.onActivate != null) widget.id: widget.onActivate!},
    child: KeyedSubtree(key: _key, child: widget.child),
  );
}

class TrainingTargetBindings extends ConsumerStatefulWidget {
  final Map<String, GlobalKey> targets;
  final Map<String, VoidCallback> actions;
  final Widget child;

  const TrainingTargetBindings({
    super.key,
    required this.targets,
    this.actions = const {},
    required this.child,
  });

  @override
  ConsumerState<TrainingTargetBindings> createState() =>
      _TrainingTargetBindingsState();
}

class _TrainingTargetBindingsState
    extends ConsumerState<TrainingTargetBindings> {
  late TrainingTargetRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = ref.read(trainingTargetRegistryProvider);
    _register(widget.targets);
  }

  void _register(Map<String, GlobalKey> targets) {
    for (final entry in targets.entries) {
      _registry.register(
        entry.key,
        entry.value,
        onActivate: widget.actions[entry.key],
      );
    }
  }

  void _unregister(Map<String, GlobalKey> targets) {
    for (final entry in targets.entries) {
      _registry.unregister(entry.key, entry.value);
    }
  }

  @override
  void didUpdateWidget(TrainingTargetBindings oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregister(oldWidget.targets);
    _register(widget.targets);
  }

  @override
  void dispose() {
    _unregister(widget.targets);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
