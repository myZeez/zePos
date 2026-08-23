# ZePOS Design System

## Direction

ZePOS menggunakan modern soft-neumorphism: permukaan lembut, rounded, dan terasa nyaman disentuh. Neumorphism digunakan sebagai aksen interaksi, bukan sebagai alasan untuk mengurangi keterbacaan atau membuat setiap elemen melayang.

Physical scene: kasir menggunakan aplikasi di meja toko dengan pencahayaan indoor yang terang, berpindah cepat antara scanner, layar, printer, dan pelanggan.

## Color Tokens

```css
--color-bg: #EEF2F7;
--color-surface: #EEF2F7;
--color-surface-white: #FFFFFF;
--color-ink: #172033;
--color-muted: #5D6B82;
--color-disabled: #9AA6B8;
--color-border: #D8E0EA;
--color-primary: #3B82F6;
--color-primary-strong: #2563EB;
--color-success: #22C55E;
--color-warning: #F59E0B;
--color-danger: #EF4444;
--color-info: #06B6D4;
--color-selected: #EAF2FF;
```

Use primary blue only for primary actions, active navigation, focus, and selected states. Use semantic colors for status, not decoration.

## Neumorphic Materials

Raised surface:

```css
box-shadow:
  8px 8px 18px rgba(163, 177, 198, 0.55),
  -8px -8px 18px rgba(255, 255, 255, 0.92);
```

Pressed/inset surface:

```css
box-shadow:
  inset 5px 5px 10px rgba(163, 177, 198, 0.42),
  inset -5px -5px 10px rgba(255, 255, 255, 0.85);
```

Rules:

- Do not pair a heavy shadow with a heavy border.
- Use flat surfaces for dense tables and long lists.
- Use inset shadow for pressed, selected, or active states.
- Never use shadow as the only indication of focus; add a visible focus ring.

## Typography

- Font: Inter, fallback system-ui, sans-serif.
- Page title: 24 px / 700.
- Section title: 18 px / 600.
- Body: 14–16 px / 400.
- Label: 13–14 px / 600.
- Button: 14 px / 600.
- Metric number: 28–36 px / 700.
- Line height: 1.4 for body text.

## Radius and Spacing

```text
Spacing: 4, 8, 12, 16, 24, 32, 40, 48 px
Input: 12 px
Button: 12 px
Card: 14 px
Panel: 16 px
Modal: 20 px
Status badge: full pill
```

## Layout

Desktop:

- Sidebar 240 px.
- Top bar 64 px.
- Content padding 32 px.
- Default content max width 1440 px.

Tablet:

- Content padding 24 px.
- Sidebar can collapse to 80 px.
- Use two columns on landscape.

Phone:

- Content padding 16 px.
- Bottom navigation.
- Bottom sheet for cart and payment.
- Sticky primary action at the bottom.

## Navigation

Desktop navigation:

1. Beranda
2. Kasir
3. Produk
4. Stok
5. Laporan
6. Transaksi
7. Pengaturan

Phone navigation:

1. Kasir
2. Produk
3. Laporan
4. Lainnya

## Components

Every interactive component must define default, hover, focus, active, disabled, loading, error, and success states.

Primary button:

- Blue surface.
- White label.
- Raised state by default.
- Inset shadow when pressed.

Input:

- Same base color as app background.
- Inset shadow.
- Dark label above field.
- Visible blue focus ring.

Card:

- Surface base color.
- Soft raised shadow.
- No decorative illustration unless it improves comprehension.

Status:

- Always use icon + label + color.
- Example: green dot + “Terhubung”.

## Accessibility

- Minimum touch target 44×44 px.
- Minimum body text 14 px.
- Contrast target WCAG AA.
- Do not communicate status through color alone.
- Support keyboard focus on desktop.
- Support reduced motion.
- Use clear Indonesian labels instead of icon-only controls.

## UI Copy

Prefer:

- “Tambah Produk” instead of “Create Item”.
- “Sesuaikan Stok” instead of “Inventory Adjustment”.
- “Pembayaran sudah diterima” instead of “Payment verified”.
- “Printer belum terhubung” instead of “Device unavailable”.

Avoid technical language in the primary workflow.
