import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

/// Affiche un document légal (markdown embarqué dans les assets) dans une
/// feuille déroulante. Utilisé à l'inscription et dans les réglages.
///
/// `baseName` : 'terms' ou 'privacy'. En anglais, la traduction de courtoisie
/// `<baseName>_en.md` est affichée (la version française prévaut légalement).
Future<void> showLegalDocument(
  BuildContext context,
  String baseName,
  String title,
) async {
  final lang = Localizations.localeOf(context).languageCode;
  final filename = lang == 'en' ? '${baseName}_en.md' : '$baseName.md';
  final text = await rootBundle.loadString('assets/legal/$filename');
  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (_, controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Markdown(
                  data: text,
                  controller: controller,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
