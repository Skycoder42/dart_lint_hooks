// coverage:ignore-file
import 'dart:io';

import 'package:dart_pre_commit/src/tasks/library_exports_task.dart';
import 'package:dart_pre_commit/src/tasks/library_imports_task.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod/riverpod.dart';

import 'hooks.dart';
import 'task_base.dart';
import 'tasks/analyze_task.dart';
import 'tasks/fix_imports_task.dart';
import 'tasks/format_task.dart';
import 'tasks/outdated_task.dart';
import 'tasks/pull_up_dependencies_task.dart';
import 'util/file_resolver.dart';
import 'util/logger.dart';
import 'util/logging/console_logger.dart';
import 'util/logging/simple_logger.dart';
import 'util/program_runner.dart';

part 'hooks_provider.freezed.dart';

/// The configuration to create dependency-injected [Hooks] via [HooksProvider].
@freezed
class HooksConfig with _$HooksConfig {
  /// Default constructor.
  const factory HooksConfig({
    /// Specifies, whether the [FixImportsTask] should be enabled.
    @Default(false) bool fixImports,

    /// Specifies, whether the [LibraryImportsTask] should be enabled.
    @Default(false) bool libraryImports,

    /// Specifies, whether the [FormatTask] should be enabled.
    @Default(false) bool format,

    /// Specifies, whether the [AnalyzeTask] should be enabled.
    @Default(false) bool analyze,

    /// Specifies, whether the [LibraryExportsTask] should be enabled.
    @Default(false) bool libraryExports,

    /// Specifies, whether the [OutdatedTask] in default mode should be enabled.
    ///
    /// The [outdated] value is used to initialize the task with that value.
    OutdatedLevel? outdated,

    /// Specifies, whether the [OutdatedTask] in nullsafety mode should be
    /// enabled.
    @Default(false) bool nullsafe,

    /// Specifies, whether the [PullUpDependenciesTask] should be enabled.
    @Default(false) bool pullUpDependencies,

    /// Sets [Hooks.continueOnRejected].
    @Default(false) bool continueOnRejected,

    /// A list of additional tasks to be added to the hook.
    ///
    /// These are added in addition to the four primary tasks. They are always
    /// added last to the hook, so they will also run last. If you need more
    /// control over the order, instanciate the primary tasks by hand, using
    /// [HooksProviderInternal]
    List<TaskBase>? extraTasks,
  }) = _HooksConfig;
}

/// A static class to give scope to [hookProvider].
///
/// If you need access to all the internal providers, use
/// [HooksProviderInternal].
abstract class HooksProvider {
  const HooksProvider._();

  /// Returns a riverpod provider family to create [Hooks].
  ///
  /// This provider uses the dependency injection of riverpod. You have to pass
  /// a [HooksConfig] to the provider to create a corresponding hooks instance.
  ///
  /// Makes use of [HooksProviderInternal] to get all the required parameters
  /// and tasks for the hooks instance.
  static final hookProvider = FutureProvider.family(
    (ref, HooksConfig param) async => Hooks(
      logger: ref.watch(HooksProviderInternal.loggerProvider),
      fileResolver: ref.watch(HooksProviderInternal.fileResolverProvider),
      programRunner: ref.watch(HooksProviderInternal.programRunnerProvider),
      continueOnRejected: param.continueOnRejected,
      tasks: [
        if (param.fixImports)
          await ref.watch(HooksProviderInternal.fixImportsProvider.future),
        if (param.libraryImports)
          await ref.watch(HooksProviderInternal.libraryImportsProvider.future),
        if (param.format) ref.watch(HooksProviderInternal.formatProvider),
        if (param.analyze) ref.watch(HooksProviderInternal.analyzeProvider),
        if (param.libraryExports)
          ref.watch(HooksProviderInternal.libraryExportsProvider),
        if (param.outdated != null)
          ref.watch(HooksProviderInternal.outdatedProvider(param.outdated!)),
        if (param.nullsafe) ref.watch(HooksProviderInternal.nullsafeProvider),
        if (param.pullUpDependencies)
          ref.watch(HooksProviderInternal.pullUpDependenciesProvider),
        if (param.extraTasks != null) ...param.extraTasks!,
      ],
    ),
  );
}

/// A static class that contains all internally used providers.
abstract class HooksProviderInternal {
  const HooksProviderInternal._();

  static bool ansiSupported = stdout.hasTerminal && stdout.supportsAnsiEscapes;

  /// A simple provider for [ConsoleLogger] as [Logger]
  static final consoleLoggerProvider = Provider<Logger>(
    (ref) => ConsoleLogger(),
  );

  /// A simple provider for [SimpleLogger] as [Logger]
  static final simpleLoggerProvider = Provider<Logger>(
    (ref) => SimpleLogger(),
  );

  static Provider<Logger> get loggerProvider =>
      ansiSupported ? consoleLoggerProvider : simpleLoggerProvider;

  /// A simple provider for [TaskLogger]
  ///
  /// This is simply [loggerProvider], but as a [TaskLogger] view.
  static final taskLoggerProvider = Provider<TaskLogger>(
    (ref) => ref.watch(loggerProvider),
  );

  /// A simple provider for [FileResolver].
  static final fileResolverProvider = Provider(
    (ref) => FileResolver(),
  );

  /// A simple provider for [ProgramRunner].
  ///
  /// Uses [taskLoggerProvider].
  static final programRunnerProvider = Provider(
    (ref) => ProgramRunner(
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [FixImportsTask].
  ///
  /// Uses [taskLoggerProvider].
  static final fixImportsProvider = FutureProvider(
    (ref) => FixImportsTask.current(
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [LibraryImportsTask].
  ///
  /// Uses [fileResolverProvider] and [taskLoggerProvider].
  static final libraryImportsProvider = FutureProvider(
    (ref) => LibraryImportsTask.current(
      fileResolver: ref.watch(fileResolverProvider),
      logger: ref.watch(loggerProvider),
    ),
  );

  /// A simple provider for [FormatTask].
  ///
  /// Uses [programRunnerProvider].
  static final formatProvider = Provider(
    (ref) => FormatTask(
      programRunner: ref.watch(programRunnerProvider),
    ),
  );

  /// A simple provider for [AnalyzeTask].
  ///
  /// Uses [fileResolverProvider], [programRunnerProvider] and
  /// [taskLoggerProvider].
  static final analyzeProvider = Provider(
    (ref) => AnalyzeTask(
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [LibraryExportsTask].
  ///
  /// Uses [taskLoggerProvider].
  static final libraryExportsProvider = Provider(
    (ref) => LibraryExportsTask(
      taskLogger: ref.read(taskLoggerProvider),
    ),
  );

  /// A simple provider for [PullUpDependenciesTask].
  ///
  /// Uses [fileResolverProvider], [programRunnerProvider] and
  /// [taskLoggerProvider].
  static final pullUpDependenciesProvider = Provider(
    (ref) => PullUpDependenciesTask(
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [OutdatedTask].
  ///
  /// Uses [programRunnerProvider] and [taskLoggerProvider].
  static final outdatedProvider = Provider.family(
    (ref, OutdatedLevel level) => OutdatedTask(
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
      outdatedLevel: level,
    ),
  );

  /// A simple provider for [NullsafeTask].
  ///
  /// Uses [programRunnerProvider] and [taskLoggerProvider].
  static final nullsafeProvider = Provider(
    (ref) => NullsafeTask(
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );
}
