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
    final lines = response.body.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('name,')) {
        continue;
      }

      final commaIndex = trimmed.indexOf(',');
      if (commaIndex == -1) continue;

      final name = trimmed.substring(0, commaIndex).trim();
      final streamUrl = trimmed.substring(commaIndex + 1).trim();
      if (name.isNotEmpty && streamUrl.isNotEmpty) {
        sources.add(StreamSource(name: name, streamUrl: streamUrl));
      }
    }

    return sources;
  }

  Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
    final response = await http.get(Uri.parse(sourceUrl)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load M3U file');
    }

    // Build new lists instead of clearing the old ones, so the UI never
    // reads a list that is being modified.
    final parsed = <Channel>[];
    String? name;
    String logoUrl = getDefaultLogoUrl();

    for (final rawLine in response.body.split('\n')) {
      final line = rawLine.trim(); // also strips Windows '\r'
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        name = extractChannelName(line);
        logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
      } else if (!line.startsWith('#')) {
        if (name != null && name.isNotEmpty) {
          parsed.add(Channel(name: name, logoUrl: logoUrl, streamUrl: line));
        }
        name = null;
        logoUrl = getDefaultLogoUrl();
      }
    }

    channels = parsed;
    filteredChannels = List.of(parsed);
    return channels;
  }

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  /// The channel name is the text after the comma that follows the last
  /// quoted attribute, so names containing commas are kept whole.
  String? extractChannelName(String line) {
    final lastQuote = line.lastIndexOf('"');
    final commaIndex = line.indexOf(',', lastQuote == -1 ? 0 : lastQuote);
    if (commaIndex == -1) return line.split(',').last.trim();
    return line.substring(commaIndex + 1).trim();
  }

  String? extractLogoUrl(String line) {
    List<String> parts = line.split('"');
    if (parts.length > 1 && isValidUrl(parts[1])) {
      return parts[1];
    } else if (parts.length > 5 && isValidUrl(parts[5])) {
      return parts[5];
    }
    return null;
  }

  bool isValidUrl(String url) {
    return url.startsWith('https') || url.startsWith('http');
  }

  /// Returns channels whose name contains exactly what was typed
  /// (case-insensitive, as one phrase). Best matches come first:
  /// 1) identical name, 2) name starts with the text,
  /// 3) text matches the start of a word, 4) text appears anywhere.
  List<Channel> filterChannels(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      filteredChannels = List.of(channels);
      return filteredChannels;
    }

    final scored = <MapEntry<int, Channel>>[];
    for (final channel in channels) {
      final n = channel.name.toLowerCase();
      final index = n.indexOf(q);
      if (index == -1) continue;

      int rank;
      if (n == q) {
        rank = 0;
      } else if (index == 0) {
        rank = 1;
      } else if (n[index - 1] == ' ') {
        rank = 2;
      } else {
        rank = 3;
      }
      scored.add(MapEntry(rank, channel));
    }

    // Dart's List.sort is not stable, so keep original order on ties.
    final order = {for (var i = 0; i < scored.length; i++) scored[i].value: i};
    scored.sort((a, b) {
      final byRank = a.key.compareTo(b.key);
      return byRank != 0 ? byRank : order[a.value]!.compareTo(order[b.value]!);
    });

    filteredChannels = scored.map((e) => e.value).toList();
    return filteredChannels;
  }
}
