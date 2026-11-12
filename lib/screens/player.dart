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

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel.streamUrl),
      );

      _videoController = controller;

      await controller.initialize();

      if (!mounted) return;

      controller.addListener(_onVideoUpdate);
      await controller.play();

      if (!mounted) return;

      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;

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
      setState(() => _hasError = true);
    } else if (controller.value.isInitialized) {
      setState(() {});
    }
  }

  Future<void> _toggleFullScreen() async {
    final next = !_isFullScreen;

    setState(() => _isFullScreen = next);

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
        const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    }
  }

  Future<void> _closePlayer() async {
    if (_isFullScreen) {
      await _toggleFullScreen();
    }

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );

    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.dispose();

    super.dispose();
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
        return 'Original';
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
      final controller = _videoController;

      if (controller != null &&
          controller.value.isInitialized) {
        controller.value.isPlaying
            ? controller.pause()
            : controller.play();

        setState(() => _showControls = true);
      }

      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _closePlayer();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft) {
      final controller = _videoController;

      if (controller != null &&
          controller.value.isInitialized) {
        final delta =
            key == LogicalKeyboardKey.arrowRight
                ? const Duration(seconds: 10)
                : const Duration(seconds: -10);

        final target = controller.value.position + delta;

        controller.seekTo(
          target < Duration.zero
              ? Duration.zero
              : target,
        );
      }

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,

        appBar: _isFullScreen
            ? null
            : AppBar(
                title: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _closePlayer,
                ),
              ),

        body: SafeArea(
          top: !_isFullScreen,
          bottom: !_isFullScreen,
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : (_hasError ||
                        controller == null ||
                        !controller.value.isInitialized)
                    ? const Text(
                        'Channel not available now',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final videoSize = controller.value.size;

                          final aspect =
                              videoSize.width > 0 &&
                                      videoSize.height > 0
                                  ? videoSize.width /
                                      videoSize.height
                                  : 16 / 9;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _showControls = !_showControls;
                              });
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: ClipRect(
                                    child: FittedBox(
                                      fit: _boxFit,
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: constraints.maxWidth,
                                        height: constraints.maxWidth /
                                            aspect,
                                        child: VideoPlayer(controller),
                                      ),
                                    ),
                                  ),
                                ),

                                if (_showControls) ...[
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withOpacity(.55),
                                            Colors.transparent,
                                            Colors.black.withOpacity(.72),
                                          ],
                                          stops: const [0, .45, 1],
                                        ),
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    top: 12,
                                    left: 16,
                                    right: 12,
                                    child: Row(
                                      children: [
                                        if (_isFullScreen)
                                          IconButton(
                                            onPressed: _toggleFullScreen,
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                              color: Colors.white,
                                            ),
                                          ),

                                        Expanded(
                                          child: Text(
                                            widget.channel.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        PopupMenuButton<_ScreenMode>(
                                          tooltip: 'Screen size: $_modeLabel',
                                          initialValue: _screenMode,
                                          onSelected: (mode) {
                                            setState(() {
                                              _screenMode = mode;
                                            });
                                          },
                                          color: const Color(0xFF182131),
                                          icon: const Icon(
                                            Icons.fit_screen_rounded,
                                            color: Colors.white,
                                          ),
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
                                              child: Text('Original'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  Center(
                                    child: IconButton.filled(
                                      iconSize: 38,
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.black.withOpacity(.55),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.all(18),
                                      ),
                                      onPressed: () {
                                        controller.value.isPlaying
                                            ? controller.pause()
                                            : controller.play();

                                        setState(() {});
                                      },
                                      icon: Icon(
                                        controller.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
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
                                          colors:
                                              const VideoProgressColors(
                                            playedColor:
                                                Color(0xFF43D9C2),
                                            bufferedColor: Colors.white38,
                                            backgroundColor: Colors.white24,
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        Row(
                                          children: [
                                            Text(
                                              _modeLabel,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),

                                            const Spacer(),

                                            IconButton(
                                              onPressed: _toggleFullScreen,
                                              icon: Icon(
                                                _isFullScreen
                                                    ? Icons.fullscreen_exit_rounded
                                                    : Icons.fullscreen_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }
}
