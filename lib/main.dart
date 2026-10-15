import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/loaders.dart';
import 'models/card.dart';
import 'models/rules.dart';
import 'screens/cards_screen.dart';
import 'screens/my_cards_screen.dart';
import 'screens/phase_screen.dart';
import 'state/nav.dart';
import 'state/phase_state.dart';
import 'state/settings.dart';
import 'state/tracker.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ValeApp());
}

class AppData {
  const AppData(this.cards, this.rules, this.prefs);
  final List<GameCard> cards;
  final Rules rules;
  final SharedPreferences prefs;
}

Future<AppData> loadAppData() async => AppData(
      await loadCards(rootBundle),
      await loadRules(rootBundle),
      await SharedPreferences.getInstance(),
    );

class ValeApp extends StatefulWidget {
  const ValeApp({super.key, this.loader = loadAppData});

  final Future<AppData> Function() loader;

  @override
  State<ValeApp> createState() => _ValeAppState();
}

class _ValeAppState extends State<ValeApp> {
  late final Future<AppData> _data = widget.loader();

  static Widget _app(Widget home) => MaterialApp(
        title: 'Vale Helper',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Palette.light, Brightness.light),
        darkTheme: buildTheme(Palette.dark, Brightness.dark),
        home: home,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppData>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return _app(Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load card data:\n${snap.error}', textAlign: TextAlign.center),
              ),
            ),
          ));
        }
        final d = snap.data;
        if (d == null) return _app(const Scaffold(body: Center(child: CircularProgressIndicator())));
        // Providers sit above MaterialApp so pushed routes (card detail) can read them.
        return MultiProvider(
          providers: [
            Provider.value(value: d.cards),
            Provider.value(value: d.rules),
            ChangeNotifierProvider(create: (_) => Tracker(d.prefs)),
            ChangeNotifierProvider(create: (_) => Nav()),
            ChangeNotifierProvider(create: (_) => Settings(d.prefs)),
            ChangeNotifierProvider(
                create: (_) => PhaseState(d.prefs, phaseCount: d.rules.phases.length)),
          ],
          child: _app(const HomeShell()),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final Nav _nav = context.read<Nav>();
  late final PageController _pages = PageController(initialPage: _nav.tab);

  @override
  void initState() {
    super.initState();
    _nav.addListener(_syncPage);
  }

  @override
  void dispose() {
    _nav.removeListener(_syncPage);
    _pages.dispose();
    super.dispose();
  }

  /// Follows tab changes requested elsewhere (nav bar, card detail's My Cards button).
  void _syncPage() {
    if (_pages.hasClients && _pages.page?.round() != _nav.tab) {
      _pages.animateToPage(_nav.tab,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<Tracker>();
    final tab = context.watch<Nav>().tab;
    final tracked = tracker.total;
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Swipe left/right to move between tabs.
        child: PageView(
          controller: _pages,
          onPageChanged: _nav.goTo,
          children: const [
            _KeepAlive(CardsScreen()),
            _KeepAlive(MyCardsScreen()),
            _KeepAlive(PhaseScreen()),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.surface2))),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: s.contains(WidgetState.selected) ? p.text : p.muted,
                )),
            iconTheme: WidgetStateProperty.resolveWith(
                (s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? p.text : p.muted)),
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: Color.lerp(p.bg, p.surface, 0.45),
            indicatorColor: p.surface2,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: tab,
            onDestinationSelected: _nav.goTo,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.style_rounded), label: 'Cards'),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: tracked > 0,
                  backgroundColor: p.badge,
                  textColor: p.onAccent,
                  label: Text('$tracked', style: const TextStyle(fontWeight: FontWeight.w800)),
                  child: const Icon(Icons.back_hand_rounded),
                ),
                label: 'My cards',
              ),
              const NavigationDestination(icon: Icon(Icons.flag_rounded), label: 'Round'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a tab's state (filters, scroll position) while swiping between tabs.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive(this.child);
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
