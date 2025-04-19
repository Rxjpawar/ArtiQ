import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'chat_text_to_image_page.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const ChatTextToImageApp());
}
class ChatTextToImageApp extends StatelessWidget {
  const ChatTextToImageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color.fromARGB(255, 21, 150, 255),
        scaffoldBackgroundColor: const Color.fromARGB(255, 14, 147, 255),
      ),
      home: const ChatTextToImagePage(),
    );
  }
}
