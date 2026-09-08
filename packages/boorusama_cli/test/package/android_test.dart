import 'package:boorusama_cli/src/package/android.dart';
import 'package:test/test.dart';

void main() {
  group('choosing which split APKs to package', () {
    final cases = [
      (
        args: ['--split-per-abi'],
        expected: ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
        description: 'packages every abi when the build is not narrowed',
      ),
      (
        args: ['--split-per-abi', '--target-platform', 'android-arm64'],
        expected: ['arm64-v8a'],
        description: 'packages only the requested abi',
      ),
      (
        args: ['--split-per-abi', '--target-platform=android-arm64'],
        expected: ['arm64-v8a'],
        description: 'accepts the flag joined by an equals sign',
      ),
      (
        args: [
          '--split-per-abi',
          '--target-platform',
          'android-arm64,android-arm',
        ],
        expected: ['arm64-v8a', 'armeabi-v7a'],
        description: 'accepts a comma separated list',
      ),
      (
        args: ['--split-per-abi', '--target-platform', ' android-x64 '],
        expected: ['x86_64'],
        description: 'tolerates surrounding whitespace',
      ),
    ];

    for (final c in cases) {
      test(c.description, () {
        expect(splitAbisFor(c.args), c.expected);
      });
    }

    test('keeps a stable abi order regardless of how they were requested', () {
      expect(
        splitAbisFor([
          '--target-platform',
          'android-x64,android-arm64',
        ]),
        ['arm64-v8a', 'x86_64'],
      );
    });

    test('falls back to every abi rather than packaging nothing', () {
      // A platform this packager does not know about must not silently
      // produce an empty release.
      final cases = [
        ['--target-platform', 'android-riscv64'],
        ['--target-platform', ''],
        ['--target-platform'],
      ];

      for (final args in cases) {
        expect(splitAbisFor(args), ['arm64-v8a', 'armeabi-v7a', 'x86_64']);
      }
    });
  });
}
