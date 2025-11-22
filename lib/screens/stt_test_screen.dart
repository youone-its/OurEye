import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SttTestScreen extends StatefulWidget {
  const SttTestScreen({super.key});

  @override
  State<SttTestScreen> createState() => _SttTestScreenState();
}

class _SttTestScreenState extends State<SttTestScreen> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _statusText = 'Not initialized';
  List<String> _availableLocales = [];
  String _selectedLocale = 'id_ID';
  double _soundLevel = 0.0;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
    debugPrint(message);
  }

  Future<void> _initializeSpeech() async {
    _addLog('Requesting microphone permission...');
    
    final micStatus = await Permission.microphone.request();
    _addLog('Microphone permission: $micStatus');
    
    if (!micStatus.isGranted) {
      setState(() {
        _statusText = 'Microphone permission denied';
      });
      return;
    }

    _addLog('Initializing speech recognition...');
    
    final available = await _speechToText.initialize(
      onError: (error) {
        _addLog('ERROR: ${error.errorMsg} (permanent: ${error.permanent})');
        setState(() {
          _statusText = 'Error: ${error.errorMsg}';
          _isListening = false;
        });
      },
      onStatus: (status) {
        _addLog('Status changed: $status');
        setState(() {
          _statusText = 'Status: $status';
        });
      },
    );

    _addLog('Speech recognition available: $available');

    if (available) {
      final locales = await _speechToText.locales();
      _addLog('Found ${locales.length} locales');
      
      setState(() {
        _isInitialized = true;
        _statusText = 'Ready';
        _availableLocales = locales.map((l) => '${l.localeId} - ${l.name}').toList();
      });

      for (var locale in locales) {
        _addLog('Locale: ${locale.localeId} (${locale.name})');
      }
    } else {
      setState(() {
        _statusText = 'Speech recognition not available';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized || _isListening) return;

    _addLog('Starting to listen with locale: $_selectedLocale');
    
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _soundLevel = 0.0;
    });

    final success = await _speechToText.listen(
      onResult: (result) {
        _addLog('Result: "${result.recognizedWords}" (final: ${result.finalResult}, confidence: ${result.confidence})');
        
        setState(() {
          _recognizedText = result.recognizedWords;
        });

        if (result.alternates.isNotEmpty) {
          _addLog('Alternatives:');
          for (var alt in result.alternates) {
            _addLog('  - "${alt.recognizedWords}" (${alt.confidence})');
          }
        }
      },
      localeId: _selectedLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level;
        });
      },
    );

    _addLog('Listen started: $success');
  }

  Future<void> _stopListening() async {
    _addLog('Stopping listening...');
    
    await _speechToText.stop();
    
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
    
    _addLog('Listening stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STT Test Screen'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              color: _isInitialized ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isInitialized ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Initialized: $_isInitialized'),
                    Text('Listening: $_isListening'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Locale selector
            if (_isInitialized) ...[
              DropdownButtonFormField<String>(
                value: _availableLocales.any((l) => l.startsWith(_selectedLocale)) 
                    ? _selectedLocale 
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Select Locale',
                  border: OutlineInputBorder(),
                ),
                items: _availableLocales.map((locale) {
                  final localeId = locale.split(' - ')[0];
                  return DropdownMenuItem(
                    value: localeId,
                    child: Text(locale, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLocale = value!;
                  });
                  _addLog('Locale changed to: $_selectedLocale');
                },
              ),
              const SizedBox(height: 16),
            ],

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && !_isListening 
                        ? _startListening 
                        : null,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isListening ? _stopListening : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sound level indicator
            if (_isListening) ...[
              Text('Sound Level: ${_soundLevel.toStringAsFixed(2)}'),
              LinearProgressIndicator(
                value: _soundLevel.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
            ],

            // Recognized text
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recognized Text:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recognizedText.isEmpty ? '(waiting...)' : _recognizedText,
                      style: TextStyle(
                        fontSize: 18,
                        color: _recognizedText.isEmpty 
                            ? Colors.grey 
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logs
            const Text(
              'Debug Logs:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }
}