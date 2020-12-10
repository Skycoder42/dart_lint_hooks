import 'dart:io';

import 'program_runner.dart';
import 'task_exception.dart';

class Format {
  final ProgramRunner runner;

  const Format(this.runner);

  Future<bool> call(File file) async {
    final exitCode = await runner.run(
      'dart',
      [
        'format',
        '--fix',
        '--set-exit-if-changed',
        file.path,
      ],
    );
    switch (exitCode) {
      case 0:
        return false;
      case 1:
        return true;
      default:
        throw TaskException('dartfmt failed to format the file', file);
    }
  }
}
