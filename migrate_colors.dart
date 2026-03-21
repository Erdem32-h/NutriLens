import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('Run this script from the project root.');
    return;
  }

  int modifiedFiles = 0;

  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart') && !file.path.endsWith('app_colors.dart') && !file.path.endsWith('app_theme.dart') && !file.path.endsWith('app_typography.dart')) {
      final oldContent = file.readAsStringSync();
      var content = oldContent;

      // Replace AppColors.* with context.colors.*
      // We match AppColors.variableName and ensure it's not preceded by import
      content = content.replaceAllMapped(RegExp(r'\bAppColors\.([a-zA-Z0-9_]+)'), (match) {
        return 'context.colors.${match.group(1)}';
      });

      if (content != oldContent) {
        // Ensure app_colors.dart is imported
        if (!content.contains('core/theme/app_colors.dart')) {
            content = "import 'package:nutrilens/core/theme/app_colors.dart';\n" + content;
        }

        file.writeAsStringSync(content);
        modifiedFiles++;
      }
    }
  }

  print('Modified $modifiedFiles files.');
}
