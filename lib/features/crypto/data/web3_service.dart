import 'dart:convert';
import 'package:http/http.dart' as http;

class Web3Asset {
  final String symbol;
  final String name;
  final double amount;
  final double priceUsd;
  final double totalUsd;
  final String chain;

  Web3Asset({
    required this.symbol,
    required this.name,
    required this.amount,
    required this.priceUsd,
    required this.totalUsd,
    required this.chain,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'amount': amount,
      'priceUsd': priceUsd,
      'totalUsd': totalUsd,
      'chain': chain,
    };
  }
}

class Web3Service {
  final String? heliusApiKey;

  Web3Service({this.heliusApiKey});

  String get _effectiveHeliusKey {
    if (heliusApiKey != null &&
        heliusApiKey!.trim().isNotEmpty &&
        !heliusApiKey!.contains('your_')) {
      return heliusApiKey!.trim();
    }
    // Ключ за замовчуванням
    return '149afd5c-07e9-4c0d-8e75-d50bbff9d1ab';
  }

  // --- 1. SOLANA: Отримання токенів через Helius RPC searchAssets ---
  Future<List<Web3Asset>> getSolanaAssets(String ownerAddress) async {
    final trimmed = ownerAddress.trim();
    if (trimmed.isEmpty || trimmed.contains('your_')) {
      return [];
    }

    final rpcUrl = Uri.parse(
        'https://mainnet.helius-rpc.com/?api-key=$_effectiveHeliusKey');

    final payload = {
      'jsonrpc': '2.0',
      'id': 'portfolio-scan',
      'method': 'searchAssets',
      'params': {
        'ownerAddress': trimmed,
        'tokenType': 'fungible',
        'page': 1,
        'limit': 50,
      }
    };

    final List<Web3Asset> assets = [];

    try {
      final response = await http
          .post(
            rpcUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['result']?['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          final ti = item['token_info'] as Map<String, dynamic>? ?? {};
          final symbol = ti['symbol']?.toString().toUpperCase();
          if (symbol == null || symbol.isEmpty) continue;

          final balanceRaw = double.tryParse(ti['balance']?.toString() ?? '0') ?? 0.0;
          final decimals = int.tryParse(ti['decimals']?.toString() ?? '0') ?? 0;
          final realAmount = decimals > 0 ? balanceRaw / _pow10(decimals) : balanceRaw;

          final priceInfo = ti['price_info'] as Map<String, dynamic>?;
          final totalPriceUsd = double.tryParse(priceInfo?['total_price']?.toString() ?? '0') ?? 0.0;
          double pricePerToken = double.tryParse(priceInfo?['price_per_token']?.toString() ?? '0') ?? 0.0;
          if (pricePerToken == 0.0 && realAmount > 0) {
            pricePerToken = totalPriceUsd / realAmount;
          }

          if (totalPriceUsd >= 0.01 || realAmount > 0.0001) {
            final metadata = item['content']?['metadata'] as Map<String, dynamic>?;
            final name = metadata?['name']?.toString() ?? symbol;

            assets.add(Web3Asset(
              symbol: symbol,
              name: name,
              amount: realAmount,
              priceUsd: pricePerToken,
              totalUsd: totalPriceUsd,
              chain: 'SOLANA',
            ));
          }
        }
      }

      // Також перевіряємо нативний SOL баланс через getBalance
      final solPayload = {
        'jsonrpc': '2.0',
        'id': 'sol-native-bal',
        'method': 'getBalance',
        'params': [trimmed]
      };

      final solResp = await http
          .post(
            rpcUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(solPayload),
          )
          .timeout(const Duration(seconds: 8));

      if (solResp.statusCode == 200) {
        final solData = json.decode(solResp.body);
        final lamports = double.tryParse(solData['result']?['value']?.toString() ?? '0') ?? 0.0;
        final solAmount = lamports / 1000000000.0;

        if (solAmount > 0.0001) {
          // Якщо SOL ще немає в списку
          final existingIdx = assets.indexWhere((a) => a.symbol == 'SOL');
          if (existingIdx == -1) {
            assets.insert(
              0,
              Web3Asset(
                symbol: 'SOL',
                name: 'Solana',
                amount: solAmount,
                priceUsd: 0.0, // ціна підтягнеться в pricing_service
                totalUsd: 0.0,
                chain: 'SOLANA',
              ),
            );
          }
        }
      }

      assets.sort((a, b) => b.totalUsd.compareTo(a.totalUsd));
    } catch (_) {
      // Помилка мережі
    }

    return assets;
  }

  // --- 2. EVM (Ethereum / BSC через Ethplorer) ---
  Future<List<Web3Asset>> getEvmAssets(String walletAddress) async {
    final trimmed = walletAddress.trim();
    if (trimmed.isEmpty || trimmed.contains('your_')) {
      return [];
    }

    final url = Uri.parse(
        'https://api.ethplorer.io/getAddressInfo/$trimmed?apiKey=freekey');
    final List<Web3Asset> assets = [];

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 1. Нативний ETH
        final ethData = data['ETH'] as Map<String, dynamic>? ?? {};
        final ethBal = double.tryParse(ethData['balance']?.toString() ?? '0') ?? 0.0;
        final ethRate = double.tryParse(ethData['price']?['rate']?.toString() ?? '0') ?? 0.0;
        final ethUsd = ethBal * ethRate;

        if (ethBal > 0.0001) {
          assets.add(Web3Asset(
            symbol: 'ETH',
            name: 'Ethereum',
            amount: ethBal,
            priceUsd: ethRate,
            totalUsd: ethUsd,
            chain: 'ETHEREUM',
          ));
        }

        // 2. Токени ERC-20
        final tokens = data['tokens'] as List<dynamic>? ?? [];
        for (final t in tokens) {
          final tinfo = t['tokenInfo'] as Map<String, dynamic>? ?? {};
          final sym = (tinfo['symbol']?.toString() ?? 'UNKNOWN').toUpperCase();
          final rawBal = double.tryParse(t['balance']?.toString() ?? '0') ?? 0.0;
          final dec = int.tryParse(tinfo['decimals']?.toString() ?? '0') ?? 0;
          final amount = dec > 0 ? rawBal / _pow10(dec) : rawBal;

          final rate = double.tryParse(tinfo['price']?['rate']?.toString() ?? '0') ?? 0.0;
          final valUsd = amount * rate;

          // Фільтр спаму: залишаємо активи дорожче $0.1 або суттєву кількість токенів
          if (valUsd >= 0.1 || (amount > 0.01 && rate > 0)) {
            assets.add(Web3Asset(
              symbol: sym,
              name: tinfo['name']?.toString() ?? sym,
              amount: amount,
              priceUsd: rate,
              totalUsd: valUsd,
              chain: 'ETHEREUM',
            ));
          }
        }

        assets.sort((a, b) => b.totalUsd.compareTo(a.totalUsd));
      }
    } catch (_) {
      // Помилка мережі
    }

    return assets;
  }

  static double _pow10(int exp) {
    double res = 1.0;
    for (int i = 0; i < exp; i++) {
      res *= 10.0;
    }
    return res;
  }
}
