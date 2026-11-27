import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_state.dart';
import '../core/enums.dart';
import '../core/mock_data.dart';
import '../core/models.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ---------------------------------------------------------------------------
// S01 Welcome / language / role
// ---------------------------------------------------------------------------
class S01Welcome extends StatelessWidget {
  const S01Welcome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Semantics(
                  label: t('s01_language'),
                  child: SegmentedButton<AppLocale>(
                    key: const Key('s01_language'),
                    segments: [
                      ButtonSegment(value: AppLocale.es, label: Text(t('lang_es'))),
                      ButtonSegment(value: AppLocale.en, label: Text(t('lang_en'))),
                    ],
                    selected: {state.locale},
                    onSelectionChanged: (s) => state.setLocale(s.first),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.local_shipping, size: 72, color: AppTheme.primary),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  t('s01_title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(t('s01_subtitle'), style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              PrimaryButton(
                key: const Key('s01_driver'),
                label: t('s01_driver'),
                icon: Icons.drive_eta_outlined,
                onPressed: () {
                  state.chooseRole(UserRole.driver);
                  Navigator.pushNamed(context, Routes.s02);
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                key: const Key('s01_shipper'),
                label: t('s01_shipper'),
                icon: Icons.inventory_2_outlined,
                onPressed: () {
                  state.chooseRole(UserRole.shipper);
                  Navigator.pushNamed(context, Routes.s02);
                },
              ),
              const SizedBox(height: 16),
              Text(
                t('demo_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S02 Phone + OTP (mocked). Correct code 123456. 5 attempts, lock-out and
// daily-cap states reachable through demo buttons (4.6 OTP rows).
// ---------------------------------------------------------------------------
class S02Otp extends StatefulWidget {
  const S02Otp({super.key});

  @override
  State<S02Otp> createState() => _S02OtpState();
}

enum _OtpStage { phone, code, locked, dailyCap }

class _S02OtpState extends State<S02Otp> {
  static const correctCode = '123456';
  static const maxAttempts = 5;

  /// 15-minute lock after 5 wrong codes (5.6). The demo starts the clock at
  /// the real value; the visible countdown is what 4.6 asks for.
  static const lockDuration = Duration(minutes: 15);

  final _phone = TextEditingController(text: '099 123 4567');
  final _code = TextEditingController();
  _OtpStage _stage = _OtpStage.phone;
  int _attemptsLeft = maxAttempts;
  String? _error;
  Timer? _lockTimer;
  Duration _lockLeft = lockDuration;

  @override
  void dispose() {
    _lockTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _sendCode() {
    _lockTimer?.cancel();
    _code.clear(); // a new code never shows the previous digits
    setState(() {
      _stage = _OtpStage.code;
      _attemptsLeft = maxAttempts;
      _error = null;
    });
  }

  void _lock() {
    _lockTimer?.cancel();
    _code.clear();
    _lockLeft = lockDuration;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _lockLeft -= const Duration(seconds: 1);
        if (_lockLeft <= Duration.zero) {
          _lockLeft = Duration.zero;
          _lockTimer?.cancel();
        }
      });
    });
    setState(() {
      _stage = _OtpStage.locked;
      _error = null;
    });
  }

  String get _lockClock {
    final m = _lockLeft.inMinutes.toString().padLeft(2, '0');
    final sec = (_lockLeft.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _verify() {
    final state = AppScope.of(context);
    if (_code.text.trim() == correctCode) {
      state.phone = _phone.text;
      final next = state.role == UserRole.driver ? Routes.s03 : Routes.s11;
      Navigator.pushNamedAndRemoveUntil(context, next, (r) => r.isFirst);
      return;
    }
    setState(() {
      _attemptsLeft--;
      if (_attemptsLeft <= 0) {
        _lock();
      } else {
        _error = context.t.f('s02_wrong', {'n': '$_attemptsLeft'});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scheme = Theme.of(context).colorScheme;
    return AppScreen(
      title: t('s02_title'),
      screenId: 'S02',
      bottom: switch (_stage) {
        _OtpStage.phone => PrimaryButton(
            key: const Key('s02_send'),
            label: t('s02_send_code'),
            onPressed: _sendCode,
          ),
        _OtpStage.code => PrimaryButton(
            key: const Key('s02_verify'),
            label: t('s02_verify'),
            onPressed: _verify,
          ),
        _OtpStage.locked => PrimaryButton(
            key: const Key('s02_resend_locked'),
            label: t('s02_send_code'),
            onPressed: _lockLeft == Duration.zero ? _sendCode : null,
          ),
        _OtpStage.dailyCap => PrimaryButton(
            key: const Key('s02_contact'),
            label: t('s02_contact_whatsapp'),
            icon: Icons.chat_outlined,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('s02_never_ask'))),
            ),
          ),
      },
      children: [
        if (_stage == _OtpStage.phone) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('s02_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: t('s02_phone_label'),
              hintText: t('s02_phone_hint'),
              prefixText: '+593 ',
            ),
          ),
          const SizedBox(height: 16),
          Text(t('s02_privacy'), style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
        if (_stage == _OtpStage.code) ...[
          const SizedBox(height: 8),
          Text(t.f('s02_code_sent', {'phone': '+593 ${_phone.text}'})),
          const SizedBox(height: 16),
          TextField(
            key: const Key('s02_code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              labelText: t('s02_code_label'),
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.f('s02_code_sent', {'phone': 'SMS'}))),
            ),
            child: Text(t('s02_resend')),
          ),
          DemoNote(t('s02_demo_code')),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('s02_demo_lock'),
                  onPressed: _lock,
                  child: Text(t('s02_demo_lock'), textAlign: TextAlign.center),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('s02_demo_cap'),
                  onPressed: () {
                    _code.clear();
                    setState(() => _stage = _OtpStage.dailyCap);
                  },
                  child: Text(t('s02_demo_cap'), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
        if (_stage == _OtpStage.locked) ...[
          InfoBanner(
            text: t('s02_locked'),
            icon: Icons.lock_clock_outlined,
            color: AppTheme.danger,
          ),
          Semantics(
            label: t('s02_locked'),
            value: _lockClock,
            liveRegion: true,
            child: Text(
              _lockClock,
              key: const Key('s02_lock_countdown'),
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('s02_back_to_code'),
            onPressed: _sendCode,
            child: Text('${t('demo')}: ${t('s02_send_code')}'),
          ),
        ],
        if (_stage == _OtpStage.dailyCap) ...[
          InfoBanner(
            text: t('s02_daily_cap'),
            icon: Icons.block_outlined,
            color: AppTheme.danger,
          ),
          TextButton(
            onPressed: _sendCode,
            child: Text('${t('demo')}: ${t('s02_send_code')}'),
          ),
        ],
        const SizedBox(height: 16),
        Text(t('s02_never_ask'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S03 Profile (drivers after OTP) / invoice data (shippers on first booking)
// ---------------------------------------------------------------------------
class S03Profile extends StatefulWidget {
  const S03Profile({super.key, this.invoiceMode = false});

  /// When true, the screen asks for cédula/RUC + invoice receiver data (A2.1,
  /// A2.4) and pops with `true` on save so the caller continues to S17.
  final bool invoiceMode;

  @override
  State<S03Profile> createState() => _S03ProfileState();
}

class _S03ProfileState extends State<S03Profile> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _taxId;
  late final TextEditingController _invoiceName;
  late final TextEditingController _address;
  late final TextEditingController _invoiceEmail;
  bool _marketing = false;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    final isDriver = s.role == UserRole.driver;
    _name = TextEditingController(text: isDriver ? s.driver.name : s.shipper.name);
    _email = TextEditingController(text: isDriver ? s.driver.email : s.shipper.email);
    _taxId = TextEditingController(text: s.shipper.taxId.isEmpty ? '0912345678001' : s.shipper.taxId);
    _invoiceName = TextEditingController(text: s.shipper.invoiceName.isEmpty ? 'Paula Mera Cía. Ltda.' : s.shipper.invoiceName);
    _address = TextEditingController(text: s.shipper.invoiceAddress.isEmpty ? 'Av. 9 de Octubre 100, Guayaquil' : s.shipper.invoiceAddress);
    _invoiceEmail = TextEditingController(text: s.shipper.invoiceEmail.isEmpty ? 'facturas@paulamera.ec' : s.shipper.invoiceEmail);
    _marketing = isDriver ? s.driver.marketingOptIn : s.shipper.marketingOptIn;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _taxId, _invoiceName, _address, _invoiceEmail]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = AppScope.of(context);
    if (s.role == UserRole.driver) {
      s.driver
        ..name = _name.text
        ..email = _email.text
        ..marketingOptIn = _marketing;
      Navigator.pushNamed(context, Routes.s04);
    } else {
      s.shipper
        ..name = _name.text
        ..email = _email.text
        ..marketingOptIn = _marketing
        ..taxId = _taxId.text
        ..invoiceName = _invoiceName.text
        ..invoiceAddress = _address.text
        ..invoiceEmail = _invoiceEmail.text;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AppScreen(
      title: widget.invoiceMode ? t('s03_title_invoice') : t('s03_title'),
      screenId: 'S03',
      bottom: PrimaryButton(
        key: const Key('s03_save'),
        label: t('s03_save'),
        onPressed: _save,
      ),
      children: [
        const SizedBox(height: 8),
        TextField(
          key: const Key('s03_name'),
          controller: _name,
          decoration: InputDecoration(labelText: t('s03_name')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: t('s03_email')),
        ),
        SwitchListTile(
          value: _marketing,
          onChanged: (v) => setState(() => _marketing = v),
          title: Text(t('s03_marketing')),
          contentPadding: EdgeInsets.zero,
        ),
        if (widget.invoiceMode) ...[
          SectionTitle(t('s03_title_invoice')),
          Text(t('s03_invoice_note'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('s03_tax_id'),
            controller: _taxId,
            decoration: InputDecoration(labelText: t('s03_tax_id')),
          ),
          const SizedBox(height: 12),
          TextField(controller: _invoiceName, decoration: InputDecoration(labelText: t('s03_invoice_name'))),
          const SizedBox(height: 12),
          TextField(controller: _address, decoration: InputDecoration(labelText: t('s03_invoice_address'))),
          const SizedBox(height: 12),
          TextField(controller: _invoiceEmail, decoration: InputDecoration(labelText: t('s03_invoice_email'))),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S04 Driver onboarding wizard (5 steps)
// ---------------------------------------------------------------------------
class S04Onboarding extends StatefulWidget {
  const S04Onboarding({super.key});

  @override
  State<S04Onboarding> createState() => _S04OnboardingState();
}

class _S04OnboardingState extends State<S04Onboarding> {
  int _step = 0; // 0..4, 5 = sent
  bool _consent = false;
  final Set<String> _captured = {};
  bool _insurance = false;
  bool _tracking = false;
  String _bodyType = 'body_van';
  int _tons = 8;

  bool get _stepComplete {
    switch (_step) {
      case 0:
        return _consent && _captured.contains('cedula') && _captured.contains('selfie');
      case 1:
        return _captured.contains('registration') && _captured.contains('vehicle');
      case 2:
        return _captured.contains('permit');
      case 3:
        return _captured.contains('licence');
      default:
        return true;
    }
  }

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      setState(() => _step = 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scheme = Theme.of(context).colorScheme;
    if (_step == 5) {
      return AppScreen(
        title: t('s04_title'),
        screenId: 'S04',
        bottom: PrimaryButton(
          key: const Key('s04_see_status'),
          label: t('s04_see_status'),
          onPressed: () => Navigator.pushReplacementNamed(context, Routes.s05),
        ),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.task_alt, size: 72, color: AppTheme.success),
          const SizedBox(height: 16),
          Text(t('s04_sent_title'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(t('s04_sent_body'), textAlign: TextAlign.center),
        ],
      );
    }

    final stepTitles = [t('s04_step1'), t('s04_step2'), t('s04_step3'), t('s04_step4'), t('s04_step5')];

    return AppScreen(
      title: t('s04_title'),
      screenId: 'S04',
      bottom: Row(
        children: [
          if (_step == 4)
            Expanded(
              child: OutlinedButton(
                key: const Key('s04_skip'),
                onPressed: _next,
                child: Text(t('skip')),
              ),
            ),
          if (_step == 4) const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const Key('s04_next'),
              onPressed: _stepComplete ? _next : null,
              child: Text(_step == 4 ? t('s04_submit') : t('next')),
            ),
          ),
        ],
      ),
      children: [
        Semantics(
          label: t.f('s04_step', {'n': '${_step + 1}'}),
          child: LinearProgressIndicator(value: (_step + 1) / 5, minHeight: 6),
        ),
        const SizedBox(height: 8),
        Text(t.f('s04_step', {'n': '${_step + 1}'}), style: TextStyle(color: scheme.onSurfaceVariant)),
        Text(stepTitles[_step], style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ..._stepBody(t, scheme),
      ],
    );
  }

  List<Widget> _stepBody(Strings t, ColorScheme scheme) {
    switch (_step) {
      case 0:
        return [
          if (!_consent)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('s04_consent_title'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 8),
                    Text(t('s04_consent_body')),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      key: const Key('s04_consent'),
                      label: t('s04_consent_accept'),
                      onPressed: () => setState(() => _consent = true),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            CaptureTrio(
              keyPrefix: 's04_cedula',
              label: t('s04_doc_cedula'),
              captured: _captured.contains('cedula'),
              onCapture: () => setState(() => _captured.add('cedula')),
            ),
            CaptureTrio(
              keyPrefix: 's04_selfie',
              label: t('s04_doc_selfie'),
              captured: _captured.contains('selfie'),
              onCapture: () => setState(() => _captured.add('selfie')),
            ),
          ],
        ];
      case 1:
        return [
          InfoBanner(text: t('s04_step2_review')),
          CaptureTrio(
            keyPrefix: 's04_registration',
            label: t('s04_doc_registration'),
            captured: _captured.contains('registration'),
            onCapture: () => setState(() => _captured.add('registration')),
          ),
          CaptureTrio(
            keyPrefix: 's04_vehicle',
            label: t('s04_doc_vehicle_photo'),
            captured: _captured.contains('vehicle'),
            onCapture: () => setState(() => _captured.add('vehicle')),
          ),
          Text(t('s04_plate_blur'), style: TextStyle(color: scheme.onSurfaceVariant)),
        ];
      case 2:
        return [
          TextField(
            decoration: InputDecoration(labelText: t('s04_operator_name')),
            controller: TextEditingController(text: MockData.me.operator),
          ),
          CaptureTrio(
            keyPrefix: 's04_permit',
            label: t('s04_doc_permit'),
            captured: _captured.contains('permit'),
            onCapture: () => setState(() => _captured.add('permit')),
          ),
        ];
      case 3:
        return [
          DropdownButtonFormField<String>(
            initialValue: 'E',
            decoration: InputDecoration(labelText: t('s04_licence_type')),
            items: const [
              DropdownMenuItem(value: 'C', child: Text('C')),
              DropdownMenuItem(value: 'D', child: Text('D')),
              DropdownMenuItem(value: 'E', child: Text('E')),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(labelText: t('s04_licence_expiry')),
            controller: TextEditingController(text: '2028-06-30'),
          ),
          CaptureTrio(
            keyPrefix: 's04_licence',
            label: t('s04_step4'),
            captured: _captured.contains('licence'),
            onCapture: () => setState(() => _captured.add('licence')),
          ),
          TextField(
            key: const Key('s04_ruc'),
            decoration: InputDecoration(labelText: t('s04_ruc')),
            onChanged: (v) => AppScope.of(context).driver.rucProvided = v.trim().isNotEmpty,
          ),
        ];
      default:
        return [
          Text(t('s04_services_intro'), style: TextStyle(color: scheme.onSurfaceVariant)),
          SwitchListTile(
            value: _insurance,
            onChanged: (v) => setState(() => _insurance = v),
            title: Text(t('s04_svc_insurance')),
            subtitle: Text(t('s04_svc_insurance_fields')),
            contentPadding: EdgeInsets.zero,
          ),
          if (_insurance)
            CaptureTrio(
              label: t('s04_svc_insurance'),
              captured: _captured.contains('insurance'),
              onCapture: () => setState(() => _captured.add('insurance')),
            ),
          SwitchListTile(
            value: _tracking,
            onChanged: (v) => setState(() => _tracking = v),
            title: Text(t('s04_svc_tracking')),
            subtitle: Text(t('s04_svc_tracking_fields')),
            contentPadding: EdgeInsets.zero,
          ),
          SectionTitle(t('s04_body_type')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in MockData.bodyTypeKeys)
                ChoiceChip(
                  label: Text(t(k)),
                  selected: _bodyType == k,
                  onSelected: (_) => setState(() => _bodyType = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          StepperRow(
            label: t('s04_tonnage'),
            value: t.f('unit_tons', {'t': '$_tons'}),
            onMinus: _tons > 1 ? () => setState(() => _tons--) : null,
            onPlus: _tons < 40 ? () => setState(() => _tons++) : null,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(labelText: t('s04_dimensions'), hintText: '6 × 2,4 × 2,4 m'),
          ),
        ];
    }
  }
}

// ---------------------------------------------------------------------------
// S05 Verification status (4 states, A1.6)
// ---------------------------------------------------------------------------
class S05Verification extends StatelessWidget {
  const S05Verification({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final v = state.driver.verification;
    final scheme = Theme.of(context).colorScheme;

    final (icon, color, body) = switch (v) {
      VerificationState.pending => (Icons.hourglass_top, AppTheme.secondary, t('s05_pending_body')),
      VerificationState.approved => (Icons.verified, AppTheme.success, t('s05_approved_body')),
      VerificationState.rejected => (Icons.error_outline, AppTheme.danger, t('s05_rejected_reason')),
      VerificationState.exhausted => (Icons.support_agent, AppTheme.danger, t('s05_exhausted_body')),
    };

    Future<void> goHome() async {
      if (state.shouldOfferInstall()) {
        await showInstallSheet(context);
      }
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.s06, (r) => r.isFirst);
    }

    return AppScreen(
      title: t('s05_title'),
      screenId: 'S05',
      bottom: switch (v) {
        VerificationState.approved => PrimaryButton(
            key: const Key('s05_continue'),
            label: t('continue'),
            onPressed: goHome,
          ),
        VerificationState.pending => SecondaryButton(
            key: const Key('s05_explore'),
            label: t('s05_explore_only'),
            onPressed: () => Navigator.pushNamed(context, Routes.s09),
          ),
        VerificationState.rejected => PrimaryButton(
            key: const Key('s05_reupload'),
            label: t('s05_reupload'),
            icon: Icons.upload_outlined,
            onPressed: () => state.setVerification(VerificationState.pending),
          ),
        VerificationState.exhausted => PrimaryButton(
            key: const Key('s05_contact'),
            label: t('s05_contact'),
            icon: Icons.chat_outlined,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('s22_rule'))),
            ),
          ),
      },
      children: [
        const SizedBox(height: 24),
        Icon(icon, size: 72, color: color),
        const SizedBox(height: 12),
        Text(
          verificationLabel(t, v),
          key: const Key('s05_state_label'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        if (v == VerificationState.rejected) ...[
          const SizedBox(height: 8),
          Text(t.f('s05_attempts_left', {'n': '2'}), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 24),
        _DocRow(label: t('s04_doc_cedula'), ok: v != VerificationState.pending),
        _DocRow(label: t('s04_doc_registration'), ok: v == VerificationState.approved, bad: v == VerificationState.rejected || v == VerificationState.exhausted),
        _DocRow(label: t('s04_doc_permit'), ok: v != VerificationState.pending),
        _DocRow(label: t('s04_step4'), ok: v != VerificationState.pending),
        const SizedBox(height: 16),
        DemoNote(t('s05_demo_states')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in VerificationState.values)
              ChoiceChip(
                key: Key('s05_demo_${s.name}'),
                label: Text(verificationLabel(t, s)),
                selected: v == s,
                onSelected: (_) => state.setVerification(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.label, required this.ok, this.bad = false});
  final String label;
  final bool ok;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // 4.7 "ninguna información solo por color": the state is also text.
    final (icon, stateText, color) = bad
        ? (Icons.cancel_outlined, t('s05_doc_rejected'), AppTheme.danger)
        : ok
            ? (Icons.check_circle_outline, t('s05_doc_approved'), AppTheme.success)
            : (Icons.hourglass_empty, t('s05_doc_pending'), AppTheme.secondary);
    return Semantics(
      label: '$label: $stateText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16)),
                  Text(stateText, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
