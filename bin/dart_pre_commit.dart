// ignore_for_file: lines_longer_than_80_chars
/// Documentation of the dart_pre_commit binary
///
/// You can run this script via `dart pub run dart_pre_commit [options]`. It
/// will create an instance of [Hooks] and invoke it to perform the pre commit
/// hooks. Check the documentation of the [Hooks] class for more details on what
/// the sepecific hooks do.
///
/// In order to be able to configure how the hooks should be run, you can
/// specify command line arguments to the script. The following tables list all
/// available options, organized into the same groups as shown when running
/// `dart pub run dart_pre_commit --help`.
///
/// ### Task selection
///  Option                             | Default    | Description
/// ------------------------------------|------------|-------------
/// `-i`, `--[no-]fix-imports`          | on         | Format and sort imports of staged files.
/// `-t`, `--[no-]library-imports`      | off        | Check if top level libraries are wrongfully imported in src and test files.
/// `-f`, `--[no-]format`               | on         | Format staged files with dart format.
/// `-a`, `--[no-]analyze`              | on         | Run dart analyze to find issue for the staged files.
/// `-x`, `--[no-]library-exports`      | off        | Check if all declared src libraries are exported from top level libraries.
/// `-o`, `--outdated=<level>`          | `disabled` | Enables the outdated packages check. You can choose one of the levels described below to require certain package updates. If they are not met, the hook will fail. No matter what level, as long as it is not disabled - which will completly disable the hook - it will still print available package updates without failing. Can be any of [OutdatedLevel].
/// `-n`, `--[no-]nullsafe`             | off        | Activates null-safety checks. Will check all installed dependencies for null-safety updates and fail if any can be installed without problems.
/// `-p`, `--[no-]check-pull-up`        | off        | Check if direct dependencies in the pubspec.lock have higher versions then specified in pubspec.yaml and warn if that's the case.
/// `-c`, `--[no-]continue-on-rejected` | off        | Continue checks even if a task rejects a certain file. The whole hook will still exit with rejected, but only after all files have been processed.
///
/// ### Other
///  Option                           | Default             | Description
/// ----------------------------------|---------------------|-------------
/// `-d`, `--directory=<dir>`         | `Directory.current` | Set the directory to run this command in. By default, it will run in the current working directory.
/// `-e`, `--[no-]detailed-exit-code` | off                 | Instead of simply 0/1 as exit code for 'commit ok' or 'commit needs user intervention', output exit codes according to the full hook result (See [HookResult]).
/// `-l`, `--log-level=<level>`       | `info`              | Specify the logging level for task logs. This only affects log details of tasks, not the status update message. Can be any of [LogLevel].
/// `--[no-]ansi`                     | auto-detected       | When enabled, a rich, ANSI-backed output is used. If disabled, a simple logger is used, which is optimized for logging to files. The mode is auto-detected, but might not detect all terminals correctly. In this case, you can use this option to set it exlicitly.
/// `-v`, `--version`                 | -                   | Show the version of the dart_pre_commit package.
/// `-h`, `--help`                    | -                   | Show this help.
library dart_pre_commit_bin;

import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:riverpod/riverpod.dart';

const disabledOutdatedLevel = 'disabled';

/// @nodoc
void main(List<String> args) {
  _run(args).then((c) => exitCode = c);
}

Future<int> _run(List<String> args) async {
  final di = ProviderContainer();
  final parser = ArgParser()
    ..addSeparator('Task selection:')
    ..addFlag(
      'fix-imports',
      abbr: 'i',
      defaultsTo: true,
      help: 'Format and sort imports of staged files.',
    )
    ..addFlag(
      'library-imports',
      abbr: 't',
      help: 'Check if top level libraries are wrongfully imported in '
          'src and test files.',
    )
    ..addFlag(
      'format',
      abbr: 'f',
      defaultsTo: true,
      help: 'Format staged files with dart format.',
    )
    ..addFlag(
      'analyze',
      abbr: 'a',
      defaultsTo: true,
      help: 'Run dart analyze to find issue for the staged files.',
    )
    ..addFlag(
      'library-exports',
      abbr: 'x',
      help: 'Check if all declared src libraries are exported from top level '
          'libraries.',
    )
    ..addOption(
      'outdated',
      abbr: 'o',
      allowed: OutdatedLevel.values
          .map((e) => e.name)
          .followedBy([disabledOutdatedLevel]),
      defaultsTo: disabledOutdatedLevel,
      help: 'Enables the outdated packages check. You can choose one of the '
          'levels described below to require certain package updates. If they '
          'are not met, the hook will fail. No matter what level, as long as '
          'it is not disabled - which will completly disable the hook - it '
          'will still print available package updates without failing.',
      valueHelp: 'level',
      allowedHelp: {
        disabledOutdatedLevel: 'Do not run the hook.',
        OutdatedLevel.none.name:
            'Only print recommended updates, do not require any.',
        OutdatedLevel.major.name:
            'Only require major updates, e.g. 1.X.Y-Z to 2.0.0-0.',
        OutdatedLevel.minor.name:
            'Only require minor updates, e.g. 1.0.X-Y to 1.1.0-0.',
        OutdatedLevel.patch.name:
            'Only require patch updates, e.g. 1.0.0-X to 1.0.1-0.',
        OutdatedLevel.any.name: 'Require all updates that are available.',
      },
    )
    ..addFlag(
      'nullsafe',
      abbr: 'n',
      help: 'Activates null-safety checks. Will check all installed '
          'dependencies for null-safety updates and fail if any can be '
          'installed without problems.',
    )
    ..addFlag(
      'check-pull-up',
      abbr: 'p',
      help: 'Check if direct dependencies in the pubspec.lock have '
          'higher versions then specified in pubspec.yaml and warn if '
          'that´s the case.',
    )
    ..addFlag(
      'continue-on-rejected',
      abbr: 'c',
      help: 'Continue checks even if a task rejects a certain file. The whole '
          'hook will still exit with rejected, but only after all files have '
          'been processed.',
    )
    ..addSeparator('Other:')
    ..addOption(
      'directory',
      abbr: 'd',
      help: 'Set the directory to run this command in. By default, it will run '
          'in the current working directory.',
      valueHelp: 'dir',
    )
    ..addFlag(
      'detailed-exit-code',
      abbr: 'e',
      help: 'Instead of simply 0/1 as exit code for "commit ok" or "commit '
          'needs user intervention", output exit codes according to the full '
          'hook result (See HookResult).',
    )
    ..addOption(
      'log-level',
      abbr: 'l',
      allowed: LogLevel.values.map((e) => e.name),
      defaultsTo: LogLevel.info.name,
      help: 'Specify the logging level for task logs. This only affects log '
          'details of tasks, not the status update message. The levels are:',
      valueHelp: 'level',
      allowedHelp: {
        LogLevel.debug.name: 'Print all messages.',
        LogLevel.info.name: 'Print informational messages.',
        LogLevel.warn.name: 'Print warnings and errors only.',
        LogLevel.error.name: 'Print errors only.',
        LogLevel.except.name: 'Print exceptions only.',
        LogLevel.nothing.name: 'Print nothing at all.',
      },
    )
    ..addFlag(
      'ansi',
      defaultsTo: HooksProviderInternal.ansiSupported,
      help: 'When enabled, a rich, ANSI-backed output is used. If disabled, '
          'a simple logger is used, which is optimized for logging to files. '
          'The mode is auto-detected, but might not detect all terminals '
          'correctly. In this case, you can use this option to set it '
          'exlicitly.',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show the version of the dart_pre_commit package.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help.',
    );

  try {
    final options = parser.parse(args);
    if (options['help'] as bool) {
      stdout.write(parser.usage);
      return 0;
    }

    HooksProviderInternal.ansiSupported = options['ansi'] as bool;

    final dir = options['directory'] as String?;
    if (dir != null) {
      Directory.current = dir;
    }

    final outdatedLevel = options['outdated'] as String;
    final hooks = await di.read(HooksProvider.hookProvider(HooksConfig(
      fixImports: options['fix-imports'] as bool,
      libraryImports: options['library-imports'] as bool,
      format: options['format'] as bool,
      analyze: options['analyze'] as bool,
      libraryExports: options['library-exports'] as bool,
      outdated: outdatedLevel == disabledOutdatedLevel
          ? null
          : OutdatedLevelX.parse(outdatedLevel),
      nullsafe: options['nullsafe'] as bool,
      pullUpDependencies: options['check-pull-up'] as bool,
      continueOnRejected: options['continue-on-rejected'] as bool,
    )).future);
    hooks.logger.logLevel = LogLevelX.parse(options['log-level'] as String);

    final result = await hooks();
    if (options['detailed-exit-code'] as bool) {
      return result.index;
    } else {
      return result.isSuccess ? 0 : 1;
    }
  } on FormatException catch (e) {
    stderr
      ..writeln('${e.message}\n')
      ..write(parser.usage);
    return 2;
  } on Exception catch (e, s) {
    di.read(HooksProviderInternal.taskLoggerProvider).except(e, s);
    return 127;
  } finally {
    di.dispose();
  }
}
