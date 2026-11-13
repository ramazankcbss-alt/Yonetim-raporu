import 'package:flutter/material.dart';

/// Kurumsal, açık renkli tema: koyu yeşil ana renk, beyaz kartlar, sade butonlar.
class Renk {
  static const ana = Color(0xFF1F7A4D); // tarım yeşili
  static const anaKoyu = Color(0xFF14593A);
  static const anaAcik = Color(0xFFE3F2EA);

  static const zemin = Color(0xFFF3F6F7);
  static const kart = Colors.white;
  static const cizgi = Color(0xFFE2E8EC);
  static const yazi = Color(0xFF1E293B);
  static const soluk = Color(0xFF64748B);

  static const yesil = Color(0xFF15803D);
  static const yesilAcik = Color(0xFFDCFCE7);
  static const mavi = Color(0xFF1D4ED8);
  static const maviAcik = Color(0xFFDBEAFE);
  static const amber = Color(0xFFB45309);
  static const amberAcik = Color(0xFFFEF3C7);
  static const turuncu = Color(0xFFC2410C);
  static const turuncuAcik = Color(0xFFFFEDD5);
  static const kirmizi = Color(0xFFDC2626);
  static const kirmiziAcik = Color(0xFFFEE2E2);
}

ThemeData temaOlustur() {
  final cs = ColorScheme.fromSeed(
    seedColor: Renk.ana,
    brightness: Brightness.light,
  ).copyWith(
    primary: Renk.ana,
    onPrimary: Colors.white,
    primaryContainer: Renk.anaAcik,
    onPrimaryContainer: Renk.anaKoyu,
    secondaryContainer: Renk.anaAcik,
    onSecondaryContainer: Renk.anaKoyu,
    surface: Renk.kart,
    onSurface: Renk.yazi,
    onSurfaceVariant: Renk.soluk,
    outline: const Color(0xFFCBD5DC),
    outlineVariant: Renk.cizgi,
    error: Renk.kirmizi,
  );
  final kenar = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFCBD5DC)),
  );
  final yuvarlak =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: Renk.zemin,
    dividerColor: Renk.cizgi,
    dividerTheme: const DividerThemeData(color: Renk.cizgi, space: 1, thickness: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.ana,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    // Üst yeşil şeritteki sekmeler: seçili beyaz, diğerleri açık beyaz.
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Color(0xCCFFFFFF),
      indicatorColor: Colors.white,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Renk.soluk),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: kenar,
      enabledBorder: kenar,
      focusedBorder:
          kenar.copyWith(borderSide: const BorderSide(color: Renk.ana, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: yuvarlak,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: yuvarlak,
        foregroundColor: Renk.yazi,
        side: const BorderSide(color: Color(0xFFCBD5DC)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Renk.anaKoyu),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Renk.ana,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Renk.anaAcik,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Renk.anaKoyu : Renk.soluk)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight:
              s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Renk.anaKoyu : Renk.soluk)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Renk.anaAcik,
      side: const BorderSide(color: Renk.cizgi),
      labelStyle: const TextStyle(color: Renk.yazi, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Renk.anaAcik,
        selectedForegroundColor: Renk.anaKoyu,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Renk.yazi,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.ana),
  );
}

void bildir(BuildContext context, String mesaj) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj)));
}

/// Beyaz, ince kenarlıklı kart; isteğe bağlı başlık ve sağda bir bağlantı.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.baslik,
    required this.child,
    this.margin,
    this.padding,
    this.eylem,
  });

  final String? baslik;
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Widget? eylem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (baslik != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(baslik!,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Renk.yazi)),
                  ),
                  if (eylem != null) eylem!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

enum ButonRenk { birincil, ikincil, tehlike }

/// Sade buton: birincil (yeşil dolu), ikincil (çerçeveli), tehlike (kırmızı).
class Buton extends StatelessWidget {
  const Buton({
    super.key,
    required this.yazi,
    this.renk = ButonRenk.birincil,
    required this.onTap,
    this.mesgul = false,
    this.ikon,
    this.yukseklik = 46,
  });

  final String yazi;
  final ButonRenk renk;
  final VoidCallback? onTap;
  final bool mesgul;
  final IconData? ikon;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final boyut = Size(64, yukseklik);
    final icerik = mesgul
        ? const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ikon != null) ...[Icon(ikon, size: 19), const SizedBox(width: 8)],
              Flexible(child: Text(yazi, overflow: TextOverflow.ellipsis)),
            ],
          );
    final tik = mesgul ? null : onTap;
    switch (renk) {
      case ButonRenk.birincil:
        return FilledButton(
            onPressed: tik,
            style: FilledButton.styleFrom(minimumSize: boyut),
            child: mesgul
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : icerik);
      case ButonRenk.ikincil:
        return OutlinedButton(
            onPressed: tik,
            style: OutlinedButton.styleFrom(minimumSize: boyut),
            child: icerik);
      case ButonRenk.tehlike:
        return OutlinedButton(
            onPressed: tik,
            style: OutlinedButton.styleFrom(
              minimumSize: boyut,
              foregroundColor: Renk.kirmizi,
              side: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            child: icerik);
    }
  }
}


class BosDurum extends StatelessWidget {
  const BosDurum({super.key, required this.ikon, required this.yazi});
  final IconData ikon;
  final String yazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        child: Column(
          children: [
            Icon(ikon, size: 44, color: const Color(0xFFB8C4CC)),
            const SizedBox(height: 10),
            Text(yazi,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Renk.soluk, fontSize: 15)),
          ],
        ),
      );
}
