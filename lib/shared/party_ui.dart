import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/core/localization/app_strings.dart';

export 'package:watchparty/core/localization/app_strings.dart';

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

String flagFor(String code) => code.length == 2
    ? String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => c + 127397))
    : '🌍';

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 38,
            height: 36,
            child: Stack(children: [
              Positioned(
                  left: 0,
                  top: 1,
                  child: Transform.rotate(
                      angle: -.16,
                      child: Container(
                          width: 28,
                          height: 30,
                          decoration: BoxDecoration(
                              color: PartyColors.orange,
                              borderRadius: BorderRadius.circular(9))))),
              Positioned(
                  left: 10,
                  top: 5,
                  child: Container(
                      width: 28,
                      height: 30,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2)),
                      child: Icon(Icons.play_arrow_rounded,
                          size: 22,
                          color: Theme.of(context).colorScheme.surface))),
            ])),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Flexible(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('watchparty',
                      style: TextStyle(
                          fontSize: 22,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w800))))
        ],
      ]);
}

class PartyAvatar extends StatelessWidget {
  const PartyAvatar(
      {super.key,
      required this.name,
      this.countryCode = '',
      this.size = 40,
      this.onTap});
  final String name;
  final String countryCode;
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      label: name,
      button: onTap != null,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: SizedBox(
              width: size + 4,
              height: size + 4,
              child: Stack(children: [
                Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: PartyColors.lime,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: PartyColors.ink.withValues(alpha: .12))),
                    child: Text(
                        name.trim().isEmpty
                            ? '?'
                            : name.trim().characters.first.toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: size * .4,
                            color: PartyColors.ink))),
                if (countryCode.isNotEmpty)
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text(flagFor(countryCode),
                          style: TextStyle(fontSize: size * .36))),
              ]))));
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: color ?? PartyColors.muted));
}

class PartyButton extends StatelessWidget {
  const PartyButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon = Icons.arrow_forward_rounded,
      this.loading = false,
      this.orange = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool loading;
  final bool orange;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: orange
            ? FilledButton.styleFrom(
                backgroundColor: PartyColors.orange,
                foregroundColor: Colors.white)
            : null,
        onPressed: loading ? null : onPressed,
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(label)),
          loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 21)
        ]),
      ));
}

/// A paired-screen illustration built from vector shapes, like two cinema tickets.
class TogetherArtwork extends StatelessWidget {
  const TogetherArtwork({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 186,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 420.0);
        return Center(
            child: SizedBox(
                width: width,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(
                      left: width * .08,
                      top: 18,
                      child: Transform.rotate(
                          angle: -.12,
                          child: _screen(
                              PartyColors.lime,
                              Icons.nightlight_round,
                              l(context, 'SEN', 'YOU', 'ВЫ', "DU", "TÚ")))),
                  Positioned(
                      right: width * .07,
                      top: 39,
                      child: Transform.rotate(
                          angle: .10,
                          child: _screen(
                              const Color(0xFFE9B199),
                              Icons.wb_sunny_rounded,
                              l(context, 'ARKADAŞIN', 'YOUR FRIEND', 'ВАШ ДРУГ',
                                  "DEIN GEGENÜBER", "TU COMPAÑÍA")))),
                  Positioned(
                      bottom: 6,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: PartyColors.ink,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: PartyColors.paper, width: 4)),
                          child: Row(children: [
                            const Icon(Icons.link_rounded,
                                color: PartyColors.lime, size: 17),
                            const SizedBox(width: 6),
                            Text(
                                l(
                                    context,
                                    'Mesafeler ayrı. Anımız aynı.',
                                    'Different places. Same moment.',
                                    'Разные места. Один момент.',
                                    "Verschiedene Orte. Derselbe Moment.",
                                    "Distintos lugares. El mismo momento."),
                                style: const TextStyle(
                                    color: PartyColors.paper,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700))
                          ]))),
                ])));
      }));

  Widget _screen(Color color, IconData icon, String label) => Container(
      width: 164,
      height: 128,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PartyColors.ink, width: 1.5)),
      child: Column(children: [
        Expanded(
            child: Container(
                decoration: BoxDecoration(
                    color: PartyColors.ink,
                    borderRadius: BorderRadius.circular(11)),
                child: Center(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(icon, color: color, size: 35),
                      const SizedBox(width: 9),
                      Icon(Icons.play_arrow_rounded, color: color, size: 40)
                    ])))),
        const SizedBox(height: 7),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Icon(Icons.graphic_eq, size: 14, color: PartyColors.ink)
        ]),
      ]));
}
