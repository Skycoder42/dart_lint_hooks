import 'package:dart_pre_commit/src/analyze_task.dart';
import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:dart_pre_commit/src/fix_imports_task.dart';
import 'package:dart_pre_commit/src/format_task.dart';
import 'package:dart_pre_commit/src/hooks_provider.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/pull_up_dependencies_task.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:test/test.dart';
import 'package:tuple/tuple.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'hooks_provider_test.mocks.dart';
import 'test_with_data.dart';

@GenerateMocks([
  Logger,
  FileResolver,
  ProgramRunner,
  FixImportsTask,
  FormatTask,
  AnalyzeTask,
  PullUpDependenciesTask,
])
void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockFixImports = MockFixImportsTask();
  final mockFormat = MockFormatTask();
  final mockAnalayze = MockAnalyzeTask();
  final mockPullUp = MockPullUpDependenciesTask();

  ProviderContainer ioc() => ProviderContainer(overrides: [
        HooksProviderInternal.loggerProvider.overrideWithValue(mockLogger),
        HooksProviderInternal.fileResolverProvider
            .overrideWithValue(mockResolver),
        HooksProviderInternal.programRunnerProvider
            .overrideWithValue(mockRunner),
        HooksProviderInternal.fixImportsProvider
            .overrideWithValue(AsyncValue.data(mockFixImports)),
        HooksProviderInternal.formatProvider.overrideWithValue(mockFormat),
        HooksProviderInternal.analyzeProvider.overrideWithValue(mockAnalayze),
        HooksProviderInternal.pullUpDependenciesProvider
            .overrideWithValue(mockPullUp),
      ]);

  setUp(() {
    reset(mockFormat);
    reset(mockFixImports);
    reset(mockAnalayze);
    reset(mockPullUp);

    when(mockFormat.taskName).thenReturn('mockFormat');
    when(mockFixImports.taskName).thenReturn('mockFixImports');
    when(mockAnalayze.taskName).thenReturn('mockAnalayze');
    when(mockPullUp.taskName).thenReturn('mockPullUp');
  });

  testWithData<Tuple3<HooksConfig, Iterable<String>, bool>>(
    'config loads correct hooks',
    const [
      Tuple3(HooksConfig(), [], false),
      Tuple3(HooksConfig(format: true), ['mockFormat'], false),
      Tuple3(HooksConfig(fixImports: true), ['mockFixImports'], false),
      Tuple3(HooksConfig(analyze: true), ['mockAnalayze'], false),
      Tuple3(HooksConfig(pullUpDependencies: true), ['mockPullUp'], false),
      Tuple3(HooksConfig(continueOnRejected: true), [], true),
      Tuple3(
        HooksConfig(
          fixImports: true,
          format: true,
          analyze: true,
          pullUpDependencies: true,
          continueOnRejected: true,
        ),
        [
          'mockFixImports',
          'mockFormat',
          'mockAnalayze',
          'mockPullUp',
        ],
        true,
      ),
    ],
    (fixture) async {
      final _ioc = ioc();
      final hooks = await _ioc.read(
        HooksProvider.hookProvider(fixture.item1).future,
      );
      expect(hooks.tasks, fixture.item2);
      expect(hooks.continueOnRejected, fixture.item3);
    },
  );
}
