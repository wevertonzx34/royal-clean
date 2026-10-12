import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core_royal_clean/services/admin_access_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import 'contacts_performance_royal_clean.dart';
import 'public_activity_index_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';

/// Dedicated app-only contact overview; ERP screens retain their own source.
class PerformanceOverviewPageRoyalClean extends StatelessWidget {
  final Stream<AdminAccessRoyalClean> Function() accessStream;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? load;
  final bool publicView;
  const PerformanceOverviewPageRoyalClean({
    super.key,
    this.accessStream = watchAdminAccessRoyalClean,
    this.load,
    this.publicView = true,
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBAA2FF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF092F43),
    ),
    child: publicView && load == null
        ? _page(context, publicIndex: true)
        : AdminRouteGuardRoyalClean(
            firebaseInitialization: Firebase.apps.isNotEmpty || load != null
                ? Future<void>.value()
                : Future<void>.error(
                    StateError('Firebase ainda não inicializado.'),
                  ),
            accessStream: accessStream,
            builder: (context) => _page(context, publicIndex: false),
          ),
  );

  Widget _page(BuildContext context, {required bool publicIndex}) => Scaffold(
    key: const ValueKey('performance-overview-page'),
    appBar: AppBar(
      backgroundColor: const Color(0xFF092F43),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: LayoutButtonRoyalClean(
        id: 'performance.overview.back',
        child: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      title: const Text('Desempenho'),
    ),
    body: SafeArea(
      top: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              if (publicIndex)
                const PublicActivityIndexRoyalClean()
              else
                ContactsPerformanceRoyalClean(load: load),
              if (publicIndex && Firebase.apps.isNotEmpty)
                StreamBuilder<AdminAccessRoyalClean>(
                  stream: accessStream(),
                  builder: (context, access) =>
                      access.data == AdminAccessRoyalClean.allowed
                      ? LayoutButtonRoyalClean(
                          id: 'performance.overview.admin.contacts',
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            label: const Text('Contatos • área administrativa'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PerformanceOverviewPageRoyalClean(
                                      publicView: false,
                                      accessStream: accessStream,
                                    ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
