import 'package:flutter/material.dart';
import 'package:watchparty/core/utils/youtube_utils.dart';
import 'package:watchparty/shared/atoms/app_button.dart';

// Yeni bir enum ekliyorum
enum RoomActionMode { create, join, custom }

class RoomActionsPanel extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onPressed;
  final RoomActionMode mode;
  final bool isLoading;
  // Custom mod için başlık ve hint opsiyonel parametreler
  final String? customLabel;
  final String? customHint;

  const RoomActionsPanel({
    super.key,
    required this.controller,
    required this.onPressed,
    required this.mode,
    this.isLoading = false,
    this.customLabel,
    this.customHint,
  });

  @override
  State<RoomActionsPanel> createState() => _RoomActionsPanelState();
}

class _RoomActionsPanelState extends State<RoomActionsPanel> {
  bool isDisabled = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validate);
    _validate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  void _validate() {
    final text = widget.controller.text;
    bool disabled;
    if (widget.mode == RoomActionMode.create) {
      disabled = !isValidYoutubeUrl(text);
    } else if (widget.mode == RoomActionMode.join) {
      disabled = text.length != 6;
    } else {
      // custom modda her zaman aktif (veya isterseniz boş ise disable edebilirsiniz)
      disabled = false;
    }
    if (disabled != isDisabled) {
      setState(() {
        isDisabled = disabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Modlara göre label, buttonText, hint ve iconPath ayarlanıyor
    String label;
    String buttonText;
    String hint;
    String iconPath;
    List<Color> gradientColors;
    Color focusBorderColor;

    switch (widget.mode) {
      case RoomActionMode.create:
        label = 'Create Room';
        buttonText = 'Create Watch Room';
        hint = 'Paste YouTube video link here...';
        iconPath = 'assets/icons/video-icon.png';
        gradientColors = [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
        focusBorderColor = const Color(0xFF8B5CF6);
        break;
      case RoomActionMode.join:
        label = 'Join Room';
        buttonText = 'Join Room';
        hint = 'ENTER ROOM CODE';
        iconPath = 'assets/icons/enter-room-icon.png';
        gradientColors = [const Color(0xFF22C55E), const Color(0xFF16A34A)];
        focusBorderColor = const Color(0xFF22C55E);
        break;
      case RoomActionMode.custom:
        label = widget.customLabel ?? '';
        buttonText = widget.customLabel ?? '';
        hint = widget.customHint ?? '';
        iconPath = 'assets/icons/chain-icon.png'; // örnek bir ikon
        gradientColors = [const Color(0xFF6366F1), const Color(0xFF818CF8)];
        focusBorderColor = const Color(0xFF6366F1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF0F0F0F)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF2A2A2A),
            offset: Offset(-8, -8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Color(0xFF050505),
            offset: Offset(8, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(iconPath, height: 20, width: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F0F0F), Color(0xFF1E1E1E)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF2A2A2A),
                  offset: Offset(-6, -6),
                  blurRadius: 12,
                ),
                BoxShadow(
                  color: Color(0xFF050505),
                  offset: Offset(6, 6),
                  blurRadius: 12,
                ),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              onChanged: (val) {
                if (widget.mode == RoomActionMode.join) {
                  String upper = val.toUpperCase();
                  if (upper.length > 6) upper = upper.substring(0, 6);
                  if (widget.controller.text != upper) {
                    widget.controller.value = TextEditingValue(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                }
                _validate();
              },
              style: const TextStyle(color: Colors.white),
              textAlign: widget.mode == RoomActionMode.create
                  ? TextAlign.start
                  : widget.mode == RoomActionMode.join
                      ? TextAlign.center
                      : TextAlign.start,
              textCapitalization: widget.mode == RoomActionMode.join
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: focusBorderColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: AppButton(
              label: buttonText,
              onPressed: widget.onPressed,
              assetIconPath: iconPath,
              isDisabled: isDisabled,
              isLoading: widget.isLoading,
              height: 60,
              borderRadius: 16,
              gradientColors: gradientColors,
            ),
          ),
        ],
      ),
    );
  }
}
