
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../model/channel.dart';
import '../model/stream_source.dart';

class ChannelsProvider with ChangeNotifier {
  static const streamsCatalogUrl =
      'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';

  static const _timeout = Duration(seconds: 20);

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];

  Future<List<StreamSource>> fetchStreamSources() async {
    final response =
        await http.get(Uri.parse(streamsCatalogUrl)).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load stream sources');
    }

    final sources = <StreamSource>[];

    for (final rawLine in response.body.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty || line.toLowerCase().startsWith('name,')) {
        continue;
      }

      final commaIndex = line.indexOf(',');
      if (commaIndex == -1) continue;

      final name = line.substring(0, commaIndex).trim();
      final streamUrl = line.substring(commaIndex + 1).trim();

      if (name.isNotEmpty && streamUrl.isNotEmpty) {
        sources.add(
          StreamSource(name: name, streamUrl: streamUrl),
        );
      }
    }

    return sources;
  }

  Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
    final response =
        await http.get(Uri.parse(sourceUrl)).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load M3U file');
    }

    final parsed = <Channel>[];

    String? name;
    String logoUrl = getDefaultLogoUrl();

    for (final rawLine in response.body.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        name = extractChannelName(line);
        logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
      } else if (!line.startsWith('#')) {
        if (name != null && name.isNotEmpty) {
          parsed.add(
            Channel(
              name: name,
              logoUrl: logoUrl,
              streamUrl: line,
            ),
          );
        }

        name = null;
        logoUrl = getDefaultLogoUrl();
      }
    }

    channels = parsed;
    filteredChannels = List.of(parsed);

    notifyListeners();

    return channels;
  }

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  String? extractChannelName(String line) {
    final lastQuote = line.lastIndexOf('"');

    final commaIndex = line.indexOf(
      ',',
      lastQuote == -1 ? 0 : lastQuote,
    );

    if (commaIndex == -1) {
      return line.split(',').last.trim();
    }

    return line.substring(commaIndex + 1).trim();
  }

  String? extractLogoUrl(String line) {
    final match = RegExp(
      r'''(?:tvg-logo|logo)="([^"]*)"''',
      caseSensitive: false,
    ).firstMatch(line);

    if (match == null) return null;

    final url = match.group(1)?.trim();

    if (url != null && isValidUrl(url)) {
      return url;
    }

    return null;
  }

  bool isValidUrl(String url) {
    final uri = Uri.tryParse(url);

    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Search priority:
  /// 1. Exact channel name
  /// 2. Name starts with search text
  /// 3. A word starts with search text
  /// 4. Search text appears anywhere

  List<Channel> filterChannels(String query) {
    final search = query.trim().toLowerCase();

    if (search.isEmpty) {
      filteredChannels = List.of(channels);
      notifyListeners();
      return filteredChannels;
    }

    final exact = <Channel>[];
    final startsWith = <Channel>[];
    final wordMatches = <Channel>[];
    final contains = <Channel>[];

    for (final channel in channels) {
      final name = channel.name.toLowerCase();

      if (name == search) {
        exact.add(channel);
      } else if (name.startsWith(search)) {
        startsWith.add(channel);
      } else if (name
          .split(RegExp(r'\s+'))
          .any((word) => word.startsWith(search))) {
        wordMatches.add(channel);
      } else if (name.contains(search)) {
        contains.add(channel);
      }
    }

    filteredChannels = [
      ...exact,
      ...startsWith,
      ...wordMatches,
      ...contains,
    ];

    notifyListeners();

    return filteredChannels;
  }
}
