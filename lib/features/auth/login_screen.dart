import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/core/auth/accesso.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _modulo = GlobalKey<FormState>();
  bool _inCorso = false;
  bool _nascondiPassword = true;
  String? _errore;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entra() async {
    if (!_modulo.currentState!.validate() || _inCorso) return;
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
      await statoAccesso.ricarica();
      if (!mounted) return;
      if (statoAccesso.entratoSenzaProfilo) {
        // Credenziali valide ma nessun permesso: non e' del ristorante, oppure
        // e' stato disattivato. Meglio chiudere la sessione subito.
        await statoAccesso.esci();
        if (mounted) {
          setState(() => _errore = 'Questo accesso non è abilitato per il ristorante.');
        }
      }
      // Con il profilo valido ci pensa il router a spostare la schermata.
    } on AuthException catch (e) {
      final testo = e.message.toLowerCase();
      setState(() => _errore = testo.contains('invalid')
          ? 'Email o password non corretti.'
          : 'Accesso non riuscito: ${e.message}');
    } catch (e) {
      setState(() => _errore = 'Accesso non riuscito: $e');
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/logo_splash.png',
                    width: 260, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                const SizedBox(height: 8),
                Text('Gestione prenotazioni',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        letterSpacing: 3)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Form(
                    key: _modulo,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline, size: 20),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Inserisci la tua email'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _nascondiPassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _entra(),
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _nascondiPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20),
                            onPressed: () =>
                                setState(() => _nascondiPassword = !_nascondiPassword),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Inserisci la password' : null,
                      ),
                      if (_errore != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errore!,
                                  style: const TextStyle(
                                      color: AppColors.accent, fontSize: 13)),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _inCorso ? null : _entra,
                        child: _inCorso
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Entra',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Se non riesci a entrare, chiedi a un amministratore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chi entra ma non ha nessuna sezione abilitata finisce qui: senza questa
/// schermata il router rimbalzerebbe all'infinito cercando dove mandarlo.
class SenzaPermessiScreen extends StatelessWidget {
  const SenzaPermessiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Nessuna sezione abilitata',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Il tuo accesso è attivo ma non ha ancora sezioni assegnate. '
              'Chiedi a un amministratore di abilitartele.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => statoAccesso.esci(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Esci'),
            ),
          ]),
        ),
      ),
    );
  }
}
