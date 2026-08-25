import 'dart:convert';

/// Turno e area che il cliente ha scelto compilando il modulo online.
///
/// Il modulo li salva come JSON dentro `internal_notes`, che pero' puo'
/// contenere anche testo libero: per questo la lettura non da' mai per scontato
/// di trovarci un oggetto valido.
class ScelteModulo {
  final String turno;
  final String area;

  const ScelteModulo({this.turno = '', this.area = ''});

  bool get vuote => turno.isEmpty && area.isEmpty;

  static ScelteModulo da(dynamic internalNotes) {
    final grezzo = internalNotes?.toString().trim() ?? '';
    if (!grezzo.startsWith('{')) return const ScelteModulo();
    try {
      final decodificato = jsonDecode(grezzo);
      if (decodificato is! Map) return const ScelteModulo();
      return ScelteModulo(
        turno: (decodificato['turno'] ?? '').toString().trim(),
        area: (decodificato['area'] ?? '').toString().trim(),
      );
    } catch (_) {
      return const ScelteModulo();
    }
  }
}
