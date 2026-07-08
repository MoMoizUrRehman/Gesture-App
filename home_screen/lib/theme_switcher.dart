// import 'package:flutter/material.dart';

// class ThemeSwitcher extends InheritedWidget {
//   final bool isDarkMode;
//   final ValueChanged<bool> toggleTheme;

//   const ThemeSwitcher({
//     super.key,
//     required this.isDarkMode,
//     required this.toggleTheme,
//     required super.child,
//   });

//   static ThemeSwitcher of(BuildContext context) {
//     final ThemeSwitcher? result =
//         context.dependOnInheritedWidgetOfExactType<ThemeSwitcher>();
//     assert(result != null, 'No ThemeSwitcher found in context');
//     return result!;
//   }

//   @override
//   bool updateShouldNotify(ThemeSwitcher oldWidget) =>
//       isDarkMode != oldWidget.isDarkMode;
// }
