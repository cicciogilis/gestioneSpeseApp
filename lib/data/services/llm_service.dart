import 'dart:convert';

import 'package:http/http.dart' as http;

class LLMService {
  static const String hardcodedApiKey = 'REDACTED';
  final String? _apiKey;
  static const _url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  LLMService({String? apiKey}) : _apiKey = apiKey ?? hardcodedApiKey;

  bool get isConfigured => _apiKey != null && _apiKey.isNotEmpty;

  Future<Map<String, dynamic>> parseReceiptText(String ocrText, String categoriesContext) async {
    if (!isConfigured) {
      throw Exception('LLM API key non configurata');
    }
    final prompt = '''
Sei un estrattore dati JSON rigoroso per spese. 
Ho uno scontrino. Testo Scontrino: "$ocrText"
Estrai i seguenti dati e convertili in JSON.
Le categorie valide (devi scegliere una e solo una stringa ESATTA da qui) sono: $categoriesContext. Se nussuna matca bene, usa "Altro".

Usa ESATTAMENTE questo schema JSON senza formattazione aggiuntiva o markup markdown:
{
  "amount": 25.50, (usa il totale, double)
  "date": "YYYY-MM-DD", (trova la data, altrimenti formatta quella di oggi)
  "category": "StringaEsattaDalleCategorieValide",
  "title": "Breve Riassunto (max 4 parole)"
}
''';

    final uri = Uri.parse('$_url?key=$_apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to communicate with LLM: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final textOutput = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final cleanJson = textOutput.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(cleanJson);
  }
}
