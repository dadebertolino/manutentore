import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manutentore_core/manutentore_core.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Rende un [FieldSpec] senza sapere a quale calcolatore appartiene.
///
/// E' il pezzo che rende la app estensibile: aggiungere un calcolatore al
/// registro non richiede nessuna modifica qui.
class CampoInput extends StatelessWidget {
  const CampoInput({
    required this.spec,
    required this.valore,
    required this.onChanged,
    this.controller,
    this.mostraAiuto = true,
    super.key,
  });

  final FieldSpec spec;
  final Object? valore;
  final ValueChanged<Object?> onChanged;
  final TextEditingController? controller;

  /// In modalita' professionista l'aiuto e' nascosto: meno da leggere.
  final bool mostraAiuto;

  @override
  Widget build(BuildContext context) {
    return switch (spec.type) {
      FieldType.number => _numero(context),
      FieldType.select => _selezione(context),
      FieldType.toggle => _interruttore(context),
    };
  }

  Widget _numero(BuildContext context) {
    return TextField(
      controller: controller,
      // controller assente solo se il campo non e' numerico
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      style: const TextStyle(
        fontFamily: T.mono,
        fontSize: 17,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: spec.label,
        suffixText: spec.unit.isEmpty ? null : spec.unit,
        suffixStyle: TextStyle(
          fontFamily: T.mono,
          color: context.c.muted,
          fontSize: 14,
        ),
        helperText: mostraAiuto ? spec.help : null,
      ),
      onChanged: (t) => onChanged(t),
    );
  }

  Widget _selezione(BuildContext context) {
    final corrente = valore is String && (valore as String).isNotEmpty
        ? valore as String
        : (spec.initial as String? ?? spec.options.first.value);
    return DropdownButtonFormField<String>(
      initialValue: corrente,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: spec.label,
        helperText: mostraAiuto ? spec.help : null,
      ),
      items: [
        for (final o in spec.options)
          DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _interruttore(BuildContext context) {
    final acceso = valore is bool
        ? valore as bool
        : (spec.initial as bool? ?? false);
    return SwitchListTile.adaptive(
      value: acceso,
      title: Text(spec.label),
      subtitle: mostraAiuto && spec.help != null ? Text(spec.help!) : null,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }
}
