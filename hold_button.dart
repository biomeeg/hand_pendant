import 'package:flutter/material.dart';

import '../ble/hold_command_controller.dart';
import '../theme/pendant_theme.dart';

/// Mot nut "nham giu" dang VIEN THUOC (pill bo tron 2 dau), mo phong cong tac vat ly
/// tren tay bam that - giao dien tham khao theo mau anh chup app dieu khien tuong tu
/// nguoi dung cung cap (nut mau theo chuc nang, chu nam giua nut, khong dung icon).
///
/// - Nham xuong: goi PendantInputCoordinator.press(commandId)
/// - Nha ra / gesture bi huy (vi du keo tay ra khoi nut): goi .release(commandId)
/// - Tu dong sang mau hon khi dang duoc giu, va tu mo (khong bam duoc) khi
///   PendantInputCoordinator.isBlocked(commandId) tra ve true - luu y: tu ban co them
///   ngoai le LEG UP/DOWN duoc phep giu DONG THOI voi 1 trong 2 nut chon ben SPLIT LEG,
///   nen logic khoa/mo nut nay do coordinator quyet dinh, khong con don gian la "chi 1
///   nut duy nhat" nhu truoc.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.commandId,
    required this.label,
    required this.connected,
    this.color,
    this.height = 52,
  });

  final String commandId;
  final String label;
  final bool connected;
  final double height;

  /// Mau nen cua nut theo chuc nang (vi du PendantColors.pillRed cho POWER/TREND,
  /// pillOlive cho UP/DOWN, pillGreen cho LEVEL). Mac dinh pillBlue neu khong chi dinh.
  final Color? color;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _pressedLocally = false;

  void _handleTapDown(TapDownDetails details) {
    if (!widget.connected) return;
    final ok = PendantInputCoordinator.instance.press(widget.commandId);
    if (ok) {
      setState(() => _pressedLocally = true);
    }
  }

  void _handleRelease() {
    if (!_pressedLocally) return;
    PendantInputCoordinator.instance.release(widget.commandId);
    setState(() => _pressedLocally = false);
  }

  @override
  void dispose() {
    // An toan: neu widget bi go khoi cay (vi du chuyen man hinh) trong luc dang giu,
    // dam bao nha lenh de khong ket dinh o trang thai "dang giu" mai mai.
    if (_pressedLocally) {
      PendantInputCoordinator.instance.release(widget.commandId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = PendantInputCoordinator.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([coordinator.activeCommand, coordinator.activeSplitSelector]),
      builder: (context, _) {
        final isThisActive = coordinator.activeCommand.value == widget.commandId ||
            coordinator.activeSplitSelector.value == widget.commandId;
        final blocked = coordinator.isBlocked(widget.commandId);
        final enabled = widget.connected && !blocked;

        final Color baseColor = widget.color ?? PendantColors.pillBlue;
        final Color faceColor =
            isThisActive ? Color.lerp(baseColor, Colors.white, 0.35)! : baseColor;

        return Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: GestureDetector(
            onTapDown: enabled ? _handleTapDown : null,
            onTapUp: (_) => _handleRelease(),
            onTapCancel: _handleRelease,
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: isThisActive
                    ? const []
                    : const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
