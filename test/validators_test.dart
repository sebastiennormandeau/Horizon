import 'package:flutter_test/flutter_test.dart';
import 'package:horizon/l10n/app_localizations_en.dart';
import 'package:horizon/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('accepte les adresses valides', () {
      expect(validateEmail('seb@example.com'), isNull);
      expect(validateEmail('  prenom.nom+tag@sous.domaine.ca  '), isNull);
    });

    test('rejette les adresses invalides', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('pas-un-courriel'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('a b@c.com'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('accepte un mot de passe conforme', () {
      expect(validatePassword('abcdef12'), isNull);
      expect(validatePassword('Tr3sSolide!'), isNull);
    });

    test('rejette les mots de passe faibles', () {
      expect(validatePassword(null), isNotNull);
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('court1'), isNotNull); // trop court
      expect(validatePassword('quedeslettres'), isNotNull); // pas de chiffre
      expect(validatePassword('12345678'), isNotNull); // pas de lettre
    });
  });

  group('validatePasswordConfirmation', () {
    test('exige une correspondance exacte', () {
      expect(validatePasswordConfirmation('abc12345', 'abc12345'), isNull);
      expect(validatePasswordConfirmation('abc12345', 'autre'), isNotNull);
      expect(validatePasswordConfirmation(null, 'abc12345'), isNotNull);
    });
  });

  group('validateDisplayName', () {
    test('accepte un prénom normal', () {
      expect(validateDisplayName('Seb'), isNull);
      expect(validateDisplayName('  Marie-Ève  '), isNull);
    });

    test('rejette les prénoms trop courts ou trop longs', () {
      expect(validateDisplayName(null), isNotNull);
      expect(validateDisplayName('A'), isNotNull);
      expect(validateDisplayName('X' * 41), isNotNull);
    });
  });

  group('localisation des messages', () {
    test('sans l10n : messages en français (comportement historique)', () {
      expect(validateEmail(''), 'Veuillez entrer votre adresse courriel.');
    });

    test('avec l10n anglais : messages en anglais', () {
      final en = AppLocalizationsEn();
      expect(validateEmail('', en), 'Please enter your email address.');
      expect(validatePassword('court1', en), isNotNull);
      expect(validateJoinCode('ABC', en), en.vJoinCodeInvalid);
    });
  });

  group('validateJoinCode', () {
    test('accepte un code à 6 caractères alphanumériques', () {
      expect(validateJoinCode('ABC234'), isNull);
      expect(validateJoinCode('abc234'), isNull); // mis en majuscules
      expect(validateJoinCode(' XYZ789 '), isNull);
    });

    test('rejette les codes invalides', () {
      expect(validateJoinCode(null), isNotNull);
      expect(validateJoinCode(''), isNotNull);
      expect(validateJoinCode('ABC'), isNotNull);
      expect(validateJoinCode('ABCD-12'), isNotNull);
      expect(validateJoinCode('ABCDEFG'), isNotNull);
    });
  });
}
