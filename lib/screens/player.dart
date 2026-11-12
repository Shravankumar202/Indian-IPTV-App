
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/channel.dart';

enum _ScreenMode { fit, crop, stretch, original }

class Player extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels;
  final int initialChannelIndex;

  const Player({
    super.key,
    required this.channel,
    this.channels = const [],
    this.initialChannelIndex = 0,
  });

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  VideoPlayerController? _controller;
  late Channel _currentChannel;
  late int _channelIndex;

  bool _loading = true;
  bool _hasError = false;
  bool _showControls = false;

  _ScreenMode _screenMode = _ScreenMode.fit;
  final FocusNode _focusNode = FocusNode();
  Timer? _hideTimer;
  int _initId = 0;

  List<Channel> get _channelList =>
      widget.channels.isEmpty ? [widget.channel] : widget.channels;

  @override
  void initState() {
    super.initState();

    _channelIndex = widget.initialChannelIndex
        .clamp(0, _channelList.length - 1)
        .toInt();

    _currentChannel = _channelList[_channelIndex];

    WakelockPlus.enable();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final id = ++_initId;

    _hideTimer?.cancel();

    final old = _controller;
    _controller = null;

    old?.removeListener(_onVideoUpdate);
    await old?.dispose();

    if (!mounted || id != _initId) return;

    setState(() {
      _loading = true;
      _hasError = false;
      _showControls = false;
    });

    VideoPlayerController? next;

    try {
      next = VideoPlayerController.networkUrl(
        Uri.parse(_currentChannel.streamUrl),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0',
        },
      );

      _controller = next;

      await next.initialize().timeout(
        const Duration(seconds: 30),
      );

      if (!mounted || id != _initId || _controller != next) {
        await next.dispose();
        return;
      }

      next.addListener(_onVideoUpdate);

      await next.setLooping(false);
      await next.play();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasError = false;
      });

      _scheduleHide();
    } catch (_) {
      if (!mounted || id != _initId) {
        await next?.dispose();
        return;
      }

      setState(() {
        _loading = false;
        _hasError = true;
        _showControls = true;
      });
    }
  }

  void _onVideoUpdate() {
    final controller = _controller;

    if (!mounted || controller == null) return;

    if (controller.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _showControls = true;
      });

      _hideTimer?.cancel();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();

    if (_controller?.value.isPlaying != true) return;

    _hideTimer = Timer(
      const Duration(seconds: 4),
      () {
        if (mounted &&
            _controller?.value.isPlaying == true) {
          setState(() => _showControls = false);
          _focusNode.requestFocus();
        }
      },
    );
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();

      setState(() => _showControls = false);

      _focusNode.requestFocus();
    } else {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  Future<void> _switchChannel(int direction) async {
    if (_channelList.length < 2) {
      setState(() => _showControls = true);
      _scheduleHide();
      return;
    }

    setState(() {
      _channelIndex =
          (_channelIndex + direction + _channelList.length) %
              _channelList.length;

      _currentChannel = _channelList[_channelIndex];
    });

    await _initPlayer();
  }

  Future<void> _closePlayer() async {
    _hideTimer?.cancel();

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    await SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );

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

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _closePlayer();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _toggleControls();
      return KeyEventResult.handled;
    }

    // Allow display-mode menu navigation when controls are visible.
    if (_showControls) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _switchChannel(-1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _switchChannel(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      setState(() => _showControls = true);
      _scheduleHide();
      return KeyEventResult.handled;
    }

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

  @override
  void dispose() {
    _initId++;

    _hideTimer?.cancel();
    _focusNode.dispose();

    final controller = _controller;

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
    final controller = _controller;

    final ready = controller != null &&
        controller.value.isInitialized;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
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

              if (_loading)
                const CircularProgressIndicator(
                  color: Color(0xFF55D6BE),
                ),

              if (_hasError)
                _errorPanel(),

              if (ready && !_hasError && _showControls)
                _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.42),
                  Colors.transparent,
                  Colors.black.withOpacity(0.42),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 16,
          right: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<_ScreenMode>(
                tooltip: 'Video display mode',
                color: const Color(0xFF182131),
                icon: const Icon(
                  Icons.aspect_ratio,
                  color: Colors.white,
                  size: 30,
                ),
                onSelected: (mode) {
                  setState(() => _screenMode = mode);
                  _scheduleHide();
                  _focusNode.requestFocus();
                },
                itemBuilder: (_) => [
                  _modeItem(
                    _ScreenMode.fit,
                    'Fit screen',
                  ),
                  _modeItem(
                    _ScreenMode.crop,
                    'Crop / Zoom',
                  ),
                  _modeItem(
                    _ScreenMode.stretch,
                    'Stretch',
                  ),
                  _modeItem(
                    _ScreenMode.original,
                    'Original ratio',
                  ),
                ],
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Back to channels',
                onPressed: _closePlayer,
                color: Colors.white,
                icon: const Icon(
                  Icons.close,
                  size: 30,
                ),
              ),
            ],
          ),
        ),

        const Center(
          child: Text(
            'OK  ·  Hide controls',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              shadows: [
                Shadow(
                  blurRadius: 5,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<_ScreenMode> _modeItem(
    _ScreenMode mode,
    String label,
  ) {
    return PopupMenuItem<_ScreenMode>(
      value: mode,
      child: Row(
        children: [
          if (_screenMode == mode)
            const Icon(
              Icons.check,
              color: Color(0xFF55D6BE),
              size: 18,
            )
          else
            const SizedBox(width: 18),

          const SizedBox(width: 10),

          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
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
              'Check your internet connection or try another channel.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              autofocus: true,
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
