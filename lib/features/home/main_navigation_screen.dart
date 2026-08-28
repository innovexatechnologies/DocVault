import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/pdf_manager_provider.dart';
import '../all_files/all_files_screen.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // ===========================================================================
  // TAB SELECTION
  // ===========================================================================

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final totalFiles =
        context.watch<PdfManagerProvider>().totalCount;

    final backgroundColor = isDark
        ? const Color(0xFF020617)
        : const Color(0xFFF9FAFC);

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },

      child: Scaffold(
        backgroundColor: backgroundColor,

        // =====================================================================
        // SCREENS
        // =====================================================================

        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              onNavigateToAllFiles: () {
                _onTabSelected(1);
              },
            ),

            AllFilesScreen(
              onNavigateToHome: () {
                _onTabSelected(0);
              },
            ),
          ],
        ),

        // =====================================================================
        // BOTTOM NAVIGATION
        // =====================================================================

        bottomNavigationBar: _buildBottomNavigation(
          context,
          isDark: isDark,
          totalFiles: totalFiles,
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM NAVIGATION CONTAINER
  // ===========================================================================

  Widget _buildBottomNavigation(
    BuildContext context, {
    required bool isDark,
    required int totalFiles,
  }) {
    final navigationBackground = isDark
        ? const Color(0xFF0B1020)
        : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF202A42)
        : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: navigationBackground,

        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.28 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),

      child: SafeArea(
        top: false,

        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            10,
          ),

          child: Container(
            height: 62,

            padding: const EdgeInsets.all(5),

            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF101629)
                  : const Color(0xFFF5F6FA),

              borderRadius: BorderRadius.circular(32),

              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E2942)
                    : const Color(0xFFE8EAF0),
              ),
            ),

            child: Row(
              children: [

                // =============================================================
                // CONVERT
                // =============================================================

                Expanded(
                  child: _buildNavigationItem(
                    context,
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Convert',
                    isSelected: _currentIndex == 0,
                    isDark: isDark,
                  ),
                ),

                // =============================================================
                // ALL FILES
                // =============================================================

                Expanded(
                  child: _buildNavigationItem(
                    context,
                    index: 1,
                    icon: Icons.folder_outlined,
                    activeIcon: Icons.folder_rounded,
                    label: 'All Files',
                    badgeCount: totalFiles,
                    isSelected: _currentIndex == 1,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // NAVIGATION ITEM
  // ===========================================================================

  Widget _buildNavigationItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
    int? badgeCount,
  }) {
    final inactiveColor = isDark
        ? const Color(0xFFB2B8C8)
        : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () {
        _onTabSelected(index);
      },

      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 250,
        ),

        curve: Curves.easeOutCubic,

        height: 52,

        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF6D4AFF),
                    Color(0xFF8B5CF6),
                    Color(0xFF9B4DFF),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,

          color: isSelected
              ? null
              : Colors.transparent,

          borderRadius:
              BorderRadius.circular(28),

          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(
                      0xFF7C3AED,
                    ).withValues(
                      alpha: isDark
                          ? 0.22
                          : 0.15,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),

        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                // =============================================================
                // ICON + BADGE
                // =============================================================

                Stack(
                  clipBehavior: Clip.none,
                  children: [

                    Icon(
                      isSelected
                          ? activeIcon
                          : icon,

                      color: isSelected
                          ? Colors.white
                          : inactiveColor,

                      size: 24,
                    ),

                    // BADGE
                    if (badgeCount != null &&
                        badgeCount > 0)
                      Positioned(
                        top: -7,
                        right: -9,

                        child: Container(
                          constraints:
                              const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),

                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),

                          decoration:
                              BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : const Color(
                                    0xFF8B5CF6,
                                  ),

                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),

                            border: isSelected
                                ? Border.all(
                                    color:
                                        const Color(
                                      0xFF7C3AED,
                                    ),
                                    width: 1,
                                  )
                                : null,
                          ),

                          child: Text(
                            badgeCount > 99
                                ? '99+'
                                : '$badgeCount',

                            textAlign:
                                TextAlign.center,

                            style: TextStyle(
                              color: isSelected
                                  ? const Color(
                                      0xFF7C3AED,
                                    )
                                  : Colors.white,

                              fontSize: 9,

                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 8),

                // =============================================================
                // LABEL
                // =============================================================

                Text(
                  label,

                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : inactiveColor,

                    fontSize: 14,

                    fontWeight: isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,

                    letterSpacing: -0.1,
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