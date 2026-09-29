import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'image_action_royal_clean.dart';
import '../home/profile_images_royal_clean.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import 'home_background_royal_clean.dart';
import '../auth/logout_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import 'home_form_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import 'dashboard_chart_royal_clean.dart';
import 'overview_shortcut_royal_clean.dart';
import 'neon_image_royal_clean.dart';
import 'stock_functions_page_royal_clean.dart';
import 'door_light_royal_clean.dart';
import 'door_invitation_royal_clean.dart';
import 'shortcut_vapor_royal_clean.dart';
import 'avatar_aura_royal_clean.dart';
import 'my_property_page_royal_clean.dart';

class HomePageRoyalClean extends StatefulWidget {
  const HomePageRoyalClean({super.key});
  @override
  State<HomePageRoyalClean> createState() => _HomePageState();
}

class _HomePageState extends State<HomePageRoyalClean> {
  final _overviewOpen = ValueNotifier<bool>(false);
  Future<void>? _imagesReady;
  bool _openingStock = false;
  bool _openingProperty = false;
  int _dataReplay = 0;
  bool _wasOverviewOpen = false;
  @override
  void initState() {
    super.initState();
    _overviewOpen.addListener(_overviewChanged);
  }

  void _overviewChanged() {
    if (_wasOverviewOpen && !_overviewOpen.value) {
      setState(() => _dataReplay++);
    }
    _wasOverviewOpen = _overviewOpen.value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _imagesReady ??= precacheProfileImagesRoyalClean(context);
  }

  @override
  void dispose() {
    _overviewOpen.dispose();
    super.dispose();
  }

  Future<void> _openStock(BuildContext context) async {
    if (_openingStock) return;
    _openingStock = true;
    try {
      await _imagesReady;
      if (!context.mounted) return;
      final route = PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, animation, secondaryAnimation) =>
            AdminRouteGuardRoyalClean(
              pendingBackground: const StockBackgroundRoyalClean(),
              firebaseInitialization: Future<void>.value(),
              builder: (_) => const StockFunctionsPageRoyalClean(),
            ),
      );
      await Navigator.of(context).push(route);
      // Replay the door lights only after the return transition finishes.
      await route.completed;
    } finally {
      _openingStock = false;
    }
  }

  Future<void> _openActions(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminRouteGuardRoyalClean(
          firebaseInitialization: Future<void>.value(),
          builder: (_) => const _AdminActionsPage(),
        ),
      ),
    );
  }

  Future<void> _openProperty(BuildContext context) async {
    if (_openingProperty) return;
    _openingProperty = true;
    try {
      await _imagesReady;
      if (!context.mounted) return;
      final route = PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, animation, secondaryAnimation) =>
            AdminRouteGuardRoyalClean(
              pendingBackground: const MyPropertyBackgroundRoyalClean(),
              firebaseInitialization: Future<void>.value(),
              builder: (_) => const MyPropertyPageRoyalClean(),
            ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      _openingProperty = false;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _overviewOpen,
    builder: (context, overviewOpen, _) => PopScope(
      canPop: !overviewOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && overviewOpen) _overviewOpen.value = false;
      },
      child: Scaffold(
        body: HomeBackgroundRoyalClean(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 70% maior, preservando a proporção 282 x 603 e a posição.
                const avatarScale = 1.7;
                final avatarHeight =
                    avatarScale *
                    math.min(
                      603.0,
                      math.min(
                        constraints.maxHeight * .28,
                        constraints.maxWidth * .25 * 603 / 282,
                      ),
                    );
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: constraints.maxWidth * .97,
                          height: constraints.maxHeight * .97,
                          child: OverviewShortcutRoyalClean(
                            onHomeActivate: () => _openProperty(context),
                            height: constraints.maxHeight * .97,
                            openState: _overviewOpen,
                            overlayTopInset: math.max(
                              // Keep the panel below the relocated 48px actions.
                              64 + constraints.maxHeight * .065,
                              8 + constraints.maxHeight * .10,
                            ),
                            foreground: Positioned(
                              left: 14 + constraints.maxWidth * .105,
                              bottom: 12 + constraints.maxHeight * .145,
                              child: SizedBox(
                                height: avatarHeight * 1.1 * 1.05 * .7 * .97,
                                width:
                                    avatarHeight *
                                    1.1 *
                                    1.05 *
                                    .7 *
                                    .97 *
                                    1397 /
                                    2272,
                                child: Tooltip(
                                  message: 'Abrir funções de estoque',
                                  child: Semantics(
                                    button: true,
                                    label: 'Abrir funções de estoque',
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: LayoutButtonRoyalClean(
                                        id: 'home_page_royal_clean.control_01',
                                        child: ImageActionRoyalClean(
                                          key: const ValueKey(
                                            'stock-door-shortcut',
                                          ),
                                          pulses: 3,
                                          replayAfterActivation: true,
                                          duration: const Duration(
                                            milliseconds: 900,
                                          ),
                                          scaleDepth: .018,
                                          onActivate: () async {
                                            _overviewOpen.value = false;
                                            await _openStock(context);
                                          },
                                          builder: (_, flash) => Stack(
                                            fit: StackFit.expand,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned.fill(
                                                child: ShortcutVaporRoyalClean(
                                                  activation: flash,
                                                  isDoor: true,
                                                ),
                                              ),
                                              Image.asset(
                                                'assets/preview/royal-store/royal-porta.webp',
                                                fit: BoxFit.contain,
                                                cacheWidth: 900,
                                              ),
                                              DoorLightRoyalClean(
                                                activation: flash,
                                              ),
                                              const DoorInvitationRoyalClean(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: DashboardChartRoyalClean(
                              availableHeight: constraints.maxHeight,
                              overlaySurface: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!overviewOpen)
                      Positioned(
                        right: 14,
                        bottom: 12 + constraints.maxHeight * .07,
                        child: SizedBox(
                          width: avatarHeight * 282 / 603,
                          child: Tooltip(
                            message: 'Abrir funções administrativas',
                            child: Semantics(
                              button: true,
                              label: 'Abrir funções administrativas',
                              child: Material(
                                type: MaterialType.transparency,
                                child: LayoutButtonRoyalClean(
                                  id: 'home_page_royal_clean.control_02',
                                  child: ImageActionRoyalClean(
                                    key: const ValueKey(
                                      'admin-avatar-shortcut',
                                    ),
                                    pulses: 2,
                                    duration: const Duration(milliseconds: 600),
                                    scaleDepth: .018,
                                    onActivate: () async {
                                      _overviewOpen.value = false;
                                      await _openActions(context);
                                    },
                                    builder: (_, flash) => Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: AvatarAuraRoyalClean(
                                            activation: flash,
                                          ),
                                        ),
                                        NeonImageRoyalClean(
                                          activation: flash,
                                          asset:
                                              'assets/preview/royal-store/royal-avatar.webp',
                                          aspectRatio: 282 / 603,
                                          glow: const Color(0xFF5CE7EC),
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
                    Positioned(
                      // Light column plus 2% of the screen width to the right.
                      key: const ValueKey('profile-data-position'),
                      left:
                          constraints.maxWidth * (.015 + .97 * .35 + .02) - 50,
                      top: constraints.maxHeight * (.015 + .97 * .25),
                      width: 100,
                      height: 100,
                      child: Visibility(
                        visible: !overviewOpen,
                        maintainState: true,
                        child: Tooltip(
                          message: 'Visão geral',
                          child: Semantics(
                            button: true,
                            label: 'Abrir Visão geral',
                            child: LayoutButtonRoyalClean(
                              id: 'home_page_royal_clean.control_03',
                              child: ImageActionRoyalClean(
                                key: const ValueKey('profile-data-shortcut'),
                                pulses: 2,
                                replayVersion: _dataReplay,
                                duration: const Duration(milliseconds: 600),
                                scaleDepth: .018,
                                onActivate: () => _overviewOpen.value = true,
                                builder: (_, flash) => NeonImageRoyalClean(
                                  asset:
                                      'assets/preview/royal-store/royal-dados.webp',
                                  aspectRatio: 1,
                                  cacheWidth: 300,
                                  glow: const Color(0xFF5CE7EC),
                                  activation: flash,
                                  activationGlow: const Color(0xFFC05AFF),
                                  activationSecondaryGlow: const Color(
                                    0xFF1623A8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8 + constraints.maxHeight * .08,
                      right: 14,
                      child: const Material(
                        type: MaterialType.transparency,
                        child: HeaderActionsRoyalClean(
                          color: Color(0xFFF5F7FA),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _AdminActionsPage extends StatelessWidget {
  const _AdminActionsPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Painel administrativo'),
      actions: const [HeaderActionsRoyalClean()],
    ),
    body: HomeBackgroundRoyalClean(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: HomeFormRoyalClean(
                onAccessControlPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutesRoyalClean.accessControl,
                ),
                onLogoutPressed: () => logoutToPreviewRoyalClean(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
