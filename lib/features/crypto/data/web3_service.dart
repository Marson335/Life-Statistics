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

  Web3Asset copyWith({
    String? symbol,
    String? name,
    double? amount,
    double? priceUsd,
    double? totalUsd,
    String? chain,
  }) {
    return Web3Asset(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      priceUsd: priceUsd ?? this.priceUsd,
      totalUsd: totalUsd ?? this.totalUsd,
      chain: chain ?? this.chain,
    );
  }

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
    return '149afd5c-07e9-4c0d-8e75-d50bbff9d1ab';
  }

  // --- 1. SOLANA: Отримання токенів та SOL через Helius RPC / Fallback ---
  Future<List<Web3Asset>> getSolanaAssets(String ownerAddress) async {
    final trimmed = ownerAddress.trim();
    if (trimmed.isEmpty || trimmed.contains('your_') || trimmed.length < 32) {
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

    // 1.1 Спроба завантажити SPL токени через Helius searchAssets
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
          if (pricePerToken == 0.0 && realAmount > 0 && totalPriceUsd > 0) {
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
    } catch (_) {}

    // 1.2 Отримання нативного SOL балансу (через Helius або публічний RPC fallback)
    double solAmount = 0.0;
    try {
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
        solAmount = lamports / 1000000000.0;
      }
    } catch (_) {}

    // Fallback на публічний Solana RPC якщо Helius не відповів
    if (solAmount == 0.0) {
      try {
        final fallbackResp = await http.post(
          Uri.parse('https://api.mainnet-beta.solana.com'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getBalance',
            'params': [trimmed]
          }),
        ).timeout(const Duration(seconds: 8));
        if (fallbackResp.statusCode == 200) {
          final solData = json.decode(fallbackResp.body);
          final lamports = double.tryParse(solData['result']?['value']?.toString() ?? '0') ?? 0.0;
          solAmount = lamports / 1000000000.0;
        }
      } catch (_) {}
    }

    if (solAmount > 0.0001) {
      final existingIdx = assets.indexWhere((a) => a.symbol == 'SOL');
      if (existingIdx == -1) {
        assets.insert(
          0,
          Web3Asset(
            symbol: 'SOL',
            name: 'Solana',
            amount: solAmount,
            priceUsd: 0.0, // Збагатиться автоматично ціною з біржі
            totalUsd: 0.0,
            chain: 'SOLANA',
          ),
        );
      }
    }

    assets.sort((a, b) => b.totalUsd.compareTo(a.totalUsd));
    return assets;
  }

  // --- 2. EVM (Ethereum / MetaMask / Trust Wallet) ---
  Future<List<Web3Asset>> getEvmAssets(String walletAddress) async {
    final trimmed = walletAddress.trim();
    if (trimmed.isEmpty ||
        trimmed.contains('your_') ||
        !trimmed.toLowerCase().startsWith('0x') ||
        trimmed.length < 40) {
      return [];
    }

    final List<Web3Asset> assets = [];
    double totalEthAmount = 0.0;
    double ethRate = 0.0;
    double totalBtcAmount = 0.0;

    // 2.1 Спроба отримати дані через Ethplorer (Ethereum Mainnet)
    try {
      final url = Uri.parse('https://api.ethplorer.io/getAddressInfo/$trimmed?apiKey=freekey');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Нативний ETH на Mainnet
        final ethData = data['ETH'] as Map<String, dynamic>? ?? {};
        final ethBal = double.tryParse(ethData['balance']?.toString() ?? '0') ?? 0.0;
        final ethPriceVal = ethData['price'];
        if (ethPriceVal is Map<String, dynamic>) {
          ethRate = double.tryParse(ethPriceVal['rate']?.toString() ?? '0') ?? 0.0;
        }
        if (ethBal > 0.0001) {
          totalEthAmount += ethBal;
        }

        // Токени ERC-20
        final tokens = data['tokens'] as List<dynamic>? ?? [];
        for (final t in tokens) {
          if (t is! Map<String, dynamic>) continue;
          final tinfo = t['tokenInfo'] as Map<String, dynamic>? ?? {};
          final sym = (tinfo['symbol']?.toString() ?? 'UNKNOWN').toUpperCase();
          final rawBal = double.tryParse(t['balance']?.toString() ?? '0') ?? 0.0;
          final dec = int.tryParse(tinfo['decimals']?.toString() ?? '0') ?? 0;
          final amount = dec > 0 ? rawBal / _pow10(dec) : rawBal;

          double rate = 0.0;
          final priceVal = tinfo['price'];
          if (priceVal is Map<String, dynamic>) {
            rate = double.tryParse(priceVal['rate']?.toString() ?? '0') ?? 0.0;
          }
          final valUsd = amount * rate;

          if (sym == 'WBTC' || sym == 'BTCB' || sym == 'TBTC') {
            totalBtcAmount += amount;
          } else {
            final isMajorToken = sym == 'USDT' || sym == 'USDC' || sym == 'DAI';
            if (valUsd >= 0.1 || (amount > 0.0001 && (rate > 0 || isMajorToken))) {
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
        }
      }
    } catch (_) {}

    // 2.2 Перевірка популярних EVM мереж у MetaMask (Ethereum, Arbitrum, Base, BSC)
    try {
      final results = await Future.wait([
        // Ethereum Mainnet fallback
        totalEthAmount <= 0.0001
            ? _getEvmNativeBalance('https://ethereum-rpc.publicnode.com', trimmed)
            : Future.value(0.0),
        // Arbitrum One ETH
        _getEvmNativeBalance('https://arb1.arbitrum.io/rpc', trimmed),
        // Base ETH
        _getEvmNativeBalance('https://mainnet.base.org', trimmed),
        // Arbitrum WBTC
        _getErc20Balance('https://arb1.arbitrum.io/rpc', '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f', trimmed, 8),
        // Base cbBTC
        _getErc20Balance('https://mainnet.base.org', '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf', trimmed, 8),
        // BSC BTCB
        _getErc20Balance('https://bsc-rpc.publicnode.com', '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c', trimmed, 18),
        // BSC ETH
        _getErc20Balance('https://bsc-rpc.publicnode.com', '0x2170Ed0880ac9A755fd29B2688956BD959F933F8', trimmed, 18),
        // Ethereum Mainnet WBTC (якщо Ethplorer не помітив)
        totalBtcAmount <= 0.00001
            ? _getErc20Balance('https://ethereum-rpc.publicnode.com', '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599', trimmed, 8)
            : Future.value(0.0),
      ]);

      final ethMainFallback = results[0];
      final arbEth = results[1];
      final baseEth = results[2];
      final arbWbtc = results[3];
      final baseCbBtc = results[4];
      final bscBtcb = results[5];
      final bscEth = results[6];
      final ethWbtcFallback = results[7];

      totalEthAmount += ethMainFallback + arbEth + baseEth + bscEth;
      totalBtcAmount += arbWbtc + baseCbBtc + bscBtcb + ethWbtcFallback;
    } catch (_) {}

    // Додаємо ETH, якщо виявлено баланс
    if (totalEthAmount > 0.0001) {
      assets.insert(
        0,
        Web3Asset(
          symbol: 'ETH',
          name: 'Ethereum (MetaMask)',
          amount: totalEthAmount,
          priceUsd: ethRate,
          totalUsd: ethRate > 0 ? (totalEthAmount * ethRate) : 0.0,
          chain: 'EVM',
        ),
      );
    }

    // Додаємо Bitcoin з MetaMask (WBTC / BTCB / cbBTC)
    if (totalBtcAmount > 0.000001) {
      assets.insert(
        0,
        Web3Asset(
          symbol: 'BTC',
          name: 'Bitcoin (MetaMask / EVM)',
          amount: totalBtcAmount,
          priceUsd: 0.0, // Підтягнеться автоматично з ринку
          totalUsd: 0.0,
          chain: 'EVM',
        ),
      );
    }

    assets.sort((a, b) => b.totalUsd.compareTo(a.totalUsd));
    return assets;
  }

  Future<double> _getEvmNativeBalance(String rpcUrl, String address) async {
    try {
      final resp = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_getBalance',
          'params': [address, 'latest']
        }),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final hex = data['result']?.toString();
        if (hex != null && hex.startsWith('0x')) {
          final wei = BigInt.tryParse(hex.substring(2), radix: 16) ?? BigInt.zero;
          return wei.toDouble() / 1e18;
        }
      }
    } catch (_) {}
    return 0.0;
  }

  Future<double> _getErc20Balance(String rpcUrl, String tokenContract, String walletAddress, int decimals) async {
    try {
      final cleanAddr = walletAddress.toLowerCase().startsWith('0x')
          ? walletAddress.substring(2)
          : walletAddress;
      final padded = cleanAddr.padLeft(64, '0');
      final data = '0x70a08231$padded';
      final resp = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_call',
          'params': [
            {'to': tokenContract, 'data': data},
            'latest'
          ]
        }),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final resData = json.decode(resp.body);
        final hex = resData['result']?.toString();
        if (hex != null && hex.startsWith('0x')) {
          final raw = BigInt.tryParse(hex.substring(2), radix: 16) ?? BigInt.zero;
          return raw.toDouble() / _pow10(decimals);
        }
      }
    } catch (_) {}
    return 0.0;
  }

  // --- 3. BITCOIN: Отримання On-chain балансу через mempool.space & fallbacks ---
  Future<List<Web3Asset>> getBtcAssets(String btcAddress) async {
    final trimmed = btcAddress.trim();
    if (trimmed.isEmpty || trimmed.contains('your_') || trimmed.length < 26) {
      return [];
    }

    final List<Web3Asset> assets = [];

    try {
      final url = Uri.parse('https://mempool.space/api/address/$trimmed');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chainStats = data['chain_stats'] as Map<String, dynamic>? ?? {};
        final funded = double.tryParse(chainStats['funded_txo_sum']?.toString() ?? '0') ?? 0.0;
        final spent = double.tryParse(chainStats['spent_txo_sum']?.toString() ?? '0') ?? 0.0;
        final satoshis = funded - spent;
        final btcAmount = satoshis / 100000000.0;

        if (btcAmount > 0.000001) {
          assets.add(Web3Asset(
            symbol: 'BTC',
            name: 'Bitcoin (On-chain)',
            amount: btcAmount,
            priceUsd: 0.0, // Підтягнеться з priceMap
            totalUsd: 0.0,
            chain: 'BITCOIN',
          ));
        }
      }
    } catch (_) {
      // Fallback 1: blockstream.info
      try {
        final bsUrl = Uri.parse('https://blockstream.info/api/address/$trimmed');
        final bsResp = await http.get(bsUrl).timeout(const Duration(seconds: 8));
        if (bsResp.statusCode == 200) {
          final data = json.decode(bsResp.body);
          final chainStats = data['chain_stats'] as Map<String, dynamic>? ?? {};
          final funded = double.tryParse(chainStats['funded_txo_sum']?.toString() ?? '0') ?? 0.0;
          final spent = double.tryParse(chainStats['spent_txo_sum']?.toString() ?? '0') ?? 0.0;
          final satoshis = funded - spent;
          final btcAmount = satoshis / 100000000.0;
          if (btcAmount > 0.000001) {
            assets.add(Web3Asset(
              symbol: 'BTC',
              name: 'Bitcoin (On-chain)',
              amount: btcAmount,
              priceUsd: 0.0,
              totalUsd: 0.0,
              chain: 'BITCOIN',
            ));
          }
        }
      } catch (_) {
        // Fallback 2: blockchain.info
        try {
          final fallbackUrl = Uri.parse('https://blockchain.info/rawaddr/$trimmed?cors=true');
          final fbResp = await http.get(fallbackUrl).timeout(const Duration(seconds: 8));
          if (fbResp.statusCode == 200) {
            final data = json.decode(fbResp.body);
            final finalBal = double.tryParse(data['final_balance']?.toString() ?? '0') ?? 0.0;
            final btcAmount = finalBal / 100000000.0;
            if (btcAmount > 0.000001) {
              assets.add(Web3Asset(
                symbol: 'BTC',
                name: 'Bitcoin (On-chain)',
                amount: btcAmount,
                priceUsd: 0.0,
                totalUsd: 0.0,
                chain: 'BITCOIN',
              ));
            }
          }
        } catch (_) {}
      }
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
