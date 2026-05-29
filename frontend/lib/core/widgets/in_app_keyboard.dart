import 'package:flutter/material.dart';

Future<void> showInAppKeyboard({
  required BuildContext context,
  required TextEditingController controller,
  required String title,
  required Color accentColor,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width,
    ),
    builder: (context) {
      return _InAppKeyboardSheet(
        controller: controller,
        title: title,
        accentColor: accentColor,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      );
    },
  );
}

class _InAppKeyboardSheet extends StatefulWidget {
  const _InAppKeyboardSheet({
    required this.controller,
    required this.title,
    required this.accentColor,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String title;
  final Color accentColor;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_InAppKeyboardSheet> createState() => _InAppKeyboardSheetState();
}

class _InAppKeyboardSheetState extends State<_InAppKeyboardSheet> {
  bool _shift = false;

  static const List<List<String>> _letterRows = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const List<String> _numberRow = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
  ];

  void _notifyChanged() {
    widget.onChanged?.call(widget.controller.text);
  }

  void _insert(String value) {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final nextText = text.replaceRange(start, end, value);
    final offset = start + value.length;

    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
    );

    setState(() {});
    _notifyChanged();
  }

  void _backspace() {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    if (start == 0 && end == 0) return;

    final deleteStart = start == end ? start - 1 : start;
    final nextText = text.replaceRange(deleteStart, end, '');

    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: deleteStart),
    );

    setState(() {});
    _notifyChanged();
  }

  void _clear() {
    widget.controller.clear();
    setState(() {});
    _notifyChanged();
  }

  void _submit() {
    widget.onSubmitted?.call(widget.controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final double availableWidth = (screen.width - 32)
        .clamp(320.0, double.infinity)
        .toDouble();
    final double preferredWidth = (screen.width * 0.92)
        .clamp(820.0, 1680.0)
        .toDouble();
    final double keyboardWidth = preferredWidth > availableWidth
        ? availableWidth
        : preferredWidth;
    final keyHeight = (screen.height * 0.070).clamp(48.0, 76.0).toDouble();
    final keySpacing = (screen.width * 0.008).clamp(8.0, 16.0).toDouble();

    final foreground =
        ThemeData.estimateBrightnessForColor(widget.accentColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: keyboardWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Material(
                color: const Color(0xEE080B10),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(30, 24, 30, 28),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.34),
                      ),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.20),
                          blurRadius: 34,
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _ActionKey(
                        label: 'Clear',
                        onTap: _clear,
                      ),
                      const SizedBox(width: 10),
                      _ActionKey(
                        label: 'Done',
                        color: widget.accentColor,
                        textColor: foreground,
                        onTap: _submit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      widget.controller.text.isEmpty
                          ? 'Tap keys to type'
                          : widget.controller.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.controller.text.isEmpty
                            ? Colors.white38
                            : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _KeyboardRow(
                    keys: _numberRow,
                    onKey: _insert,
                    keyHeight: keyHeight,
                    keySpacing: keySpacing,
                  ),
                  SizedBox(height: keySpacing),
                  for (final row in _letterRows) ...[
                    _KeyboardRow(
                      keys: row
                          .map((key) => _shift ? key.toUpperCase() : key)
                          .toList(),
                      horizontalInset: row.length == 9
                          ? keyboardWidth * 0.024
                          : row.length == 7
                          ? keyboardWidth * 0.070
                          : 0,
                      onKey: _insert,
                      keyHeight: keyHeight,
                      keySpacing: keySpacing,
                    ),
                    SizedBox(height: keySpacing),
                  ],
                  Row(
                    children: [
                      _IconKey(
                        icon: Icons.keyboard_capslock_rounded,
                        active: _shift,
                        width: keyHeight * 1.45,
                        height: keyHeight,
                        onTap: () => setState(() => _shift = !_shift),
                      ),
                      SizedBox(width: keySpacing),
                      Expanded(
                        flex: 5,
                        child: _TextKey(
                          label: 'Space',
                          height: keyHeight,
                          onTap: () => _insert(' '),
                        ),
                      ),
                      SizedBox(width: keySpacing),
                      Expanded(
                        flex: 2,
                        child: _TextKey(
                          label: '-',
                          height: keyHeight,
                          onTap: () => _insert('-'),
                        ),
                      ),
                      SizedBox(width: keySpacing),
                      Expanded(
                        flex: 2,
                        child: _TextKey(
                          label: '_',
                          height: keyHeight,
                          onTap: () => _insert('_'),
                        ),
                      ),
                      SizedBox(width: keySpacing),
                      _IconKey(
                        icon: Icons.backspace_rounded,
                        width: keyHeight * 1.45,
                        height: keyHeight,
                        onTap: _backspace,
                      ),
                    ],
                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  const _KeyboardRow({
    required this.keys,
    required this.onKey,
    required this.keyHeight,
    required this.keySpacing,
    this.horizontalInset = 0,
  });

  final List<String> keys;
  final ValueChanged<String> onKey;
  final double keyHeight;
  final double keySpacing;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Row(
        children: [
          for (final key in keys) ...[
            Expanded(
              child: _TextKey(
                label: key,
                height: keyHeight,
                onTap: () => onKey(key),
              ),
            ),
            if (key != keys.last) SizedBox(width: keySpacing),
          ],
        ],
      ),
    );
  }
}

class _TextKey extends StatelessWidget {
  const _TextKey({
    required this.label,
    required this.onTap,
    required this.height,
  });

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      onTap: onTap,
      height: height,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({
    required this.icon,
    required this.onTap,
    required this.width,
    required this.height,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _KeySurface(
        active: active,
        onTap: onTap,
        height: height,
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.label,
    required this.onTap,
    this.color,
    this.textColor = Colors.white,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _KeySurface extends StatelessWidget {
  const _KeySurface({
    required this.child,
    required this.onTap,
    required this.height,
    this.active = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
