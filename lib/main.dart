import 'package:flutter/material.dart';
import 'screens/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Show the error on screen instead of a blank page, so problems are visible.
  ErrorWidget.builder = (details) => Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Something went wrong:\n${details.exceptionAsString()}'),
          ),
        ),
      );

  runApp(M3UPlayer());
}

class M3UPlayer extends StatefulWidget {
  @override
  _M3UPlayerState createState() => _M3UPlayerState();
}

class _M3UPlayerState extends State<M3UPlayer> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Tv',
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Live TV'),
          ),
          body: const Home()),
    );
  }
}
