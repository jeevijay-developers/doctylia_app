import 'dart:convert';

import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Cloudflare Turnstile, matching the web (src/components/shared/
/// TurnstileWidget.tsx).
///
/// Supabase Auth has CAPTCHA protection enabled, so every OTP send, password
/// login and password-reset request must carry a fresh, single-use token
/// (`captchaToken`), exactly like the web's login/signup form.
abstract final class TurnstileConfig {
  /// Public sitekey — the same one the web uses. Override at build time with
  /// `--dart-define=TURNSTILE_SITE_KEY=...`.
  static const siteKey = String.fromEnvironment(
    'TURNSTILE_SITE_KEY',
    defaultValue: '0x4AAAAAAEIBVX_7AEWMtPMj',
  );

  /// The widget page is served under the web's origin: the sitekey only
  /// renders on its allowed hostnames.
  static final baseUrl = Uri.parse('https://doctylia.com/');
}

/// The sitekey when Turnstile is active, or null to skip it. Null by
/// default (tests, mock flavor); bootstrap enables it for the real app.
final turnstileSiteKeyProvider = Provider<String?>((ref) => null);

/// Whether a real WebView can host the challenge. Override with false where
/// no WebView implementation exists (widget tests): the widget then renders
/// an inert placeholder and tokens arrive via [TurnstileWidget.onToken].
final turnstileWebViewProvider = Provider<bool>((ref) => true);

/// Shared token handling for screens that send auth requests: hold the
/// latest token, refuse to send without one (the web's message), and hand
/// it out once — tokens are single-use — re-arming the widget each time.
mixin TurnstileGate<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final turnstile = TurnstileController();
  String _captcha = '';

  /// The web's "Please complete the verification check." while blocking.
  String? captchaError;

  /// True (and sets [captchaError]) when a token is required but missing.
  bool captchaMissing() {
    if (ref.read(turnstileSiteKeyProvider) == null || _captcha.isNotEmpty) {
      return false;
    }
    setState(() => captchaError = 'Please complete the verification check.');
    return true;
  }

  /// The token for one request (null when Turnstile is off).
  String? spendCaptcha() {
    final token = _captcha.isEmpty ? null : _captcha;
    _captcha = '';
    turnstile.reset();
    return token;
  }

  /// Pass to [TurnstileWidget.onToken].
  void onCaptcha(String token) {
    if (!mounted) return;
    setState(() {
      _captcha = token;
      if (token.isNotEmpty) captchaError = null;
    });
  }

  /// Spacing helper: true when the widget is shown at all.
  bool get captchaEnabled => ref.watch(turnstileSiteKeyProvider) != null;
}

/// Lets a screen reset the widget after its token has been spent.
class TurnstileController {
  _TurnstileWidgetState? _state;

  /// Discards the current token and issues a fresh challenge.
  void reset() => _state?._reset();
}

/// Inline Turnstile challenge. Usually passes invisibly within a second or
/// two; may ask the user to tap a checkbox. Reports the token (or "" when it
/// expires / errors) through [onToken].
class TurnstileWidget extends ConsumerStatefulWidget {
  const TurnstileWidget({
    required this.action,
    required this.onToken,
    this.controller,
    super.key,
  });

  /// Same action names as the web ("login", "signup").
  final String action;
  final ValueChanged<String> onToken;
  final TurnstileController? controller;

  @override
  ConsumerState<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends ConsumerState<TurnstileWidget> {
  WebViewController? _web;
  String? _loadedFor;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(TurnstileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  void _reset() {
    widget.onToken('');
    if (_failed) {
      setState(() {
        _failed = false;
        _loadedFor = null;
      });
      return;
    }
    _web?.runJavaScript('resetTurnstile()');
  }

  void _onMessage(JavaScriptMessage message) {
    final text = message.message;
    if (text.startsWith('token:')) {
      widget.onToken(text.substring(6));
    } else if (text == 'expired') {
      widget.onToken('');
    } else if (text.startsWith('error')) {
      widget.onToken('');
      if (mounted) setState(() => _failed = true);
    }
  }

  WebViewController _controllerFor(String siteKey, Brightness brightness) {
    final key = '$siteKey|${widget.action}|${brightness.name}';
    if (_web != null && _loadedFor == key) return _web!;
    _loadedFor = key;
    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('TurnstileBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Keep the page in place; links inside the widget (Cloudflare
          // privacy / terms) open in the browser instead.
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.isMainFrame &&
                uri != null &&
                uri.host != TurnstileConfig.baseUrl.host &&
                uri.scheme.startsWith('http')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(
        _html(siteKey, widget.action, brightness),
        baseUrl: TurnstileConfig.baseUrl.toString(),
      );
    _web = web;
    return web;
  }

  @override
  Widget build(BuildContext context) {
    final siteKey = ref.watch(turnstileSiteKeyProvider);
    if (siteKey == null || siteKey.isEmpty) return const SizedBox.shrink();
    if (_failed) {
      return _FailedNotice(onRetry: _reset);
    }
    if (!ref.watch(turnstileWebViewProvider)) {
      return const SizedBox(height: 70);
    }
    final brightness = Theme.of(context).brightness;
    return Semantics(
      label: 'Security verification',
      child: SizedBox(
        height: 70,
        child: WebViewWidget(controller: _controllerFor(siteKey, brightness)),
      ),
    );
  }

  static String _html(String siteKey, String action, Brightness brightness) {
    final options = jsonEncode({
      'sitekey': siteKey,
      'action': action,
      'theme': brightness == Brightness.dark ? 'dark' : 'light',
      'size': 'flexible',
    });
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
  #ts { width: 100%; display: flex; justify-content: center; }
</style>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=onTurnstileLoad" async defer></script>
</head>
<body>
<div id="ts"></div>
<script>
  var widgetId = null;
  function send(message) { TurnstileBridge.postMessage(message); }
  function onTurnstileLoad() {
    var options = $options;
    options.callback = function (token) { send('token:' + token); };
    options['expired-callback'] = function () { send('expired'); };
    options['error-callback'] = function (code) { send('error:' + code); };
    widgetId = turnstile.render('#ts', options);
  }
  function resetTurnstile() {
    if (widgetId !== null && window.turnstile) { turnstile.reset(widgetId); }
  }
  setTimeout(function () { if (!window.turnstile) { send('error:script'); } }, 15000);
</script>
</body>
</html>''';
  }
}

class _FailedNotice extends StatelessWidget {
  const _FailedNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.destructive.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.destructive.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 18,
          color: AppColors.destructive,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Security check could not load. Check your connection.',
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 12.5,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
