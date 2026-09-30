import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tracks whether the server is reachable.
///
/// connectivity_plus only tells us whether a network interface is up; a phone
/// can be on WiFi with no internet, so we additionally probe the API host.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  /// Injectable for tests.
  http.Client client = http.Client();

  bool _online = true;
  bool _hasInterface = true;
  String? _baseUrl;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _probeTimer;
  DateTime? _lastProbe;

  bool get isOnline => _online;
  bool get hasInterface => _hasInterface;

  /// Called by the sync service whenever we transition offline → online.
  final List<VoidCallback> _onlineListeners = [];
  void addOnlineListener(VoidCallback cb) => _onlineListeners.add(cb);
  void removeOnlineListener(VoidCallback cb) => _onlineListeners.remove(cb);

  Future<void> init() async {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) {
      _hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!_hasInterface) {
        _set(false);
      } else {
        // Interface came up — verify the server actually answers.
        probe(force: true);
      }
    });
    final initial = await Connectivity().checkConnectivity();
    _hasInterface = initial.any((r) => r != ConnectivityResult.none);
    if (!_hasInterface) _set(false);
    // Periodic re-check so a flaky link recovers without user action.
    _probeTimer ??= Timer.periodic(const Duration(seconds: 45), (_) => probe());
  }

  void setBaseUrl(String? url) {
    _baseUrl = url;
    if (url != null) probe(force: true);
  }

  /// Report a network failure observed by an API call.
  void reportFailure() => _set(false);

  /// Report a successful API round-trip.
  void reportSuccess() => _set(true);

  /// Probe the API host. Any HTTP response (even 404) means reachable.
  Future<bool> probe({bool force = false}) async {
    final url = _baseUrl;
    if (url == null) return _online;
    if (!_hasInterface) {
      _set(false);
      return false;
    }
    final now = DateTime.now();
    if (!force &&
        _lastProbe != null &&
        now.difference(_lastProbe!) < const Duration(seconds: 10)) {
      return _online;
    }
    _lastProbe = now;
    try {
      await client
          .get(Uri.parse('$url/ping.php'))
          .timeout(const Duration(seconds: 6));
      _set(true);
    } catch (_) {
      _set(false);
    }
    return _online;
  }

  void _set(bool v) {
    if (_online == v) return;
    _online = v;
    notifyListeners();
    if (v) {
      for (final cb in List.of(_onlineListeners)) {
        cb();
      }
    }
  }

  /// Tests: stop the periodic probe without disposing the singleton.
  void stopBackgroundTimers() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _probeTimer?.cancel();
    super.dispose();
  }
}
