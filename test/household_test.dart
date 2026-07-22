import 'package:flutter_test/flutter_test.dart';
import 'package:horizon/l10n/app_localizations_en.dart';
import 'package:horizon/l10n/app_localizations_fr.dart';
import 'package:horizon/models/household.dart';

/// Construit un foyer de test. `mode` : 'solo' ou 'couple'.
Household buildHousehold({
  String mode = 'couple',
  String? userAId = 'uidA',
  String? userBId,
  double soloA = 0,
  double common = 0,
  double soloB = 0,
  double alertThreshold = 100,
}) {
  return Household(
    id: 'h1',
    userAId: userAId,
    userBId: userBId,
    userAName: userAId == null ? null : 'Seb',
    userBName: userBId == null ? null : 'Marie',
    safeToSpendCommon: common,
    safeToSpendSoloA: soloA,
    safeToSpendSoloB: soloB,
    internalDebtBalance: 0,
    splitRatioUserA: 50,
    splitRatioUserB: 50,
    joinCode: 'ABC234',
    subscriptionTier: 'free',
    alertThreshold: alertThreshold,
    householdMode: mode,
  );
}

void main() {
  group('Household.isSolo', () {
    test('vrai quand le mode est solo et qu\'aucun partenaire n\'a rejoint', () {
      expect(buildHousehold(mode: 'solo').isSolo, isTrue);
    });

    test('faux en mode couple', () {
      expect(buildHousehold(mode: 'couple').isSolo, isFalse);
    });

    test('faux dès qu\'un partenaire a rejoint, même si le mode dit solo', () {
      // Filet de sécurité : le serveur bascule le mode en « couple » quand
      // quelqu'un rejoint, mais l'UI ne doit pas masquer le partenaire si
      // les deux champs se contredisent.
      final h = buildHousehold(mode: 'solo', userBId: 'uidB');
      expect(h.isSolo, isFalse);
    });

    test('vrai quand c\'est le siège A qui a été libéré (séparation)', () {
      // Quand le membre A quitte le foyer, c'est B qui reste seul. Tester
      // uniquement userBId aurait laissé l'app en affichage « couple ».
      final h = buildHousehold(mode: 'solo', userAId: null, userBId: 'uidB');
      expect(h.isSolo, isTrue);
    });

    test('les foyers sans le champ mode sont traités comme couple', () {
      // Rétrocompatibilité : householdMode vaut 'couple' par défaut dans
      // fromSnapshot pour les foyers créés avant l'ajout de l'option.
      expect(buildHousehold().isSolo, isFalse);
    });
  });

  group('Household.bucketLabel', () {
    test('en couple : Solo A/B nommés, Commun traduit', () {
      final h = buildHousehold(userBId: 'uidB');
      final fr = AppLocalizationsFr();
      expect(h.bucketLabel('Solo_A', fr), 'Solo Seb');
      expect(h.bucketLabel('Solo_B', fr), 'Solo Marie');
      expect(h.bucketLabel('Common', fr), 'Commun');
      expect(h.bucketLabel('', fr), 'À trier');
    });

    test('en solo : Perso et Essentiel remplacent Solo A et Commun', () {
      final h = buildHousehold(mode: 'solo');
      final fr = AppLocalizationsFr();
      expect(h.bucketLabel('Solo_A', fr), 'Perso');
      expect(h.bucketLabel('Common', fr), 'Essentiel');
    });

    test('en solo, en anglais', () {
      final h = buildHousehold(mode: 'solo');
      final en = AppLocalizationsEn();
      expect(h.bucketLabel('Solo_A', en), 'Personal');
      expect(h.bucketLabel('Common', en), 'Essentials');
    });
  });

  group('Household.visibleBuckets et mySoloBalance', () {
    test('en couple : les trois cagnottes, dans l\'ordre d\'affichage', () {
      final h = buildHousehold(userBId: 'uidB');
      expect(h.visibleBuckets('uidA'), ['Solo_A', 'Common', 'Solo_B']);
    });

    test('en solo sur le siège A : sa cagnotte et le commun', () {
      final h = buildHousehold(mode: 'solo', soloA: 40);
      expect(h.visibleBuckets('uidA'), ['Solo_A', 'Common']);
      expect(h.mySoloBalance('uidA'), 40);
    });

    test('en solo sur le siège B : c\'est Solo_B qui est visible', () {
      // Cas issu d'une séparation où le membre A est parti. Afficher Solo_A
      // montrerait une cagnotte vide à la place de la vraie.
      final h = buildHousehold(
        mode: 'solo',
        userAId: null,
        userBId: 'uidB',
        soloB: 75,
      );
      expect(h.visibleBuckets('uidB'), ['Solo_B', 'Common']);
      expect(h.mySoloBalance('uidB'), 75);
    });
  });

  group('Household.worstAlertLevel', () {
    test('en solo, la cagnotte du siège vide est ignorée', () {
      // Solo_B reste à zéro donc « sous le seuil » : l'inclure afficherait
      // une alerte orange permanente et trompeuse.
      final h = buildHousehold(mode: 'solo', soloA: 500, common: 500);
      expect(h.worstAlertLevel('uidA'), 0);
    });

    test('en couple, une cagnotte vide déclenche bien l\'alerte', () {
      final h = buildHousehold(userBId: 'uidB', soloA: 500, common: 500);
      expect(h.worstAlertLevel('uidA'), 1);
    });

    test('le négatif prime sur le simple dépassement de seuil', () {
      final h = buildHousehold(
        userBId: 'uidB',
        soloA: 10,
        common: 500,
        soloB: -5,
      );
      expect(h.worstAlertLevel('uidA'), 2);
    });
  });

  group('Household.alertLevel', () {
    test('0 = ok, 1 = sous le seuil, 2 = négatif', () {
      final h = buildHousehold(alertThreshold: 100);
      expect(h.alertLevel(250), 0);
      expect(h.alertLevel(50), 1);
      expect(h.alertLevel(-10), 2);
    });

    test('une cagnotte vide compte comme « sous le seuil »', () {
      // C'est pourquoi l'accueil doit exclure Solo B du calcul en solo :
      // sinon une alerte orange s'afficherait en permanence.
      expect(buildHousehold().alertLevel(0), 1);
    });
  });
}
