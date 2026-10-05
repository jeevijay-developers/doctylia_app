import 'dart:ui' show ImageFilter;

import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/theme/theme_mode_provider.dart';
import 'package:doctylia_app/core/widgets/doctylia_brand_mark.dart';
import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/dashboard/presentation/navigation/dashboard_destination.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Neutral slate used for inactive navigation icons and labels.
const _inactiveNav = Color(0xFF8A99B0);

class DashboardShell extends ConsumerWidget {
  const DashboardShell({required this.child, super.key});
  final Widget child;

  /// Identifies the phone bottom navigation bar (used by widget tests).
  static const bottomNavKey = ValueKey('dashboard-bottom-nav');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = dashboardDestinationIndex(location);
    final name = ref.watch(authControllerProvider).value?.session?.displayName;
    final isDark = AppColors.isDark(context);
    final appBar = AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
      titleSpacing: AppSpacing.md,
      title: const DoctyliaLogo(width: 132, height: 42),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: DashboardTokens.border(context)),
      ),
      actions: [
        _IconChip(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onPressed: () => context.push(RoutePaths.notifications),
        ),
        const SizedBox(width: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Builder(
            builder: (buttonContext) => Tooltip(
              message: 'Profile menu',
              child: InkWell(
                onTap: () => Scaffold.of(buttonContext).openEndDrawer(),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: _ProfileAvatar(name: name, size: 32),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return DashboardShadcnScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 840) {
            return _KeyboardBackScope(
              child: _wideScaffold(context, ref, appBar, selected, name),
            );
          }
          return _KeyboardBackScope(
            child: Scaffold(
              appBar: appBar,
              endDrawer: _ProfileDrawer(name: name),
              body: child,
              bottomNavigationBar: _FloatingNavBar(
                selected: selected,
                onDestinationSelected: (index) =>
                    context.go(dashboardDestinations[index].path),
                onCreate: () => showAppointmentForm(context, ref),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wideScaffold(
    BuildContext context,
    WidgetRef ref,
    AppBar appBar,
    int selected,
    String? name,
  ) {
    final railSurface = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    return Scaffold(
      appBar: appBar,
      endDrawer: _ProfileDrawer(name: name),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            labelType: NavigationRailLabelType.all,
            minWidth: 88,
            groupAlignment: -0.9,
            backgroundColor: railSurface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            selectedIconTheme: const IconThemeData(
              color: AppColors.primary,
              size: 22,
            ),
            unselectedIconTheme: const IconThemeData(
              color: _inactiveNav,
              size: 22,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: AppColors.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: _inactiveNav,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            onDestinationSelected: (index) =>
                context.go(dashboardDestinations[index].path),
            leading: const Padding(
              padding: EdgeInsets.only(
                bottom: AppSpacing.lg,
                top: AppSpacing.sm,
              ),
              child: DoctyliaBrandMark(size: 38, showName: false),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _IconChip(
                    icon: Icons.logout_rounded,
                    tooltip: 'Log out',
                    color: AppColors.destructive,
                    onPressed: () => confirmLogout(context, ref),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final item in dashboardDestinations)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
          Container(width: 1, color: DashboardTokens.border(context)),
          Expanded(child: child),
        ],
      ),
    );
  }

  static String _initial(String? name) {
    final value = (name ?? '').replaceFirst(RegExp(r'^Dr\.?\s*'), '').trim();
    return value.isEmpty ? 'D' : value[0].toUpperCase();
  }

  static Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Log out of Doctylia?'),
        content: const Text(
          'You will need to sign in again to access your dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

/// shadcn [shadcn.Avatar] showing the doctor's initial.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.size});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) => shadcn.Avatar(
    initials: DashboardShell._initial(name),
    size: size,
    borderRadius: size * 0.34,
    backgroundColor: AppColors.isDark(context)
        ? AppColors.primary.withValues(alpha: 0.2)
        : AppColors.primary100,
    theme: shadcn.AvatarTheme(
      textStyle: TextStyle(
        color: AppColors.isDark(context)
            ? AppColors.primary400
            : AppColors.primary600,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// A small bordered, rounded-square icon button — the shadcn "outline icon
/// button" look, kept on Material ink so it carries a [Tooltip].
class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: DashboardTokens.border(context)),
            ),
            child: Icon(
              icon,
              size: 19,
              color: color ?? AppColors.onSurface(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation presented as a floating, frosted, bordered card.
///
/// Custom instead of [NavigationBar] because Material's label is an
/// unconstrained `Text` that wraps "Appointments" onto two lines on phones;
/// here every label stays on one line and scales down only if it must.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selected,
    required this.onDestinationSelected,
    required this.onCreate,
  });

  final int selected;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreate;

  static const _items = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    (
      label: 'Appointments',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    (
      label: 'Patients',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
    ),
    (
      label: 'More',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Widget item(int index) {
      final entry = _items[index];
      return Expanded(
        child: _NavBarItem(
          label: entry.label,
          icon: entry.icon,
          selectedIcon: entry.selectedIcon,
          selected: selected == index,
          onTap: () => onDestinationSelected(index),
        ),
      );
    }

    final isDark = AppColors.isDark(context);
    final surface = isDark ? AppColors.darkCard : AppColors.card;
    final radius = BorderRadius.circular(22);
    return SafeArea(
      key: DashboardShell.bottomNavKey,
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: DashboardTokens.blueDeep.withValues(
                  alpha: isDark ? 0.25 : 0.1,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.92),
                  borderRadius: radius,
                  border: Border.all(color: DashboardTokens.border(context)),
                ),
                child: Row(
                  children: [
                    item(0),
                    item(1),
                    Expanded(
                      child: Center(child: _CreateButton(onTap: onCreate)),
                    ),
                    item(2),
                    item(3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      label: 'Add appointment',
      button: true,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary600, DashboardTokens.teal],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.isDark(context)
        ? AppColors.primary400
        : AppColors.primary600;
    final color = selected ? activeColor : _inactiveNav;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 40,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedSwitcher(
                duration: _duration,
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: _duration,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    height: 1.05,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                  child: Text(label, maxLines: 1, softWrap: false),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: _duration,
              width: selected ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDrawer extends ConsumerWidget {
  const _ProfileDrawer({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(themeModeProvider);
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final darkMode =
        selectedMode == ThemeMode.dark ||
        (selectedMode == ThemeMode.system && platformDark);
    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DashboardTokens.radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    DashboardTokens.teal.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  _ProfileAvatar(name: name, size: 48),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name?.trim().isNotEmpty ?? false ? name! : 'Doctor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onSurface(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Practice account',
                          style: TextStyle(
                            color: AppColors.mutedText(context),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profile'),
              subtitle: const Text('View and edit your profile'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('${RoutePaths.settings}?tab=profile');
              },
            ),
            SwitchListTile(
              secondary: Icon(
                darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              ),
              title: const Text('Dark mode'),
              subtitle: Text(
                darkMode ? 'Dark theme enabled' : 'Light theme enabled',
              ),
              value: darkMode,
              onChanged: (value) =>
                  ref.read(themeModeProvider.notifier).setDarkMode(value),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: shadcn.Divider(color: DashboardTokens.border(context)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: BorderSide(
                    color: AppColors.destructive.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onPressed: () async {
                  await DashboardShell.confirmLogout(context, ref);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyboardBackScope extends StatelessWidget {
  const _KeyboardBackScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent ||
          event.logicalKey != LogicalKeyboardKey.backspace) {
        return KeyEventResult.ignored;
      }
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext?.widget is EditableText ||
          focusedContext?.findAncestorWidgetOfExactType<EditableText>() !=
              null) {
        return KeyEventResult.ignored;
      }

      final location = GoRouterState.of(context).matchedLocation;
      if (location.startsWith('${RoutePaths.patients}/')) {
        context.go(RoutePaths.patients);
      } else if (location == RoutePaths.appointments ||
          location == RoutePaths.patients ||
          location == RoutePaths.more) {
        context.go(RoutePaths.dashboard);
      } else if (location != RoutePaths.dashboard && context.canPop()) {
        context.pop();
      } else if (location != RoutePaths.dashboard) {
        context.go(RoutePaths.more);
      }
      return KeyEventResult.handled;
    },
    child: child,
  );
}
