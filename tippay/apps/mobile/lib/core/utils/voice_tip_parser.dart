/// Parses a voice-transcribed string into a tip amount in rupees.
///
/// Supports:
///   - English words: "fifty", "hundred", "two hundred", "five hundred"
///   - Hindi words: "pachaas", "ek sau", "do sau", "paanch sau", "hazaar"
///   - Mixed phrases: "₹200", "200 rupees", "100 rs", "do sau rupay"
///   - Plain digits: "150"
///
/// Returns null if no recognisable amount is found, or if the result is
/// outside [minRupees]..[maxRupees].
class VoiceTipParser {
  static const int _minRupees = 10;
  static const int _maxRupees = 10000;

  // ── Hindi number word tables ──────────────────────────────────────────────

  static const Map<String, int> _hindiUnits = {
    'ek': 1,
    'do': 2,
    'teen': 3,
    'char': 4,
    'paanch': 5,
    'chhe': 6,
    'saat': 7,
    'aath': 8,
    'nau': 9,
  };

  static const Map<String, int> _hindiTens = {
    'das': 10,
    'bees': 20,
    'tees': 30,
    'chalis': 40,
    'pachaas': 50,
    'saath': 60,
    'sattar': 70,
    'assi': 80,
    'nabbe': 90,
  };

  static const Map<String, int> _hindiCompound = {
    // Teens
    'gyarah': 11,
    'barah': 12,
    'terah': 13,
    'chaudah': 14,
    'pandrah': 15,
    'solah': 16,
    'satrah': 17,
    'atharah': 18,
    'unnis': 19,
    // 20s
    'ikkis': 21,
    'bais': 22,
    'teis': 23,
    'chaubis': 24,
    'pachis': 25,
    'chhabbis': 26,
    'sattaees': 27,
    'athaees': 28,
    'untees': 29,
    // 30s
    'ikattis': 31,
    'battis': 32,
    'taintis': 33,
    'chauntis': 34,
    'paintis': 35,
    'chhattis': 36,
    'sainttis': 37,
    'artis': 38,
    'unchtalis': 39,
    // 40s
    'iktalis': 41,
    'bayalis': 42,
    'tentalis': 43,
    'chavalis': 44,
    'pentalis': 45,
    'chhiyalis': 46,
    'saintalis': 47,
    'artalis': 48,
    'unchnas': 49,
    // 50s
    'ikavan': 51,
    'baavan': 52,
    'tirpan': 53,
    'chauvan': 54,
    'pachpan': 55,
    'chhappan': 56,
    'sattawan': 57,
    'atthawan': 58,
    'unsath': 59,
    // round
    'saath': 60,
    'ikasath': 61,
    'basath': 62,
    'tirasath': 63,
    'chaunsath': 64,
    'pensath': 65,
    'chhiyasath': 66,
    'sarsath': 67,
    'arsath': 68,
    'unattar': 69,
    'sattar': 70,
    'ikattar': 71,
    'bahattar': 72,
    'tihattar': 73,
    'chauhattar': 74,
    'pachhattar': 75,
    'chhiyattar': 76,
    'satattar': 77,
    'athattar': 78,
    'unaasi': 79,
    'assi': 80,
    'ikyaasi': 81,
    'byaasi': 82,
    'tiraasi': 83,
    'chauraasi': 84,
    'pachaasi': 85,
    'chhiyaasi': 86,
    'sataasi': 87,
    'athaasi': 88,
    'nabbe': 90,
    'ikyaanve': 91,
    'baanve': 92,
    'tiraanve': 93,
    'chauraanve': 94,
    'pachaanve': 95,
    'chhiyaanve': 96,
    'sattaanve': 97,
    'atthaanve': 98,
    'ninyanve': 99,
  };

  // ── English number word tables ────────────────────────────────────────────

  static const Map<String, int> _englishOnes = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  static const Map<String, int> _englishMultipliers = {
    'hundred': 100,
    'thousand': 1000,
    'hazaar': 1000, // Hindi hybrid
    'hazar': 1000,
  };

  // ── Public API ────────────────────────────────────────────────────────────

  /// Parse [transcript] and return the tip amount in rupees, or null.
  static int? parse(String transcript) {
    final cleaned = _clean(transcript);

    // 1. Try to extract a plain integer or decimal
    final digitAmount = _extractDigitAmount(cleaned);
    if (digitAmount != null) return _validate(digitAmount);

    // 2. Try to parse Hindi words
    final hindiAmount = _parseHindi(cleaned);
    if (hindiAmount != null) return _validate(hindiAmount);

    // 3. Try to parse English words
    final englishAmount = _parseEnglish(cleaned);
    if (englishAmount != null) return _validate(englishAmount);

    return null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static String _clean(String input) {
    return input
        .toLowerCase()
        .replaceAll('₹', ' ')
        .replaceAll(',', '')
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'\b(rupees?|rupay|rs\.?|inr|tip|send|pay|paisa)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int? _extractDigitAmount(String text) {
    // Look for an integer amount in the string
    final match = RegExp(r'\b(\d{1,5})\b').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static int? _parseHindi(String text) {
    // Remove noise words
    final cleaned = text
        .replaceAll(RegExp(r'\b(ka|ki|ke|aur|mujhe|dena|bhejo)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = cleaned.split(' ');
    int total = 0;
    int current = 0;
    bool foundAny = false;

    // "ek sau pachaas" = 1 × 100 + 50 = 150
    // "do hazaar" = 2 × 1000 = 2000
    for (int i = 0; i < words.length; i++) {
      final word = words[i];

      if (_hindiCompound.containsKey(word)) {
        current += _hindiCompound[word]!;
        foundAny = true;
      } else if (_hindiUnits.containsKey(word)) {
        current += _hindiUnits[word]!;
        foundAny = true;
      } else if (_hindiTens.containsKey(word)) {
        current += _hindiTens[word]!;
        foundAny = true;
      } else if (word == 'sau') {
        // "sau" alone = 100; with preceding value = value × 100
        if (current == 0) {
          current = 100;
        } else {
          current *= 100;
        }
        foundAny = true;
      } else if (word == 'hazaar' || word == 'hazar') {
        if (current == 0) current = 1;
        current *= 1000;
        total += current;
        current = 0;
        foundAny = true;
      }
    }

    total += current;
    return (foundAny && total > 0) ? total : null;
  }

  static int? _parseEnglish(String text) {
    final words = text.split(' ');
    int total = 0;
    int current = 0;
    bool foundAny = false;

    for (final word in words) {
      if (_englishOnes.containsKey(word)) {
        current += _englishOnes[word]!;
        foundAny = true;
      } else if (_englishMultipliers.containsKey(word)) {
        final mult = _englishMultipliers[word]!;
        if (mult >= 1000) {
          // "thousand" resets current accumulator into total
          if (current == 0) current = 1;
          total += current * mult;
          current = 0;
        } else {
          // "hundred" multiplies current, or defaults to 1
          if (current == 0) current = 1;
          current *= mult;
        }
        foundAny = true;
      }
    }

    total += current;
    return (foundAny && total > 0) ? total : null;
  }

  static int? _validate(int amount) {
    if (amount < _minRupees || amount > _maxRupees) return null;
    return amount;
  }
}
