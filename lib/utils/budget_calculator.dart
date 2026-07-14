class BudgetCalculator {
  /// Calcule les mois "magiques" (ceux ayant plus de 2 ou 4 paies selon la fréquence)
  /// Retourne une liste des index de mois (1 = Janvier, 12 = Décembre)
  static List<int> calculateMagicMonths(String payFrequency, DateTime nextPayDate) {
    if (payFrequency == 'Mensuel') return [];

    List<int> magicMonths = [];
    DateTime currentDate = nextPayDate;
    
    int currentYear = nextPayDate.year;
    
    // Remonter à la première paie de l'année courante
    while (currentDate.year >= currentYear) {
      DateTime previous = _subtractPayPeriod(currentDate, payFrequency);
      if (previous.year < currentYear) break;
      currentDate = previous;
    }

    // Compter les occurrences par mois pour l'année courante
    Map<int, int> paysPerMonth = {};
    while (currentDate.year == currentYear) {
      paysPerMonth[currentDate.month] = (paysPerMonth[currentDate.month] ?? 0) + 1;
      currentDate = _addPayPeriod(currentDate, payFrequency);
    }

    // Un mois magique a >2 paies pour Bi-hebdo, ou >4 pour Hebdo
    paysPerMonth.forEach((month, count) {
      if (payFrequency == 'Hebdomadaire' && count >= 5) {
        magicMonths.add(month);
      } else if (payFrequency == 'Bi-hebdomadaire' && count >= 3) {
        magicMonths.add(month);
      }
    });

    return magicMonths;
  }

  static DateTime _subtractPayPeriod(DateTime date, String frequency) {
    if (frequency == 'Hebdomadaire') return date.subtract(const Duration(days: 7));
    if (frequency == 'Bi-hebdomadaire') return date.subtract(const Duration(days: 14));
    return date; 
  }

  static DateTime _addPayPeriod(DateTime date, String frequency) {
    if (frequency == 'Hebdomadaire') return date.add(const Duration(days: 7));
    if (frequency == 'Bi-hebdomadaire') return date.add(const Duration(days: 14));
    return date;
  }
}
