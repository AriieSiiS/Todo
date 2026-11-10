import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/presentation/shared/library_platinum_shine.dart';

void main() {
  testWidgets(
      'el reflejo deja pulsar la portada y respeta el movimiento reducido',
      (tester) async {
    var taps = 0;
    Widget view(bool reduced) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
                body: Center(
                    child: SizedBox(
              width: 180,
              height: 270,
              child: Stack(fit: StackFit.expand, children: [
                GestureDetector(
                    onTap: () => taps++,
                    child: const ColoredBox(color: Colors.blue)),
                const LibraryPlatinumShine(),
              ]),
            ))),
          ),
        );
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tapAt(tester.getCenter(find.byType(LibraryPlatinumShine)));
    expect(taps, 1);
    await tester.pumpWidget(view(true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
