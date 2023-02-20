import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_downloader/image_downloader.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText speechToTextInstance = SpeechToText();
  String recordedAudioString = "";
  TextEditingController userInputTextEditingController =
      TextEditingController();
  bool isLoading = false;
  String modeOpenAI = "chat";
  String imageUrlFromOpenAI = "";
  String answerTextFromOpenAI = "";
  bool isMuted = false;
  void initializeSpeechToText() async {
    await speechToTextInstance.initialize();
    setState(() {});
  }

  void startListeningNow() async {
    FocusScope.of(context).unfocus();
    await speechToTextInstance.listen(onResult: onSpeechToTextResult);
    setState(() {});
  }

  void speak(String textToSpeak) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(0.9);
    await flutterTts.speak(textToSpeak);
  }

  void stopListeningNow() async {
    await speechToTextInstance.stop();
    setState(() {});
  }

  void onSpeechToTextResult(SpeechRecognitionResult recognitionResult) {
    recordedAudioString = recognitionResult.recognizedWords;

    speechToTextInstance.isListening
        ? null
        : sendRequestToOpenAI(recordedAudioString);

    print("Speech result");
    print(recordedAudioString);
  }

  Future<void> sendRequestToOpenAI(String userInput) async {
    stopListeningNow();

    setState(() {
      isLoading = true;
    });

    await APIService().requestOpenAI(userInput, modeOpenAI, 2000).then((value) {
      setState(() {
        isLoading = false;
      });

      if (value.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Api key you are/were using is expired or it is not working anymore",
            ),
          ),
        );
      }
      userInputTextEditingController.clear();
      final responseAvailable = jsonDecode(value.body);
      if (modeOpenAI == "chat") {
        setState(() {
          answerTextFromOpenAI = utf8.decode(
              responseAvailable["choices"][0]["text"].toString().codeUnits);
          print("CHATBOT");
          print(answerTextFromOpenAI);
        });
        isMuted ? null : speak(answerTextFromOpenAI);
      } else {
        setState(() {
          imageUrlFromOpenAI = responseAvailable["data"][0]["url"];
          print("DALL_E");
          print(imageUrlFromOpenAI);
        });
      }
    }).catchError((errorMessage) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error $errorMessage.toString()",
          ),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    initializeSpeechToText();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          isMuted = !isMuted;
          isMuted ? flutterTts.stop() : speak(answerTextFromOpenAI);
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(isMuted ? "images/mute.png" : "images/audio.png"),
        ),
      ),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
          Colors.purpleAccent.shade100,
          Colors.deepPurple.shade100
        ]))),
        title: Row(
          children: [
            Image.asset(
              "images/logo.png",
              width: 110,
            ),
          ],
        ),
        titleSpacing: 10,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 4),
            child: InkWell(
                onTap: () {
                  setState(() {
                    modeOpenAI = "chat";
                  });
                },
                child: Icon(
                  Icons.chat,
                  size: 30,
                  color: modeOpenAI == "chat" ? Colors.white : Colors.grey,
                )),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: InkWell(
                onTap: () {
                  setState(() {
                    modeOpenAI = "image";
                  });
                },
                child: Icon(
                  Icons.image,
                  size: 30,
                  color: modeOpenAI == "image" ? Colors.white : Colors.grey,
                )),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(
                height: 40,
              ),
              Center(
                child: InkWell(
                  onTap: () {
                    speechToTextInstance.isListening
                        ? startListeningNow()
                        : startListeningNow();
                  },
                  child: speechToTextInstance.isListening
                      ? Center(
                          child: LoadingAnimationWidget.beat(
                              color: speechToTextInstance.isListening
                                  ? Colors.deepPurple
                                  : isLoading
                                      ? Colors.deepPurple[300]!
                                      : Colors.deepPurple[200]!,
                              size: 300),
                        )
                      : Image.asset(
                          "images/assistant.png",
                          height: 300,
                          width: 300,
                          color: Colors.black87,
                        ),
                ),
              ),
              const SizedBox(
                height: 50,
              ),
              Row(
                children: [
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: TextField(
                      controller: userInputTextEditingController,
                      decoration: const InputDecoration(
                          labelStyle: TextStyle(fontFamily: 'FontMain'),
                          border: OutlineInputBorder(),
                          labelText: "How can I help you?"),
                    ),
                  )),
                  const SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      if (userInputTextEditingController.text.isNotEmpty) {
                        sendRequestToOpenAI(
                            userInputTextEditingController.text.toString());
                      }
                    },
                    child: AnimatedContainer(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        color: Colors.deepPurple[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.bounceInOut,
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(
                height: 24,
              ),
              modeOpenAI == "chat"
                  ? SelectableText(
                      answerTextFromOpenAI,
                      style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'FontMain'),
                    )
                  : modeOpenAI == "image" && imageUrlFromOpenAI.isNotEmpty
                      ? Column(
                          children: [
                            Image.network(
                              imageUrlFromOpenAI,
                            ),
                            const SizedBox(
                              height: 15,
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                String? imageStatus =
                                    await ImageDownloader.downloadImage(
                                        imageUrlFromOpenAI);
                                if (imageStatus != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Image downloaded successfully")));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple),
                              child: const Text(
                                "Download this image",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'FontMain'),
                              ),
                            )
                          ],
                        )
                      : Container()
            ],
          ),
        ),
      ),
    );
  }
}
