import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DebugPage(),
    );
  }
}

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  _DebugPageState createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final TextEditingController _promptController = TextEditingController();
  Uint8List? _imageBytes;
  String _statusMessage = "Enter a prompt and press 'Generate'.";

  Future<void> _generateImage(String prompt) async {
    const String apiUrl = "http://10.0.2.2:5000/generate-image"; // Flask API URL

    setState(() {
      _statusMessage = "Sending request...";
      _imageBytes = null;
    });

    try {
      print("Sending request to: $apiUrl");
      print("Prompt: $prompt");

      // Sending the API request to Flask
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"prompt": prompt}),
      );

      print("Response received. Status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Parse the response and decode the Base64 image
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        if (responseBody.containsKey('image')) {
          print("Image data found in response.");
          final Uint8List imageBytes = base64Decode(responseBody['image']);
          print("Image successfully decoded. Size: ${imageBytes.length} bytes.");

          setState(() {
            _imageBytes = imageBytes;
            _statusMessage = "Image generated successfully!";
          });
        } else {
          print("Error: 'image' key not found in response.");
          setState(() {
            _statusMessage = "Error: 'image' key not found in response.";
          });
        }
      } else {
        print("Error: API returned a non-200 status code.");
        print("Response Body: ${response.body}");
        setState(() {
          _statusMessage = "Error: API returned status code ${response.statusCode}.";
        });
      }
    } catch (error) {
      print("Exception occurred during API call: $error");
      setState(() {
        _statusMessage = "Exception: $error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("API Debugger"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: "Enter a prompt",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final prompt = _promptController.text.trim();
                if (prompt.isNotEmpty) {
                  _generateImage(prompt);
                } else {
                  setState(() {
                    _statusMessage = "Please enter a valid prompt.";
                  });
                }
              },
              child: const Text("Generate"),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            if (_imageBytes != null)
              Expanded(
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
