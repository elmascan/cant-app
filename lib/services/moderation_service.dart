class ModerationResult {
  final bool isAllowed;
  final String cleanedText;
  final String? reason;

  const ModerationResult({
    required this.isAllowed,
    required this.cleanedText,
    this.reason,
  });
}

class ModerationService {
  // ── Block list ─────────────────────────────────────────────────────────────
  // Phrases/words that trigger a full block (personal insults, threats, targeting).
  // Checked as case-insensitive substrings against the full message.
  static const List<String> _blockList = [
    // ── Turkish (Türkçe) ────────────────────────────────────────────────────
    'seni öldürürüm',
    'öldüreceğim',
    'seni geberteyim',
    'geberesin',
    'geberin',
    'ölürsün',
    'öleceksin',
    'defol',
    'it herif',
    'it gibi adam',
    'hayvan gibi',
    'aşağılık',
    'alçak herif',
    'gerizekalı',
    'geri zekalı',
    'geri zekâlı',
    'ahmak',
    'dangalak',
    'orospu çocuğu',
    'oç',
    'amına koyayım',
    'ananı sikim',
    'ananı s',
    'seni s',
    // ── English ─────────────────────────────────────────────────────────────
    'kill yourself',
    'kys',
    'go die',
    'drop dead',
    'you should die',
    'i will kill you',
    "i'll kill you",
    'go kill yourself',
    'go fuck yourself',
    'burn in hell',
    'rot in hell',
    'stupid idiot',
    'dumb idiot',
    'fucking idiot',
    'fucking moron',
    'fucking loser',
    'fucking retard',
    "you're worthless",
    'you are worthless',
    'youre worthless',
    'go to hell',
    'piece of shit human',
    // ── German (Deutsch) ────────────────────────────────────────────────────
    'ich töte dich',
    'ich bringe dich um',
    'du sollst sterben',
    'stirb doch',
    'verpiss dich',
    'fick dich',
    'du bist nichts wert',
    'du bist wertlos',
    'blöder idiot',
    'du vollidiot',
    'halt dein maul',
    'halt die klappe',
    'scheiß idiot',
    'dreckiges schwein',
    'du dreckskerl',
    'du armes würstchen',
  ];

  // ── Censor list ─────────────────────────────────────────────────────────────
  // Words replaced with *** using whole-word matching.
  // List longer / more specific forms before shorter roots so overlapping
  // patterns each get their own independent regex (order is still explicit).
  static const List<String> _censorList = [
    // ── Turkish küfürler ────────────────────────────────────────────────────
    'amına', 'amını', 'amın',
    'orospu', 'orsp',
    'amk', 'amq',
    'siktiret', 'siktir', 'sikik', 'sikim', 'sike', 'sik',
    'yarrağı', 'yarrak',
    'götü', 'göt',
    'piçlik', 'piç',
    'kahpe',
    'ibne',
    'boktan', 'bok',
    'salak',
    'mal',
    // ── English profanity ───────────────────────────────────────────────────
    'motherfucking', 'motherfucker',
    'bullshit', 'dipshit', 'dumbass', 'jackass', 'shithole',
    'assholes', 'asshole',
    'bitching', 'bitches', 'bitch',
    'bastards', 'bastard',
    'fucking', 'fucker', 'fucked', 'fucks', 'fuck',
    'shitty', 'shitting', 'shit',
    'douchebag', 'douche',
    'wanker', 'wank',
    'pissed', 'piss',
    'crappy', 'crap',
    'dammit', 'damn',
    'cocks', 'cock',
    'dicks', 'dick',
    'pussies', 'pussy',
    'cunts', 'cunt',
    'ass',
    // ── German Schimpfwörter ─────────────────────────────────────────────────
    'hurensohn', 'hurenkerl',
    'arschloch', 'arsch',
    'schlampen', 'schlampe',
    'wichser', 'wichsen',
    'miststück',
    'vollidiot', 'dummkopf',
    'scheiße', 'scheisse', 'scheiß',
    'ficken', 'gefickt',
    'verdammte', 'verdammt',
    'trottel', 'depp', 'idiot',
    'mist',
  ];

  // Characters treated as part of a word (ASCII + Turkish + German letters).
  // Used in look-around assertions to implement whole-word matching for
  // languages whose letters fall outside \w (Unicode non-ASCII).
  static const _wc = 'a-zA-Z0-9_ğüşıöçĞÜŞİÖÇäöüÄÖÜß';

  static RegExp _wordPattern(String word) => RegExp(
        '(?<![$_wc])${RegExp.escape(word)}(?![$_wc])',
        caseSensitive: false,
        unicode: true,
      );

  // Compiled once on first access.
  static final List<RegExp> _censorPatterns =
      _censorList.map(_wordPattern).toList();

  static Future<ModerationResult> moderate(String text) async {
    if (text.trim().isEmpty) {
      return ModerationResult(isAllowed: true, cleanedText: text);
    }

    final normalized = text.toLowerCase();

    // 1. Block check — full message blocked if any phrase matches.
    for (final phrase in _blockList) {
      if (normalized.contains(phrase)) {
        return ModerationResult(
          isAllowed: false,
          cleanedText: text,
          reason: 'This content violates community guidelines.',
        );
      }
    }

    // 2. Profanity censor — replace matching words with ***.
    String cleaned = text;
    for (final pattern in _censorPatterns) {
      cleaned = cleaned.replaceAll(pattern, '***');
    }

    return ModerationResult(isAllowed: true, cleanedText: cleaned);
  }
}
