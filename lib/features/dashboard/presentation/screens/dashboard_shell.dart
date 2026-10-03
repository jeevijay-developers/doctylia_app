import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/theme/theme_mode_provider.dart';
import 'package:doctylia_app/core/widgets/doctylia_brand_mark.dart';
import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/dashboard/presentation/navigation/dashboard_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final appBar = AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      title: const DoctyliaLogo(width: 140, height: 44),
      actions: [
        _IconChip(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onPressed: () => context.push(RoutePaths.notifications),
        ),
        const SizedBox(width: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Builder(
            builder: (buttonContext) => Tooltip(
              message: 'Profile menu',
              child: InkWell(
                onTap: () => Scaffold.of(buttonContext).openEndDrawer(),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary100,
                    foregroundColor: AppColors.primary600,
                    child: Text(
                      _initial(name),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
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
    );
  }

  Widget _wideScaffold(
    BuildContext context,
    WidgetRef ref,
    AppBar appBar,
    int selected,
    String? name,
  ) {
    return Scaffold(
      appBar: appBar,
      endDrawer: _ProfileDrawer(name: name),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.14),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: AppColors.mutedText(context),
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
                ),
            ],
          ),
          VerticalDivider(width: 1, color: AppColors.border(context)),
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

/// A small tinted-circle icon button — the "modern icon" treatment used
/// consistently across the app instead of a bare IconButton.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.08),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Bottom navigation presented as a floating rounded card with a soft
/// shadow, rather than an edge-to-edge flat bar.
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

    return Container(
      key: DashboardShell.bottomNavKey,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              item(0),
              item(1),
              Expanded(
                child: Center(
                  child: Semantics(
                    label: 'Add appointment',
                    button: true,
                    child: GestureDetector(
                      onTap: onCreate,
                      child: Transform.translate(
                        offset: const Offset(0, -10),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(2),
              item(3),
            ],
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

  static const _inactive = Color(0xFF9AAAC0);

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56,
            height: 30,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              selected ? selectedIcon : icon,
              size: 23,
              color: selected ? AppColors.primary : _inactive,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.05,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primary : _inactive,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
      width: 292,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.primary100,
                    foregroundColor: AppColors.primary600,
                    child: Text(
                      DashboardShell._initial(name),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name?.trim().isNotEmpty ?? false ? name! : 'Doctor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
            const Divider(height: 1),
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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: BorderSide(
                    color: AppColors.destructive.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size.fromHeight(48),
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
