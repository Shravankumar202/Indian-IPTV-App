
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/channel.dart';

enum _ScreenMode { fit, crop, stretch, original }

class Player extends StatefulWidget {
  final Channel channel;

  const Player({super.key, required this.channel});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  VideoPlayerController? _videoController;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isFullScreen = false;
  bool _showControls = true;

  _ScreenMode _screenMode = _ScreenMode.fit;
  final FocusNode _focusNode = FocusNode();
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _hideTimer?.cancel();

    final oldController = _videoController;
    _videoController = null;

    oldController?.removeListener(_onVideoUpdate);
    await oldController?.dispose();

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _showControls = true;
    });

    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel.streamUrl),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0',
        },
      );

      _videoController = controller;

      await controller.initialize().timeout(
        const Duration(seconds: 30),
      );

      if (!mounted || _videoController != controller) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onVideoUpdate);

      await controller.setLooping(false);
      await controller.play();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = false;
      });

      _scheduleHideControls();
    } catch (_) {
      if (!mounted) {
        await controller?.dispose();
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onVideoUpdate() {
    final controller = _videoController;

    if (!mounted || controller == null) return;

    if (controller.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _showControls = true;
      });
      _hideTimer?.cancel();
    } else {
      setState(() {});
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();

    final controller = _videoController;

    if (controller == null || !controller.value.isPlaying) return;

    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      if (_videoController?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    if (!mounted) return;

    setState(() => _showControls = true);
    _scheduleHideControls();
  }

  Future<void> _togglePlayPause() async {
    final controller = _videoController;

    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      _hideTimer?.cancel();

      if (mounted) {
        setState(() => _showControls = true);
      }
    } else {
      await controller.play();
      _showControlsTemporarily();
    }
  }

  Future<void> _seek(int seconds) async {
    final controller = _videoController;

    if (controller == null || !controller.value.isInitialized) return;

    final current = controller.value.position;
    final duration = controller.value.duration;

    var target = current + Duration(seconds: seconds);

    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    await controller.seekTo(target);
    _showControlsTemporarily();
  }

  Future<void> _changeVolume(double amount) async {
    final controller = _videoController;

    if (controller == null || !controller.value.isInitialized) return;

    final volume = (controller.value.volume + amount).clamp(0.0, 1.0);

    await controller.setVolume(volume);
    _showControlsTemporarily();
  }

  Future<void> _toggleFullScreen() async {
    if (!mounted) return;

    final next = !_isFullScreen;

    if (next) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );

      await SystemChrome.setPreferredOrientations(
        const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );

      await SystemChrome.setPreferredOrientations(
        DeviceOrientation.values,
      );
    }

    if (mounted) {
      setState(() => _isFullScreen = next);
    }
  }

  Future<void> _closePlayer() async {
    _hideTimer?.cancel();

    if (_isFullScreen) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );

      await SystemChrome.setPreferredOrientations(
        DeviceOrientation.values,
      );
    }

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  KeyEventResult _handleKey(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seek(10);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _seek(-10);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _changeVolume(0.1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _changeVolume(-0.1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _closePlayer();
      return KeyEventResult.handled;
    }

    _showControlsTemporarily();
    return KeyEventResult.ignored;
  }

  BoxFit get _boxFit {
    switch (_screenMode) {
      case _ScreenMode.crop:
        return BoxFit.cover;

      case _ScreenMode.stretch:
        return BoxFit.fill;

      case _ScreenMode.fit:
      case _ScreenMode.original:
        return BoxFit.contain;
    }
  }

  String get _modeLabel {
    switch (_screenMode) {
      case _ScreenMode.fit:
        return 'Fit screen';

      case _ScreenMode.crop:
        return 'Crop / Zoom';

      case _ScreenMode.stretch:
        return 'Stretch';

      case _ScreenMode.original:
        return 'Original ratio';
    }
  }

  String _formatDuration(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${two(minutes)}:${two(seconds)}';
    }

    return '${two(minutes)}:${two(seconds)}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();

    final controller = _videoController;
    controller?.removeListener(_onVideoUpdate);
    controller?.dispose();

    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;

    final ready = controller != null &&
        controller.value.isInitialized;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,

        appBar: _isFullScreen
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF101827),
                foregroundColor: Colors.white,
                title: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  PopupMenuButton<_ScreenMode>(
                    tooltip: 'Video display mode',
                    icon: const Icon(Icons.aspect_ratio),
                    onSelected: (mode) {
                      setState(() => _screenMode = mode);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ScreenMode.fit,
                        child: Text('Fit screen'),
                      ),
                      PopupMenuItem(
                        value: _ScreenMode.crop,
                        child: Text('Crop / Zoom'),
                      ),
                      PopupMenuItem(
                        value: _ScreenMode.stretch,
                        child: Text('Stretch'),
                      ),
                      PopupMenuItem(
                        value: _ScreenMode.original,
                        child: Text('Original ratio'),
                      ),
                    ],
                  ),
                ],
              ),

        body: SafeArea(
          top: !_isFullScreen,
          bottom: !_isFullScreen,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showControlsTemporarily,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (ready)
                  Positioned.fill(
                    child: ClipRect(
                      child: FittedBox(
                        fit: _boxFit,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                  ),

                if (_isLoading)
                  const CircularProgressIndicator(
                    color: Color(0xFF55D6BE),
                  ),

                if (_hasError)
                  _errorPanel(),

                if (ready && !_hasError)
                  _buildPlaybackControls(controller),

                if (_isFullScreen && _showControls)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      onPressed: _closePlayer,
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(VideoPlayerController controller) {
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 10,
              left: 16,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  PopupMenuButton<_ScreenMode>(
                    tooltip: _modeLabel,
                    color: const Color(0xFF182131),
                    icon: const Icon(
                      Icons.aspect_ratio,
                      color: Colors.white,
                    ),
                    onSelected: (mode) {
                      setState(() => _screenMode = mode);
                      _scheduleHideControls();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ScreenMode.fit,
                        child: Text('Fit screen'),
                      ),
                      PopupMenuItem(
                        value: _ScreenMode.crop,
                        child: Text('Crop / Zoom'),
                      ),
                      PopupMenuItem(
                        value: _ScreenMode.stretch,
                        child: Text('Stretch'),
                      ),
                      PopupMenuItem(
                        value: _ScreenMode.original,
                        child: Text('Original ratio'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _seek(-10),
                    iconSize: 38,
                    color: Colors.white,
                    icon: const Icon(Icons.replay_10),
                  ),

                  const SizedBox(width: 18),

                  IconButton.filled(
                    autofocus: true,
                    onPressed: _togglePlayPause,
                    iconSize: 42,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF55D6BE),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(15),
                    ),
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),

                  const SizedBox(width: 18),

                  IconButton(
                    onPressed: () => _seek(10),
                    iconSize: 38,
                    color: Colors.white,
                    icon: const Icon(Icons.forward_10),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: Column(
                children: [
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF55D6BE),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        'Vol ${(controller.value.volume * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                      IconButton(
                        tooltip: 'Volume down',
                        onPressed: () => _changeVolume(-0.1),
                        color: Colors.white,
                        icon: const Icon(Icons.volume_down),
                      ),

                      IconButton(
                        tooltip: 'Volume up',
                        onPressed: () => _changeVolume(0.1),
                        color: Colors.white,
                        icon: const Icon(Icons.volume_up),
                      ),

                      IconButton(
                        tooltip: 'Full screen',
                        onPressed: _toggleFullScreen,
                        color: Colors.white,
                        icon: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.signal_wifi_connected_no_internet_4,
              color: Colors.white70,
              size: 55,
            ),

            const SizedBox(height: 16),

            const Text(
              'Channel is temporarily unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Check your internet connection or try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: _initPlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry channel'),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _closePlayer,
              child: const Text('Back to channels'),
            ),
          ],
        ),
      ),
    );
  }
}
