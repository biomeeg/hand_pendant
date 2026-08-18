import 'package:flutter/material.dart';

import '../ble/hold_command_controller.dart';
import '../theme/pendant_theme.dart';

/// Mot nut "nham giu" mo phong cong tac vat ly tren tay bam that.
///
/// - Nham xuong: goi PendantInputCoordinator.press(commandId)
/// - Nha ra / gesture bi huy (vi du keo tay ra khoi nut): goi .release(commandId)
/// - Tu dong hien mau "dang nham" khi la nut active, va tu mo (khong bam duoc) khi:
///     a) dang co nut KHAC duoc giu (chi 1 nut active tai 1 thoi diem), hoac
///     b) [connected] = false (mat ket noi Bluetooth)
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.commandId,
    required this.label,
    required this.icon,
    required this.connected,
    this.diameter = 64,
    this.accentColor,
  });

  final String commandId;
  final String label;
  final IconData icon;
  final bool connected;
  final double diameter;

  /// Mau nhan (vi du do cho nut TREND), mac dinh dung mau nut thuong.
  final Color? accentColor;

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
    return ValueListenableBuilder<String?>(
      valueListenable: PendantInputCoordinator.instance.activeCommand,
      builder: (context, activeId, _) {
        final isThisActive = activeId == widget.commandId;
        final isBlockedByOther = activeId != null && !isThisActive;
        final enabled = widget.connected && !isBlockedByOther;

        final Color faceColor = isThisActive
            ? PendantColors.buttonFacePressed
            : (widget.accentColor ?? PendantColors.buttonFace);

        return Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: GestureDetector(
            onTapDown: enabled ? _handleTapDown : null,
            onTapUp: (_) => _handleRelease(),
            onTapCancel: _handleRelease,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: widget.diameter,
                  height: widget.diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: faceColor,
                    boxShadow: isThisActive
                        ? []
                        : const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: PendantColors.textDark,
                    size: widget.diameter * 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PendantColors.textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
