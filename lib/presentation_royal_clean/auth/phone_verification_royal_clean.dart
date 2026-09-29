import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'account_ui_royal_clean.dart';

String? profilePhoneRoyalClean(String raw) {
  if (!RegExp(r'^[+0-9()\s-]+$').hasMatch(raw)) {
    return null;
  }
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if ((digits.length == 12 || digits.length == 13) && digits.startsWith('55')) {
    digits = digits.substring(2);
  }
  return RegExp(r'^[1-9][0-9]{9,10}$').hasMatch(digits) ? '+55$digits' : null;
}

class PhoneVerificationRoyalClean extends StatefulWidget {
  final User user;
  final String phone;
  const PhoneVerificationRoyalClean({
    super.key,
    required this.user,
    required this.phone,
  });
  @override
  State<PhoneVerificationRoyalClean> createState() => _PhoneVerificationState();
}

class _PhoneVerificationState extends State<PhoneVerificationRoyalClean> {
  final _code = TextEditingController();
  String? _verificationId, _error;
  bool _busy = false, _finishing = false;
  DateTime? _sentAt;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _finish(PhoneAuthCredential credential) async {
    if (!mounted || _finishing) return;
    _finishing = true;
    setState(() => _busy = true);
    try {
      if (FirebaseAuth.instance.currentUser?.uid != widget.user.uid) {
        throw StateError('session');
      }
      await widget.user.updatePhoneNumber(credential);
      await widget.user.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AccountServiceRoyalClean.error(e);
          _busy = false;
        });
      }
    } finally {
      _finishing = false;
    }
  }

  Future<void> _send() async {
    if (_busy ||
        (_sentAt != null &&
            DateTime.now().difference(_sentAt!).inSeconds < 60)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: _finish,
        verificationFailed: (e) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = AccountServiceRoyalClean.error(e);
            });
          }
        },
        codeSent: (id, token) {
          if (mounted) {
            setState(() {
              _verificationId = id;
              _sentAt = DateTime.now();
              _busy = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (id) {
          if (mounted) {
            setState(() {
              _verificationId = id;
              _busy = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AccountServiceRoyalClean.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: 'Confirmar telefone',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.phone, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text(
          'Enviaremos um código por SMS. O número será processado pelo Google/Firebase para autenticação e prevenção de abuso.',
        ),
        const SizedBox(height: 16),
        LayoutButtonRoyalClean(
          id: 'phone_verification_royal_clean.control_01',
          child: OutlinedButton(
            onPressed: tactileTapRoyalClean(_busy ? null : _send),
            child: Text(
              _verificationId == null
                  ? 'Enviar código por SMS'
                  : 'Reenviar código (aguarde 60 s)',
            ),
          ),
        ),
        if (_verificationId != null) ...[
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Código do SMS'),
            onTap: TouchFeedbackRoyalClean.pulse,
          ),
          LayoutButtonRoyalClean(
            id: 'phone_verification_royal_clean.control_02',
            child: FilledButton(
              onPressed: tactileTapRoyalClean(
                _busy
                    ? null
                    : () {
                        if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
                          setState(
                            () => _error = 'Informe os seis dígitos do SMS.',
                          );
                          return;
                        }
                        _finish(
                          PhoneAuthProvider.credential(
                            verificationId: _verificationId!,
                            smsCode: _code.text.trim(),
                          ),
                        );
                      },
              ),
              child: Text(_busy ? 'Confirmando…' : 'Confirmar telefone'),
            ),
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
