import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/logging/simple_logger.dart';
import 'package:path/path.dart';

import '../repo_entry.dart';
import '../task_base.dart';

export '../hooks.dart';

class _InvalidLibraryResolutionException implements Exception {
  final SomeResolvedLibraryResult result;

  _InvalidLibraryResolutionException(this.result);

  @override
  String toString() => 'Failed to load library with result: $result';
}

class LibraryExportsTask implements RepoTask {
  final _locator = ContextLocator();
  final _builder = ContextBuilder();

  final TaskLogger taskLogger;

  LibraryExportsTask({
    required this.taskLogger,
  });

  @override
  String get taskName => 'library-exports';

  @override
  Pattern get filePattern => RegExp(r'^lib[\/\\].*\.dart$');

  @override
  bool get callForEmptyEntries => false;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final entriesList = entries.toList();
    final exportedLibraries = <LibraryElement>[];
    final srcLibraries = <LibraryElement>[];

    final libDir = Directory('lib');
    final srcDir = Directory(join(libDir.path, 'src'));

    final contextList = _getAnalysisContextList(entriesList);
    for (final entry in entriesList) {
      try {
        taskLogger.debug('Analyzing $entry...');
        final libraryElement = await contextList.loadLibraryElement(entry);
        if (libraryElement == null) {
          taskLogger.debug('> Skipping part');
          continue;
        }

        if (isWithin(srcDir.path, entry.file.path)) {
          if (libraryElement.hasExportedElements) {
            taskLogger.debug('> Found src library with exports');
            srcLibraries.add(libraryElement);
          }
        } else if (isWithin(libDir.path, entry.file.path)) {
          taskLogger.debug('> Found top level library');
          exportedLibraries.addAll(
            libraryElement.exportedLibraries,
          );
        } else {
          taskLogger.warn('Unexpected element: $entry');
        }
      } on Exception catch (e) {
        taskLogger.error('Failed to load $entry with error: $e');
      }
    }

    final unexported =
        srcLibraries.toSet().difference(exportedLibraries.toSet());

    for (final library in unexported) {
      taskLogger.info(
        'Found library with unexported elements: ${library.librarySource.uri}',
      );
    }

    return unexported.isEmpty ? TaskResult.accepted : TaskResult.rejected;
  }

  List<AnalysisContext> _getAnalysisContextList(Iterable<RepoEntry> entries) =>
      _locator
          .locateRoots(
            includedPaths: entries
                .map((e) => canonicalize(absolute(e.file.path)))
                .toList(),
          )
          .map(
            (contextRoot) => _builder.createContext(contextRoot: contextRoot),
          )
          .toList();
}

extension _ContextRootListX on List<AnalysisContext> {
  Future<LibraryElement?> loadLibraryElement(
    RepoEntry entry,
  ) async {
    final absolutePath = canonicalize(absolute(entry.file.path));
    final session = sessionForPath(absolutePath);
    final libraryResult = await session.getResolvedLibrary2(absolutePath);
    if (libraryResult is ResolvedLibraryResult) {
      return libraryResult.element!;
    } else if (libraryResult is NotLibraryButPartResult) {
      return null;
    } else {
      throw _InvalidLibraryResolutionException(libraryResult);
    }
  }

  AnalysisSession sessionForPath(String path) {
    for (final context in this) {
      if (context.contextRoot.isAnalyzed(path)) {
        return context.currentSession;
      }
    }

    throw Exception('Path is not covered by any analyzer context');
  }
}

extension _LibraryElementX on LibraryElement {
  bool get hasExportedElements => topLevelElements.any(
        (element) =>
            !element.hasInternal &&
            !element.isPrivate &&
            !(element.name?.startsWith(r'$') ?? false),
      );
}

Future<void> main() async {
  final task = LibraryExportsTask(
    taskLogger: SimpleLogger(logLevel: LogLevel.debug),
  );
  await task(
    await Directory('.')
        .list(recursive: true)
        .where((entry) => entry is File)
        .cast<File>()
        .where((file) =>
            task.filePattern.matchAsPrefix(file.path.substring(2)) != null)
        .map((file) => RepoEntry(file: file, partiallyStaged: false))
        .toList(),
  );
}
