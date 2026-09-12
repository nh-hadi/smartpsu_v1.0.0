import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/psu_telemetry.dart';

enum ConnectionStatus { disconnected, searching, connected }

class UdpService extends ChangeNotifier {
  PsuTelemetry _latestTelemetry = PsuTelemetry();
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _espIp = '192.168.4.1';
  int _pollingIntervalMs = 100; // Strict continuous 100ms (10Hz)
  bool _isDemoMode = false;
  int _latencyMs = 0;

  Timer? _pollingTimer;
  Timer? _simTimer;
  bool _isRequestInProgress = false;
  DateTime _lastSuccessResponseTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Energy & Trip Telemetry Statistics
  double _peakVoltage = 0.0;
  double _peakCurrent = 0.0;
  double _peakPower = 0.0;
  double _totalEnergyMWh = 0.0;
  double _totalCapacityMah = 0.0;
  DateTime _lastTimestamp = DateTime.now();

  // Sliding window buffer (80 samples = 8 seconds of continuous 100ms history)
  final List<PsuTelemetry> _telemetryHistory = [];

  // Terminal logs
  final List<String> _terminalLogs = [
    '[SYSTEM] Smart PSU v1.0.0 High-Speed 100ms Engine active.',
    '[SYSTEM] Continuous 60FPS fluid simulation & intake.',
  ];

  // Getters
  PsuTelemetry get telemetry => _latestTelemetry;
  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  String get espIp => _espIp;
  int get pollingIntervalMs => _pollingIntervalMs;
  bool get isDemoMode => _isDemoMode;
  int get latencyMs => _latencyMs;
  double get peakVoltage => _peakVoltage;
  double get peakCurrent => _peakCurrent;
  double get peakPower => _peakPower;
  double get totalEnergyMWh => _totalEnergyMWh;
  double get totalCapacityMah => _totalCapacityMah;
  List<PsuTelemetry> get history => List.unmodifiable(_telemetryHistory);
  List<String> get terminalLogs => List.unmodifiable(_terminalLogs);

  void setEspIp(String ip) {
    final cleanIp = ip.trim().replaceAll('http://', '').replaceAll('/', '');
    if (cleanIp.isNotEmpty && cleanIp != _espIp) {
      _espIp = cleanIp;
      startListening();
      notifyListeners();
    }
  }

  void setPollingInterval(int ms) {
    _pollingIntervalMs = ms.clamp(100, 1000);
    startListening();
  }

  void setDemoMode(bool enable) {
    _isDemoMode = enable;
    notifyListeners();
  }

  void startListening() {
    stopListening();
    _status = _isDemoMode ? ConnectionStatus.connected : ConnectionStatus.searching;
    notifyListeners();

    // 1. Continuous Non-Blocking UI Stream
    _simTimer = Timer.periodic(Duration(milliseconds: _pollingIntervalMs), (_) {
      final now = DateTime.now();
      final dtHours = now.difference(_lastTimestamp).inMilliseconds / 3600000.0;
      _lastTimestamp = now;

      final isHardwareActive = now.difference(_lastSuccessResponseTime).inMilliseconds < 1200;

      if (!isHardwareActive || _isDemoMode) {
        _simulateTelemetry(dtHours);
      }
    });

    // 2. Asynchronous Hardware Poller
    _pollingTimer = Timer.periodic(Duration(milliseconds: _pollingIntervalMs), (_) {
      if (!_isDemoMode) {
        _fetchTelemetryAsync();
      }
    });
  }

  void _fetchTelemetryAsync() async {
    if (_isRequestInProgress) return;
    _isRequestInProgress = true;

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('http://$_espIp/data');
      final response = await http.get(uri).timeout(const Duration(milliseconds: 900));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final parsed = PsuTelemetry.tryParse(response.body);
        if (parsed != null) {
          _lastSuccessResponseTime = DateTime.now();
          _latencyMs = stopwatch.elapsedMilliseconds;
          _latestTelemetry = parsed;
          if (_status != ConnectionStatus.connected) {
            _status = ConnectionStatus.connected;
          }

          final now = DateTime.now();
          final dtHours = (now.difference(_lastTimestamp).inMilliseconds.clamp(1, 300)) / 3600000.0;
          _integrateEnergy(dtHours, parsed);
          _recordHistory(parsed);
          notifyListeners();
        }
      } else {
        _handleDisconnect();
      }
    } catch (_) {
      _handleDisconnect();
    } finally {
      _isRequestInProgress = false;
    }
  }

  void _simulateTelemetry(double dtHours) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sinVal = math.sin(nowMs / 1000.0);
    final cosVal = math.cos(nowMs / 800.0);

    final sim = PsuTelemetry(
      v1: double.parse((12.0 + (sinVal * 0.15) + (math.Random().nextDouble() * 0.03)).toStringAsFixed(2)),
      i1: double.parse((1250 + (cosVal * 120) + (math.Random().nextDouble() * 12)).toStringAsFixed(1)),
      v2: double.parse((5.02 + (sinVal * 0.06) + (math.Random().nextDouble() * 0.02)).toStringAsFixed(2)),
      i2: double.parse((850 + (cosVal * 80) + (math.Random().nextDouble() * 10)).toStringAsFixed(1)),
      v3: double.parse((9.10 + (sinVal * 0.1) + (math.Random().nextDouble() * 0.03)).toStringAsFixed(2)),
      i3: double.parse((1650 + (cosVal * 150) + (math.Random().nextDouble() * 20)).toStringAsFixed(1)),
      dm: double.parse((0.60 + math.Random().nextDouble() * 0.02).toStringAsFixed(2)),
      dp: double.parse((3.30 + math.Random().nextDouble() * 0.03).toStringAsFixed(2)),
      avo: double.parse((4.98 + math.Random().nextDouble() * 0.04).toStringAsFixed(2)),
      mosfet: _latestTelemetry.mosfet,
      relay1: _latestTelemetry.relay1,
      relay2: _latestTelemetry.relay2,
    );

    _latestTelemetry = sim;
    _integrateEnergy(dtHours, sim);
    _recordHistory(sim);
    notifyListeners();
  }

  void _integrateEnergy(double dtHours, PsuTelemetry t) {
    final activeCurrentMa = t.i1;
    final activeVoltage = t.v1;
    final powerWatts = activeVoltage * (activeCurrentMa / 1000.0);

    _totalCapacityMah += (activeCurrentMa * dtHours);
    _totalEnergyMWh += (powerWatts * 1000.0 * dtHours);

    // Track peak stats
    final maxV = [t.v1, t.v2, t.v3, t.avo].reduce((a, b) => a > b ? a : b);
    final maxI = [t.i1, t.i2, t.i3].reduce((a, b) => a > b ? a : b);
    final curP = t.totalPower;

    if (maxV > _peakVoltage) _peakVoltage = maxV;
    if (maxI > _peakCurrent) _peakCurrent = maxI;
    if (curP > _peakPower) _peakPower = curP;
  }

  void _recordHistory(PsuTelemetry t) {
    _telemetryHistory.add(t);
    if (_telemetryHistory.length > 80) {
      _telemetryHistory.removeAt(0);
    }
  }

  void _handleDisconnect() {
    if (_status == ConnectionStatus.connected) {
      _status = ConnectionStatus.searching;
      notifyListeners();
    }
  }

  Future<void> sendCommand(String target, bool state) async {
    final val = state ? 1 : 0;
    
    _latestTelemetry = PsuTelemetry(
      v1: _latestTelemetry.v1,
      i1: _latestTelemetry.i1,
      v2: _latestTelemetry.v2,
      i2: _latestTelemetry.i2,
      v3: _latestTelemetry.v3,
      i3: _latestTelemetry.i3,
      dm: _latestTelemetry.dm,
      dp: _latestTelemetry.dp,
      avo: _latestTelemetry.avo,
      mosfet: (target == 'mosfet' || target == 'all') ? state : _latestTelemetry.mosfet,
      relay1: (target == 'relay1' || target == 'all') ? state : _latestTelemetry.relay1,
      relay2: (target == 'relay2' || target == 'all') ? state : _latestTelemetry.relay2,
    );
    notifyListeners();

    addTerminalLog('[CMD] ${target.toUpperCase()} -> ${state ? "ON" : "OFF"}');

    if (!_isDemoMode) {
      try {
        final uri = Uri.parse('http://$_espIp/cmd?set=$target&val=$val');
        await http.get(uri).timeout(const Duration(milliseconds: 300));
        _fetchTelemetryAsync();
      } catch (e) {
        addTerminalLog('[ERR] Gagal mengirim perintah ke $_espIp');
      }
    }
  }

  void toggleMosfet() => sendCommand('mosfet', !_latestTelemetry.mosfet);
  void toggleRelay1() => sendCommand('relay1', !_latestTelemetry.relay1);
  void toggleRelay2() => sendCommand('relay2', !_latestTelemetry.relay2);
  
  void toggleAllSwitches() {
    final anyOn = _latestTelemetry.mosfet || _latestTelemetry.relay1 || _latestTelemetry.relay2;
    sendCommand('all', !anyOn);
  }

  void resetTripStats() {
    _peakVoltage = 0.0;
    _peakCurrent = 0.0;
    _peakPower = 0.0;
    _totalEnergyMWh = 0.0;
    _totalCapacityMah = 0.0;
    notifyListeners();
  }

  void addTerminalLog(String message) {
    _terminalLogs.add(message);
    if (_terminalLogs.length > 100) {
      _terminalLogs.removeAt(0);
    }
    notifyListeners();
  }

  void clearTerminalLogs() {
    _terminalLogs.clear();
    notifyListeners();
  }

  Future<void> sendRawTerminalCommand(String cmd) async {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;
    addTerminalLog('> $trimmed');

    if (trimmed.toLowerCase() == 'clear') {
      clearTerminalLogs();
      return;
    }

    if (trimmed.toLowerCase() == 'mosfet on') { toggleMosfet(); return; }
    if (trimmed.toLowerCase() == 'mosfet off') { toggleMosfet(); return; }
    if (trimmed.toLowerCase() == 'relay1 on') { toggleRelay1(); return; }
    if (trimmed.toLowerCase() == 'relay1 off') { toggleRelay1(); return; }
    if (trimmed.toLowerCase() == 'relay2 on') { toggleRelay2(); return; }
    if (trimmed.toLowerCase() == 'relay2 off') { toggleRelay2(); return; }

    try {
      final uri = Uri.parse('http://$_espIp/test?msg=${Uri.encodeComponent(trimmed)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      addTerminalLog('[RESP] ${res.body}');
    } catch (e) {
      addTerminalLog('[ERR] Tidak dapat terhubung ke $_espIp ($e)');
    }
  }

  Future<Map<String, dynamic>> testConnection(String customMessage) async {
    final stopwatch = Stopwatch()..start();
    
    // 1. Coba endpoint /test
    try {
      final uri = Uri.parse('http://$_espIp/test?msg=${Uri.encodeComponent(customMessage)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
      stopwatch.stop();

      if (response.statusCode == 200) {
        _status = ConnectionStatus.connected;
        _lastSuccessResponseTime = DateTime.now();
        _latencyMs = stopwatch.elapsedMilliseconds;
        notifyListeners();
        _fetchTelemetryAsync();
        return {
          'success': true,
          'latency_ms': stopwatch.elapsedMilliseconds,
          'body': response.body,
          'sent': customMessage,
        };
      }
    } catch (_) {
      // Lanjut coba /ping jika /test belum ready
    }

    // 2. Fallback: Coba endpoint /ping
    try {
      final pingUri = Uri.parse('http://$_espIp/ping');
      final pingRes = await http.get(pingUri).timeout(const Duration(seconds: 2));
      stopwatch.stop();

      if (pingRes.statusCode == 200) {
        _status = ConnectionStatus.connected;
        _lastSuccessResponseTime = DateTime.now();
        _latencyMs = stopwatch.elapsedMilliseconds;
        notifyListeners();
        _fetchTelemetryAsync();
        return {
          'success': true,
          'latency_ms': stopwatch.elapsedMilliseconds,
          'body': pingRes.body,
          'sent': 'PING (/ping)',
        };
      }
    } catch (_) {
      // Lanjut coba /data
    }

    // 3. Fallback: Coba endpoint /data
    try {
      final dataUri = Uri.parse('http://$_espIp/data');
      final dataRes = await http.get(dataUri).timeout(const Duration(seconds: 2));
      stopwatch.stop();

      if (dataRes.statusCode == 200) {
        final parsed = PsuTelemetry.tryParse(dataRes.body);
        if (parsed != null) {
          _latestTelemetry = parsed;
          _status = ConnectionStatus.connected;
          _lastSuccessResponseTime = DateTime.now();
          _latencyMs = stopwatch.elapsedMilliseconds;
          notifyListeners();
          return {
            'success': true,
            'latency_ms': stopwatch.elapsedMilliseconds,
            'body': dataRes.body,
            'sent': 'DATA (/data)',
          };
        }
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latency_ms': stopwatch.elapsedMilliseconds,
        'error': '$e',
        'sent': customMessage,
      };
    }

    stopwatch.stop();
    return {
      'success': false,
      'latency_ms': stopwatch.elapsedMilliseconds,
      'error': 'Gagal terhubung ke $_espIp (Tidak ada respon dari ESP)',
      'sent': customMessage,
    };
  }

  void stopListening() {
    _pollingTimer?.cancel();
    _simTimer?.cancel();
    _pollingTimer = null;
    _simTimer = null;
    _status = ConnectionStatus.disconnected;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
