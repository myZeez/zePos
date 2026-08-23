String generateProductBarcode([DateTime? timestamp]) {
  final now = timestamp ?? DateTime.now();
  final serial = now.microsecondsSinceEpoch
      .remainder(1000000000)
      .toString()
      .padLeft(9, '0');
  final body = '899$serial';
  var sum = 0;
  for (var index = 0; index < body.length; index++) {
    final digit = int.parse(body[index]);
    sum += digit * (index.isEven ? 1 : 3);
  }
  final checkDigit = (10 - sum % 10) % 10;
  return '$body$checkDigit';
}

String formatRupiah(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final positionFromEnd = digits.length - index;
    buffer.write(digits[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp$buffer';
}

String inventoryReasonLabel(String reason) {
  return switch (reason) {
    'INITIAL_STOCK' => 'Stok awal produk',
    'SALE' => 'Penjualan',
    'VOID' => 'Transaksi dibatalkan',
    'RETURN' => 'Retur transaksi',
    _ => reason,
  };
}

String paymentMethodLabel(String method) {
  return switch (method) {
    'CASH' => 'Tunai',
    'QRIS' => 'QRIS',
    'TRANSFER' => 'Transfer',
    _ => method,
  };
}

String transactionStatusLabel(String status) {
  return switch (status) {
    'COMPLETED' => 'Selesai',
    'VOIDED' => 'Dibatalkan',
    'RETURNED' => 'Diretur',
    _ => status,
  };
}

String formatDateTime(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day} ${months[value.month - 1]} ${value.year}, ${value.hour}:$minute';
}

String formatReportPeriod(DateTime start, DateTime end) {
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return 'Laporan ${formatDateTime(start).split(',').first}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${start.day} ${months[start.month - 1]} ${start.year} – ${end.day} ${months[end.month - 1]} ${end.year}';
}

String formatFileSize(int sizeBytes) {
  if (sizeBytes < 1024) return '$sizeBytes B';
  final kilobytes = sizeBytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}
