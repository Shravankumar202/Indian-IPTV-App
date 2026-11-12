
import 'package:flutter/material.dart';

import '../model/channel.dart';
import '../model/stream_source.dart';
import '../provider/channels_provider.dart';
import 'player.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Channel> allChannels = [];
  List<Channel> filteredChannels = [];
  List<StreamSource> streamSources = [];

  final TextEditingController searchController =
      TextEditingController();

  final ChannelsProvider channelsProvider = ChannelsProvider();

  bool _isLoading = true;
  bool _hasError = false;

  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    fetchAllChannels();
  }

  Future<void> fetchAllChannels() async {
    final loadId = ++_loadId;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final sources = await channelsProvider.fetchStreamSources();

      if (!mounted || loadId != _loadId) return;

      streamSources = sources;

      final results = await Future.wait(
        sources.map((source) async {
          try {
            return await channelsProvider.fetchM3UFile(
              source.streamUrl,
            );
          } catch (_) {
            return <Channel>[];
          }
        }),
      );

      if (!mounted || loadId != _loadId) return;

      final combinedChannels = <Channel>[];
      final seenStreams = <String>{};

      for (final channels in results) {
        for (final channel in channels) {
          final stream = channel.streamUrl.trim();

          if (stream.isNotEmpty && seenStreams.add(stream)) {
            combinedChannels.add(channel);
          }
        }
      }

      setState(() {
        allChannels = combinedChannels;
        filteredChannels = combinedChannels;
        _isLoading = false;
        _hasError = combinedChannels.isEmpty;
      });
    } catch (_) {
      if (!mounted || loadId != _loadId) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void filterChannels(String query) {
    final search = query.trim().toLowerCase();

    if (search.isEmpty) {
      setState(() {
        filteredChannels = allChannels;
      });
      return;
    }

    final exact = <Channel>[];
    final startsWith = <Channel>[];
    final partial = <Channel>[];

    for (final channel in allChannels) {
      final name = channel.name.toLowerCase();

      if (name == search) {
        exact.add(channel);
      } else if (name.startsWith(search)) {
        startsWith.add(channel);
      } else if (name.contains(search)) {
        partial.add(channel);
      }
    }

    setState(() {
      filteredChannels = [
        ...exact,
        ...startsWith,
        ...partial,
      ];
    });
  }

  void _openPlayer(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Player(channel: channel),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D16),
      body: SafeArea(
        child: _isLoading
            ? _loadingScreen()
            : _hasError
                ? _errorScreen()
                : _channelScreen(),
      ),
    );
  }

  Widget _loadingScreen() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF55D6BE),
          ),
          SizedBox(height: 18),
          Text(
            'Loading all channels...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _errorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              color: Colors.white54,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load channels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: fetchAllChannels,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Channels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Indian TV and Sports in one place',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh channels',
                onPressed: fetchAllChannels,
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF55D6BE),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: TextField(
            controller: searchController,
            onChanged: filterChannels,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search all channels...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF55D6BE),
              ),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        filterChannels('');
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                      ),
                    ),
              filled: true,
              fillColor: const Color(0xFF1B2638),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Text(
            '${filteredChannels.length} channels available',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ),

        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(
                  child: Text(
                    'No channels found',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 17,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 88,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];

                    return _FocusCard(
                      onPressed: () => _openPlayer(channel),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: _ChannelLogo(
                              logoUrl: channel.logoUrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              channel.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF55D6BE),
                            size: 27,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _FocusCard({
    required this.child,
    required this.onPressed,
  });

  @override
  State<_FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<_FocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        setState(() => _focused = focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: _focused
              ? const Color(0xFF244B59)
              : const Color(0xFF1B2638),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _focused
                ? const Color(0xFF55D6BE)
                : Colors.white10,
            width: _focused ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final String logoUrl;

  const _ChannelLogo({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    const size = 54.0;

    if (logoUrl.startsWith('http://') ||
        logoUrl.startsWith('https://')) {
      return Image.network(
        logoUrl,
        width: size,
        height: size,
        cacheWidth: 108,
        cacheHeight: 108,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Image.asset(
      'assets/images/tv-icon.png',
      width: 54,
      height: 54,
      fit: BoxFit.contain,
    );
  }
}
