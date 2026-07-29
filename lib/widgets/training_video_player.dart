import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/colors.dart';

/// Real in-app playback for a training course's attached video (`Course.
/// videoUrl`, migration 0115) — before this, `course_detail_page.dart` had
/// no content viewer of any kind regardless of `format`. Wraps `video_player`
/// with `chewie` for ready-made play/pause/seek/fullscreen controls rather
/// than hand-rolling a control bar. Works on Flutter Web via
/// `video_player_web`'s HTML5 `<video>` backing, same as every other
/// platform this app targets.
class TrainingVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const TrainingVideoPlayer({super.key, required this.videoUrl});

  @override
  State<TrainingVideoPlayer> createState() => _TrainingVideoPlayerState();
}

class _TrainingVideoPlayerState extends State<TrainingVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant TrainingVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A course's attached video can change (staff replaces it) while this
    // widget stays mounted on the same CourseDetailPage instance — without
    // this, the player would keep showing the OLD video's already-
    // initialized controller after a reload.
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      setState(() => _failed = false);
      _init();
    }
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await controller.initialize();
    } catch (_) {
      controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    // `initialize()`'s own try/catch only covers a failure to START
    // playback — a MID-playback failure (dropped connection, the video
    // deleted from storage while playing, a transient decode error) has no
    // listener at all otherwise, unlike this exact init-time path, so it
    // silently leaves the player stuck rather than showing the same error
    // state a startup failure already gets.
    controller.addListener(_onVideoControllerUpdate);
    setState(() {
      _videoController = controller;
      _chewieController = ChewieController(videoPlayerController: controller, aspectRatio: controller.value.aspectRatio, autoPlay: false, looping: false);
    });
  }

  void _onVideoControllerUpdate() {
    if (_videoController?.value.hasError == true && mounted && !_failed) {
      _disposeControllers();
      setState(() => _failed = true);
    }
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewieController;
    if (_failed) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Neutral.c100,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: Accent.red500, size: 28),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.trainingVideoPlayerError, style: TextStyle(fontSize: 12, color: Neutral.c600)),
              ],
            ),
          ),
        ),
      );
    }
    if (chewie == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(color: Neutral.c100, alignment: Alignment.center, child: const CircularProgressIndicator()),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: Chewie(controller: chewie)),
    );
  }
}
