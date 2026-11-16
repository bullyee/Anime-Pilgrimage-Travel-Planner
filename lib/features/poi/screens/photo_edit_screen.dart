import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/platform_media.dart';
import '../../camera/services/reinhard_match_service.dart';
import '../../camera/widgets/capture_sheets.dart';
import '../../library/providers/place_providers.dart';
import '../services/background_photo_save.dart';
import '../services/brightness_service.dart';
import '../services/edit_preview_service.dart';
import '../services/edit_recipe.dart';
import '../services/full_res_render.dart';
import '../services/sharpness_service.dart';
import 'collage_page.dart';

/// One step in the edit history.
///
/// Filters chain: every step's [toolBaseBytes] is the previous step's
/// committed [bytes] (or the editor's downscaled `_editingBaseBytes`
/// for the very first step), so a sequence like Match Color → Brightness
/// → Sharpness stacks effects on top of each other instead of throwing
/// the previous one away.
///
/// `bytes == null` means the step has been created but not yet committed
/// (the user is still dialling in the slider); on Confirm we compute the
/// byte-buffer result against [toolBaseBytes] and populate [bytes].
///
/// Tool-specific fields (`matchedBaseBytes` + `strength` for Match
/// Color, `brightness`, `sharpness`) ride along so a slider drag can
/// mutate the current step rather than spam undo with one history entry
/// per slider tick.
@immutable
class _EditState {
  final Uint8List? bytes;
  final String? tool;
  final Uint8List? toolBaseBytes;
  final Uint8List? matchedBaseBytes;
  final double strength;
  final double brightness;
  final double sharpness;

  /// Match Color: the reference [matchedBaseBytes] was matched against, so
  /// Save matches the full-res photo against the same one even if the
  /// reference is swapped later.
  final String? matchReferencePath;

  const _EditState({
    this.bytes,
    this.tool,
    this.toolBaseBytes,
    this.matchedBaseBytes,
    this.strength = 1.0,
    this.brightness = 0,
    this.sharpness = 0,
    this.matchReferencePath,
  });

  _EditState copyWith({
    Uint8List? bytes,
    String? tool,
    Uint8List? toolBaseBytes,
    Uint8List? matchedBaseBytes,
    double? strength,
    double? brightness,
    double? sharpness,
    String? matchReferencePath,
  }) {
    return _EditState(
      bytes: bytes ?? this.bytes,
      tool: tool ?? this.tool,
      toolBaseBytes: toolBaseBytes ?? this.toolBaseBytes,
      matchedBaseBytes: matchedBaseBytes ?? this.matchedBaseBytes,
      strength: strength ?? this.strength,
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
      matchReferencePath: matchReferencePath ?? this.matchReferencePath,
    );
  }

  /// This step as Save replays it on the full-resolution photo.
  EditStep? get asEditStep => switch (tool) {
        'match' =>
          EditStep('match', strength, referencePath: matchReferencePath),
        'brightness' => EditStep('brightness', brightness),
        'sharpness' => EditStep('sharpness', sharpness),
        _ => null,
      };
}

/// Standalone photo editor — reads everything it needs from its
/// constructor args and saves through [BackgroundPhotoSaves], so the
/// same screen serves both the live camera flow ("just shot this") and
/// the place page flow ("edit this photo") without either path needing
/// to seed any global state. Lives under `poi/screens` until the old POI
/// screens go; reuses the colour-match service that still ships from the
/// camera feature.
class PhotoEditScreen extends ConsumerStatefulWidget {
  /// Place whose photos the saved photo joins, until the user picks another
  /// with the AppBar's place button. Null when the photo has no place yet —
  /// Edit Photo, or an Anime Camera shot taken without one: the result then
  /// only goes to the phone's gallery, unless the user picks a place or a
  /// frame from one.
  final String? placeKey;

  /// The trip the saved photo is filed under. Null lets the save find the
  /// trip that has the place on the day the photo was taken.
  final String? tripId;

  /// The place photo being edited, when it is one: the saved edit derives
  /// from it.
  final String? derivedFromId;

  /// File on disk that this screen edits. It's never written to — the
  /// edited result is rendered into its own temp file in the background
  /// and copied into permanent app storage from there.
  final String sourcePath;

  /// Optional anime-scene reference: when set, the editor allows the
  /// reference-overlay toggle, the swipe-to-reference page, and the
  /// Match Color chip. When null, all three are disabled.
  final String? referencePath;

  /// If a reference image is provided, the matching `ReferenceImages`
  /// row id is passed through to the saved `MediaAsset` so the
  /// before/after pair survives in the database.
  final String? referenceImageId;

  /// `true` when [sourcePath] is a gallery-picked image rather than a
  /// fresh camera capture, so the old POI page's media list shows the
  /// upload icon for it.
  final bool wasUpload;

  /// `true` for a photo just taken with the Anime Camera. It isn't in the
  /// phone's gallery yet, so Save puts the untouched original there next
  /// to the edit.
  final bool isCapture;

  const PhotoEditScreen({
    super.key,
    this.placeKey,
    this.tripId,
    this.derivedFromId,
    required this.sourcePath,
    this.referencePath,
    this.referenceImageId,
    this.wasUpload = false,
    this.isCapture = false,
  });

  @override
  ConsumerState<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends ConsumerState<PhotoEditScreen> {
  // History always starts with the original (bytes: null, tool: null).
  // _historyIndex points at the currently-visible step; tapping a tool
  // truncates anything past it and appends the new step.
  List<_EditState> _history = const [_EditState()];
  int _historyIndex = 0;

  // Reference image is mutable — the Reference tool lets the user swap it
  // (or add one when there isn't one yet) without leaving the editor. When
  // the swap happens we drop any pending Match Color result because the
  // matched bytes were computed against the old reference and would
  // mislead the user.
  String? _referencePath;
  String? _referenceImageId;
  // Place the photo is saved into (null: only the phone's gallery). Starts
  // as [PhotoEditScreen.placeKey]; the AppBar's place button changes it, and
  // picking a frame from a place fills it in when it's still empty.
  String? _placeKey;

  // Reference overlay starts visible (when a reference image is in
  // play) to match the live camera — the floating bar provides the eye
  // toggle to hide / re-show it without leaving the canvas.
  bool _showOverlay = true;
  // Overlay pan / pinch / opacity, matched to the live camera's
  // reference overlay so behaviour transfers across screens.
  Offset _overlayOffset = Offset.zero;
  // Starts at 0.8 (not 1) so that when the user first toggles the
  // overlay on, the reference image is clearly inset from the canvas
  // edges — otherwise a full-size overlay can blanket the underlying
  // photo so completely that the user can't tell anything changed.
  double _overlayScale = 0.8;
  double _overlayOpacity = 0.4;
  // Free rotation of the reference overlay in radians — driven by a
  // two-finger twist or the floating bar's rotate button. Purely a
  // framing aid; never burned into the saved photo.
  double _overlayRotation = 0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;
  double _gestureStartScale = 1;
  double _gestureStartRotation = 0;

  bool _processing = false;
  bool _saving = false;

  // Manual photo orientation, set with the Rotate tool: mirrored left to
  // right (first), then clockwise quarter-turns (0–3), then straightened by
  // a free angle in degrees clockwise. Kept as global editor properties
  // rather than history steps: they're geometry sitting on top of the
  // filter chain (the per-pixel filters are orientation-agnostic), and at
  // Save they're baked into the saved file so the saved photo matches the
  // preview.
  bool _mirrored = false;
  int _rotationQuarters = 0;
  double _straightenDegrees = 0;

  // While the Rotate tool is open: the orientation being dialled in, shown
  // live on the canvas and kept on Done.
  bool _inRotateMode = false;
  bool _draftMirrored = false;
  int _draftQuarters = 0;
  double _draftDegrees = 0;

  // Crop is a geometric post-op like rotation: a normalised (0..1) rect
  // over the *displayed* (turned and straightened) image. null = no crop /
  // full frame. It's shown in the preview by clipping and baked into the
  // saved file at Save. Solves the "phone shoots 4:3 but the anime is 16:9"
  // mismatch — crop the capture down to the reference's proportions.
  Rect? _cropRect;
  // While the crop editor is open: the in-progress rect + an optional
  // locked output aspect (width/height in pixels; null = free-form).
  bool _inCropMode = false;
  Rect _draftCropRect = const Rect.fromLTWH(0, 0, 1, 1);
  double? _cropAspectLock;
  // Pixel dimensions (decoded once) of the upright editing base and the
  // reference image, so the crop UI knows the photo's aspect ratio and
  // can offer a "Match ref" preset.
  Size? _baseImageSize;
  Size? _referenceImageSize;

  // Downscaled (1024 px long edge) copy of the source built once on
  // editor mount. Every preview compute — Match Color's Reinhard,
  // Sharpness prepare, the canvas Image.memory — runs against this
  // instead of the full-res source, so each tool's first interactive
  // result lands in well under a second on a 12 MP shot. Save replays
  // the tools on the full-res source instead ([_recipe]), so disk
  // quality isn't downscaled.
  Uint8List? _editingBaseBytes;
  bool _preparingEditingBase = false;

  // Cached downscaled source + blur for the Sharpness preview path.
  // Built once when the user enters Sharpness mode (faster now that
  // the input is already the 1024 px editing base), reused across
  // every slider release after that.
  PreparedSharpness? _sharpnessCache;
  bool _preparingSharpness = false;

  // True while the user is actively dialling in a tool's parameters.
  // In this submode the AppBar swaps to Cancel + tool name + Confirm,
  // the bottom tool row hides, and the active slider becomes the only
  // interactive control — committing or backing out is the only way
  // to switch tools.
  bool _inEditMode = false;

  _EditState get _current => _history[_historyIndex];
  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex < _history.length - 1;

  /// Tools with a committed step in the active chain (≤ `_historyIndex`). Their
  /// tool button shows an "applied" (blue) state; because it's derived from the
  /// history index, undo/redo automatically re-colours the icons as the stack
  /// is walked.
  Set<String> get _appliedTools {
    final applied = <String>{};
    for (var i = 1; i <= _historyIndex && i < _history.length; i++) {
      final step = _history[i];
      if (step.tool != null && step.bytes != null) applied.add(step.tool!);
    }
    return applied;
  }

  /// Bytes that a freshly-tapped tool chip should chain on top of —
  /// the most recent committed bytes in history, or the downscaled
  /// editing base when nothing has been confirmed yet.
  Uint8List? get _chainBase {
    for (var i = _historyIndex; i >= 0; i--) {
      final b = _history[i].bytes;
      if (b != null) return b;
    }
    return _editingBaseBytes;
  }

  bool get _hasReference => _referencePath != null;

  @override
  void initState() {
    super.initState();
    _referencePath = widget.referencePath;
    _referenceImageId = widget.referenceImageId;
    _placeKey = widget.placeKey;
    unawaited(_prepareEditingBase());
    unawaited(_loadReferenceSize());
  }

  /// Decode just the pixel dimensions of [bytes] (cheap — no full raster
  /// kept around). Used to learn the photo's and reference's aspect
  /// ratios for the crop tool.
  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  Future<void> _loadReferenceSize() async {
    final refPath = _referencePath;
    if (refPath == null) {
      if (mounted) setState(() => _referenceImageSize = null);
      return;
    }
    try {
      final size = await _decodeImageSize(await readMediaBytes(refPath));
      if (!mounted) return;
      setState(() => _referenceImageSize = size);
    } catch (_) {
      // Unreadable reference (e.g. a missing file): the crop tool just
      // won't offer the "Match ref" preset.
      if (mounted) setState(() => _referenceImageSize = null);
    }
  }

  /// Aspect ratio (w/h) of the photo as currently displayed — i.e. with
  /// the manual rotation applied (odd quarter-turns swap width/height;
  /// mirroring and straightening keep the shape). null until the editing
  /// base has been decoded.
  double? get _displayedImageAspect => _aspectFor(_rotationQuarters);

  /// [_displayedImageAspect] for the photo turned [quarters] times.
  double? _aspectFor(int quarters) {
    final s = _baseImageSize;
    if (s == null) return null;
    final swap = quarters.isOdd;
    final w = swap ? s.height : s.width;
    final h = swap ? s.width : s.height;
    return h == 0 ? null : w / h;
  }

  /// Decode the source + downscale to 1024 px long edge once, cache
  /// the resulting JPEG bytes. Every preview compute reads from this
  /// instead of decoding the source repeatedly, so a 12 MP JPEG only
  /// pays its ~300-500 ms decode cost a single time per editing
  /// session.
  Future<void> _prepareEditingBase() async {
    setState(() => _preparingEditingBase = true);
    try {
      final sourceBytes = await readMediaBytes(widget.sourcePath);
      final downscaled = await compute(downscaleForEditing, sourceBytes);
      if (!mounted) return;
      setState(() => _editingBaseBytes = downscaled);
      // The downscaled base is already EXIF-baked upright, so its pixel
      // dimensions give the correct (un-rotated) display aspect ratio.
      final size = await _decodeImageSize(downscaled);
      if (mounted) setState(() => _baseImageSize = size);
    } finally {
      if (mounted) setState(() => _preparingEditingBase = false);
    }
  }

  void _pushHistory(_EditState state) {
    // Drop any redo branch when a new edit is applied past an undo.
    final base = _historyIndex < _history.length - 1
        ? _history.sublist(0, _historyIndex + 1)
        : List<_EditState>.from(_history);
    base.add(state);
    _history = base;
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (!_canUndo) return;
    setState(() => _historyIndex--);
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() => _historyIndex++);
  }

  /// Open the Rotate tool on the photo's current orientation. The canvas
  /// shows the draft live, uncropped and under a grid; Done keeps it and
  /// Save bakes it into the saved file.
  void _enterRotateMode() {
    if (_processing) return;
    setState(() {
      _draftMirrored = _mirrored;
      _draftQuarters = _rotationQuarters;
      _draftDegrees = _straightenDegrees;
      _inRotateMode = true;
    });
  }

  /// Turn the draft a quarter clockwise ([turns] = 1) or anticlockwise (-1).
  void _turnDraft(int turns) =>
      setState(() => _draftQuarters = (_draftQuarters + turns) % 4);

  /// Flip the draft as it's shown: left to right, or top to bottom when
  /// [vertical]. The photo is mirrored before it's turned, so on screen a
  /// flip also reverses the turn — and the straightening angle.
  void _flipDraft({required bool vertical}) {
    setState(() {
      _draftMirrored = !_draftMirrored;
      _draftQuarters = ((vertical ? 2 : 0) - _draftQuarters) % 4;
      _draftDegrees = _draftDegrees == 0 ? 0 : -_draftDegrees;
    });
  }

  void _resetRotateDraft() => setState(() {
        _draftMirrored = false;
        _draftQuarters = 0;
        _draftDegrees = 0;
      });

  void _cancelRotate() => setState(() => _inRotateMode = false);

  /// Keep the draft orientation. A committed crop follows the photo through
  /// the turns and flips, so it still frames the same part of it; a new
  /// straightening angle keeps its normalised rect.
  void _confirmRotate() {
    setState(() {
      final crop = _cropRect;
      if (crop != null) {
        _cropRect = _carryCrop(
          crop,
          fromMirrored: _mirrored,
          fromQuarters: _rotationQuarters,
          toMirrored: _draftMirrored,
          toQuarters: _draftQuarters,
        );
      }
      _mirrored = _draftMirrored;
      _rotationQuarters = _draftQuarters;
      _straightenDegrees = _draftDegrees;
      _inRotateMode = false;
    });
  }

  /// Enter the crop editor — seed the draft rect from any existing crop
  /// (or full frame) and start in free-form mode.
  void _enterCropMode() {
    if (_processing) return;
    setState(() {
      _draftCropRect = _cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);
      _cropAspectLock = null;
      _inCropMode = true;
    });
  }

  void _cancelCrop() => setState(() => _inCropMode = false);

  void _confirmCrop() {
    setState(() {
      final r = _draftCropRect;
      // A (near) full-frame rect means "no crop" — avoid baking a
      // pointless re-encode that would just shave a pixel off the edges.
      final isFull = r.left <= 0.001 &&
          r.top <= 0.001 &&
          r.right >= 0.999 &&
          r.bottom >= 0.999;
      _cropRect = isFull ? null : r;
      _inCropMode = false;
    });
  }

  /// Lock the crop to a given output aspect (width/height in pixels), or
  /// null for free-form. Locking re-centres the draft rect at the largest
  /// rectangle of that aspect that fits inside the photo.
  void _setCropAspect(double? aspect) {
    setState(() {
      _cropAspectLock = aspect;
      if (aspect != null) _draftCropRect = _centeredAspectRect(aspect);
    });
  }

  /// Largest normalised rect of output pixel-aspect [a], centred in the
  /// displayed image. In normalised space the width/height ratio is
  /// `a / displayedAspect` because the image's own aspect stretches the
  /// [0,1]² box.
  Rect _centeredAspectRect(double a) {
    final dispAR = _displayedImageAspect ?? 1;
    final k = a / dispAR; // normalised width / height
    double nw, nh;
    if (k >= 1) {
      nw = 1;
      nh = 1 / k;
    } else {
      nh = 1;
      nw = k;
    }
    return Rect.fromLTWH((1 - nw) / 2, (1 - nh) / 2, nw, nh);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Runs the given compute-safe match algorithm against the current
  /// source + reference bytes and pushes the result onto the edit
  /// history. Filters are applied against the **original** source
  /// image (not the previous filter's output), so tapping a different
  /// chip swaps filter rather than stacking it — undo lets the user
  /// step back through previously-applied filters.
  Future<void> _runMatch(
    String activeTool,
    Future<Uint8List> Function(MatchArgs) algorithm, {
    bool storeMatchedBase = false,
  }) async {
    final refPath = _referencePath;
    if (refPath == null) return;
    if (_processing) return;
    // Re-tapping the same chip while already on this tool's step just
    // re-enters edit submode without recomputing the (still-cached)
    // matched bytes — useful after Confirm when the user wants to
    // fine-tune the slider again.
    if (_current.tool == activeTool && _current.matchedBaseBytes != null) {
      setState(() => _inEditMode = true);
      return;
    }
    final existing = _stepIndexForTool(activeTool);
    if (existing != -1 && _history[existing].matchedBaseBytes != null) {
      _revisitStep(existing); // revisit the single Match instance
      return;
    }
    // Chain on top of whatever filters have already been confirmed —
    // Reinhard runs against the previous step's bytes (or the editing
    // base when nothing has landed yet), not against the raw source.
    final base = _chainBase;
    if (base == null) return;

    setState(() => _processing = true);
    try {
      final referenceBytes = await readMediaBytes(refPath);
      final result = await compute(
        algorithm,
        MatchArgs(
          capturedBytes: base,
          referenceBytes: referenceBytes,
        ),
      );
      if (!mounted) return;
      setState(() {
        _pushHistory(_EditState(
          // bytes left null until the user Confirms — slider drag
          // previews via Stack opacity on top of `toolBaseBytes`, so
          // there's no need to commit a byte buffer until then.
          tool: activeTool,
          toolBaseBytes: base,
          matchedBaseBytes: storeMatchedBase ? result : null,
          strength: 1.0,
          matchReferencePath: refPath,
        ));
        _inEditMode = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Match failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Replace the current history step with [update] applied to it.
  /// Slider drags shouldn't push a new history step every frame, so
  /// instead the current entry's tool params get mutated in place —
  /// undo still goes back to before the tool was tapped.
  void _mutateCurrent(_EditState Function(_EditState) update) {
    setState(() {
      final newHistory = List<_EditState>.from(_history);
      newHistory[_historyIndex] = update(_current);
      _history = newHistory;
    });
  }

  void _setStrength(double value) {
    if (_current.tool != 'match' || _current.matchedBaseBytes == null) return;
    _mutateCurrent((s) => s.copyWith(strength: value));
  }

  /// Brightness drag mutates the live state — the canvas re-renders
  /// the source image through a `ColorFilter.matrix` matrix in real
  /// time, so the user gets immediate visual feedback without any
  /// per-frame compute. The byte-buffer adjust runs at Confirm, and Save
  /// replays it on the full-res source so the JPEG that lands on disk
  /// matches the canvas.
  void _setBrightness(double value) {
    if (_current.tool != 'brightness') return;
    _mutateCurrent((s) => s.copyWith(brightness: value));
  }

  void _setSharpness(double value) {
    if (_current.tool != 'sharpness') return;
    _mutateCurrent((s) => s.copyWith(sharpness: value));
  }

  /// Pre-compute the Sharpness preview cache (downscaled source +
  /// blurred buffer). Idempotent — early-returns if it's already
  /// built or in-flight.
  Future<void> _prepareSharpnessCache() async {
    if (_sharpnessCache != null || _preparingSharpness) return;
    // Cache is per-chain-step — the bytes the user is about to
    // sharpen are this step's `toolBaseBytes` (= the previous
    // filter's committed result), not the raw editing base.
    final baseBytes = _current.toolBaseBytes ?? _editingBaseBytes;
    if (baseBytes == null) return;
    setState(() => _preparingSharpness = true);
    try {
      final prepared = await compute(prepareSharpness, baseBytes);
      if (!mounted) return;
      setState(() => _sharpnessCache = prepared);
    } finally {
      if (mounted) setState(() => _preparingSharpness = false);
    }
  }

  Future<void> _commitSharpness(double value) async {
    if (_current.tool != 'sharpness') return;
    if (_processing) return;
    final cache = _sharpnessCache;
    final base = _current.toolBaseBytes ?? _editingBaseBytes;
    if (base == null) return;
    setState(() => _processing = true);
    try {
      final Uint8List result;
      if (cache != null) {
        // Fast path — combine on the cached prepare (downscaled +
        // pre-blurred copy of `toolBaseBytes`), encode a small JPEG.
        result = await compute(
          applySharpnessQuick,
          QuickSharpnessArgs(prepared: cache, amount: value),
        );
      } else {
        // Cache wasn't ready yet — run the full path on this step's
        // base bytes. Slower but the next release will be fast.
        result = await compute(
          applySharpness,
          SharpnessArgs(sourceBytes: base, amount: value),
        );
      }
      if (!mounted) return;
      _mutateCurrent((s) => s.copyWith(bytes: result, sharpness: value));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Brightness / Sharpness chip taps push a fresh history step with
  /// the relevant tool selected — slider starts at the no-op value
  /// (0) so the displayed image equals the source until the user
  /// drags. Tapping the chip again with the same tool already active
  /// is a no-op so it doesn't reset slider state mid-edit.
  void _runBrightness() {
    if (_current.tool == 'brightness') {
      setState(() => _inEditMode = true);
      return;
    }
    final existing = _stepIndexForTool('brightness');
    if (existing != -1) {
      _revisitStep(existing); // one instance per tool — revisit, don't stack
      return;
    }
    final base = _chainBase;
    if (base == null) return;
    setState(() {
      _pushHistory(_EditState(tool: 'brightness', toolBaseBytes: base));
      _inEditMode = true;
    });
  }

  void _runSharpness() {
    if (_current.tool == 'sharpness') {
      setState(() => _inEditMode = true);
      return;
    }
    final existing = _stepIndexForTool('sharpness');
    if (existing != -1) {
      _revisitStep(existing);
      _sharpnessCache = null;
      unawaited(_prepareSharpnessCache());
      return;
    }
    final base = _chainBase;
    if (base == null) return;
    setState(() {
      _pushHistory(_EditState(tool: 'sharpness', toolBaseBytes: base));
      _inEditMode = true;
    });
    // Sharpness cache is tied to a specific `toolBaseBytes`, so a new
    // chain step always needs a fresh prepare.
    _sharpnessCache = null;
    unawaited(_prepareSharpnessCache());
  }

  /// Jump back to an already-applied tool's step to re-dial its value (showing
  /// its current params). Editing discards any redo branch; tools applied after
  /// it stay in the chain and are replayed on Confirm.
  void _revisitStep(int index) {
    setState(() {
      if (_historyIndex < _history.length - 1) {
        _history = _history.sublist(0, _historyIndex + 1);
      }
      _historyIndex = index;
      _inEditMode = true;
    });
  }

  /// Commit the current tool's dialled-in result into the history
  /// step's `bytes` field, then exit edit submode. The next tool the
  /// user picks chains on top of these bytes — that's how stacking
  /// filters works.
  ///
  /// Sharpness already commits on each slider release, so it only
  /// needs a no-op confirm. Brightness's preview lives entirely in
  /// the `ColorFilter` widget, so Confirm runs the byte-buffer
  /// adjust here. Match Color lerps the cached match against the
  /// step's `toolBaseBytes` according to the current strength.
  Future<void> _confirmEdit() async {
    if (_processing) return;
    final state = _current;
    final base = state.toolBaseBytes ?? _editingBaseBytes;
    if (base == null) {
      setState(() => _inEditMode = false);
      return;
    }

    setState(() => _processing = true);
    try {
      Uint8List? newBytes;
      switch (state.tool) {
        case 'match':
          if (state.matchedBaseBytes != null) {
            final t = state.strength.clamp(0.0, 1.0);
            if (t >= 0.999) {
              newBytes = state.matchedBaseBytes;
            } else if (t <= 0.001) {
              newBytes = base;
            } else {
              newBytes = await compute(
                lerpJpegs,
                LerpArgs(
                  jpegA: base,
                  jpegB: state.matchedBaseBytes!,
                  strength: t,
                ),
              );
            }
          }
          break;
        case 'brightness':
          if (state.brightness != 0) {
            newBytes = await compute(
              applyBrightness,
              BrightnessArgs(
                sourceBytes: base,
                brightness: state.brightness,
              ),
            );
          } else {
            newBytes = base;
          }
          break;
        case 'sharpness':
          if (state.bytes != null) {
            newBytes = state.bytes;
          } else if (state.sharpness != 0) {
            // No release happened yet (user confirmed without
            // touching the slider). Quick-path against the cache
            // when ready, otherwise full-path on `base`.
            final cache = _sharpnessCache;
            if (cache != null) {
              newBytes = await compute(
                applySharpnessQuick,
                QuickSharpnessArgs(prepared: cache, amount: state.sharpness),
              );
            } else {
              newBytes = await compute(
                applySharpness,
                SharpnessArgs(sourceBytes: base, amount: state.sharpness),
              );
            }
          } else {
            newBytes = base;
          }
          break;
      }
      if (!mounted) return;
      if (newBytes != null) {
        _mutateCurrent((s) => s.copyWith(bytes: newBytes));
      }
      // Replay any later tools on top of this step's new result, so revisiting
      // an earlier adjustment keeps the later ones instead of dropping them.
      await _replayDownstream(_historyIndex);
      if (!mounted) return;
      setState(() {
        _historyIndex = _history.length - 1; // show the full composed result
        _inEditMode = false;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Index of the committed step for [tool] in the active chain
  /// (1.._historyIndex), or -1 — so re-tapping a tool revisits its single
  /// instance instead of stacking a duplicate.
  int _stepIndexForTool(String tool) {
    for (var i = 1; i <= _historyIndex && i < _history.length; i++) {
      if (_history[i].tool == tool && _history[i].bytes != null) return i;
    }
    return -1;
  }

  /// Re-apply [step]'s tool to [base] (preview resolution) — used to replay the
  /// later tools after an earlier one is revisited.
  Future<Uint8List?> _recomputePreview(_EditState step, Uint8List base) async {
    switch (step.tool) {
      case 'brightness':
        if (step.brightness == 0) return base;
        return compute(applyBrightness,
            BrightnessArgs(sourceBytes: base, brightness: step.brightness));
      case 'sharpness':
        if (step.sharpness == 0) return base;
        return compute(applySharpness,
            SharpnessArgs(sourceBytes: base, amount: step.sharpness));
      case 'match':
        if (_referencePath == null || step.matchedBaseBytes == null) return base;
        final t = step.strength.clamp(0.0, 1.0);
        if (t <= 0.001) return base;
        if (t >= 0.999) return step.matchedBaseBytes;
        return compute(
            lerpJpegs,
            LerpArgs(
                jpegA: base, jpegB: step.matchedBaseBytes!, strength: t));
      default:
        return base;
    }
  }

  /// After the step at [from] changes, replay every later tool on top of it so
  /// revisiting an earlier adjustment keeps the later ones. Re-matches Match
  /// against the new upstream so its colour transfer stays correct.
  Future<void> _replayDownstream(int from) async {
    final refPath = _referencePath;
    for (var j = from + 1; j < _history.length; j++) {
      final prev = _history[j - 1].bytes;
      if (prev == null) continue;
      var step = _history[j];
      if (step.tool == 'match' && refPath != null) {
        final refBytes = await readMediaBytes(refPath);
        final matched = await compute(
            reinhardMatch, MatchArgs(capturedBytes: prev, referenceBytes: refBytes));
        step = step.copyWith(
          matchedBaseBytes: matched,
          matchReferencePath: refPath,
        );
      }
      final recomputed = await _recomputePreview(step, prev);
      _history[j] = step.copyWith(toolBaseBytes: prev, bytes: recomputed);
    }
  }

  /// Discard the tool's history step and exit edit submode — same
  /// effect as undo + closing the slider strip, used by the AppBar's
  /// Cancel button while a tool is being edited.
  void _cancelEdit() {
    setState(() {
      if (_historyIndex > 0) _historyIndex--;
      _inEditMode = false;
    });
  }

  String _editModeTitle() {
    switch (_current.tool) {
      case 'match':
        return 'Match Color';
      case 'brightness':
        return 'Brightness';
      case 'sharpness':
        return 'Sharpness';
      default:
        return '';
    }
  }


  /// Switch to the 拼貼 / Compose page (edit v2). Requires a reference image
  /// (the cutout source) and the prepared editing base.
  bool _collagePage = false;

  // Downscaled base the Compose page draws on: the chain preview with the
  // manual rotation and crop applied, so its geometry matches the full-res
  // photo [_recipe] renders for Compose at save time. Rebuilt every time
  // Compose opens.
  Uint8List? _composeBase;
  bool _preparingCompose = false;

  bool get _isTurned =>
      _mirrored || _rotationQuarters % 4 != 0 || _straightenDegrees != 0;

  bool get _hasGeometryEdits => _isTurned || _cropRect != null;

  /// What Save and Compose render at full resolution: the tools of the
  /// active chain in order, then the mirror, rotation, straightening and
  /// crop.
  EditRecipe _recipe() {
    final crop = _cropRect;
    return EditRecipe(
      steps: [
        for (var i = 1; i <= _historyIndex && i < _history.length; i++)
          ?_history[i].asEditStep,
      ],
      mirror: _mirrored,
      quarters: _rotationQuarters % 4,
      angle: _straightenDegrees,
      crop: crop == null ? null : [crop.left, crop.top, crop.width, crop.height],
    );
  }

  /// Hands the full-res render to [BackgroundPhotoSaves] and closes the
  /// editor at once: a 12 MP render takes seconds, and the user shouldn't
  /// have to sit through it. The photo shows up on the place page (or in the
  /// phone's gallery, for Edit Photo) when the save finishes; the render
  /// never touches the source file.
  void _save() {
    if (_saving) return;
    // The render runs when its turn in the save queue comes, after this
    // editor has closed, so take everything it needs now. With no filter,
    // rotation or crop the original is saved as-is.
    final recipe = _recipe();
    final edited = !recipe.isEmpty;
    final sourcePath = widget.sourcePath;
    final placeKey = _placeKey;
    // Every new picture also goes to the phone's gallery. An unedited photo
    // that isn't a fresh capture is already there (or already in the app),
    // so it's skipped. So is an unedited place photo going back to its own
    // place.
    final toGallery = edited || widget.isCapture;
    final unchangedPlacePhoto =
        !edited && widget.derivedFromId != null && placeKey == widget.placeKey;
    if ((placeKey == null && !toGallery) || unchangedPlacePhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }
    _saving = true;
    ref.read(backgroundPhotoSavesProvider.notifier).save(
          placeKey: placeKey,
          tripId: widget.tripId,
          kind: edited ? 'edited' : 'original',
          derivedFromId: widget.derivedFromId,
          takenAt: _takenAt(),
          toGallery: toGallery,
          originalToGallery: widget.isCapture,
          render: () async =>
              edited ? await renderEditedJpeg(sourcePath, recipe) : null,
          originalPath: sourcePath,
          referenceImageId: _referenceImageId,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving in the background…')),
    );
    Navigator.of(context).pop();
  }

  /// When the photo was taken, as far as the editor can tell: now for a fresh
  /// capture, else the file's date. The save files the photo under the trip
  /// that has its place on that day.
  DateTime? _takenAt() {
    if (widget.isCapture || kIsWeb || isRemoteOrMemoryUri(widget.sourcePath)) {
      return null;
    }
    try {
      return File(widget.sourcePath).lastModifiedSync();
    } catch (_) {
      return null;
    }
  }

  /// Bake the manual orientation, then the crop, into the downscaled
  /// preview [bytes], for the Compose page's canvas. Crop goes last so its
  /// normalised rect lines up with the turned pixels the user saw.
  Future<Uint8List> _applyGeometry(Uint8List bytes) {
    final crop = _cropRect;
    return compute(
      transformJpeg,
      TransformArgs(
        bytes,
        mirror: _mirrored,
        quarters: _rotationQuarters % 4,
        angle: _straightenDegrees,
        crop: crop == null ? null : [crop.left, crop.top, crop.width, crop.height],
      ),
    );
  }

  /// Open the Compose page. Its preview base gets the same rotation and
  /// crop as the full-res base it saves with — otherwise layers placed on
  /// the preview would land somewhere else in the saved image.
  Future<void> _openCompose() async {
    final base = _chainBase;
    if (base == null || _referencePath == null || _preparingCompose) return;
    setState(() => _preparingCompose = true);
    try {
      final composeBase =
          _hasGeometryEdits ? await _applyGeometry(base) : base;
      if (!mounted) return;
      setState(() {
        _composeBase = composeBase;
        _collagePage = true;
      });
    } finally {
      if (mounted) setState(() => _preparingCompose = false);
    }
  }

  void _back() {
    Navigator.of(context).pop();
  }

  /// Add or replace the reference image: one of this place's anime frames,
  /// or any image from the gallery (e.g. a screenshot the user saved
  /// themselves).
  Future<void> _changeReference() async {
    if (_processing) return;
    final fromPlace = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.collections, color: Colors.white),
              title: Text(
                _placeKey != null
                    ? "This place's anime frames"
                    : "A place's anime frames",
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: _placeKey != null
                  ? null
                  : const Text(
                      'The photo is also saved to that place.',
                      style: TextStyle(color: Colors.white54),
                    ),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Pick a reference from the gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (fromPlace == null || !mounted) return;
    if (fromPlace) {
      await _pickPlaceReference();
    } else {
      await _pickGalleryReference();
    }
  }

  /// Any image from the gallery. It isn't one of a place's frames, so the
  /// saved photo isn't linked to a frame.
  Future<void> _pickGalleryReference() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: ${e.message ?? e.code}')),
      );
      return;
    }
    if (picked == null || !mounted) return;
    _useReference(picked.path);
  }

  /// One of a place's anime frames — keeping its id, so the saved photo
  /// records which frame it was matched against. Without a place yet, the
  /// editor asks which place first, and the result is saved into that
  /// place's photos as well.
  Future<void> _pickPlaceReference() async {
    final placeKey = _placeKey ?? await pickPlaceKey(context, ref);
    if (placeKey == null || !mounted) return;
    final picked = await pickPlaceFrame(context, ref, placeKey);
    if (picked == null || !mounted) return;
    _useReference(picked.localPath!, imageId: picked.id, placeKey: placeKey);
  }

  /// The AppBar's place button: save the photo into another place, a new
  /// one (made on the new place page, which hands back its key), or none —
  /// then it only goes to the phone's gallery.
  Future<void> _choosePlace() async {
    final choice = await pickPhotoPlace(context, ref, current: _placeKey);
    if (choice == null || !mounted) return;
    if (!choice.createNew) {
      setState(() => _placeKey = choice.placeKey);
      return;
    }
    final created = await context.push<String>('/library/new?pick=1');
    if (created != null && mounted) setState(() => _placeKey = created);
  }

  /// Switch to the reference at [path] — from [placeKey] when it's one of a
  /// place's anime frames, which also becomes the photo's place if it has
  /// none yet. When the user is editing through a Match Color result, push a
  /// fresh original step on top of the history — the existing matched bytes
  /// were computed against the previous reference and would be misleading
  /// to keep displayed.
  void _useReference(String path, {String? imageId, String? placeKey}) {
    setState(() {
      _referencePath = path;
      _referenceImageId = imageId;
      _placeKey ??= placeKey;
      _overlayOffset = Offset.zero;
      _overlayScale = 0.8;
      _overlayOpacity = 0.4;
      _overlayRotation = 0;
      if (_current.tool == 'match') {
        _pushHistory(const _EditState());
      }
      // Changing the reference invalidates any in-progress edit; drop
      // back to main mode so the user can re-enter a tool against the
      // new reference.
      _inEditMode = false;
    });
    unawaited(_loadReferenceSize());
  }

  void _resetOverlay() {
    setState(() {
      _overlayOffset = Offset.zero;
      _overlayScale = 0.8;
      _overlayOpacity = 0.4;
      _overlayRotation = 0;
    });
  }

  /// Bottom strip — centered slider for the active tool's continuous
  /// param above, horizontal row of icon-above-label tool buttons
  /// below. Modelled on Google Photos: each tool reads as a
  /// little icon with its label underneath, the slider lives on its
  /// own centered row above the tool icons so it doesn't have to
  /// share width with the buttons.
  Widget _buildBottomStrip(
    ThemeData theme,
    bool hasReference,
    String? activeTool,
  ) {
    if (_inRotateMode) return _buildRotateStrip(theme);
    final slider = _activeSliderForTool(activeTool, theme);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slider != null) ...[
            slider,
            if (!_inEditMode) const SizedBox(height: 4),
          ],
          // Tool row hides while a tool is being dialled in — the
          // AppBar's Cancel / Confirm pair is the only legal way to
          // switch tools while editing, so the row would just be a
          // distracting accidental-tap target if it stayed visible.
          if (!_inEditMode)
            SizedBox(
              // Room for the icon over a two-line label like
              // "Match\nColor"; single-line labels stay centred.
              height: 80,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = _toolButtonWidth(constraints.maxWidth);
                  return Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      // Center keeps the buttons as a balanced row when
                      // they all fit; on a phone the 7 tools scroll, with
                      // the one at the edge cut in half.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Add or change the reference: the overlay,
                          // Match Color and Compose all work from it.
                          _ToolButton(
                            width: width,
                            icon: hasReference
                                ? Icons.photo_library
                                : Icons.add_photo_alternate,
                            label: 'Reference',
                            enabled: !_processing,
                            selected: false,
                            onTap: _changeReference,
                          ),
                          _ToolButton(
                            width: width,
                            icon: Icons.palette,
                            // Two lines, so the label stays large enough
                            // to read instead of shrinking to fit.
                            label: 'Match\nColor',
                            enabled: hasReference && !_processing,
                            disabledHint:
                                hasReference ? null : 'No reference image',
                            selected: activeTool == 'match',
                            applied: _appliedTools.contains('match'),
                            onTap: () => _runMatch(
                              'match',
                              reinhardMatch,
                              storeMatchedBase: true,
                            ),
                          ),
                          _ToolButton(
                            width: width,
                            icon: Icons.brightness_6,
                            label: 'Brightness',
                            enabled: !_processing,
                            selected: activeTool == 'brightness',
                            applied: _appliedTools.contains('brightness'),
                            onTap: _runBrightness,
                          ),
                          _ToolButton(
                            width: width,
                            icon: Icons.deblur,
                            label: 'Sharpness',
                            enabled: !_processing,
                            selected: activeTool == 'sharpness',
                            applied: _appliedTools.contains('sharpness'),
                            onTap: _runSharpness,
                          ),
                          _ToolButton(
                            width: width,
                            icon: Icons.rotate_90_degrees_cw,
                            label: 'Rotate',
                            enabled: !_processing && _baseImageSize != null,
                            selected: false,
                            applied: _isTurned,
                            onTap: _enterRotateMode,
                          ),
                          _ToolButton(
                            width: width,
                            icon: Icons.crop,
                            label: 'Crop',
                            enabled: !_processing && _baseImageSize != null,
                            selected: false,
                            applied: _cropRect != null,
                            onTap: _enterCropMode,
                          ),
                          // Compose (stage 2) flattens cutouts / the
                          // reference onto the edited photo and saves
                          // from its own page.
                          _ToolButton(
                            width: width,
                            icon: Icons.auto_awesome_mosaic,
                            label: 'Compose',
                            enabled: hasReference &&
                                !_processing &&
                                !_saving &&
                                !_preparingCompose &&
                                _chainBase != null,
                            disabledHint:
                                hasReference ? null : 'No reference image',
                            selected: false,
                            applied: false,
                            onTap: _openCompose,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The Rotate tool's strip: the straightening slider over the
  /// quarter-turn and flip buttons.
  Widget _buildRotateStrip(ThemeData theme) {
    final degrees = _draftDegrees;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabelledSlider(
            label: 'Straighten',
            value: degrees,
            min: -45,
            max: 45,
            readout: '${degrees > 0 ? '+' : ''}${degrees.toStringAsFixed(1)}°',
            theme: theme,
            // Tenths of a degree, so the slider can land back on exactly 0.
            onChanged: (v) =>
                setState(() => _draftDegrees = (v * 10).round() / 10),
          ),
          SizedBox(
            height: 80,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The same size as the main strip's tool buttons.
                final width = _toolButtonWidth(constraints.maxWidth);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ToolButton(
                      width: width,
                      icon: Icons.rotate_left,
                      label: '90° left',
                      enabled: true,
                      selected: false,
                      onTap: () => _turnDraft(-1),
                    ),
                    _ToolButton(
                      width: width,
                      icon: Icons.rotate_right,
                      label: '90° right',
                      enabled: true,
                      selected: false,
                      onTap: () => _turnDraft(1),
                    ),
                    _ToolButton(
                      width: width,
                      icon: Icons.flip,
                      label: 'Flip ↔',
                      enabled: true,
                      selected: false,
                      onTap: () => _flipDraft(vertical: false),
                    ),
                    _ToolButton(
                      width: width,
                      icon: Icons.flip,
                      iconQuarterTurns: 1,
                      label: 'Flip ↕',
                      enabled: true,
                      selected: false,
                      onTap: () => _flipDraft(vertical: true),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the centered slider widget for the currently-active tool,
  /// or `null` when the active tool has no continuous param or the
  /// editor isn't in edit submode (sliders only appear while the user
  /// is dialling in a tool; the dialled-in result is shown in main
  /// mode without the slider so the canvas can take the full height).
  Widget? _activeSliderForTool(String? activeTool, ThemeData theme) {
    if (!_inEditMode) return null;
    switch (activeTool) {
      case 'match':
        if (_current.matchedBaseBytes == null) return null;
        return _LabelledSlider(
          label: 'Strength',
          value: _current.strength.clamp(0.0, 1.0),
          min: 0,
          max: 1,
          theme: theme,
          onChanged: _setStrength,
        );
      case 'brightness':
        return _LabelledSlider(
          label: 'Brightness',
          value: _current.brightness.clamp(-0.5, 0.5),
          min: -0.5,
          max: 0.5,
          centerZero: true,
          theme: theme,
          onChanged: _setBrightness,
        );
      case 'sharpness':
        return _LabelledSlider(
          label: 'Sharpness',
          value: _current.sharpness.clamp(0.0, 1.0),
          min: 0,
          max: 1,
          theme: theme,
          onChanged: _setSharpness,
          onChangeEnd: _commitSharpness,
        );
      default:
        return null;
    }
  }

  /// Builds the edited captured image.
  ///
  /// In edit submode the preview chains on top of the current step's
  /// `toolBaseBytes` (= the previous filter's committed result). That
  /// way a Match Color → Brightness → Sharpness sequence visibly
  /// stacks instead of resetting to the source each time. Outside of
  /// edit mode the canvas just renders the current step's committed
  /// `bytes`, or the editing base when nothing has been committed.
  Widget _buildEditingCanvas(Uint8List? currentBytes) {
    final tool = _current.tool;
    final base = _editingBaseBytes;
    Widget baseDisplay() => base != null
        ? Image.memory(
            base,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          )
        : PlatformImage(widget.sourcePath, fit: BoxFit.contain);

    if (_inEditMode) {
      final toolBase = _current.toolBaseBytes ?? base;
      Widget toolBaseDisplay() => toolBase != null
          ? Image.memory(toolBase,
              fit: BoxFit.contain, gaplessPlayback: true)
          : baseDisplay();

      if (tool == 'match' && _current.matchedBaseBytes != null) {
        return Stack(
          alignment: Alignment.center,
          children: [
            toolBaseDisplay(),
            Opacity(
              opacity: _current.strength.clamp(0.0, 1.0),
              child: Image.memory(
                _current.matchedBaseBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ],
        );
      }
      if (tool == 'brightness') {
        final b = _current.brightness.clamp(-0.5, 0.5);
        final s = 1 + b;
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            s, 0, 0, 0, 0,
            0, s, 0, 0, 0,
            0, 0, s, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: toolBaseDisplay(),
        );
      }
      if (tool == 'sharpness') {
        // Until the user releases the slider, the canvas shows the
        // `toolBaseBytes` (no effect yet); after release `bytes` is
        // populated and we show that.
        return currentBytes != null
            ? Image.memory(currentBytes,
                fit: BoxFit.contain, gaplessPlayback: true)
            : toolBaseDisplay();
      }
    }

    // Main mode — display the committed chain result.
    return currentBytes != null
        ? Image.memory(currentBytes,
            fit: BoxFit.contain, gaplessPlayback: true)
        : baseDisplay();
  }

  /// Default-mode AppBar: back/undo/redo on the left, the place the photo
  /// is saved into in the middle, Save on the right. Use while no tool is
  /// being dialled in, so the user can step through edit history and
  /// commit to disk. Save is always here; Compose (which saves from its own
  /// page), the reference and rotation are tools in the bottom strip.
  PreferredSizeWidget _buildMainAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      // Wider leading slot to fit back + undo + redo in a row without
      // pushing the title.
      leadingWidth: 168,
      titleSpacing: 0,
      title: _buildPlaceButton(),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _back,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _canUndo && !_processing ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: _canRedo && !_processing ? _redo : null,
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            onPressed: (_saving || _processing) ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              disabledForegroundColor: Colors.white38,
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ),
      ],
    );
  }

  /// The main AppBar's place button: the place the photo is saved into, or
  /// "No place" when it only goes to the phone's gallery. Tapping it picks
  /// another ([_choosePlace]).
  Widget _buildPlaceButton() {
    final key = _placeKey;
    final name = key == null
        ? 'No place'
        : ref.watch(placeDetailProvider(key)).valueOrNull?.name ?? 'Place';
    return TextButton.icon(
      onPressed: _processing ? null : _choosePlace,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(key == null ? Icons.location_off : Icons.place, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }

  /// Rotate-tool AppBar: Cancel ✕, "Rotate", Reset (once the draft is
  /// turned, flipped or straightened), Done.
  PreferredSizeWidget _buildRotateAppBar(ThemeData theme) {
    final changed =
        _draftMirrored || _draftQuarters != 0 || _draftDegrees != 0;
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel rotate',
        onPressed: _cancelRotate,
      ),
      title: const Text('Rotate', style: TextStyle(fontSize: 16)),
      actions: [
        if (changed)
          TextButton(
            onPressed: _resetRotateDraft,
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Reset'),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            onPressed: _confirmRotate,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  /// Edit-submode AppBar: Cancel ✕ on the left, tool name in the
  /// title, Confirm on the right. Undo/Redo and the "Save the disk
  /// version" affordance disappear — the only way out of this
  /// AppBar is Cancel (discard) or Confirm (keep), matching the
  /// modal feel of Google Photos' per-tool editing.
  PreferredSizeWidget _buildEditModeAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel edit',
        onPressed: _processing ? null : _cancelEdit,
      ),
      title: Text(
        _editModeTitle(),
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            onPressed: _processing ? null : _confirmEdit,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              disabledForegroundColor: Colors.white38,
            ),
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }

  /// [image], which fills its box, mirrored, turned and straightened the
  /// way Save writes it. Lay it out in a box of the turned photo's [aspect].
  Widget _orientedPhoto(
    Widget image, {
    required bool mirror,
    required int quarters,
    required double degrees,
    required double aspect,
  }) {
    Widget photo = RotatedBox(
      quarterTurns: quarters,
      child: mirror ? Transform.flip(flipX: true, child: image) : image,
    );
    if (degrees != 0) {
      // Turned about its centre and zoomed in to the largest rectangle of
      // its shape that it still covers, as straightenAndCrop renders it.
      photo = ClipRect(
        child: Transform.rotate(
          angle: degrees * math.pi / 180,
          child: Transform.scale(
            scale: 1 / straightenScale(aspect, 1, degrees),
            child: photo,
          ),
        ),
      );
    }
    return photo;
  }

  /// Outer canvas wrapper: the edited captured image (turned and
  /// cropped as Save will write it) with the optional translucent
  /// reference overlay layered on top. While the Rotate tool is open the
  /// photo shows the draft orientation instead, uncropped, under a grid.
  Widget _buildCanvasContent(Uint8List? currentBytes, String? referencePath) {
    // Only the photo turns with the Rotate tool; the reference overlay
    // below keeps its own independent rotation.
    final rotating = _inRotateMode;
    final quarters = rotating ? _draftQuarters : _rotationQuarters;
    final aspect = _aspectFor(quarters);
    Widget photo;
    if (aspect == null) {
      // The editing base isn't decoded yet, so neither is the photo's
      // shape — and nothing can be turned before it is.
      photo = Center(child: _buildEditingCanvas(currentBytes));
    } else {
      final oriented = _orientedPhoto(
        _buildEditingCanvas(currentBytes),
        mirror: rotating ? _draftMirrored : _mirrored,
        quarters: quarters,
        degrees: rotating ? _draftDegrees : _straightenDegrees,
        aspect: aspect,
      );
      // When a crop is committed, show only the cropped region (scaled up
      // to fill the canvas) so the preview matches what Save will write.
      final crop = rotating ? null : _cropRect;
      photo = crop != null
          ? _CroppedView(crop: crop, imageAspect: aspect, child: oriented)
          : Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: rotating
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          oriented,
                          const IgnorePointer(
                            child: CustomPaint(painter: _GridPainter()),
                          ),
                        ],
                      )
                    : oriented,
              ),
            );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        photo,
        if (_showOverlay && referencePath != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (details) {
                _gestureStartOffset = _overlayOffset;
                _gestureStartFocalPoint = details.focalPoint;
                _gestureStartScale = _overlayScale;
                _gestureStartRotation = _overlayRotation;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _overlayOffset = _gestureStartOffset +
                      (details.focalPoint - _gestureStartFocalPoint);
                  _overlayScale =
                      (_gestureStartScale * details.scale)
                          .clamp(0.35, 4)
                          .toDouble();
                  // Two-finger twist rotates the reference overlay.
                  _overlayRotation =
                      _gestureStartRotation + details.rotation;
                });
              },
              child: Center(
                child: Transform.translate(
                  offset: _overlayOffset,
                  child: Transform.rotate(
                    angle: _overlayRotation,
                    child: Transform.scale(
                      scale: _overlayScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: _overlayOpacity,
                          child: PlatformImage(referencePath, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReference = _hasReference;
    final referencePath = _referencePath;
    final currentBytes = _current.bytes;
    final activeTool = _current.tool;

    if (_inCropMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildCropAppBar(theme),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildCropCanvas()),
              _buildCropStrip(theme),
            ],
          ),
        ),
      );
    }

    final adjust = Scaffold(
      backgroundColor: Colors.black,
      appBar: _inRotateMode
          ? _buildRotateAppBar(theme)
          : _inEditMode
              ? _buildEditModeAppBar(theme)
              : _buildMainAppBar(theme),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCanvasContent(currentBytes, referencePath),
                  if (_processing || _preparingEditingBase || _preparingCompose)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  // Floating opacity bar — only when a reference image
                  // is in play (the Reference tool adds one).
                  if (hasReference)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _FloatingOverlayBar(
                        overlayVisible: _showOverlay,
                        opacity: _overlayOpacity,
                        theme: theme,
                        onOpacityChanged: (v) =>
                            setState(() => _overlayOpacity = v),
                        onReset: _resetOverlay,
                        onRotate: () => setState(
                            () => _overlayRotation += math.pi / 2),
                        onToggleVisibility: () =>
                            setState(() => _showOverlay = !_showOverlay),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomStrip(theme, hasReference, activeTool),
          ],
        ),
      ),
    );

    // Adjust → Compose → Save. Keep Compose alive in an IndexedStack so going
    // Back to Adjust doesn't lose placed layers. Compose needs a reference
    // (the cutout source) + the prepared base; without one there's no
    // Compose page (Adjust's Save still works either way).
    final base = _editingBaseBytes;
    final refPath = _referencePath;
    if (base == null || refPath == null) {
      if (_collagePage) _collagePage = false;
      return adjust;
    }
    return IndexedStack(
      index: _collagePage ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        adjust,
        CollagePage(
          basePreview: _composeBase ?? _chainBase ?? base,
          sourcePath: widget.sourcePath,
          recipe: _recipe(),
          referencePath: refPath,
          placeKey: _placeKey,
          tripId: widget.tripId,
          derivedFromId: widget.derivedFromId,
          takenAt: _takenAt(),
          originalCapturePath: widget.isCapture ? widget.sourcePath : null,
          onBack: () => setState(() => _collagePage = false),
        ),
      ],
    );
  }

  /// Crop-submode AppBar: Cancel ✕, "Crop" title, Reset (when a crop is
  /// already committed), Done. The reference's visibility is on the
  /// overlay bar in the crop strip.
  PreferredSizeWidget _buildCropAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel crop',
        onPressed: _cancelCrop,
      ),
      title: const Text('Crop', style: TextStyle(fontSize: 16)),
      actions: [
        if (_cropRect != null)
          TextButton(
            onPressed: () => setState(() {
              _cropRect = null;
              _draftCropRect = const Rect.fromLTWH(0, 0, 1, 1);
              _cropAspectLock = null;
            }),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Reset'),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            onPressed: _confirmCrop,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  /// Crop canvas — the photo at its display aspect with the interactive
  /// crop frame on top. Shows the latest committed look (the chain
  /// result, else the editing base) since crop is purely geometric.
  ///
  /// With a reference loaded (and the overlay on), the reference floats
  /// inside the crop box at the overlay's opacity (set on the crop strip's
  /// overlay bar) and moves and resizes with it, so the user can line the
  /// crop up with the anime frame — with "Match ref" it fills the box
  /// exactly.
  Widget _buildCropCanvas() {
    final ar = _displayedImageAspect ?? 1;
    final display = _chainBase;
    final referencePath = _showOverlay ? _referencePath : null;
    final image = _orientedPhoto(
      display != null
          ? Image.memory(display, fit: BoxFit.fill, gaplessPlayback: true)
          : PlatformImage(widget.sourcePath, fit: BoxFit.fill),
      mirror: _mirrored,
      quarters: _rotationQuarters,
      degrees: _straightenDegrees,
      aspect: ar,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: ar,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final box = _draftCropRect;
              return Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (referencePath != null)
                    Positioned(
                      left: box.left * constraints.maxWidth,
                      top: box.top * constraints.maxHeight,
                      width: box.width * constraints.maxWidth,
                      height: box.height * constraints.maxHeight,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: _overlayOpacity,
                          child: PlatformImage(referencePath, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  _CropFrame(
                    rect: _draftCropRect,
                    aspectLock: _cropAspectLock,
                    onChanged: (r) => setState(() => _draftCropRect = r),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Horizontal strip of aspect-ratio presets for the crop editor. The
  /// "Match ref" chip (only with a reference loaded) locks to the anime
  /// image's proportions — the whole point of the feature. With a
  /// reference, the overlay bar above the chips sets how see-through it is
  /// in the crop box, or hides it.
  Widget _buildCropStrip(ThemeData theme) {
    final ref = _referenceImageSize;
    final dispAR = _displayedImageAspect;
    final chips = <Widget>[
      _cropChip('Free', null, theme),
      if (ref != null && ref.height > 0)
        _cropChip('Match ref', ref.width / ref.height, theme),
      if (dispAR != null) _cropChip('Original', dispAR, theme),
      _cropChip('1:1', 1, theme),
      _cropChip('4:3', 4 / 3, theme),
      _cropChip('3:4', 3 / 4, theme),
      _cropChip('16:9', 16 / 9, theme),
      _cropChip('9:16', 9 / 16, theme),
    ];
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasReference)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _FloatingOverlayBar(
                overlayVisible: _showOverlay,
                opacity: _overlayOpacity,
                theme: theme,
                onOpacityChanged: (v) => setState(() => _overlayOpacity = v),
                onToggleVisibility: () =>
                    setState(() => _showOverlay = !_showOverlay),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: chips),
          ),
        ],
      ),
    );
  }

  Widget _cropChip(String label, double? aspect, ThemeData theme) {
    final lock = _cropAspectLock;
    final selected = aspect == null
        ? lock == null
        : lock != null && (lock - aspect).abs() < 0.001;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setCropAspect(aspect),
        backgroundColor: Colors.white12,
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white70,
        ),
        side: BorderSide.none,
        showCheckmark: false,
      ),
    );
  }
}

/// [crop] (normalised, over the photo as shown mirrored [fromMirrored] and
/// turned [fromQuarters] times) moved onto the photo shown mirrored
/// [toMirrored] and turned [toQuarters] times, so it frames the same part
/// of the photo.
Rect _carryCrop(
  Rect crop, {
  required bool fromMirrored,
  required int fromQuarters,
  required bool toMirrored,
  required int toQuarters,
}) {
  // Shown = turns ∘ mirror, so getting from one to the other is a turn —
  // after a left-to-right mirror when only one of them is mirrored.
  var r = crop;
  final int turns;
  if (fromMirrored != toMirrored) {
    r = Rect.fromLTWH(1 - r.right, r.top, r.width, r.height);
    turns = toQuarters + fromQuarters;
  } else {
    turns = toQuarters - fromQuarters;
  }
  for (var i = 0; i < turns % 4; i++) {
    // A clockwise quarter-turn takes (x, y) to (1 - y, x).
    r = Rect.fromLTWH(1 - r.bottom, r.left, r.height, r.width);
  }
  return r;
}

/// Width of a tool button in the editor's bottom strips: four and a half of
/// them across a strip [stripWidth] wide, so when a row of tools doesn't
/// fit, the button cut in half at the edge shows that it scrolls. At most
/// 96 dp, so they don't sprawl across a tablet or a landscape screen, where
/// they all fit anyway.
double _toolButtonWidth(double stripWidth) => math.min(96, stripWidth / 4.5);

/// Grid over the photo while the Rotate tool is open, to line horizons and
/// verticals up against when straightening.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    const lines = 6;
    for (var i = 1; i < lines; i++) {
      final x = size.width * i / lines;
      final y = size.height * i / lines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// Floating overlay control bar — sits at the bottom edge of the
/// canvas whenever a reference image is in play. Layout follows the
/// camera screen's bottom row, plus a rotate button:
///
///   visible:  [🗏] [slider────────] [⟳ 90°] [↻ reset] [👁‍🗨 hide]
///   hidden:                                            [👁 show]
///
/// The AppBar carries no overlay toggle — this bar is the only way in
/// and out of the overlay state, so the two surfaces feel like the
/// same tool. The crop strip shows it too, without [onRotate] and
/// [onReset]: there the reference just fills the crop box.
class _FloatingOverlayBar extends StatelessWidget {
  final bool overlayVisible;
  final double opacity;
  final ThemeData theme;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback? onReset;
  final VoidCallback? onRotate;
  final VoidCallback onToggleVisibility;

  const _FloatingOverlayBar({
    required this.overlayVisible,
    required this.opacity,
    required this.theme,
    required this.onOpacityChanged,
    required this.onToggleVisibility,
    this.onReset,
    this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            if (overlayVisible) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child:
                    Icon(Icons.layers, color: Colors.white70, size: 18),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: theme.colorScheme.primary,
                    overlayColor:
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: opacity.clamp(0.1, 1),
                    min: 0.1,
                    max: 1,
                    onChanged: onOpacityChanged,
                  ),
                ),
              ),
              if (onRotate != null)
                IconButton(
                  icon: const Icon(Icons.rotate_right),
                  color: Colors.white,
                  tooltip: 'Rotate reference 90°',
                  onPressed: onRotate,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                ),
              if (onReset != null)
                IconButton(
                  icon: const Icon(Icons.restart_alt),
                  color: Colors.white,
                  tooltip: 'Reset overlay',
                  onPressed: onReset,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                ),
            ] else
              const Spacer(),
            IconButton(
              icon: Icon(
                overlayVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              color: Colors.white,
              tooltip:
                  overlayVisible ? 'Hide reference overlay' : 'Show reference overlay',
              onPressed: onToggleVisibility,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 36,
                height: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label + centered Slider + value indicator. Used for the active
/// tool's slider strip (Match Color strength, Brightness, Sharpness)
/// and for the floating overlay-opacity bar.
///
/// When [centerZero] is true the indicator shows signed percentages
/// (`-50%` / `+25%`) so a slider whose default is the midpoint reads
/// the way Lightroom / Google Photos do; otherwise it shows
/// `0%`–`100%` over the [min]–[max] range. [readout], when given, is shown
/// instead (e.g. the Rotate tool's degrees).
class _LabelledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final bool centerZero;
  final String? readout;
  final ThemeData theme;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _LabelledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.theme,
    required this.onChanged,
    this.centerZero = false,
    this.readout,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final String readout;
    if (this.readout case final given?) {
      readout = given;
    } else if (centerZero) {
      final extent = (max - min).abs() / 2;
      final percent = extent > 0 ? (value / extent) * 100 : 0;
      readout =
          '${percent >= 0 ? '+' : ''}${percent.round()}%';
    } else {
      final span = (max - min);
      final percent = span > 0 ? ((value - min) / span) * 100 : 0;
      readout = '${percent.round()}%';
    }

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 6),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: theme.colorScheme.primary,
              overlayColor:
                  theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            readout,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Google-Photos-style edit tool button: icon on top, label below,
/// no border. The active tool's foreground colour goes primary; the
/// rest sit in dim white so the selection reads at a glance against
/// the canvas's typically dark surroundings.
class _ToolButton extends StatelessWidget {
  /// From [_toolButtonWidth], so the strips' buttons all match.
  final double width;
  final IconData icon;

  /// Clockwise quarter-turns for [icon] — the Rotate tool's vertical flip
  /// is the horizontal flip icon turned once.
  final int iconQuarterTurns;
  final String label;
  final bool enabled;
  final bool selected;
  final bool applied;
  final String? disabledHint;
  final VoidCallback onTap;

  const _ToolButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
    this.iconQuarterTurns = 0,
    this.applied = false,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // disabled > selected (being dialled in) > applied (committed) > idle.
    final fg = !enabled
        ? Colors.white24
        : selected
            ? theme.colorScheme.primary
            : applied
                ? Colors.lightBlueAccent
                : Colors.white70;
    final tile = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          RotatedBox(
            quarterTurns: iconQuarterTurns,
            child: Icon(icon, color: fg, size: 28),
          ),
          const SizedBox(height: 4),
          // Labels like "Match\nColor" break where they say; a long single
          // word on a narrow screen shrinks to fit instead of being cut off.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(color: fg, fontSize: 12, height: 1.15),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
    return Tooltip(
      message: enabled ? '' : (disabledHint ?? ''),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: tile,
        ),
      ),
    );
  }
}

/// Displays only [crop] (a normalised rect over a [imageAspect] image),
/// scaled up to fill this widget's box with letterboxing — used so the
/// main-mode preview shows exactly what a committed crop will save,
/// without re-encoding anything. [child] must render the full displayed
/// image filling whatever box it's given.
class _CroppedView extends StatelessWidget {
  final Rect crop;
  final double imageAspect;
  final Widget child;

  const _CroppedView({
    required this.crop,
    required this.imageAspect,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final outAR = imageAspect * (crop.width / crop.height);
        // Fit the cropped output into the box (contain).
        double outW = box.width;
        double outH = outW / outAR;
        if (outH > box.height) {
          outH = box.height;
          outW = outH * outAR;
        }
        final outLeft = (box.width - outW) / 2;
        final outTop = (box.height - outH) / 2;
        // The full image, sized so its crop region maps onto outW × outH.
        final fullW = outW / crop.width;
        final fullH = outH / crop.height;
        return Stack(
          children: [
            Positioned(
              left: outLeft,
              top: outTop,
              width: outW,
              height: outH,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -crop.left * fullW,
                      top: -crop.top * fullH,
                      width: fullW,
                      height: fullH,
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Interactive crop frame drawn over the photo (which is laid out at its
/// display aspect, so this widget's box and the image share coordinates).
/// Drag a corner to resize, drag inside to move; with [aspectLock] set,
/// resizes keep that output pixel aspect. Reports the new rect in
/// normalised (0..1) coordinates via [onChanged].
class _CropFrame extends StatefulWidget {
  final Rect rect;
  final double? aspectLock;
  final ValueChanged<Rect> onChanged;

  const _CropFrame({
    required this.rect,
    required this.aspectLock,
    required this.onChanged,
  });

  @override
  State<_CropFrame> createState() => _CropFrameState();
}

class _CropFrameState extends State<_CropFrame> {
  // Touch radius for grabbing a corner, and the smallest crop side.
  static const double _handleHit = 30;
  static const double _minSide = 44;

  int _handle = -1; // -1 none, 0=TL 1=TR 2=BL 3=BR, 4=move
  Rect _startPx = Rect.zero;
  Offset _startPoint = Offset.zero;
  Size _size = Size.zero;

  Rect get _rectPx => Rect.fromLTRB(
        widget.rect.left * _size.width,
        widget.rect.top * _size.height,
        widget.rect.right * _size.width,
        widget.rect.bottom * _size.height,
      );

  void _onStart(Offset p) {
    _startPoint = p;
    _startPx = _rectPx;
    final corners = [
      _startPx.topLeft,
      _startPx.topRight,
      _startPx.bottomLeft,
      _startPx.bottomRight,
    ];
    _handle = -1;
    for (var i = 0; i < 4; i++) {
      if ((corners[i] - p).distance <= _handleHit) {
        _handle = i;
        break;
      }
    }
    if (_handle == -1 && _startPx.contains(p)) _handle = 4;
  }

  void _onUpdate(Offset p) {
    if (_handle == -1 || _size.isEmpty) return;
    final dx = p.dx - _startPoint.dx;
    final dy = p.dy - _startPoint.dy;
    final r = _startPx;

    if (_handle == 4) {
      final nl = (r.left + dx).clamp(0.0, _size.width - r.width);
      final nt = (r.top + dy).clamp(0.0, _size.height - r.height);
      _emit(Rect.fromLTWH(nl, nt, r.width, r.height));
      return;
    }

    double l = r.left, t = r.top, rt = r.right, b = r.bottom;
    switch (_handle) {
      case 0:
        l += dx;
        t += dy;
        break;
      case 1:
        rt += dx;
        t += dy;
        break;
      case 2:
        l += dx;
        b += dy;
        break;
      case 3:
        rt += dx;
        b += dy;
        break;
    }
    l = l.clamp(0.0, _size.width);
    rt = rt.clamp(0.0, _size.width);
    t = t.clamp(0.0, _size.height);
    b = b.clamp(0.0, _size.height);
    var nr = Rect.fromLTRB(math.min(l, rt), math.min(t, b), math.max(l, rt),
        math.max(t, b));
    if (nr.width < _minSide || nr.height < _minSide) return;

    final a = widget.aspectLock;
    if (a != null) {
      nr = _applyAspect(nr, a, _handle);
      if (nr.width < _minSide ||
          nr.height < _minSide ||
          nr.left < -0.5 ||
          nr.top < -0.5 ||
          nr.right > _size.width + 0.5 ||
          nr.bottom > _size.height + 0.5) {
        return;
      }
    }
    _emit(nr);
  }

  /// Re-shape [r] to output pixel-aspect [a], keeping the corner opposite
  /// the dragged [handle] anchored.
  Rect _applyAspect(Rect r, double a, int handle) {
    final w = r.width;
    final h = w / a;
    switch (handle) {
      case 0: // TL moves, BR fixed
        return Rect.fromLTRB(r.right - w, r.bottom - h, r.right, r.bottom);
      case 1: // TR moves, BL fixed
        return Rect.fromLTRB(r.left, r.bottom - h, r.left + w, r.bottom);
      case 2: // BL moves, TR fixed
        return Rect.fromLTRB(r.right - w, r.top, r.right, r.top + h);
      default: // BR moves, TL fixed
        return Rect.fromLTRB(r.left, r.top, r.left + w, r.top + h);
    }
  }

  void _emit(Rect px) {
    widget.onChanged(Rect.fromLTRB(
      px.left / _size.width,
      px.top / _size.height,
      px.right / _size.width,
      px.bottom / _size.height,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onStart(d.localPosition),
          onPanUpdate: (d) => _onUpdate(d.localPosition),
          child: CustomPaint(size: _size, painter: _CropPainter(_rectPx)),
        );
      },
    );
  }
}

/// Paints the crop frame: dimmed mask outside the rect, a white border,
/// rule-of-thirds guides, and bold corner brackets.
class _CropPainter extends CustomPainter {
  final Rect rect;

  _CropPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addRect(rect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()..color = const Color(0x99000000),
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);

    final thirds = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thirds);
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), thirds);
    }

    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const len = 22.0;
    void bracket(Offset c, double sx, double sy) {
      canvas.drawLine(c, c.translate(sx * len, 0), handle);
      canvas.drawLine(c, c.translate(0, sy * len), handle);
    }

    bracket(rect.topLeft, 1, 1);
    bracket(rect.topRight, -1, 1);
    bracket(rect.bottomLeft, 1, -1);
    bracket(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => oldDelegate.rect != rect;
}
