import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/themes/car_theme.dart';

class PhoneContent extends StatefulWidget {
  const PhoneContent({super.key});

  @override
  State<PhoneContent> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhoneContent> {
  final TextEditingController _numberController = TextEditingController();

  final List<Map<String, dynamic>> recentCalls = [
    {'name': 'Mom', 'number': '+62 812 3456 7890', 'icon': Icons.favorite},

    {'name': 'John Doe', 'number': '+62 878 1122 3344', 'icon': Icons.person},

    {'name': 'Office', 'number': '+62 811 9988 7766', 'icon': Icons.work},

    {'name': 'Emergency', 'number': '112', 'icon': Icons.warning},
  ];

  void addNumber(String number) {
    setState(() {
      _numberController.text += number;
    });
  }

  void removeNumber() {
    if (_numberController.text.isEmpty) {
      return;
    }

    setState(() {
      _numberController.text = _numberController.text.substring(
        0,

        _numberController.text.length - 1,
      );
    });
  }

  Widget buildDialButton(String text, CarThemeData theme) {
    return GestureDetector(
      onTap: () {
        addNumber(text);
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        width: 80.w,
        height: 80.w,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.r),

          color: Colors.white.withValues(alpha: 0.07),

          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),

          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withValues(alpha: 0.08),

              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),

        child: Center(
          child: Text(
            text,

            style: TextStyle(
              color: Colors.white,

              fontSize: 34.sp,

              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildBottomButton({
    required IconData icon,
    required String title,
    required CarThemeData theme,
    required Color musicAccent,
  }) {
    return Expanded(
      child: Container(
        height: 68.h,

        margin: EdgeInsets.symmetric(horizontal: 8.w),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),

          color: Colors.white.withValues(alpha: 0.06),

          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, color: musicAccent, size: 22.sp),

            SizedBox(width: 10.w),

            Text(
              title,

              style: TextStyle(
                color: Colors.white,

                fontSize: 18.sp,

                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final musicAccent = currentTheme == CarThemeType.comfort
        ? getMusicAccentColor(currentTheme, theme)
        : theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: theme.backgroundGradient,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),

            child: Row(
              children: [
                /// =====================
                /// LEFT PANEL
                /// =====================
                Expanded(
                  flex: 3,

                  child: Container(
                    padding: EdgeInsets.all(24.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withValues(alpha: 0.05),

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// TITLE
                        Row(
                          children: [
                            Icon(Icons.call, color: musicAccent, size: 34.sp),

                            SizedBox(width: 14.w),

                            Text(
                              AppStrings.phone,

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 36.sp,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 34.h),

                        /// SEARCH
                        Container(
                          height: 70.h,

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24.r),

                            color: Colors.white.withValues(alpha: 0.06),
                          ),

                          child: TextField(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                            ),

                            textAlignVertical: TextAlignVertical.center,

                            decoration: InputDecoration(
                              border: InputBorder.none,

                              contentPadding: EdgeInsets.symmetric(
                                vertical: 24.h,
                              ),

                              prefixIcon: Padding(
                                padding: EdgeInsets.only(
                                  left: 18.w,
                                  right: 12.w,
                                ),

                                child: Icon(
                                  Icons.search,

                                  color: Colors.white.withValues(alpha: 0.6),

                                  size: 30.sp,
                                ),
                              ),

                              prefixIconConstraints: BoxConstraints(
                                minWidth: 60.w,
                              ),

                              hintText: 'Search contact...',

                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),

                                fontSize: 20.sp,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 34.h),

                        Text(
                          'Recent Calls',

                          style: TextStyle(
                            color: Colors.white,

                            fontSize: 28.sp,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 24.h),

                        /// RECENT CALLS
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),

                            itemCount: recentCalls.length,

                            itemBuilder: (context, index) {
                              final call = recentCalls[index];

                              return Container(
                                margin: EdgeInsets.only(bottom: 18.h),

                                padding: EdgeInsets.all(18.w),

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28.r),

                                  color: Colors.white.withValues(alpha: 0.05),

                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    /// AVATAR
                                    Container(
                                      width: 64.w,

                                      height: 64.w,

                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,

                                        color: theme.accentColor.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),

                                      child: Icon(
                                        call['icon'],

                                        color: musicAccent,

                                        size: 30.sp,
                                      ),
                                    ),

                                    SizedBox(width: 18.w),

                                    /// INFO
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            call['name'],

                                            style: TextStyle(
                                              color: Colors.white,

                                              fontSize: 22.sp,

                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          SizedBox(height: 6.h),

                                          Text(
                                            call['number'],

                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.55,
                                              ),

                                              fontSize: 16.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    /// CALL BUTTON
                                    Container(
                                      width: 54.w,

                                      height: 54.w,

                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,

                                        color: musicAccent,

                                        boxShadow: [
                                          BoxShadow(
                                            color: musicAccent.withValues(
                                              alpha: 0.45,
                                            ),

                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),

                                      child: const Icon(
                                        Icons.call,

                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 24.w),

                /// =====================
                /// RIGHT PANEL
                /// =====================
                Expanded(
                  flex: 4,

                  child: Container(
                    padding: EdgeInsets.all(28.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withValues(alpha: 0.05),

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),

                    child: Column(
                      children: [
                        /// NUMBER DISPLAY
                        Container(
                          width: double.infinity,

                          padding: EdgeInsets.symmetric(
                            vertical: 26.h,

                            horizontal: 24.w,
                          ),

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28.r),

                            color: Colors.white.withValues(alpha: 0.06),
                          ),

                          child: Text(
                            _numberController.text.isEmpty
                                ? '+62'
                                : _numberController.text,

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              color: Colors.white,

                              fontSize: 34.sp,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        SizedBox(height: 34.h),

                        /// DIAL PAD
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,

                                children: [
                                  buildDialButton('1', theme),

                                  buildDialButton('2', theme),

                                  buildDialButton('3', theme),
                                ],
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,

                                children: [
                                  buildDialButton('4', theme),

                                  buildDialButton('5', theme),

                                  buildDialButton('6', theme),
                                ],
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,

                                children: [
                                  buildDialButton('7', theme),

                                  buildDialButton('8', theme),

                                  buildDialButton('9', theme),
                                ],
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,

                                children: [
                                  buildDialButton('*', theme),

                                  buildDialButton('0', theme),

                                  buildDialButton('#', theme),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20.h),

                        /// ACTION BUTTONS
                        Row(
                          children: [
                            /// DELETE
                            GestureDetector(
                              onTap: removeNumber,

                              child: Container(
                                width: 82.w,
                                height: 82.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: Colors.white.withValues(alpha: 0.06),
                                ),

                                child: const Icon(
                                  Icons.backspace,

                                  color: Colors.white,
                                ),
                              ),
                            ),

                            SizedBox(width: 24.w),

                            /// CALL

                            /// CALL
                            Expanded(
                              child: Container(
                                height: 82.h,

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28.r),

                                  color: currentTheme == CarThemeType.comfort
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : theme.accentColor.withValues(
                                          alpha: 0.12,
                                        ),

                                  border: Border.all(
                                    color: theme.accentColor.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),

                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          currentTheme == CarThemeType.comfort
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : theme.accentColor.withValues(
                                              alpha: 0.12,
                                            ),

                                      blurRadius: 25,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),

                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Icon(
                                      Icons.call,

                                      color: musicAccent,

                                      size: 28.sp,
                                    ),

                                    SizedBox(width: 12.w),

                                    Text(
                                      'Call',

                                      style: TextStyle(
                                        color: musicAccent,

                                        fontSize: 24.sp,

                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 28.h),

                        /// BOTTOM MENU
                        Row(
                          children: [
                            buildBottomButton(
                              musicAccent: musicAccent,
                              icon: Icons.dialpad,

                              title: 'Keypad',

                              theme: theme,
                            ),

                            buildBottomButton(
                              icon: Icons.history,
                              musicAccent: musicAccent,

                              title: 'Recent',

                              theme: theme,
                            ),

                            buildBottomButton(
                              musicAccent: musicAccent,
                              icon: Icons.contacts,

                              title: 'Contacts',

                              theme: theme,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
