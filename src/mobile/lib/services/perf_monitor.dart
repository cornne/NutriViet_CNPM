import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in zero-overhead frame-timing telemetry modeled after VyseTV's perf
/// diagnostics.
///
/// Enable during profiling with:
/// `flutter run --profile --dart-define=NUTRIVIET_PERF=true`
/// or release profiling with `--dart-define=NUTRIVIET_PERF=true`.
/// When disabled (default production builds), [start] is a compile-time no-op.
class NutriVietPerfMonitor {
  NutriVietPerfMonitor._();

  static const bool enabled = bool.fromEnvironment('NUTRIVIET_PERF');
  static const int _flushBatchSize = 60;
  static const int _budget120HzUs = 8333; // 1000ms / 120fps
  static const int _budget60HzUs = 16667; // 1000ms / 60fps

  static bool _attached = false;
  static final List<int> _buildUs = <int>[];
  static final List<int> _rasterUs = <int>[];
  static int _over120Hz = 0;
  static int _over60Hz = 0;
  static int _totalFrames = 0;

  static void start({bool force = false}) {
    if ((!enabled && !force) || _attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    debugPrint('[NV_PERF] FrameTiming monitor enabled (120Hz budget=8.33ms)');
  }

  static void stop() {
    if (!_attached) return;
    _attached = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  @visibleForTesting
  static void reset() {
    _buildUs.clear();
    _rasterUs.clear();
    _over120Hz = 0;
    _over60Hz = 0;
    _totalFrames = 0;
  }

  @visibleForTesting
  static void recordSample({required int buildUs, required int rasterUs}) {
    _totalFrames++;
    _buildUs.add(buildUs);
    _rasterUs.add(rasterUs);
    final total = buildUs + rasterUs;
    if (total > _budget120HzUs) _over120Hz++;
    if (total > _budget60HzUs) _over60Hz++;
  }

  static Map<String, num> snapshot() {
    return <String, num>{
      'frames': _totalFrames,
      'build_avg_ms': _avgMs(_buildUs),
      'build_p95_ms': _percentileMs(_buildUs, 0.95),
      'raster_avg_ms': _avgMs(_rasterUs),
      'raster_p95_ms': _percentileMs(_rasterUs, 0.95),
      'over_120hz': _over120Hz,
      'over_60hz': _over60Hz,
    };
  }

  static void _onFrameTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      recordSample(
        buildUs: t.buildDuration.inMicroseconds,
        rasterUs: t.rasterDuration.inMicroseconds,
      );
    }
    if (_buildUs.length >= _flushBatchSize) {
      _flushSummary();
    }
  }

  static void _flushSummary() {
    if (_buildUs.isEmpty) return;
    final bAvg = _avgMs(_buildUs).toStringAsFixed(2);
    final bP95 = _percentileMs(_buildUs, 0.95).toStringAsFixed(2);
    final bMax = _maxMs(_buildUs).toStringAsFixed(2);
    final rAvg = _avgMs(_rasterUs).toStringAsFixed(2);
    final rP95 = _percentileMs(_rasterUs, 0.95).toStringAsFixed(2);
    final rMax = _maxMs(_rasterUs).toStringAsFixed(2);
    debugPrint(
      '[NV_PERF] batch=${_buildUs.length} total=$_totalFrames '
      'build(avg=${bAvg}ms p95=${bP95}ms max=${bMax}ms) '
      'raster(avg=${rAvg}ms p95=${rP95}ms max=${rMax}ms) '
      '>8.3ms=$_over120Hz >16.7ms=$_over60Hz',
    );
    _buildUs.clear();
    _rasterUs.clear();
  }

  static double _avgMs(List<int> samples) {
    if (samples.isEmpty) return 0.0;
    int sum = 0;
    for (final v in samples) {
      sum += v;
    }
    return (sum / samples.length) / 1000.0;
  }

  static double _maxMs(List<int> samples) {
    if (samples.isEmpty) return 0.0;
    int best = samples.first;
    for (final v in samples) {
      if (v > best) best = v;
    }
    return best / 1000.0;
  }

  static double _percentileMs(List<int> samples, double p) {
    if (samples.isEmpty) return 0.0;
    final sorted = List<int>.from(samples)..sort();
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[idx] / 1000.0;
  }
}

