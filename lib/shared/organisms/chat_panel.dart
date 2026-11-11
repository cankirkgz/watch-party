import 'dart:async';
import 'package:flutter/material.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/services/voice_room_service.dart';
import 'package:watchparty/shared/molecules/chat_input_bar.dart';
import 'package:watchparty/shared/molecules/swipe_to_reply.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';
import 'package:watchparty/shared/party_ui.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel(
      {super.key,
      required this.messages,
      required this.currentUserId,
      required this.controller,
      required this.onSendText,
      required this.onPickImage,
      required this.onSendAudio,
      this.isSending = false,
      this.voiceService,
      this.targetLanguage = 'tr',
      this.autoTranslate = false,
      this.joinedAt,
      this.isActive = true,
      this.readThrough = const {},
      this.onMessageVisible,
      this.onReply,
      this.replyTo,
      this.onClearReply,
      this.onSeek});
  final List<MessageModel> messages;
  final String currentUserId, targetLanguage;
  final VoiceRoomService? voiceService;
  final TextEditingController controller;
  final Future<void> Function(String) onSendText;
  final Future<void> Function() onPickImage;
  final Future<void> Function(String, int) onSendAudio;
  final bool isSending, autoTranslate;
  final DateTime? joinedAt;
  final bool isActive;
  final Map<String, DateTime> readThrough;
  final Future<void> Function(MessageModel message)? onMessageVisible;
  final String? replyTo;
  final ValueChanged<MessageModel>? onReply;
  final VoidCallback? onClearReply;
  final ValueChanged<double>? onSeek;
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  void _replyTo(MessageModel message) {
    widget.onReply?.call(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  final _viewport = GlobalKey();
  final _messageKeys = <String, GlobalKey>{};
  Timer? _receiptTimer;
  DateTime? _lastReported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_scheduleRead);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _scheduleRead();

  void _scheduleRead() {
    _receiptTimer?.cancel();
    _receiptTimer = Timer(const Duration(milliseconds: 450), _reportVisible);
  }

  Future<void> _reportVisible() async {
    if (!mounted ||
        !widget.isActive ||
        widget.onMessageVisible == null ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.isCurrentOf(context) == false) {
      return;
    }
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return;
    }
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    MessageModel? newest;
    for (final message in widget.messages) {
      if (message.senderId == widget.currentUserId ||
          message.id.isEmpty ||
          message.hasPendingWrites ||
          !message.hasServerTimestamp ||
          (_lastReported != null && !message.sentAt.isAfter(_lastReported!))) {
        continue;
      }
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final visible =
          bounds.intersect(box.localToGlobal(Offset.zero) & box.size);
      final requiredHeight =
          (box.size.height < bounds.height ? box.size.height : bounds.height) *
              .5;
      if (visible.width > 0 &&
          visible.height >= requiredHeight &&
          (newest == null || message.sentAt.isAfter(newest.sentAt))) {
        newest = message;
      }
    }
    if (newest == null) return;
    final previous = _lastReported;
    _lastReported = newest.sentAt;
    try {
      await widget.onMessageVisible!(newest);
    } catch (_) {
      if (_lastReported == newest.sentAt) _lastReported = previous;
    }
  }

  @override
  void didUpdateWidget(covariant ChatPanel old) {
    super.didUpdateWidget(old);
    final ids = widget.messages.map((m) => m.id).toSet();
    _messageKeys.removeWhere((id, _) => !ids.contains(id));
    if (widget.messages.isNotEmpty &&
        old.messages.isNotEmpty &&
        widget.messages.first.id != old.messages.first.id &&
        _scroll.hasClients &&
        _scroll.offset < 120) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _receiptTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ModalRoute.isCurrentOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !(_receiptTimer?.isActive ?? false)) _scheduleRead();
    });
    return LayoutBuilder(
        builder: (context, constraints) => Column(children: [
              Expanded(
                  child: SizedBox(
                      key: _viewport,
                      child: widget.messages.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                  child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                                width: 48,
                                                height: 48,
                                                decoration: const BoxDecoration(
                                                    color: PartyColors.panel,
                                                    shape: BoxShape.circle),
                                                child: const Icon(
                                                    Icons.waving_hand_outlined,
                                                    color: PartyColors.lime,
                                                    size: 24)),
                                            const SizedBox(height: 12),
                                            Text(
                                                l(
                                                    context,
                                                    'İlk merhaba senden olsun.',
                                                    'Be the first to say hello.',
                                                    'Скажите первое «привет».',
                                                    "Sag als Erstes Hallo.",
                                                    "Sé la primera persona en saludar."),
                                                style: const TextStyle(
                                                    color: PartyColors.paper,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15)),
                                            const SizedBox(height: 6),
                                            Text(
                                                l(
                                                    context,
                                                    'Videoyu izlerken burada buluşalım.',
                                                    'Your conversation lives right here.',
                                                    'Общайтесь здесь во время просмотра.',
                                                    "Hier könnt ihr euch beim Schauen unterhalten.",
                                                    "Aquí pueden conversar mientras ven el video."),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11)),
                                          ]))))
                          : ListView.builder(
                              controller: _scroll,
                              reverse: true,
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 8),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: widget.messages.length,
                              itemBuilder: (_, i) => SwipeToReply(
                                  onReply: widget.onReply == null
                                      ? null
                                      : () => _replyTo(widget.messages[i]),
                                  child: ChatMessageBubble(
                                    key: _messageKeys.putIfAbsent(
                                        widget.messages[i].id, GlobalKey.new),
                                    message: widget.messages[i],
                                    isMine: widget.messages[i].senderId ==
                                        widget.currentUserId,
                                    isRead: widget.messages[i].isReadByPeer(
                                        widget.currentUserId,
                                        widget.readThrough),
                                    currentUserId: widget.currentUserId,
                                    targetLanguage: widget.targetLanguage,
                                    autoTranslate: widget.autoTranslate &&
                                        widget.messages[i].sentAt.isAfter(
                                            widget.joinedAt ?? DateTime.now()),
                                    onReply: _replyTo,
                                    onSeek: widget.onSeek,
                                  ))))),
              ChatInputBar(
                  controller: widget.controller,
                  focusNode: _inputFocus,
                  onSendText: widget.onSendText,
                  onPickImage: widget.onPickImage,
                  onSendAudio: widget.onSendAudio,
                  isSending: widget.isSending,
                  voiceService: widget.voiceService,
                  compact: constraints.maxHeight < 160,
                  replyTo: widget.replyTo,
                  onClearReply: widget.onClearReply),
            ]));
  }
}
