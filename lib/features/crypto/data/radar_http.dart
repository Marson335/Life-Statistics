import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// HTTP-хелпер для Binance: повтори з експоненційною паузою, повага до 429/418 (Retry-After),
/// таймаути та кеш денних свічок (денна свічка змінюється раз на добу — немає сенсу
/// завантажувати 200 монет × 365 свічок при кожному скані).
class RadarHttp {
  static const String baseUrl = 'https://api.binance.com';

  /// Кеш сирих відповідей klines: ключ → (час завантаження, тіло).
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration klinesTtl = Duration(minutes: 45);

  static void clearCache() => _cache.clear();

  /// GET із повторами. Повертає null, якщо всі спроби невдалі.
  /// [onRateLimited] викликається при 429/418, щоб сканер міг показати це користувачу.
  static Future<http.Response?> getWithRetry(
    Uri uri, {
    int attempts = 3,
    Duration timeout = const Duration(seconds: 10),
    void Function()? onRateLimited,
  }) async {
    for (int attempt = 0; attempt < attempts; attempt++) {
      try {
        final resp = await http.get(uri).timeout(timeout);
        if (resp.statusCode == 200) return resp;

        if (resp.statusCode == 429 || resp.statusCode == 418) {
          onRateLimited?.call();
          final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '') ?? (2 << attempt);
          await Future.delayed(Duration(seconds: math.min(retryAfter, 20)));
          continue;
        }
        // 4xx (окрім лімітів) — повтор не допоможе (напр. невідомий символ)
        if (resp.statusCode >= 400 && resp.statusCode < 500) return null;
      } on TimeoutException {
        // повтор нижче
      } catch (_) {
        // мережева помилка — повтор нижче
      }
      if (attempt < attempts - 1) {
        await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
      }
    }
    return null;
  }

  /// Денні свічки з кешем. Повертає декодований список або null.
  static Future<List<dynamic>?> fetchDailyKlines(
    String pair,
    int limit, {
    void Function()? onRateLimited,
    bool useCache = true,
  }) async {
    final key = '$pair|$limit';
    final cached = _cache[key];
    if (useCache && cached != null && DateTime.now().difference(cached.at) < klinesTtl) {
      return cached.data;
    }
    final resp = await getWithRetry(
      Uri.parse('$baseUrl/api/v3/klines?symbol=$pair&interval=1d&limit=$limit'),
      onRateLimited: onRateLimited,
    );
    if (resp == null) return cached?.data; // краще застарілі дані, ніж жодних
    try {
      final data = json.decode(resp.body) as List<dynamic>;
      _cache[key] = _CacheEntry(DateTime.now(), data);
      return data;
    } catch (_) {
      return cached?.data;
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.at, this.data);
  final DateTime at;
  final List<dynamic> data;
}
