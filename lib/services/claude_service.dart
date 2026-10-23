import 'dart:convert';
import 'package:http/http.dart' as http;

class ClaudeService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-6';
  final String apiKey;

  ClaudeService({required this.apiKey});

  /// Explain a single file
  Future<String> explainFile(String filename, String content) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content':
                'Explain this file concisely, as an experienced engineer in its language would. Focus on what it does, its main interfaces (ports, functions or classes), and any key design decisions.\n\nFile: $filename\n\n$content'
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] as String;
    }
    throw Exception('Claude API error: ${response.statusCode}');
  }
}
