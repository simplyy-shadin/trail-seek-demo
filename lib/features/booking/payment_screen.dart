import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import 'booking_controller.dart';

/// Payment step. The gateway is simulated for the beta: every method succeeds
/// after a short delay and the booking is recorded in Trail Seek's database.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'UPI';
  bool _busy = false;
  final _upi = TextEditingController();

  static const methods = [
    ('UPI', Icons.qr_code_2, 'Google Pay, PhonePe, Paytm or any UPI app'),
    ('Card', Icons.credit_card, 'Debit or credit card'),
    ('Net banking', Icons.account_balance, 'All major banks'),
  ];

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    try {
      final b = await ref.read(bookingProvider.notifier).confirm(widget.draft, paymentMethod: _method);
      if (!mounted) return;
      context.pushReplacement('/booking/${b.id}?new=1');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
        children: [
          TsCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.adventure.name, style: TsText.h3),
                const SizedBox(height: 4),
                Text('${DateFormat('EEE, d MMM yyyy').format(d.date)} · ${d.slot}', style: TsText.caption),
                Text(d.party.label, style: TsText.caption),
                const Divider(height: 18),
                for (final l in d.quote.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [Expanded(child: Text(l.label, style: TsText.caption.copyWith(color: TsColors.textPrimary))), Text(ProgramPricing.rupees(l.amount), style: TsText.caption.copyWith(color: TsColors.textPrimary))]),
                  ),
                const SizedBox(height: 6),
                Row(children: [const Expanded(child: Text('To pay', style: TsText.h3)), Text(ProgramPricing.rupees(d.quote.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TsColors.neon))]),
              ],
            ),
          ),
          const SectionHeader('Pay with'),
          for (final (name, icon, sub) in methods)
            TsCard(
              onTap: () => setState(() => _method = name),
              highlighted: _method == name,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: _method == name ? TsColors.neon : TsColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(name, style: TsText.bodyStrong), Text(sub, style: TsText.caption)],
                    ),
                  ),
                  Icon(_method == name ? Icons.radio_button_checked : Icons.radio_button_off, color: _method == name ? TsColors.neon : TsColors.textMuted),
                ],
              ),
            ),
          if (_method == 'UPI')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(controller: _upi, decoration: const InputDecoration(hintText: 'yourname@upi (optional in the beta)', prefixIcon: Icon(Icons.alternate_email))),
            ),
          const SizedBox(height: 14),
          const Text('Beta: payments are simulated. No money moves until the payment gateway goes live; your booking is still recorded and your ticket is issued.', style: TsText.caption),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: NeonButton(label: 'Pay ${ProgramPricing.rupees(d.quote.total)}', icon: Icons.lock_outline, loading: _busy, onPressed: _busy ? null : _pay),
      ),
    );
  }
}
