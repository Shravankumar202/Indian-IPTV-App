
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

  StreamSource? selectedSource;

  final TextEditingController searchController =
      TextEditingController();

  final ChannelsProvider channelsProvider = ChannelsProvider();

  bool _isLoading = true;
  bool _hasError = false;

  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    fetchStreamSources();
  }

  Future<void> fetchStreamSources() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final sources = await channelsProvider.fetchStreamSources();

      if (!mounted) return;

      setState(() {
        streamSources = sources;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> fetchChannels(StreamSource source) async {
    final loadId = ++_loadId;

    setState(() {
      _isLoading = true;
      _hasError = false;
      selectedSource = source;
      searchController.clear();
    });

    try {
      final data = await channelsProvider.fetchM3UFile(
        source.streamUrl,
      );

      if (!mounted || loadId != _loadId) return;

      setState(() {
        allChannels = data;
        filteredChannels = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || loadId != _loadId) return;

      setState(() {
        selectedSource = null;
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void backToCategories() {
    _loadId++;

    setState(() {
      selectedSource = null;
      allChannels = [];
      filteredChannels = [];
      searchController.clear();
      _isLoading = false;
      _hasError = false;
    });
  }

  // Exact matches first, followed by prefix and partial matches.
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
    return PopScope(
      canPop: selectedSource == null,
      onPopInvoked: (didPop) {
        if (!didPop && selectedSource != null) {
          backToCategories();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080D16),
        body: SafeArea(
          child: _isLoading
              ? _loadingScreen()
              : _hasError
                  ? _errorScreen()
                  : selectedSource == null
                      ? _categoryScreen()
                      : _channelScreen(),
        ),
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
            'Loading...',
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
              'Unable to load data',
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
              onPressed: selectedSource == null
                  ? fetchStreamSources
                  : () => fetchChannels(selectedSource!),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          'Live TV',
          'Choose a category to watch your favourite channels',
        ),

        Expanded(
          child: streamSources.isEmpty
              ? const Center(
                  child: Text(
                    'No categories available',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: streamSources.length,
                  itemBuilder: (context, index) {
                    final source = streamSources[index];

                    return _FocusCard(
                      onPressed: () => fetchChannels(source),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.live_tv_rounded,
                            color: Color(0xFF55D6BE),
                            size: 32,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              source.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
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

  Widget _channelScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to categories',
                onPressed: backToCategories,
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedSource!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${filteredChannels.length} channels',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
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
              hintText: 'Search channels...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF55D6BE),
              ),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
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
