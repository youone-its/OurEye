import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SttTestScreen extends StatefulWidget {
  const SttTestScreen({super.key});

  @override
  State<SttTestScreen> createState() => _SttTestScreenState();
}

class _SttTestScreenState extends State<SttTestScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Setup TTS (bahasa Indonesia)
    await _tts.setLanguage("id-ID");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Minta izin mikrofon
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      await _tts.speak("Izin mikrofon ditolak. Aplikasi tidak dapat digunakan.");
      return;
    }

    // Inisialisasi Speech To Text
    final available = await _speechToText.initialize(
      onError: (error) => debugPrint("STT Error: ${error.errorMsg}"),
      onStatus: (status) => debugPrint("STT Status: $status"),
    );

    if (available) {
      setState(() => _isInitialized = true);

      // PETUNJUK SUARA OTOMATIS SAAT APLIKASI SIAP
      await _tts.speak(
        "Aplikasi siap. Sebelah kiri tombol Command, sebelah kanan tombol SOS.",
      );
    } else {
      await _tts.speak("Pengenalan suara tidak tersedia di perangkat ini.");
    }
  }

  Future<void> _toggleListening() async {
    if (!_isInitialized) return;

    if (_isListening) {
      // STOP MENDENGAR
      await _speechToText.stop();
      setState(() => _isListening = false);

      if (_recognizedText.isNotEmpty) {
        await _tts.speak("Perintah tersimpan. $_recognizedText");
      } else {
        await _tts.speak("Tidak ada suara yang terdeteksi.");
      }
    } else {
      // MULAI MENDENGAR
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      await _tts.speak("Sedang mendengarkan. Silakan bicara sekarang.");

      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
        },
        localeId: "id_ID",
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 6),
        partialResults: true,
        listenMode: ListenMode.confirmation,
      );
    }
  }

  void _onSosPressed() async {
    await _tts.speak("Tombol SOS ditekan. Fitur darurat segera hadir.");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("SOS - Fitur darurat segera hadir"),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(
            color: Colors.grey[900],
          ),

          // DUA TOMBOL BESAR: COMMAND (kiri) & SOS (kanan)
          Row(
            children: [
              // TOMBOL COMMAND (KIRI)
              Expanded(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : Colors.blueAccent,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 140,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _isListening ? "STOP" : "COMMAND",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // TOMBOL SOS (KANAN)
              Expanded(
                child: GestureDetector(
                  onTap: _onSosPressed,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red[800],
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 140,
                        ),
                        SizedBox(height: 32),
                        Text(
                          "SOS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // STATUS DI ATAS
          Positioned(
            top: 70,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Sedang mendengarkan
                if (_isListening)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 44),
                        SizedBox(width: 20),
                        Text(
                          "SEDANG MENDENGARKAN...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Hasil perintah
                if (!_isListening && _recognizedText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.greenAccent, width: 5),
                    ),
                    child: Text(
                      "Perintah:\n$_recognizedText",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}