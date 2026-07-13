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
    'orospu', 'orospunun', 'orospu cocugu', 'orospu çocuğu',
    'sik', 'sikis', 'sikiş', 'sikisme', 'sikilmek', 'sikeyim', 'siktir',
    'siktirin', 'siktirgit', 'siktir git', 'sikerim', 'sikik',
    'amcik', 'amcık', 'amk', 'amina', 'amına', 'amini', 'amını',
    'got', 'göt', 'gotveren', 'götveren', 'gotu', 'götü',
    'yarrak', 'yarak', 'yarragi',
    'oc', 'oç',
    'pic', 'piç', 'piclik', 'piçlik',
    'kahpe', 'kahpenin',
    'ibne', 'ibnelik',
    'pezevenk',
    'serefesiz', 'şerefsiz',
    'haysiyetsiz',
    'dol', 'döl',
    'fahise', 'fahişe',
    'gerzek', 'gerizekalı', 'geri zekalı',
    'aptal', 'salak', 'mal',
    'pislik', 'alcak', 'alçak', 'asagilik', 'aşağılık',
    'katil', 'terorist', 'terörist',
    'sapik', 'sapık',
    'tecavuz', 'tecavüz',
    'irz', 'ırz',
    'namussuz', 'kaltak', 'surtuk', 'sürtük',
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
    'fuck', 'fucker', 'fucked', 'fucking', 'fucks', 'fck', 'f**k', 'f***',
    'shit', 'shits', 'shitting', 'shitty', 'sh1t', 'sh!t',
    'bitch', 'bitches', 'bitching', 'b1tch',
    'asshole', 'ass hole', 'a**hole',
    'bastard', 'bastards',
    'cunt', 'cunts', 'c**t',
    'cock', 'cocks', 'c0ck',
    'dick', 'dicks', 'dickhead', 'd1ck',
    'pussy', 'pussies',
    'whore', 'whores', 'wh0re',
    'slut', 'sluts',
    'porn', 'porno', 'pornography', 'p0rn',
    'sex', 'sexy', 'sexual', 'sexting', 's3x',
    'nude', 'nudes', 'naked',
    'penis', 'vagina', 'breast', 'breasts',
    'anal', 'anus',
    'suck', 'sucking', 'blowjob', 'bj', 'handjob',
    'masturbat', 'masturbation',
    'erotic', 'erotica',
    'escort',
    'prostitut', 'prostitution',
    'onlyfans', 'only fans',
    'nigger', 'nigga', 'n1gger',
    'faggot', 'fag', 'f4ggot',
    'retard', 'retarded',
    'kill yourself', 'kys',
    'go die',
    'rape', 'rapist', 'raping',
    'molest', 'molester',
    'pedophil', 'pedo',
    'terrorist', 'terrorism',
    'nazi', 'nazis',
    'racist', 'racism',
    'genocide',
    // ── Sexual / Adult content ───────────────────────────────────────────────
    'bdsm', 'fetish', 'bondage', 'dominat', 'submissive',
    'kink', 'kinky', 'orgy', 'threesome', 'swinger',
    'hookup', 'hook up', 'fwb', 'friends with benefits',
    'nsa', 'one night stand', 'sugar daddy', 'sugar baby',
    'cam girl', 'camgirl', 'strip', 'stripper', 'lapdance',
    'adult only', 'adults only', '18+', 'erotic', 'sensual massage',
    'happy ending', 'sex party', 'sex club', 'strip club',
    // ── Drug related ─────────────────────────────────────────────────────────
    'weed', 'cannabis', 'cocaine', 'heroin', 'mdma', 'ecstasy',
    'lsd', 'acid trip', 'drug party', 'high party', 'stoned',
    '420', 'blunt', 'joint', 'bong',
    'weed party', '420 friendly',
    // ── Violence / Hate / Weapons ─────────────────────────────────────────────
    'white power', 'white supremacy', 'white pride', 'ethnic cleansing',
    'lynching', 'go back to your country',
    'heil', 'kkk',
    'jihad', 'allahu akbar', 'incel', 'blackpill',
    'gun for hire', 'armed event', 'bring weapons',
    // ── Alcohol / Party risk ──────────────────────────────────────────────────
    'drinking game', 'beer pong', 'drunk party', 'wasted',
    // ── Scam / Spam ───────────────────────────────────────────────────────────
    'free money', 'earn €', 'earn $', 'make money fast',
    'pyramid scheme', 'network marketing',
    // ── Safety / Privacy ─────────────────────────────────────────────────────
    'meet at my place', 'come to my house', 'secret location',
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
    'scheiße', 'scheisse', 'scheiß',
    'ficken', 'fick', 'gefickt', 'vögeln',
    'arsch', 'arschloch', 'arschgesicht',
    'wichser', 'wichsen', 'wichse',
    'hurensohn', 'hure', 'hurenbalg',
    'schlampe',
    'nutte',
    'fotze',
    'schwanz',
    'titten',
    'muschi',
    'pornografie',
    'vergewaltigung', 'vergewaltiger',
    'terrorist', 'terrorismus',
    'rassist', 'rassismus',
    'nazi', 'nazismus',
    'vollidiot', 'blödmann',
    'depp', 'trottel', 'versager',
    'dreckstück', 'drecksau', 'dreckskerl',
    'mistkerl', 'hurenbock',
    'fick dich', 'verpiss dich',
    'halt die fresse', 'halt die klappe',
    
      // ── SPANISH ──────────────────────────────────────────────────────────
    'puta', 'putas', 'putada', 'putero',
    'coño', 'cono',
    'joder', 'jodete', 'jódete',
    'mierda',
    'cabron', 'cabrón', 'cabrona',
    'pendejo', 'pendeja',
    'maricon', 'maricón',
    'verga',
    'polla',
    'culo', 'culero', 'culona',
    'chinga', 'chingada', 'chingadazo', 'chingarte',
    'hijo de puta', 'hdp',
    'me cago',
    'follar', 'folla',
    'pornografia',
    'prostituta', 'prostitucion',
    'violacion', 'violador',
    'terrorista', 'terrorismo',
    'racista', 'racismo',
    'gilipollas',
    'imbecil', 'imbécil',
    'estupido', 'estúpido',
    'bastardo', 'zorra',
 
    // ── PORTUGUESE ───────────────────────────────────────────────────────
    'puta', 'putas',
    'foda', 'fodase', 'foda-se', 'fodendo',
    'merda',
    'caralho',
    'buceta',
    'cuzao', 'cuzão',
    'viado', 'viadagem',
    'vagabunda',
    'piranha',
    'porra',
    'filho da puta', 'fdp',
    'vai se foder', 'vsf',
    'pornografia',
    'prostituta', 'prostituicao',
    'estupro', 'estuprador',
    'terrorista', 'terrorismo',
    'racista', 'racismo',
    'idiota', 'imbecil', 'burro',
    'otario', 'otário',
    'cretino', 'safado', 'safada',
    'desgraçado', 'desgraçada',
    'arrombado',
 
    // ── FRENCH ───────────────────────────────────────────────────────────
    'putain', 'pute', 'putasse',
    'merde', 'merdique',
    'connard', 'connarde', 'conasse',
    'salope', 'salaud',
    'encule', 'enculé', 'enculer',
    'baiser', 'baise',
    'foutre', 'va te faire foutre',
    'chier', 'chieur',
    'bite', 'bites',
    'chatte',
    'cul', 'culot',
    'nique', 'niquer', 'nique ta mere',
    'fils de pute', 'fdp',
    'pornographie',
    'prostituee', 'prostituée',
    'viol', 'violeur',
    'terroriste', 'terrorisme',
    'raciste', 'racisme',
    'nazi', 'nazisme',
    'idiot', 'idiote', 'imbecile',
    'abruti', 'cretin', 'crétin',
    'ordure', 'connerie',
 
    // ── RUSSIAN (transliterated + cyrillic) ──────────────────────────────
    'blyad', 'blya', 'blyadi', 'blyat',
    'pizda', 'pizdet', 'pizdec',
    'khuy', 'huy', 'hui',
    'ebat', 'ebal', 'ebe', 'yebat',
    'suka', 'suki', 'sukin syn',
    'pizdets', 'pzdc',
    'mudak', 'mudaki', 'mudila',
    'govno', 'govnuk',
    'zhopa', 'zhopu',
    'tvar', 'tvari',
    'urod', 'urodi',
    'pidor', 'pidoras', 'pederast',
    'dolboeb', 'dolboёb',
    'nahuy', 'poshel nahuy',
    'prostitutka',
    'iznasilovanie', 'nasilnik',
    'terrorist', 'terrorizm',
    'rasist', 'rasizm',
    'nazi', 'natsist',
    'durak', 'duraki', 'debil',
    'ublyudok', 'ублюдок',
    'пизда', 'хуй', 'ёб', 'еба', 'сука', 'блядь', 'блять',
    'гавно', 'говно', 'мудак', 'пидор', 'урод', 'дурак',
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
    'damn', 'damned', 'dammit',
    'crap', 'crappy',
    'wtf', 'wth', 'omfg',
    'piss', 'pissed',
    // Turkish mild
    'bok', 'boktan', 'boklu',
    'lanet', 'lanetli',
    // German mild
    'verdammt', 'verflucht', 'mist',
    // Spanish mild
    'maldito', 'maldita', 'diablos',
    // French mild
    'sacre', 'sacré', 'diable',
    // Portuguese mild
    'droga', 'raios', 'caramba',
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
  static final List<RegExp> _blockPatterns =
      _blockList.map(_wordPattern).toList();

  static final List<RegExp> _censorPatterns =
      _censorList.map(_wordPattern).toList();

  // Normalizes text to catch leet-speak / character-substitution evasion.
  // Returns lowercased normalized form; never shown to the user.
  static String _normalize(String text) {
    var t = text.toLowerCase();
    // Collapse consecutive repeated characters: dixxs → dixs
    t = t.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
    // Leet-speak substitutions
    t = t
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('!', 'i')
        .replaceAll('+', 't')
        .replaceAll('x', 'ck');
    return t;
  }

  static Future<ModerationResult> moderate(String text) async {
    if (text.trim().isEmpty) {
      return ModerationResult(isAllowed: true, cleanedText: text);
    }

    final normalized = _normalize(text);

    // 1. Block check — original and normalized (catches leet-speak evasion).
    for (final pattern in _blockPatterns) {
      if (pattern.hasMatch(text) || pattern.hasMatch(normalized)) {
        return ModerationResult(
          isAllowed: false,
          cleanedText: text,
          reason: 'This content violates community guidelines.',
        );
      }
    }

    // 2. Censor-evasion check — if normalized hits censor list but original
    //    doesn't, the user is actively evading; block instead of censor.
    for (final pattern in _censorPatterns) {
      if (pattern.hasMatch(normalized) && !pattern.hasMatch(text)) {
        return ModerationResult(
          isAllowed: false,
          cleanedText: text,
          reason: 'This content violates community guidelines.',
        );
      }
    }

    // 3. Profanity censor — apply to original text, return original wording.
    String cleaned = text;
    for (final pattern in _censorPatterns) {
      cleaned = cleaned.replaceAll(pattern, '***');
    }

    return ModerationResult(isAllowed: true, cleanedText: cleaned);
  }
}
