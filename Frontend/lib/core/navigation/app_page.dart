import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

/// Transizioni di pagina dell'app.
///
/// Le Cupertino di default (su iPhone e Mac) fanno scorrere anche la pagina
/// sotto, in parallasse: sul web, con pagine pesanti, al ritorno si vedeva
/// uno slide a destra seguito da uno a sinistra, a scatti. Qui entra/esce solo
/// la pagina in cima, con dissolvenza e un breve scorrimento: poco da disegnare.
class AppPage<T> extends Page<T> {
  final Widget child;

  const AppPage({required this.child, super.key, super.name, super.arguments, super.restorationId});

  @override
  Route<T> createRoute(BuildContext context) => _AppPageRoute<T>(this);
}

class _AppPageRoute<T> extends PageRoute<T> {
  _AppPageRoute(AppPage<T> page) : super(settings: page);

  AppPage<T> get _page => settings as AppPage<T>;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  @override
  bool didPop(T? result) {
    // Indietro dal browser (gesto di Safari, tasto di Android): il browser ha
    // gia' mostrato la pagina precedente, rifare l'uscita animata la farebbe
    // ricomparire per un attimo. Si toglie e basta.
    if (BrowserBack.consume()) controller?.reverseDuration = Duration.zero;
    return super.didPop(result);
  }
}

/// Riconosce i "back" arrivati dal browser (popstate) e non dall'app.
class BrowserBack {
  static DateTime? _at;

  static void install() {
    web.window.addEventListener(
      'popstate',
      ((web.Event _) {
        _at = DateTime.now();
      }).toJS,
    );
  }

  /// true se un popstate e' appena arrivato; lo consuma.
  static bool consume() {
    final at = _at;
    _at = null;
    return at != null && DateTime.now().difference(at) < const Duration(milliseconds: 500);
  }
}

extension BackNavigation on BuildContext {
  /// Indietro verso la schermata da cui si e' arrivati; [fallback] solo se
  /// sotto non c'e' niente (link diretto, notifica aperta a freddo).
  void popOr(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
