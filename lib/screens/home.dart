
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
  List<Channel> filteredChannels = [];
  List<StreamSource> streamSources = [];
  StreamSource? selectedSource;
  final TextEditingController searchController = TextEditingController();
  final ChannelsProvider channelsProvider = ChannelsProvider();
  bool _isLoading = true;
  int _loadId = 0; // ignores results of an outdated category request

  @override
  void initState() {
    super.initState();
    fetchStreamSources();
  }

  Future<void> fetchStreamSources() async {
    try {
      final sources = await channelsProvider.fetchStreamSources();
      if (!mounted) return;
      setState(() {
        streamSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem loading stream categories'),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchChannels(StreamSource source) async {
    final loadId = ++_loadId;
    setState(() {
      _isLoading = true;
      selectedSource = source;
      searchController.clear();
    });

    try {
      final data = await channelsProvider.fetchM3UFile(source.streamUrl);
      if (!mounted || loadId != _loadId) return;
      setState(() {
        filteredChannels = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem loading channels'),
        ),
      );
      setState(() {
        selectedSource = null;
        _isLoading = false;
      });
    }
  }

  void backToCategories() {
    _loadId++; // cancel any category still loading
    setState(() {
      selectedSource = null;
      filteredChannels = [];
      _isLoading = false;
      searchController.clear();
    });
  }

  // Instant filtering: the list is small, so no delay is needed.
  void filterChannels(String query) {
    setState(() {
      filteredChannels = channelsProvider.filterChannels(query);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (selectedSource == null) {
      body = _buildCategoryList();
    } else {
      body = _buildChannelList();
    }

    // Back button / remote Back returns to categories instead of closing
    // the app while a channel list is open.
    return PopScope(
      canPop: selectedSource == null,
      onPopInvoked: (didPop) {
        if (!didPop) backToCategories();
      },
      child: body,
    );
  }

  Widget _buildCategoryList() {
    if (streamSources.isEmpty) {
      return const Center(child: Text('No stream categories available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: streamSources.length,
      itemBuilder: (context, index) {
        final source = streamSources[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => fetchChannels(source),
            child: Text(
              source.name,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: backToCategories,
              ),
              Expanded(
                child: Text(
                  selectedSource!.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            onChanged: filterChannels,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Type exact channel name...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        filterChannels('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(child: Text('No channels found'))
              : ListView.builder(
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];
                    return ListTile(
                      leading: Image.network(
                        channel.logoUrl,
                        width: 50,
                        height: 50,
                        // Decode logos at thumbnail size to save memory;
                        // big logos can get the app killed on low-RAM TVs.
                        cacheWidth: 100,
                        cacheHeight: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/tv-icon.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                      title: Text(channel.name),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Player(channel: channel),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
