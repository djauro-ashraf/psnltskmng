import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/page_side_toggle.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_screen.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The screen of one s, one ch, or one part (an s inside a ch), in the Info
/// mode (in the Quran mode `ScopeScreen` opens its pages instead). It shows the
/// unit's info (complete, worst state, all pages at least D3; a merged ch also
/// its shared state) and its navigation together, then its notes. The Info |
/// Quran switch under the title is the one of a page screen: Quran goes to the
/// pages of the unit.
///
/// Supports seamless swipe navigation between sibling items, in the reading
/// direction (with the text running right to left, swiping right on ch 1 goes
/// to ch 2, swiping left goes backward, etc.).
class ScopeDetailPage extends ConsumerStatefulWidget {
  const ScopeDetailPage({
    super.key,
    required this.scope,
    required this.location,
  });

  final BrowseScope scope;

  /// This screen's own location; the next screen is a child of it.
  final String location;

  @override
  ConsumerState<ScopeDetailPage> createState() => _ScopeDetailPageState();
}

class _ScopeDetailPageState extends ConsumerState<ScopeDetailPage> {
  late PageController _controller;
  late int _currentIndex;
  late int _itemCount;
  late List<BrowseScope> _scopes;
  late List<String> _locations;

  @override
  void initState() {
    super.initState();
    _initScopes();
    _controller = PageController(initialPage: _currentIndex);
  }

  void _initScopes() {
    final scope = widget.scope;
    final location = widget.location;

    switch (scope) {
      case SScope(:final s):
        _itemCount = BrowseIndex.sCount;
        _currentIndex = s - 1;
        _scopes = [for (var i = 1; i <= _itemCount; i++) SScope(i)];
        _locations = [for (var i = 1; i <= _itemCount; i++) '/browse/ss/$i'];
      case ChScope(:final ch):
        _itemCount = BrowseIndex.chCount;
        _currentIndex = ch - 1;
        _scopes = [for (var i = 1; i <= _itemCount; i++) ChScope(i)];
        _locations = [for (var i = 1; i <= _itemCount; i++) '/browse/ch/$i'];
      case PartScope(:final part):
        List<BrowsePart> siblings = const [];
        if (location.contains('/ss/${part.s}/ch/')) {
          siblings = BrowseIndex.instance.children(SScope(part.s));
        } else if (location.contains('/ch/${part.ch}/ss/')) {
          siblings = BrowseIndex.instance.children(ChScope(part.ch));
        }

        if (siblings.isNotEmpty) {
          _itemCount = siblings.length;
          _currentIndex = siblings.indexWhere(
            (p) => p.s == part.s && p.ch == part.ch,
          );
          if (_currentIndex < 0) _currentIndex = 0;
          _scopes = [for (final p in siblings) PartScope(p)];
          if (location.contains('/ss/${part.s}/ch/')) {
            _locations = [
              for (final p in siblings) '/browse/ss/${part.s}/ch/${p.ch}',
            ];
          } else {
            _locations = [
              for (final p in siblings) '/browse/ch/${part.ch}/ss/${p.s}',
            ];
          }
        } else {
          _itemCount = 1;
          _currentIndex = 0;
          _scopes = [PartScope(part)];
          _locations = [location];
        }
    }
  }

  @override
  void didUpdateWidget(covariant ScopeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scope != oldWidget.scope || widget.location != oldWidget.location) {
      _initScopes();
      if (_controller.hasClients && _controller.page?.round() != _currentIndex) {
        _controller.jumpToPage(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (mounted && index < _locations.length) {
      GoRouter.maybeOf(context)?.replace(_locations[index]);
    }
  }

  void _animateTo(int index) {
    if (_controller.hasClients) {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _detailsLocation(BrowseScope currentScope, String currentLocation) {
    if (BrowseIndex.instance.children(currentScope).isEmpty) {
      return '$currentLocation/ps';
    }
    return switch (currentScope) {
      SScope() => '$currentLocation/ch',
      ChScope() => '$currentLocation/ss',
      PartScope() => '$currentLocation/ps',
    };
  }

  String _positionLabel(BrowseScope currentScope, int index) {
    return switch (currentScope) {
      SScope(:final s) => 's $s / $_itemCount',
      ChScope(:final ch) => 'ch $ch / $_itemCount',
      PartScope(:final part) =>
        widget.location.contains('/ss/${part.s}/ch/')
            ? 'ch ${part.ch} (${index + 1}/$_itemCount)'
            : 's ${part.s} (${index + 1}/$_itemCount)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PageView.builder(
      reverse: context.textRunsRightToLeft,
      controller: _controller,
      itemCount: _itemCount,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final currentScope = _scopes[index];
        final currentLocation = _locations[index];

        // A merged ch is one unit: its notes are listed together.
        final merged = currentScope is ChScope &&
            ref.watch(
              browseDataProvider.select(
                (data) => data.isMerged(currentScope.ch),
              ),
            );

        return UnitScreen(
          title: scopeTitle(l10n, currentScope),
          info: ScopeInfoCard(scope: currentScope),
          unit: NoteUnit.of(currentScope, merged: merged),
          positionLabel: _positionLabel(currentScope, index),
          sideToggle: const PageSideToggle(),
          onPrevious: index > 0 ? () => _animateTo(index - 1) : null,
          onNext: index < _itemCount - 1 ? () => _animateTo(index + 1) : null,
          navigation: currentScope.pageCount > 1
              ? FilledButton.tonalIcon(
                  onPressed: () =>
                      context.go(_detailsLocation(currentScope, currentLocation)),
                  icon: const Icon(Icons.unfold_more_rounded),
                  label: Text(l10n.browseMoreDetails),
                )
              : null,
        );
      },
    );
  }
}
