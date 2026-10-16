import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/widgets/keyboard_insets_isolation.dart';

/// Считает перестроения: зависит от всего `MediaQuery`, как `Scaffold`.
class _MediaQueryProbe extends StatelessWidget {
  final List<MediaQueryData> builds;

  const _MediaQueryProbe(this.builds);

  @override
  Widget build(BuildContext context) {
    builds.add(MediaQuery.of(context));
    return const SizedBox.shrink();
  }
}

/// [probe] передаётся одним экземпляром: перестроить его может только
/// уведомление `MediaQuery`, а не новый виджет.
Widget _app(EdgeInsets viewInsets, Widget probe) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(412, 892),
      viewInsets: viewInsets,
      viewPadding: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.only(
        bottom: (24 - viewInsets.bottom).clamp(0, 24).toDouble(),
      ),
    ),
    child: KeyboardInsetsIsolation(child: probe),
  );
}

void main() {
  group('KeyboardInsetsIsolation', () {
    testWidgets('скрывает клавиатуру и сохраняет нижний отступ системы',
        (tester) async {
      final builds = <MediaQueryData>[];
      final probe = _MediaQueryProbe(builds);
      await tester.pumpWidget(_app(const EdgeInsets.only(bottom: 300), probe));

      expect(builds.last.viewInsets, EdgeInsets.zero);
      expect(builds.last.padding.bottom, 24);
    });

    testWidgets('кадры анимации клавиатуры не перестраивают содержимое',
        (tester) async {
      final builds = <MediaQueryData>[];
      final probe = _MediaQueryProbe(builds);
      await tester.pumpWidget(_app(EdgeInsets.zero, probe));
      expect(builds, hasLength(1));

      for (final inset in [40.0, 120.0, 220.0, 300.0]) {
        await tester.pumpWidget(_app(EdgeInsets.only(bottom: inset), probe));
      }

      expect(builds, hasLength(1));
    });
  });
}
