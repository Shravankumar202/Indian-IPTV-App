import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/channel.dart';

class Player extends StatefulWidget {
  final Channel channel;

  const Player({super.key, required this.channel});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake for as long as the player is open.
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

      // User may have left the screen while the stream was loading.
      if (!mounted) return;

      controller.addListener(_onVideoUpdate);
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoInitialize: false,
        isLive: true,
        autoPlay: true,
        aspectRatio: 3 / 2,
        showOptions: false,
        customControls: const MaterialDesktopControls(
          showPlayButton: false,
        ),
      );
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // Show the error message if the stream drops while playing.
  void _onVideoUpdate() {
    final controller = _videoController;
    if (!mounted || controller == null) return;
    if (controller.value.hasError && !_hasError) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _videoController?.removeListener(_onVideoUpdate);
    // Dispose Chewie first, then the video controller it uses.
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewieController;

    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : (_hasError || chewie == null)
                ? const Text('Channel not available now',
                    style: TextStyle(fontSize: 24.0))
                : SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Chewie(controller: chewie),
                  ),
      ),
    );
  }
}
