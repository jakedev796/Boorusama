import '../io/platform.dart';
import '../tool/tool_command.dart';
import '../tool/toolchain.dart';
import 'build_target.dart';

final class BuildRequirements {
  const BuildRequirements._();

  static HostPlatform? requiredHost(BuildTarget target) => switch (target) {
    BuildTarget.ipa || BuildTarget.dmg => HostPlatform.macos,
    BuildTarget.windows => HostPlatform.windows,
    BuildTarget.linux ||
    BuildTarget.appimage ||
    BuildTarget.flatpak => HostPlatform.linux,
    BuildTarget.apk || BuildTarget.aab || BuildTarget.web => null,
  };

  static List<ToolCommand> requiredTools(
    BuildTarget target,
    Toolchain toolchain,
  ) {
    return switch (target) {
      BuildTarget.web => [toolchain.zip],
      BuildTarget.windows => const [],
      BuildTarget.ipa => [toolchain.pod, toolchain.zip],
      BuildTarget.linux => [toolchain.tar],
      BuildTarget.appimage => const [],
      BuildTarget.flatpak => [toolchain.flatpak, toolchain.flatpakBuilder],
      BuildTarget.dmg => [toolchain.pod, toolchain.createDmg],
      BuildTarget.apk || BuildTarget.aab => const [],
    };
  }

  /// Environment keys a target cannot be built without.
  ///
  /// Prod `apk`/`aab`/`ipa` builds used to require a RevenueCat API key. Plus
  /// is now granted unconditionally and nothing reads the entitlement, so an
  /// unconfigured RevenueCat SDK simply no-ops and the key is dead weight that
  /// would only block releases. Kept as a hook for a future real requirement.
  static List<EnvRequirement> requiredEnv({
    required BuildTarget target,
    required String? flavor,
    required bool foss,
    required bool noCodesign,
  }) => const [];
}

final class EnvRequirement {
  const EnvRequirement(this.key);

  final String key;
}
