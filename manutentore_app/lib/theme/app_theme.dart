import 'package:flutter/material.dart';

import 'tokens.dart';

/// Colori semantici e superfici, accessibili da qualsiasi widget.
@immutable
class Sfumature extends ThemeExtension<Sfumature> {
  const Sfumature({
    required this.plate,
    required this.line,
    required this.muted,
    required this.ok,
    required this.warn,
    required this.fail,
  });

  final Color plate;
  final Color line;
  final Color muted;
  final Color ok;
  final Color warn;
  final Color fail;

  @override
  Sfumature copyWith({
    Color? plate,
    Color? line,
    Color? muted,
    Color? ok,
    Color? warn,
    Color? fail,
  }) => Sfumature(
    plate: plate ?? this.plate,
    line: line ?? this.line,
    muted: muted ?? this.muted,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    fail: fail ?? this.fail,
  );

  @override
  Sfumature lerp(covariant Sfumature? other, double t) {
    if (other == null) return this;
    return Sfumature(
      plate: Color.lerp(plate, other.plate, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      fail: Color.lerp(fail, other.fail, t)!,
    );
  }
}

extension SfumatureContext on BuildContext {
  Sfumature get c => Theme.of(this).extension<Sfumature>()!;
}

ThemeData temaScuro() => _tema(
  brightness: Brightness.dark,
  ground: T.groundDark,
  surface: T.surfaceDark,
  plate: T.plateDark,
  line: T.lineDark,
  text: T.textDark,
  muted: T.mutedDark,
);

ThemeData temaChiaro() => _tema(
  brightness: Brightness.light,
  ground: T.groundLight,
  surface: T.surfaceLight,
  plate: T.plateLight,
  line: T.lineLight,
  text: T.textLight,
  muted: T.mutedLight,
);

ThemeData _tema({
  required Brightness brightness,
  required Color ground,
  required Color surface,
  required Color plate,
  required Color line,
  required Color text,
  required Color muted,
}) {
  final schema = ColorScheme(
    brightness: brightness,
    primary: T.giallo,
    onPrimary: const Color(0xFF17130A),
    secondary: T.giallo,
    onSecondary: const Color(0xFF17130A),
    error: T.fail,
    onError: Colors.white,
    surface: surface,
    onSurface: text,
    outline: line,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: schema,
    scaffoldBackgroundColor: ground,
    fontFamily: T.sans,
  );

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      Sfumature(
        plate: plate,
        line: line,
        muted: muted,
        ok: T.ok,
        warn: T.warn,
        fail: T.fail,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: ground,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: T.sans,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: text,
        letterSpacing: -0.2,
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: T.s3,
        vertical: T.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.radius),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.radius),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.radius),
        borderSide: const BorderSide(color: T.giallo, width: 2),
      ),
      labelStyle: TextStyle(color: muted, fontSize: 14),
      helperStyle: TextStyle(color: muted, fontSize: 12),
      helperMaxLines: 3,
    ),
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
    listTileTheme: ListTileThemeData(iconColor: muted),
  );
}
