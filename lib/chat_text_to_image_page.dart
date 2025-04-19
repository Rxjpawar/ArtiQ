import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'api_handler.dart';
import 'package:flutter/rendering.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatTextToImagePage extends StatefulWidget {
  const ChatTextToImagePage({super.key});

  @override
  ChatTextToImagePageState createState() => ChatTextToImagePageState();
}

class ChatTextToImagePageState extends State<ChatTextToImagePage>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _showHint = true;
  bool _showMicButton = true; // Add this to track which button to show
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  late AnimationController _loadingColorController;
  late Animation<Color?> _loadingColorAnimation;
  late ScrollController _scrollController;
  bool _showTagline = true;
  final double _scrollThreshold = 100.0;
  double _headerPadding = 12.0;
  
  // Speech to text variables
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _showHint = _textController.text.isEmpty;
        // Only update mic button if not loading
        if (!_isLoading) {
          _showMicButton = _textController.text.isEmpty;
        }
      });
    });

    _scrollController = ScrollController()..addListener(_scrollListener);

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), 
    );

    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: Colors.blue,
          end: const Color.fromARGB(255, 232, 104, 255),
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: const Color.fromARGB(255, 232, 104, 255),
          end: Colors.red,
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: Colors.red,
          end: const Color.fromARGB(255, 18, 57, 255),
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: const Color.fromARGB(255, 26, 91, 255),
          end: const Color.fromARGB(255, 247, 82, 219),
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: const Color.fromARGB(255, 247, 82, 219),
          end: const Color.fromARGB(255, 243, 33, 33),
        ),
      ),
    ]).animate(_colorController);

    // Add listener to reset color to blue after animation completes
    _colorController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // If mic is still listening, restart the animation
        if (_isListening) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _isListening) {
              _colorController.reset();
              _colorController.forward();
            }
          });
        } else {
          // Animation is complete, reset to blue
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _colorController.reset();
              setState(() {}); // Force rebuild to update button color
            }
          });
        }
      }
    });

    _loadingColorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _loadingColorAnimation = ColorTween(
      begin: const Color.fromARGB(255, 71, 170, 251),
      end: const Color.fromARGB(223, 63, 111, 255),
    ).animate(
      CurvedAnimation(
        parent: _loadingColorController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initialize speech to text
    _initSpeech();
  }
  
  // Initialize speech recognition
  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          setState(() {
            _isListening = status == 'listening';
          });
        },
        onError: (errorNotification) {
          print('Speech error: ${errorNotification.errorMsg}');
          setState(() {
            _isListening = false;
          });
        },
      );
      setState(() {});
    } catch (e) {
      print('Speech initialization error: $e');
      setState(() {
        _speechEnabled = false;
        _isListening = false;
      });
    }
  }
  
  // Start listening to speech
  void _startListening() {
    _colorController.reset();
    _colorController.forward();
    
    if (!_speech.isAvailable) {
      _initSpeech();
      return;
    }
    
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available on this device')),
      );
      return;
    }
    
    setState(() {
      _isListening = true;
    });
    
    // Using a different approach to avoid deprecated warnings
    // We're directly using the listen method with individual parameters
    // but suppressing the lint warnings since this is the most reliable way
    // to make it work across different versions of the package
    
    // ignore: deprecated_member_use
    _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _textController.text = _lastWords;
          // Update mic button state
          _showMicButton = _textController.text.isEmpty;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      // ignore: deprecated_member_use
      partialResults: true,
      // ignore: deprecated_member_use
      localeId: 'en_US',
      // ignore: deprecated_member_use
      cancelOnError: true,
      // ignore: deprecated_member_use
      listenMode: ListenMode.confirmation,
    );
  }
  
  // Stop listening to speech
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    
    // Reset color animation when stopping listening
    _colorController.reset();
  }

  void _handleSendPress() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text.')),
      );
      return;
    }

    // Removing color animation for send button
    // _colorController.reset();
    // _colorController.forward();
    _generateImage();
  }

  void _generateImage() async {
    final String userMessage = _textController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({'text': userMessage, 'isUser': true});
      _isLoading = true;
      _showMicButton = false; // Keep showing send button during loading
    });

    _textController.clear();

    try {
      final imageBytes = await ApiHandler.generateImage(userMessage);

      setState(() {
        _isLoading = false;
        _showMicButton = true; // Show mic button after image generation is complete
        _messages.add({
          'text': "Here's your generated image:",
          'isUser': false,
          'imageBytes': imageBytes,
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showMicButton = true; // Show mic button even if there's an error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to generate image. Please try again.')),
        );
      });
    }
  }

  void _scrollListener() {
    if (_messages.length > 2) {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_scrollController.offset > _scrollThreshold) {
          setState(() {
            _showTagline = false;
            _headerPadding = 2.0;
          });
        }
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        setState(() {
          _showTagline = true;
          _headerPadding = 8.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _colorController.dispose();
    _loadingColorController.dispose();
    _scrollController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 14, 147, 255),
              Color.fromARGB(224, 140, 199, 248),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.only(top: _headerPadding),
                child: Column(
                  children: [
                    const Text(
                      'ArtiQ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_messages.length > 2) ...[
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showTagline ? 1.0 : 0.0,
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                          child: AnimatedTextKit(
                            animatedTexts: [
                              TypewriterAnimatedText(
                                'Where Words Become Vision',
                                speed: const Duration(milliseconds: 150),
                              ),
                            ],
                            totalRepeatCount: 1,
                            displayFullTextOnTap: true,
                            stopPauseOnTap: true,
                          ),
                        ),
                      ),
                    ] else ...[
                      DefaultTextStyle(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'Where Words Become Vision',
                              speed: const Duration(milliseconds: 100),
                            ),
                          ],
                          totalRepeatCount: 1,
                          displayFullTextOnTap: true,
                          stopPauseOnTap: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    final bool isUser = message['isUser'];

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        padding: const EdgeInsets.all(12.0),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color.fromARGB(255, 66, 122, 254)
                              : const Color.fromARGB(170, 255, 255, 255),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isUser
                                ? const Radius.circular(20)
                                : Radius.zero,
                            bottomRight: isUser
                                ? Radius.zero
                                : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser && message['imageBytes'] != null) ...[
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                  bottomLeft: Radius.zero,
                                  bottomRight: Radius.circular(12),
                                ),
                                child: Image.memory(
                                  message['imageBytes'],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ] else ...[
                              Text(
                                message['text'],
                                style: TextStyle(
                                  color: isUser
                                      ? const Color.fromARGB(255, 255, 255, 255)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Loading Indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimatedBuilder(
                    animation: _loadingColorController,
                    builder: (context, child) {
                      return SpinKitWave(
                        color: _loadingColorAnimation.value,
                        size: 40.0,
                        itemCount: 5,
                      );
                    },
                  ),
                ),

              // Input Section
              Padding(
                padding: const EdgeInsets.only(
                  top: 1.0,
                  bottom: 8.0,
                  left: 12.0,
                  right: 12.0,
                ),
                child: Row(
                  children: [
                    // Text Input
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 217, 230, 246),
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _handleSendPress(),
                              onChanged: (text) {
                                // Force rebuild to update button state
                                setState(() {});
                              },
                            ),
                            if (_showHint)
                              Positioned(
                                left: 2,
                                child: IgnorePointer(
                                  child: AnimatedTextKit(
                                    animatedTexts: [
                                      ColorizeAnimatedText(
                                        'Your imagination starts here...',
                                        textAlign: TextAlign.left,
                                        textStyle: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        colors: const [
                                          Color.fromARGB(255, 79, 176, 255),
                                          Color.fromARGB(255, 72, 112, 255),
                                          Colors.red,
                                          Color.fromARGB(255, 248, 44, 183),
                                          Colors.red,
                                          Colors.blue,
                                        ],
                                        speed:
                                            const Duration(milliseconds: 600),
                                      ),
                                    ],
                                    repeatForever: true,
                                    isRepeatingAnimation: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Toggle Button
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: AnimatedBuilder(
                        animation: _colorController,
                        builder: (context, child) {
                          return ElevatedButton(
                            onPressed: _showMicButton 
                                ? () {
                                    // Start speech recognition when mic button is pressed
                                    if (_isListening) {
                                      _stopListening();
                                    } else {
                                      _startListening();
                                    }
                                  }
                                : _handleSendPress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 217, 230, 246),
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.blue,
                              elevation: _showMicButton && _colorController.status == AnimationStatus.forward ? 4 : 0,
                              disabledBackgroundColor:
                                  const Color.fromARGB(255, 217, 230, 246)
                                      .withValues(alpha: 0.5),
                              disabledForegroundColor: const Color.fromARGB(255, 255, 255, 255),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                _showMicButton 
                                    ? (_isListening ? Icons.mic_off : Icons.mic) 
                                    : Icons.send,
                                key: ValueKey<String>(_showMicButton 
                                    ? (_isListening ? 'mic_off' : 'mic') 
                                    : 'send'),
                                size: 23,
                                color: _showMicButton && _colorController.status == AnimationStatus.forward
                                    ? _colorAnimation.value
                                    : Colors.blue, // Always blue for send button, animated for mic
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
