import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchparty/core/theme/party_theme.dart';

/// A deliberate right swipe replies without removing or rebuilding the message.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, required this.onReply});
  final Widget child;
  final VoidCallback? onReply;
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _offset = 0;
  bool _armed = false;
  void _reset() => setState(() {
        _offset = 0;
        _armed = false;
      });
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: widget.onReply == null
            ? null
            : (details) {
                setState(
                    () => _offset = (_offset + details.delta.dx).clamp(0, 80));
                if (_offset >= 58 && !_armed) {
                  _armed = true;
                  HapticFeedback.selectionClick();
                }
              },
        onHorizontalDragEnd: widget.onReply == null
            ? null
            : (_) {
                if (_offset >= 58) widget.onReply!();
                _reset();
              },
        onHorizontalDragCancel: _reset,
        child: Stack(alignment: Alignment.centerLeft, children: [
          if (_offset > 0)
            Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Opacity(
                    opacity: (_offset / 58).clamp(0, 1),
                    child: const Icon(Icons.reply_rounded,
                        size: 22, color: PartyColors.lime))),
          AnimatedContainer(
              duration: Duration(milliseconds: _offset == 0 ? 160 : 0),
              transform: Matrix4.translationValues(_offset, 0, 0),
              child: widget.child),
        ]),
      );
}
