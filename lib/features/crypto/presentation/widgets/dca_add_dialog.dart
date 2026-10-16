import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';

class DcaAddDialog extends StatefulWidget {
  final Function(DcaTransaction) onAdd;
  final String? initialSymbol;
  final double? initialPrice;
  final String? initialNotes;

  const DcaAddDialog({
    super.key,
    required this.onAdd,
    this.initialSymbol,
    this.initialPrice,
    this.initialNotes,
  });

  @override
  State<DcaAddDialog> createState() => _DcaAddDialogState();
}

class _DcaAddDialogState extends State<DcaAddDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _symbolController;
  final _amountController = TextEditingController();
  late final TextEditingController _priceController;
  final _feeController = TextEditingController(text: '0');
  late final TextEditingController _notesController;

  String _walletType = 'MANUAL';
  final DateTime _txDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: widget.initialSymbol ?? '');
    _priceController = TextEditingController(
      text: (widget.initialPrice != null && widget.initialPrice! > 0)
          ? widget.initialPrice.toString()
          : '',
    );
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _amountController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final symbol = _symbolController.text.trim().toUpperCase();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final buyPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final fee = double.tryParse(_feeController.text.trim()) ?? 0.0;
    final notes = _notesController.text.trim();

    final tx = DcaTransaction(
      id: '',
      symbol: symbol,
      walletType: _walletType,
      amount: amount,
      buyPrice: buyPrice,
      fee: fee,
      txDate: _txDate,
      notes: notes,
    );

    widget.onAdd(tx);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Додати покупку (DCA)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border, height: 20),
                TextFormField(
                  controller: _symbolController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Тікер монети (наприклад: BTC, SOL)',
                    prefixIcon: Icon(Icons.token_rounded, color: AppColors.accent),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Вкажіть символ монети' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Кількість монет',
                    prefixIcon: Icon(Icons.numbers_rounded, color: AppColors.accent),
                  ),
                  validator: (val) {
                    final n = double.tryParse(val ?? '');
                    if (n == null || n <= 0) return 'Введіть число > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ціна покупки (\$ за 1 шт)',
                    prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.accent),
                  ),
                  validator: (val) {
                    final n = double.tryParse(val ?? '');
                    if (n == null || n <= 0) return 'Введіть ціну покупки > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _feeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Комісія (\$)',
                          prefixText: '\$ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _walletType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Гаманець',
                        ),
                        dropdownColor: AppColors.surfaceVariant,
                        items: const [
                          DropdownMenuItem(
                            value: 'MANUAL',
                            child: Text('Ручний запис', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'BINANCE',
                            child: Text('Binance Spot', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'SOLANA',
                            child: Text('Solana', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'EVM',
                            child: Text('EVM / MetaMask', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _walletType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Нотатки (стратегія, рівні входу)',
                    prefixIcon: Icon(Icons.notes_rounded, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submit,
                    child: const Text(
                      'Зберегти покупку',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
