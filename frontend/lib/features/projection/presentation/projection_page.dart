import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/services/bluetooth_discovery_control.dart';
import 'package:frontend/features/projection/data/projection_backend.dart';
import 'package:frontend/features/projection/domain/projection_models.dart';
import 'package:frontend/features/projection/presentation/projection_controller.dart';

class ProjectionPage extends StatefulWidget {
  const ProjectionPage({
    super.key,
    this.backend,
    this.autoStartAndroidAuto = false,
    this.initialTarget,
  });

  final ProjectionBackend? backend;
  final bool autoStartAndroidAuto;
  final ProjectionTarget? initialTarget;

  @override
  State<ProjectionPage> createState() => _ProjectionPageState();
}

class _ProjectionPageState extends State<ProjectionPage> {
  late final ProjectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProjectionController(
      backend: widget.backend ?? NativeProjectionBackend(),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await BluetoothDiscoveryControl.stopActiveDiscovery();
    await _controller.initialize();
    if (widget.autoStartAndroidAuto) {
      await _controller.connect(ProjectionTarget.androidAuto);
    }
  }

  @override
  void dispose() {
    // The native receiver session is intentionally kept alive. Leaving this
    // page only stops UI polling, so reopening Projection resumes immediately.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageTarget = widget.initialTarget;
    final pageBackground = pageTarget == ProjectionTarget.carPlay
        ? const Color(0xFF080A10)
        : pageTarget == ProjectionTarget.androidAuto
        ? const Color(0xFF06110D)
        : const Color(0xFF05070B);
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final status = _controller.status;
            if (status.isActive &&
                status.textureId != null &&
                !status.simulation) {
              return _FullscreenProjection(
                status: status,
                onTouch: _controller.sendTouch,
                onBack: () => Navigator.maybePop(context),
                onDisconnect: _controller.disconnect,
              );
            }
            return Column(
              children: [
                _ProjectionHeader(
                  status: status,
                  target: pageTarget ?? status.target,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(28.w, 8.h, 28.w, 28.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProjectionSurface(
                            status: status,
                            target: pageTarget ?? status.target,
                            onTouch: _controller.sendTouch,
                          ),
                        ),
                        SizedBox(width: 24.w),
                        SizedBox(
                          width: 300.w,
                          child: _ProjectionControls(
                            status: status,
                            fixedTarget: pageTarget,
                            busy: _controller.busy,
                            onConnect: _controller.connect,
                            onDisconnect: _controller.disconnect,
                            onSuspend: _controller.suspend,
                            onResume: _controller.resume,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FullscreenProjection extends StatelessWidget {
  const _FullscreenProjection({
    required this.status,
    required this.onTouch,
    required this.onBack,
    required this.onDisconnect,
  });

  final ProjectionStatus status;
  final Future<void> Function({
    required double x,
    required double y,
    required String action,
  })
  onTouch;
  final VoidCallback onBack;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('projection-fullscreen'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              void forward(Offset position, String action) {
                final size = constraints.biggest;
                if (size.width <= 0 || size.height <= 0) return;
                unawaited(
                  onTouch(
                    x: position.dx / size.width,
                    y: position.dy / size.height,
                    action: action,
                  ),
                );
              }

              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => forward(event.localPosition, 'down'),
                onPointerMove: (event) => forward(event.localPosition, 'move'),
                onPointerUp: (event) => forward(event.localPosition, 'up'),
                child: Texture(
                  key: const ValueKey('projection-native-texture'),
                  textureId: status.textureId!,
                  filterQuality: FilterQuality.low,
                ),
              );
            },
          ),
          Positioned(
            top: 18.h,
            left: 20.w,
            child: _FullscreenIconAction(
              key: const ValueKey('projection-fullscreen-back'),
              icon: Icons.arrow_back_rounded,
              tooltip: AppStrings.returnToHmi,
              onPressed: onBack,
            ),
          ),
          Positioned(
            top: 18.h,
            right: 20.w,
            child: _FullscreenIconAction(
              key: const ValueKey('projection-fullscreen-disconnect'),
              icon: Icons.link_off_rounded,
              tooltip: AppStrings.disconnect,
              destructive: true,
              onPressed: () => unawaited(onDisconnect()),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenIconAction extends StatelessWidget {
  const _FullscreenIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? const Color(0xFFFDA4AF) : Colors.white;
    final border = destructive
        ? const Color(0xFF9F4E59)
        : const Color(0xFF69717D);
    return RepaintBoundary(
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: DecoratedBox(
                key: ValueKey(
                  destructive
                      ? 'projection-disconnect-surface'
                      : 'projection-back-surface',
                ),
                decoration: BoxDecoration(
                  // Fully opaque on purpose. Alpha-blended Material state
                  // layers flicker over the continuously refreshed texture on
                  // the Linux embedder/NVIDIA composition path.
                  color: const Color(0xFF101318),
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1.5),
                ),
                child: SizedBox(
                  width: 48.w,
                  height: 48.h,
                  child: Center(
                    child: Icon(icon, size: 22.sp, color: foreground),
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

class _ProjectionHeader extends StatelessWidget {
  const _ProjectionHeader({
    required this.status,
    required this.target,
    required this.onBack,
  });

  final ProjectionStatus status;
  final ProjectionTarget? target;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28.w, 20.h, 28.w, 16.h),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: AppStrings.back,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          SizedBox(width: 18.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                target?.label ?? AppStrings.phoneProjection,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                target == ProjectionTarget.androidAuto
                    ? AppStrings.androidAutoEnvironment
                    : target == ProjectionTarget.carPlay
                    ? AppStrings.carPlayEnvironment
                    : AppStrings.projectionSubtitle,
                style: TextStyle(color: Colors.white60, fontSize: 14.sp),
              ),
            ],
          ),
          const Spacer(),
          _StatusBadge(status: status),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ProjectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.state) {
      ProjectionConnectionState.active => const Color(0xFF6EE7B7),
      ProjectionConnectionState.connecting ||
      ProjectionConnectionState.discovering => const Color(0xFF60A5FA),
      ProjectionConnectionState.suspended => const Color(0xFFFBBF24),
      ProjectionConnectionState.error => const Color(0xFFFB7185),
      _ => Colors.white54,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 9.w),
          Text(
            _stateLabel(status.state),
            style: TextStyle(
              color: color,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _stateLabel(ProjectionConnectionState state) {
    return switch (state) {
      ProjectionConnectionState.idle => AppStrings.projectionIdle,
      ProjectionConnectionState.discovering => AppStrings.discovering,
      ProjectionConnectionState.connecting => AppStrings.connecting,
      ProjectionConnectionState.active => AppStrings.active,
      ProjectionConnectionState.suspended => AppStrings.suspended,
      ProjectionConnectionState.disconnected => AppStrings.disconnected,
      ProjectionConnectionState.error => AppStrings.connectionFailed,
    };
  }
}

class _ProjectionSurface extends StatelessWidget {
  const _ProjectionSurface({
    required this.status,
    required this.target,
    required this.onTouch,
  });

  final ProjectionStatus status;
  final ProjectionTarget? target;
  final Future<void> Function({
    required double x,
    required double y,
    required String action,
  })
  onTouch;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28.r),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1018),
          border: Border.all(color: Colors.white12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textureId = status.textureId;
            if (status.isActive && textureId != null) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _forwardTouch(
                  event.localPosition,
                  constraints.biggest,
                  'down',
                ),
                onPointerMove: (event) => _forwardTouch(
                  event.localPosition,
                  constraints.biggest,
                  'move',
                ),
                onPointerUp: (event) => _forwardTouch(
                  event.localPosition,
                  constraints.biggest,
                  'up',
                ),
                child: Texture(
                  key: const ValueKey('projection-native-texture'),
                  textureId: textureId,
                  filterQuality: FilterQuality.low,
                ),
              );
            }

            if (status.isActive && status.simulation) {
              return _SimulatedProjectionSurface(target: status.target);
            }

            if (status.state == ProjectionConnectionState.connecting ||
                status.state == ProjectionConnectionState.discovering) {
              return _ConnectingSurface(target: status.target);
            }

            return _IdleSurface(status: status, target: target);
          },
        ),
      ),
    );
  }

  void _forwardTouch(Offset position, Size size, String action) {
    if (size.width <= 0 || size.height <= 0) return;
    unawaited(
      onTouch(
        x: position.dx / size.width,
        y: position.dy / size.height,
        action: action,
      ),
    );
  }
}

class _IdleSurface extends StatelessWidget {
  const _IdleSurface({required this.status, required this.target});

  final ProjectionStatus status;
  final ProjectionTarget? target;

  @override
  Widget build(BuildContext context) {
    final isError = status.state == ProjectionConnectionState.error;
    final isCarPlay = target == ProjectionTarget.carPlay;
    final accent = isCarPlay
        ? const Color(0xFFD6E4FF)
        : const Color(0xFF3DDC84);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(42.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError
                  ? Icons.warning_amber_rounded
                  : isCarPlay
                  ? Icons.apple
                  : target == ProjectionTarget.androidAuto
                  ? Icons.android_rounded
                  : Icons.phone_iphone_rounded,
              color: isError ? const Color(0xFFFB7185) : accent,
              size: 82.sp,
            ),
            SizedBox(height: 20.h),
            Text(
              isError
                  ? AppStrings.projectionBridgeUnavailable
                  : target == ProjectionTarget.androidAuto
                  ? AppStrings.androidAutoConnectTitle
                  : target == ProjectionTarget.carPlay
                  ? AppStrings.carPlayConnectTitle
                  : AppStrings.connectYourPhone,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 25.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              status.message.isNotEmpty
                  ? status.message
                  : target == ProjectionTarget.androidAuto
                  ? AppStrings.androidAutoConnectHelp
                  : target == ProjectionTarget.carPlay
                  ? AppStrings.carPlayConnectHelp
                  : AppStrings.chooseProjectionPlatform,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectingSurface extends StatelessWidget {
  const _ConnectingSurface({required this.target});

  final ProjectionTarget? target;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          SizedBox(height: 22.h),
          Text(
            '${AppStrings.connecting} ${target?.label ?? ''}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            AppStrings.keepPhoneConnected,
            style: TextStyle(color: Colors.white54, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

class _SimulatedProjectionSurface extends StatelessWidget {
  const _SimulatedProjectionSurface({required this.target});

  final ProjectionTarget? target;

  @override
  Widget build(BuildContext context) {
    final isCarPlay = target == ProjectionTarget.carPlay;
    final accent = isCarPlay
        ? const Color(0xFF60A5FA)
        : const Color(0xFF34D399);

    return DecoratedBox(
      key: const ValueKey('projection-simulator-surface'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            const Color(0xFF101827),
            Colors.black,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(34.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCarPlay ? Icons.apple : Icons.android_rounded,
                  color: accent,
                  size: 42.sp,
                ),
                SizedBox(width: 14.w),
                Text(
                  target?.label ?? AppStrings.phoneProjection,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _SimulationPill(accent: accent),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _MockApp(
                  icon: Icons.map_rounded,
                  label: 'Maps',
                  accent: accent,
                ),
                SizedBox(width: 18.w),
                _MockApp(
                  icon: Icons.music_note_rounded,
                  label: AppStrings.music,
                  accent: accent,
                ),
                SizedBox(width: 18.w),
                _MockApp(
                  icon: Icons.phone_rounded,
                  label: AppStrings.phone,
                  accent: accent,
                ),
                SizedBox(width: 18.w),
                _MockApp(
                  icon: Icons.mic_rounded,
                  label: 'Assistant',
                  accent: accent,
                ),
              ],
            ),
            SizedBox(height: 30.h),
            Text(
              AppStrings.simulatorSurfaceDescription,
              style: TextStyle(color: Colors.white54, fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulationPill extends StatelessWidget {
  const _SimulationPill({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: accent.withValues(alpha: 0.14),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Text(
        'SIMULATOR',
        style: TextStyle(
          color: accent,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _MockApp extends StatelessWidget {
  const _MockApp({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 34.sp),
              SizedBox(height: 10.h),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectionControls extends StatelessWidget {
  const _ProjectionControls({
    required this.status,
    required this.fixedTarget,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSuspend,
    required this.onResume,
  });

  final ProjectionStatus status;
  final ProjectionTarget? fixedTarget;
  final bool busy;
  final Future<void> Function(
    ProjectionTarget target, {
    required ProjectionTransport transport,
  })
  onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onSuspend;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final isDedicated = fixedTarget != null;
    final isCarPlay = fixedTarget == ProjectionTarget.carPlay;
    final accent = isCarPlay
        ? const Color(0xFF9CC2FF)
        : const Color(0xFF3DDC84);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: isDedicated
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.035),
                ],
              )
            : null,
        color: isDedicated ? null : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isDedicated ? accent.withValues(alpha: 0.28) : Colors.white12,
        ),
      ),
      child: ListView(
        padding: EdgeInsets.all(22.w),
        children: [
          if (isDedicated) ...[
            Icon(
              isCarPlay ? Icons.apple : Icons.android_rounded,
              color: accent,
              size: 44.sp,
            ),
            SizedBox(height: 14.h),
          ],
          Text(
            fixedTarget == ProjectionTarget.androidAuto
                ? AppStrings.androidAutoConnectTitle
                : fixedTarget == ProjectionTarget.carPlay
                ? AppStrings.carPlayConnectTitle
                : AppStrings.choosePlatform,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            fixedTarget == ProjectionTarget.androidAuto
                ? AppStrings.androidAutoConnectHelp
                : fixedTarget == ProjectionTarget.carPlay
                ? AppStrings.carPlayConnectHelp
                : AppStrings.receiverRunsBehindFlutter,
            style: TextStyle(color: Colors.white54, fontSize: 13.sp),
          ),
          SizedBox(height: 18.h),
          if (fixedTarget != ProjectionTarget.carPlay)
            _PlatformButton(
              key: const ValueKey('connect-android-auto'),
              label: status.simulation
                  ? AppStrings.testAndroidAutoUi
                  : AppStrings.androidAutoWired,
              icon: Icons.android_rounded,
              color: const Color(0xFF3DDC84),
              selected:
                  status.target == ProjectionTarget.androidAuto &&
                  status.transport == ProjectionTransport.wiredUsb,
              enabled: !busy,
              onPressed: () => onConnect(
                ProjectionTarget.androidAuto,
                transport: ProjectionTransport.wiredUsb,
              ),
            ),
          if (fixedTarget != ProjectionTarget.carPlay) SizedBox(height: 12.h),
          if (fixedTarget != ProjectionTarget.carPlay)
            _PlatformButton(
              key: const ValueKey('connect-android-auto-wireless'),
              label: AppStrings.androidAutoWireless,
              icon: Icons.wifi_tethering_rounded,
              color: const Color(0xFF60A5FA),
              selected:
                  status.target == ProjectionTarget.androidAuto &&
                  status.transport == ProjectionTransport.wireless,
              enabled: !busy && !status.simulation,
              onPressed: () => onConnect(
                ProjectionTarget.androidAuto,
                transport: ProjectionTransport.wireless,
              ),
            ),
          if (fixedTarget == null) SizedBox(height: 14.h),
          if (fixedTarget != ProjectionTarget.androidAuto)
            _PlatformButton(
              key: const ValueKey('connect-carplay'),
              label: AppStrings.appleCarPlay,
              icon: Icons.apple,
              color: const Color(0xFF9CC2FF),
              selected: status.target == ProjectionTarget.carPlay,
              enabled: !busy,
              onPressed: () => onConnect(
                ProjectionTarget.carPlay,
                transport: ProjectionTransport.wiredUsb,
              ),
            ),
          SizedBox(height: 18.h),
          if (fixedTarget == ProjectionTarget.carPlay)
            const _CarPlayConnectionInfo()
          else ...[
            _UsbConnectionInfo(status: status),
            SizedBox(height: 10.h),
            const _WirelessConnectionInfo(),
          ],
          SizedBox(height: 22.h),
          const Divider(color: Colors.white12),
          SizedBox(height: 14.h),
          if (status.canSuspend)
            OutlinedButton.icon(
              onPressed: busy ? null : onSuspend,
              icon: const Icon(Icons.pause_rounded),
              label: Text(AppStrings.suspendProjection),
            ),
          if (status.canResume)
            OutlinedButton.icon(
              onPressed: busy ? null : onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(AppStrings.resumeProjection),
            ),
          if (status.canDisconnect) ...[
            SizedBox(height: 10.h),
            OutlinedButton.icon(
              key: const ValueKey('disconnect-projection'),
              onPressed: busy ? null : onDisconnect,
              icon: const Icon(Icons.link_off_rounded),
              label: Text(AppStrings.disconnect),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFB7185),
              ),
            ),
          ],
          SizedBox(height: 24.h),
          if (fixedTarget != ProjectionTarget.carPlay)
            _BridgeInfo(status: status),
        ],
      ),
    );
  }
}

class _PlatformButton extends StatelessWidget {
  const _PlatformButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68.h,
      child: FilledButton.tonalIcon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: color, size: 26.sp),
        label: Text(
          label,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? color.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.07),
          foregroundColor: Colors.white,
          side: BorderSide(
            color: selected ? color.withValues(alpha: 0.65) : Colors.white12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
        ),
      ),
    );
  }
}

class _BridgeInfo extends StatelessWidget {
  const _BridgeInfo({required this.status});

  final ProjectionStatus status;

  @override
  Widget build(BuildContext context) {
    final nativeReady = status.nativeReceiverReady;
    final color = nativeReady
        ? const Color(0xFF6EE7B7)
        : const Color(0xFFFBBF24);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.memory_rounded, color: color, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              nativeReady
                  ? AppStrings.nativeReceiverReady
                  : AppStrings.receiverSimulatorActive,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsbConnectionInfo extends StatelessWidget {
  const _UsbConnectionInfo({required this.status});

  final ProjectionStatus status;

  @override
  Widget build(BuildContext context) {
    final detected = status.usbPhoneDetected;
    final color = detected ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8);
    final deviceName = status.usbDeviceName.replaceAll('_', ' ').trim();
    final details = <String>[
      if (detected && deviceName.isNotEmpty) deviceName,
      if (detected && status.usbIdentifier.isNotEmpty) status.usbIdentifier,
      if (status.usbAccessoryMode) AppStrings.accessoryModeActive,
      if (detected && !status.nativeReceiverReady) AppStrings.receiverRequired,
    ];

    return Container(
      key: const ValueKey('wired-usb-status'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.usb_rounded, color: color, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.wiredUsbStage,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  detected
                      ? AppStrings.usbPhoneDetected
                      : AppStrings.waitingForUsbPhone,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    details.join(' · '),
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10.sp,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WirelessConnectionInfo extends StatelessWidget {
  const _WirelessConnectionInfo();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF60A5FA);
    return Container(
      key: const ValueKey('wireless-android-auto-status'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_tethering_rounded, color: color, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.wirelessStage,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  AppStrings.wirelessAndroidAutoHelp,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10.sp,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarPlayConnectionInfo extends StatelessWidget {
  const _CarPlayConnectionInfo();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF9CC2FF);
    return Container(
      key: const ValueKey('carplay-connection-status'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cable_rounded, color: color, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              AppStrings.carPlayReceiverPending,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
