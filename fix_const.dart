import 'dart:io';

void main() {
  final analyzeFile = File('analyze.txt');
  if (!analyzeFile.existsSync()) return;

  final lines = analyzeFile.readAsLinesSync();
  final errors = <String, List<int>>{};

  for (final line in lines) {
    if (line.contains('invalid_constant') || line.contains('non_constant_default_value')) {
      final parts = line.split(' - ');
      if (parts.length >= 2) {
        final loc = parts[1].split(':');
        if (loc.length >= 2) {
          final file = loc[0].trim();
          final lineNum = int.tryParse(loc[1]);
          if (lineNum != null) {
            errors.putIfAbsent(file, () => []).add(lineNum);
          }
        }
      }
    }
  }

  for (final fileEntry in errors.entries) {
    final file = File(fileEntry.key);
    if (!file.existsSync()) continue;

    final fileLines = file.readAsLinesSync();
    final lineNums = fileEntry.value.toSet().toList()..sort((a, b) => b.compareTo(a));
    
    for (final lineNum in lineNums) {
      if (lineNum >= 1 && lineNum <= fileLines.length) {
        // Search current line, then up to 5 lines back
        bool found = false;
        for (int i = 0; i < 7; i++) {
          final idx = lineNum - 1 - i;
          if (idx < 0) break;
          
          if (fileLines[idx].contains(RegExp(r'\bconst\s+'))) {
            fileLines[idx] = fileLines[idx].replaceAll(RegExp(r'\bconst\s+'), '');
            found = true;
            break;
          }
        }
        if (!found) {
           print('Could not find const for ${file.path} at line $lineNum');
        }
      }
    }
    file.writeAsStringSync(fileLines.join('\n'));
  }

  print('Fixed another ${errors.length} files structurally.');
}
