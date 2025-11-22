import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'stt_test_screen.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  String _selectedLanguage = 'id_ID';

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppStateProvider>();
    _apiKeyController = TextEditingController(
      text: appState.geminiApiKey ?? '',
    );
    _selectedLanguage = appState.sttLanguage;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    if (_formKey.currentState!.validate()) {
      final appState = context.read<AppStateProvider>();
      await appState.saveGeminiApiKey(_apiKeyController.text.trim());
      await appState.saveSttLanguage(_selectedLanguage);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan berhasil disimpan')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan API'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Gemini API Key',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dapatkan API key dari Google AI Studio:\nhttps://aistudio.google.com/app/apikey',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Masukkan Gemini API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'API Key tidak boleh kosong';
                  }
                  return null;
                },
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Bahasa Speech Recognition',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'Bahasa untuk Voice Command',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'id_ID',
                    child: Text('🇮🇩 Bahasa Indonesia'),
                  ),
                  DropdownMenuItem(
                    value: 'en_US',
                    child: Text('🇺🇸 English (US)'),
                  ),
                  DropdownMenuItem(
                    value: 'en_GB',
                    child: Text('🇬🇧 English (UK)'),
                  ),
                  DropdownMenuItem(
                    value: 'ms_MY',
                    child: Text('🇲🇾 Bahasa Melayu'),
                  ),
                  DropdownMenuItem(
                    value: 'zh_CN',
                    child: Text('🇨🇳 中文 (简体)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveApiKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Informasi:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Speech-to-Text: Menggunakan Speech Recognition bawaan Android/iOS',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                '• Text-to-Speech: Menggunakan TTS bawaan Android/iOS',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                '• AI: Google Gemini Vision',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}