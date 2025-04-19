import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiHandler {
  static const String _flaskUrl = "https://rxjpawar.pythonanywhere.com/generate-image";

  static Future<Uint8List> generateImage(String description) async {
    try {
      final response = await http.post(
        Uri.parse(_flaskUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"prompt": description}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey("image")) {
          return base64Decode(responseData["image"]);
        } else {
          throw Exception('Server response missing image data');
        }
      } else {
        throw Exception('Failed with status code: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Failed to generate image: $error');
    }
  }
}

class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  _ImageGeneratorScreenState createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen> with WidgetsBindingObserver {
  Uint8List? generatedImage;
  bool isConnected = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print("App background me chala gaya!");
      isConnected = false;
    } else if (state == AppLifecycleState.resumed) {
      print("App wapas foreground me aaya!");
      isConnected = true;
    }
  }

  Future<void> fetchImage() async {
    try {
      Uint8List image = await ApiHandler.generateImage("A beautiful sunset");
      setState(() {
        generatedImage = image;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Generator")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            generatedImage != null
                ? Image.memory(generatedImage!)
                : const Text("No image generated yet."),
            ElevatedButton(
              onPressed: fetchImage,
              child: const Text("Generate Image"),
            ),
          ],
        ),
      ),
    );
  }
}
