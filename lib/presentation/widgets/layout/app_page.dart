import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../common/app_text.dart';
import '../motion/motion.dart';

/// Which of the app's two established looks a page wears.
enum AppPageStyle {
  /// The Settings look without the tall photo: artwork backdrop, an app bar
  /// that turns white as you scroll, an animated title block, and content that
  /// slides in card by card. The right choice for almost every new page.
  content,

  /// The Settings look in full: a pinned photo hero that pans and collapses
  /// into the app bar. For landing pages of a section that deserve a picture.
  hero,

  /// The Home look: full-bleed artwork under a transparent app bar. The page
  /// supplies its own header as the first child, the way the dashboard does.
  home,
}

/// The default shell for every page: pass a [title] and [children] and it
/// looks like the rest of the app, with the same backdrop, motion, safe-area
/// padding and reduced-motion behaviour, and no per-page animation code.
///
/// ```dart
/// AppPage(
///   title: AppCopy.clients,
///   children: [AppCard(...), AppCard(...)],
/// )
/// ```
///
/// Reach for [AppPage.hero] or [AppPage.home] only when the page is a section
/// landing page. Pages with a long lazy list pass [slivers] instead of
/// [children]. [BackdropPage] remains for screens that must keep their own
/// scaffold; new screens should use this.
class AppPage extends StatefulWidget {
  const AppPage({
    super.key,
    required this.title,
    this.children,
    this.slivers,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
    this.bottomBar,
    this.onRefresh,
    this.reveal = true,
    this.maxContentWidth = 700,
    this.backdrop = defaultBackdrop,
  })  : style = AppPageStyle.content,
        heroAsset = null,
        heroStart = null,
        heroEnd = null,
        assert((children == null) != (slivers == null),
            'Pass either children or slivers.');

  const AppPage.hero({
    super.key,
    required this.title,
    this.children,
    this.slivers,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
    this.bottomBar,
    this.onRefresh,
    this.reveal = true,
    this.maxContentWidth = 700,
    this.backdrop = defaultBackdrop,
    this.heroAsset = defaultHeroAsset,
    this.heroStart = const Alignment(0, -0.05),
    this.heroEnd = const Alignment(-0.2, 0.95),
  })  : style = AppPageStyle.hero,
        assert((children == null) != (slivers == null),
            'Pass either children or slivers.');

  const AppPage.home({
    super.key,
    required this.title,
    this.children,
    this.slivers,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
    this.bottomBar,
    this.onRefresh,
    this.reveal = false,
    this.maxContentWidth = double.infinity,
    this.backdrop = homeBackdrop,
  })  : style = AppPageStyle.home,
        eyebrow = null,
        subtitle = null,
        heroAsset = null,
        heroStart = null,
        heroEnd = null,
        assert((children == null) != (slivers == null),
            'Pass either children or slivers.');

  static const defaultBackdrop = 'assets/backgrounds/bg_body.webp';
  static const homeBackdrop = 'assets/backgrounds/bg_home_neutral.png';
  static const defaultHeroAsset = 'assets/backgrounds/bg_settings.webp';

  final AppPageStyle style;

  /// Shown in the title block and, once you scroll, in the app bar.
  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// Page content as plain widgets; they are laid out in a centred column of
  /// at most [maxContentWidth] and, when [reveal] is on, slide in one by one.
  final List<Widget>? children;

  /// Page content as slivers, for long lazy lists. Not wrapped or revealed.
  final List<Widget>? slivers;

  final List<Widget> actions;

  /// Defaults to the platform back arrow when the page was pushed.
  final Widget? leading;
  final Widget? floatingActionButton;

  /// Pinned under the page, e.g. a `BottomActionBar`.
  final Widget? bottomBar;

  /// Adds pull-to-refresh.
  final Future<void> Function()? onRefresh;
  final bool reveal;
  final double maxContentWidth;
  final String backdrop;

  final String? heroAsset;
  final Alignment? heroStart;
  final Alignment? heroEnd;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> with SingleTickerProviderStateMixin {
  late final AmbientController _ambient = AmbientController(vsync: this);

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  bool get _isHome => widget.style == AppPageStyle.home;
  bool get _isHero => widget.style == AppPageStyle.hero;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final barHeight = media.padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // The hero brings its own collapsing toolbar; every other style uses a
      // regular app bar that starts clear and turns white as content passes
      // under it.
      appBar: _isHero ? null : _buildAppBar(),
      body: AmbientListener(
        controller: _ambient,
        child: Stack(
          children: [
            Positioned.fill(child: _buildBackdrop()),
            if (!_isHome)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.background.withValues(alpha: 0.22),
                ),
              ),
            // Home keeps the sparkles behind its cards; the Settings look lets
            // them drift across the top.
            if (_isHome)
              Positioned.fill(child: AmbientGlints(controller: _ambient)),
            Positioned.fill(child: _buildScroll(context, barHeight, media)),
            if (!_isHome)
              Positioned.fill(child: AmbientGlints(controller: _ambient)),
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: Center(child: ScrollRail(controller: _ambient)),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomBar,
    );
  }

  Widget _buildBackdrop() {
    if (_isHome) {
      return AmbientImage(
        controller: _ambient,
        asset: widget.backdrop,
        alignment: const Alignment(0.85, -0.15),
      );
    }
    // The wide artwork stays behind the whole page, sliding across as you
    // scroll, so nothing ever falls back to a flat colour.
    return AmbientImage(
      controller: _ambient,
      asset: widget.backdrop,
      zoom: 1.0,
      panFrom: const Alignment(-0.6, 0),
      panTo: const Alignment(0.75, 0.1),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final solid = (_ambient.scrollOffset / 80).clamp(0.0, 1.0);
          // On content pages the title block already names the page, so the
          // bar only repeats it once that block has scrolled away.
          final titleIn = _isHome
              ? 1.0
              : ((_ambient.scrollOffset - 40) / 50).clamp(0.0, 1.0);
          return AppBar(
            backgroundColor: Colors.white.withValues(alpha: solid),
            scrolledUnderElevation: 0,
            elevation: 0,
            shape: Border(
              bottom: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.5 * solid),
              ),
            ),
            leading: widget.leading,
            title: Opacity(opacity: titleIn, child: AppText(widget.title)),
            actions: widget.actions,
          );
        },
      ),
    );
  }

  Widget _buildScroll(
      BuildContext context, double barHeight, MediaQueryData media) {
    final bottomInset = media.viewPadding.bottom +
        (widget.floatingActionButton != null ? 88 : 24);

    final slivers = <Widget>[
      if (_isHero) _buildHero(media),
      if (!_isHero) SliverToBoxAdapter(child: SizedBox(height: barHeight + 8)),
      if (!_isHome)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: AnimatedTitle(
              eyebrow: widget.eyebrow,
              title: widget.title,
              subtitle: widget.subtitle,
            ),
          ),
        ),
      if (widget.children != null) _buildChildren(),
      ...?widget.slivers,
      SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
    ];

    final scroll = CustomScrollView(slivers: slivers);
    if (widget.onRefresh == null) return scroll;
    return RefreshIndicator(
      edgeOffset: _isHero ? media.padding.top + kToolbarHeight : barHeight,
      onRefresh: widget.onRefresh!,
      child: scroll,
    );
  }

  Widget _buildHero(MediaQueryData media) {
    final top = media.padding.top;
    final expanded = (media.size.height * 0.34).clamp(240.0, 320.0).toDouble();
    return SliverPersistentHeader(
      pinned: true,
      delegate: HeroHeaderDelegate(
        asset: widget.heroAsset ?? AppPage.defaultHeroAsset,
        title: widget.title,
        // The artwork carries the branding; the title sits below it instead.
        showTitle: false,
        expanded: expanded,
        collapsed: top + kToolbarHeight,
        topPadding: top,
        controller: _ambient,
        startAlignment: widget.heroStart ?? const Alignment(0, -0.05),
        endAlignment: widget.heroEnd ?? const Alignment(-0.2, 0.95),
        foreground: AppColors.textPrimary,
        scrim: AppColors.background,
        scrimStrength: 0,
        fadeBottom: true,
        leading: widget.leading ??
            (Navigator.of(context).canPop() ? const BackButton() : null),
        actions: widget.actions,
      ),
    );
  }

  Widget _buildChildren() {
    final items = widget.children!;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, _isHome ? 0 : 12, 16, 0),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
              child: items[i],
            ),
          );
          return widget.reveal ? Reveal(index: i, child: item) : item;
        },
      ),
    );
  }
}
