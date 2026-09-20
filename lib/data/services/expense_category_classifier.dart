import '../../domain/models/scanned_receipt.dart';
import '../../domain/models/transaction.dart';

class ExpenseCategoryClassifier {
  static const Map<String, List<String>> _categoryKeywords = {
    'cat_alimentari': ['supermercato', 'conad', 'esselunga', 'coop', 'lidl', 'eurospin', 'md', 'famila', 'carrefour', 'auchans', 'grocery', 'food', 'alimentari', 'market', 'pane', 'latte', 'pasta', 'frutta', 'verdura', 'carne', 'pesce'],
    'cat_trasporti': ['benzina', 'carburante', 'eni', 'q8', 'ip', 'tamoil', 'autostrada', 'parcheggio', 'taxi', 'uber', 'bus', 'treno', 'fuel', 'gas', 'diesel', 'metano', 'gpl', 'autogrill', 'casello'],
    'cat_ristoranti': ['ristorante', 'pizzeria', 'bar', 'caffe', 'caffè', 'mcdonald', 'burger', 'kfc', 'subway', 'restaurant', 'cafe', 'pub', 'trattoria', 'osteria', 'gelateria', 'pasticceria', 'colazione', 'pranzo', 'cena', 'aperitivo'],
    'cat_salute': ['farmacia', 'pharmacy', 'medico', 'dentista', 'ospedale', 'analisi', 'ricetta', 'medicine', 'farmaco', 'parafarmacia', 'sanitaria', 'visita', 'esame', 'laboratorio'],
    'cat_intrattenimento': ['cinema', 'teatro', 'netflix', 'spotify', 'disney', 'prime', 'videogame', 'steam', 'playstation', 'xbox', 'nintendo', 'gioco', 'film', 'serie', 'streaming', 'abbonamento', 'ticket', 'biglietto'],
    'cat_abbigliamento': ['negozio', 'abbigliamento', 'vestiti', 'scarpe', 'zara', 'h&m', 'uniqlo', 'decathlon', 'clothing', 'moda', 'jeans', 'maglietta', 'pantalone', 'giacca', 'cappotto', 'intimo', 'calze'],
    'cat_casa': ['ikea', 'leroy', 'brico', 'casa', 'arredamento', 'eletrodomestici', 'mediaworld', 'expert', 'home', 'ferramenta', 'fai da te', 'giardino', 'mobili', 'tende', 'tappeto', 'lampada', 'vernice', 'attrezzi'],
    'cat_utenze': ['luce', 'gas', 'acqua', 'elettricita', 'elettricità', 'bolletta', 'utenza', 'condominio', 'telefono', 'internet', 'fibra', 'adsl', 'wifi', 'telecom', 'tim', 'vodafone', 'wind', 'fastweb', 'tiscali'],
    'cat_sport': ['palestra', 'gym', 'fitness', 'piscina', 'calcio', 'tennis', 'padell', 'running', 'corsa', 'bici', 'bicicletta', 'sport', 'allenamento', 'personal trainer', 'abbonamento sportivo'],
    'cat_abbonamenti': ['abbonamento', 'subscription', 'mensile', 'annuale', 'rinnovo', 'canone', 'quota', 'iscrizione', 'tessera'],
    'cat_cura': ['parrucchiere', 'barbiere', 'estetista', 'centro benessere', 'spa', 'massaggio', 'trattamento', 'bellezza', 'unghie', 'depilazione', 'ceretta', 'taglio', 'piega', 'colore'],
    'cat_istruzione': ['scuola', 'universita', 'università', 'corso', 'master', 'laurea', 'esame', 'libro', 'testo', 'dispensa', 'lezioni', 'tutor', 'ripetizioni', 'formazione'],
    'cat_viaggi': ['hotel', 'albergo', 'ostello', 'booking', 'airbnb', 'volo', 'aereo', 'treno', 'nave', 'traghetto', 'noleggio', 'autonoleggio', 'valigia', 'bagaglio', 'passaporto', 'visto', 'assicurazione viaggio'],
    'cat_animali': ['veterinario', 'animale', 'cane', 'gatto', 'pet', 'crocchette', 'cibo animale', 'toelettatura', 'visita veterinaria', 'vaccino', 'farmaco animale'],
    'cat_tasse': ['tasse', 'imposta', 'bollo', 'multa', 'verbale', 'burocrazia', 'certificato', 'visura', 'atto', 'notaio', 'avvocato', 'commercialista', 'caf', 'patronato', 'inps', 'inail', 'agenzia entrate'],
    'cat_regali': ['regalo', 'gift', 'compleanno', 'natale', 'pasqua', 'onnastico', 'laurea', 'matrimonio', 'battesimo', 'comunione', 'cresima', 'fidanzamento', 'anniversario'],
    'cat_rimborso': ['rimborso', 'restituzione', 'resi', 'recesso', 'garanzia', 'difettoso', 'non conforme', 'storno', 'accredito'],
    'cat_stipendio': ['stipendio', 'salario', 'paga', 'busta paga', 'retribuzione', 'compenso', 'onoraio', 'fees', 'freelance', 'consulenza', 'professionista', 'partita iva'],
  };

  String classify({
    required String? merchantName,
    required List<ScannedReceiptItem> items,
    String? description,
  }) {
    final allText = _buildSearchText(merchantName, items, description);
    final lowerText = allText.toLowerCase();

    // Score each category
    final scores = <String, int>{};
    
    for (final entry in _categoryKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword.toLowerCase())) {
          score += 1;
        }
      }
      if (score > 0) {
        scores[entry.key] = score;
      }
    }

    if (scores.isNotEmpty) {
      // Return category with highest score
      return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    // Default to 'Altro'
    return 'cat_altro';
  }

  String _buildSearchText(String? merchantName, List<ScannedReceiptItem> items, String? description) {
    final parts = <String>[];
    if (merchantName != null) parts.add(merchantName);
    if (description != null) parts.add(description);
    for (final item in items) {
      parts.add(item.description);
    }
    return parts.join(' ');
  }

  /// Classifica anche per tipo entrata/uscita basandosi sulla categoria
  static TransactionType classifyTransactionType(String categoryId) {
    final incomeCategories = {
      'cat_stipendio',
      'cat_regalo',
      'cat_rimborso',
    };
    return incomeCategories.contains(categoryId) ? TransactionType.income : TransactionType.expense;
  }
}