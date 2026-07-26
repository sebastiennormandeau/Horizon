import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/household_loader.dart';

/// Gestion des règles de classement automatique par marchand (créées depuis la
/// file de tri). Liste et suppression ; l'ajout se fait au fil du tri.
class SortRulesScreen extends StatelessWidget {
  const SortRulesScreen({super.key});

  Future<void> _delete(BuildContext context, String merchant) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteSortRule')
          .call({'merchant': merchant});
      messenger.showSnackBar(SnackBar(content: Text(l10n.ruleDeleted)));
    } catch (e) {
      debugPrint('Erreur deleteSortRule: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.householdActionError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sortRulesTitle)),
      body: HouseholdLoader(
        builder: (context, household, uid) {
          final rules = household.sortRules.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.sortRulesEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: context.borderColor),
            itemBuilder: (context, i) {
              final e = rules[i];
              return ListTile(
                title: Text(e.key),
                subtitle: Text(household.bucketLabel(e.value, l10n)),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: context.palette.danger),
                  tooltip: l10n.ruleDeleted,
                  onPressed: () => _delete(context, e.key),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
