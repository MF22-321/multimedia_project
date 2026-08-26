import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/navigation/hmi_page_route.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/features/personalize/presentation/page/personalize_page.dart';
import 'package:intl/intl.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppLanguageControl.languageCode,
      builder: (context, _, _) {
        final time = DateFormat("HH:mm").format(_now);
        final date = AppStrings.isEnglish
            ? DateFormat("EEEE, d MMMM yyyy").format(_now)
            : _formatIndonesianDate(_now);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _profileButton(context),

            /// TIME + DATE
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  date,
                  style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _profileButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40.r),
      onTap: () {
        Navigator.of(
          context,
        ).push(HmiPageRoute(builder: (_) => const PersonalizePage()));
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(40.r),
        ),
        child: ValueListenableBuilder<String?>(
          valueListenable: DriverSession.currentDriver,
          builder: (context, driver, _) {
            final displayName = _displayDriverName(driver);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: Colors.grey.shade700,
                  child: Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 260.w),
                  child: Text(
                    "${AppStrings.hello}, $displayName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 22.sp),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatIndonesianDate(DateTime date) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${days[date.weekday - 1]}, ${date.day} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _displayDriverName(String? driver) {
    if (driver == null ||
        driver.trim().isEmpty ||
        driver.trim().toLowerCase() == 'guest') {
      return AppStrings.guest;
    }

    final pref = DriverHiveService.load(driver);
    final displayName = pref?.displayName.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return driver;
  }
}
