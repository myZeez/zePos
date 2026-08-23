import 'package:flutter/material.dart';
import 'package:zepos/core/formatting/formatters.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/ui/widgets/loading_panel.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class StockHistory extends StatelessWidget {
  const StockHistory({super.key, required this.movements});

  final List<InventoryMovement> movements;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ZeRadius.panel,
        border: Border.all(color: ZeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mutasi Stok Terbaru',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Setiap perubahan tercatat otomatis.',
            style: TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (movements.isEmpty)
            const _EmptyStockHistoryState()
          else
            for (var index = 0; index < movements.length; index++) ...[
              _MovementRow(movement: movements[index]),
              if (index < movements.length - 1) const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final InventoryMovement movement;

  @override
  Widget build(BuildContext context) {
    final added = movement.quantityDelta > 0;
    final color = added ? ZeColors.success : ZeColors.danger;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: added ? ZeColors.successSoft : ZeColors.dangerSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(added ? Icons.add : Icons.remove, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                inventoryReasonLabel(movement.reason),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ZeColors.mutedAlt, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                formatDateTime(movement.createdAt),
                style: const TextStyle(color: Color(0xFF71819A), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${added ? '+' : ''}${movement.quantityDelta}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class EmptyStockCatalogState extends StatelessWidget {
  const EmptyStockCatalogState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_outlined, size: 46, color: Color(0xFF71819A)),
            SizedBox(height: 10),
            Text(
              'Produk tidak ditemukan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Ubah kata pencarian atau filter stok.',
              style: TextStyle(color: ZeColors.mutedAlt),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStockHistoryState extends StatelessWidget {
  const _EmptyStockHistoryState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_outlined, size: 36, color: Color(0xFF71819A)),
            SizedBox(height: 8),
            Text(
              'Belum ada mutasi stok',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class StockLoadingState extends StatelessWidget {
  const StockLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          LoadingPanel(height: 72),
          SizedBox(height: 16),
          Expanded(child: LoadingPanel(height: double.infinity)),
        ],
      ),
    );
  }
}

class StockErrorState extends StatelessWidget {
  const StockErrorState({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warehouse_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Stok belum dapat dimuat',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat Ulang'),
          ),
        ],
      ),
    );
  }
}
