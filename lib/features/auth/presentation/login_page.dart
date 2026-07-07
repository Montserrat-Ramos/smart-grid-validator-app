import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/common_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    await ref.read(authControllerProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  Future<void> _guest() async {
    await ref.read(authControllerProvider.notifier).guest();
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        backgroundColor: AppColors.surface,
        title: const Text('Recuperar contraseña'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (email == null || email.isEmpty || !mounted) return;

    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud registrada. Revisa las instrucciones del administrador.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _register() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final key = GlobalKey<FormState>();

    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        backgroundColor: AppColors.surface,
        title: const Text('Crear cuenta'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                  (value ?? '').trim().length < 2
                      ? 'Escribe tu nombre.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) => !(value ?? '').contains('@')
                      ? 'Correo no válido.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => (value ?? '').length < 8
                      ? 'Mínimo 8 caracteres.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() != true) return;

              Navigator.pop(
                dialogContext,
                (
                name.text.trim(),
                email.text.trim(),
                password.text,
                ),
              );
            },
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );

    name.dispose();
    email.dispose();
    password.dispose();

    if (result == null || !mounted) return;

    await ref
        .read(authControllerProvider.notifier)
        .register(result.$1, result.$2, result.$3);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final width = viewport.maxWidth;
          final height = viewport.maxHeight;

          // No se decide únicamente por ancho. Una ventana ancha pero baja
          // también necesita una composición vertical y desplazable.
          final useWideLayout = width >= 1050 && height >= 720;
          final useDesktopBackground = width >= 900;

          final horizontalPadding = width >= 1200
              ? 64.0
              : width >= 700
              ? 32.0
              : 18.0;
          final verticalPadding = height >= 800 ? 32.0 : 18.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                useDesktopBackground
                    ? 'assets/images/login_background_web.png'
                    : 'assets/images/login_background_mobile.png',
                fit: BoxFit.cover,
                alignment: useDesktopBackground
                    ? Alignment.center
                    : Alignment.topCenter,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: useDesktopBackground
                        ? [
                      AppColors.background.withValues(alpha: .98),
                      AppColors.background.withValues(alpha: .91),
                      AppColors.background.withValues(alpha: .72),
                    ]
                        : [
                      AppColors.background.withValues(alpha: .88),
                      AppColors.background.withValues(alpha: .92),
                      AppColors.background.withValues(alpha: .99),
                    ],
                    begin: useDesktopBackground
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    end: useDesktopBackground
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, safeViewport) {
                    final calculatedMinHeight =
                        safeViewport.maxHeight - (verticalPadding * 2);
                    final minContentHeight = calculatedMinHeight > 0
                        ? calculatedMinHeight
                        : 0.0;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 1440,
                            minHeight: minContentHeight,
                          ),
                          child: useWideLayout
                              ? _WideLoginLayout(
                            compactPresentation:
                            height < 850 || width < 1250,
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            rememberMe: _rememberMe,
                            isSubmitting: auth.isSubmitting,
                            errorMessage: auth.errorMessage,
                            onTogglePassword: () => setState(
                                  () => _obscurePassword =
                              !_obscurePassword,
                            ),
                            onRememberChanged: (value) => setState(
                                  () => _rememberMe = value ?? false,
                            ),
                            onSubmit: _submit,
                            onGuest: _guest,
                            onForgotPassword: _forgotPassword,
                            onRegister: _register,
                          )
                              : _NarrowLoginLayout(
                            showCompactPresentation:
                            width < 430 || height < 620,
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            rememberMe: _rememberMe,
                            isSubmitting: auth.isSubmitting,
                            errorMessage: auth.errorMessage,
                            onTogglePassword: () => setState(
                                  () => _obscurePassword =
                              !_obscurePassword,
                            ),
                            onRememberChanged: (value) => setState(
                                  () => _rememberMe = value ?? false,
                            ),
                            onSubmit: _submit,
                            onGuest: _guest,
                            onForgotPassword: _forgotPassword,
                            onRegister: _register,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WideLoginLayout extends StatelessWidget {
  const _WideLoginLayout({
    required this.compactPresentation,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onSubmit,
    required this.onGuest,
    required this.onForgotPassword,
    required this.onRegister,
  });

  final bool compactPresentation;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onSubmit;
  final VoidCallback onGuest;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth >= 1300 ? 70.0 : 36.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 11,
              child: _DesktopPresentation(
                compact: compactPresentation,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 8,
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _LoginCard(
                    formKey: formKey,
                    emailController: emailController,
                    passwordController: passwordController,
                    obscurePassword: obscurePassword,
                    rememberMe: rememberMe,
                    isSubmitting: isSubmitting,
                    errorMessage: errorMessage,
                    onTogglePassword: onTogglePassword,
                    onRememberChanged: onRememberChanged,
                    onSubmit: onSubmit,
                    onGuest: onGuest,
                    onForgotPassword: onForgotPassword,
                    onRegister: onRegister,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NarrowLoginLayout extends StatelessWidget {
  const _NarrowLoginLayout({
    required this.showCompactPresentation,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onSubmit,
    required this.onGuest,
    required this.onForgotPassword,
    required this.onRegister,
  });

  final bool showCompactPresentation;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onSubmit;
  final VoidCallback onGuest;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MobilePresentation(compact: showCompactPresentation),
        SizedBox(height: showCompactPresentation ? 16 : 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _LoginCard(
            formKey: formKey,
            emailController: emailController,
            passwordController: passwordController,
            obscurePassword: obscurePassword,
            rememberMe: rememberMe,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onTogglePassword: onTogglePassword,
            onRememberChanged: onRememberChanged,
            onSubmit: onSubmit,
            onGuest: onGuest,
            onForgotPassword: onForgotPassword,
            onRegister: onRegister,
          ),
        ),
      ],
    );
  }
}

class _DesktopPresentation extends StatelessWidget {
  const _DesktopPresentation({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _FeatureCard(
        icon: Icons.verified_user_outlined,
        title: 'Validación\nautomática',
        description: 'Reglas topológicas y eléctricas estandarizadas.',
        color: AppColors.green,
      ),
      const _FeatureCard(
        icon: Icons.hub_outlined,
        title: 'Análisis de\ngrafos',
        description: 'Topologías interactivas y fáciles de comprender.',
        color: AppColors.primary,
      ),
      const _FeatureCard(
        icon: Icons.warning_amber_rounded,
        title: 'Detección de\nanomalías',
        description: 'Identificación clara de inconsistencias críticas.',
        color: AppColors.warning,
      ),
      const _FeatureCard(
        icon: Icons.description_outlined,
        title: 'Reportes\nprofesionales',
        description: 'Resultados listos para análisis y auditoría.',
        color: Color(0xFF9FC2FF),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBrand(logoSize: compact ? 88 : 112),
        SizedBox(height: compact ? 20 : 34),
        Text(
          'Valida. Visualiza. Confía.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 28 : 32,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Plataforma inteligente para la validación de redes eléctricas con '
                'análisis topológico, detección de anomalías y generación de reportes profesionales.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 15 : 17,
              height: compact ? 1.4 : 1.55,
            ),
          ),
        ),
        SizedBox(height: compact ? 18 : 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 620
                ? (constraints.maxWidth - 42) / 4
                : constraints.maxWidth >= 360
                ? (constraints.maxWidth - 14) / 2
                : constraints.maxWidth;

            final normalizedWidth = cardWidth.clamp(120.0, 150.0).toDouble();

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: cards
                  .map(
                    (card) => SizedBox(
                  width: normalizedWidth,
                  child: _FeatureCard(
                    icon: card.icon,
                    title: card.title,
                    description: card.description,
                    color: card.color,
                    compact: compact,
                  ),
                ),
              )
                  .toList(),
            );
          },
        ),
        SizedBox(height: compact ? 18 : 30),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 18,
              vertical: compact ? 11 : 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .76),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seguridad. Trazabilidad. Eficiencia.',
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Smart Grid Validator impulsa redes más inteligentes y confiables.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobilePresentation extends StatelessWidget {
  const _MobilePresentation({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBrand(logoSize: compact ? 72 : 94),
          SizedBox(height: compact ? 12 : 22),
          Text(
            'Valida. Visualiza. Confía.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: compact ? 22 : 26,
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          Text(
            compact
                ? 'Validación inteligente y detección de anomalías para redes eléctricas.'
                : 'Plataforma inteligente para la validación de redes eléctricas con '
                'análisis topológico, detección de anomalías y generación de reportes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 13 : 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: compact ? 158 : 185,
      ),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 30 : 34),
          SizedBox(height: compact ? 9 : 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 13 : 14,
              height: 1.3,
            ),
          ),
          SizedBox(height: compact ? 7 : 9),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 10.5 : 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onSubmit,
    required this.onGuest,
    required this.onForgotPassword,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onSubmit;
  final VoidCallback onGuest;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final veryCompact = constraints.maxWidth < 350;

        return Card(
          margin: EdgeInsets.zero,
          color: AppColors.surface.withValues(alpha: .93),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: veryCompact
                  ? 14
                  : compact
                  ? 20
                  : 34,
              vertical: compact ? 22 : 32,
            ),
            child: AutofillGroup(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: compact ? 50 : 58,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 13),
                    Text(
                      'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Accede a tu plataforma de validación',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    SizedBox(height: compact ? 20 : 24),
                    const Text(
                      'Correo electrónico',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: emailController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        hintText: 'correo@ejemplo.com',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty || !text.contains('@')) {
                          return 'Ingresa un correo válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Contraseña',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: passwordController,
                      enabled: !isSubmitting,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => onSubmit(),
                      decoration: InputDecoration(
                        hintText: '••••••••••',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: isSubmitting
                              ? null
                              : onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) {
                          return 'La contraseña debe tener al menos 8 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    _LoginOptions(
                      compact: compact,
                      rememberMe: rememberMe,
                      isSubmitting: isSubmitting,
                      onRememberChanged: onRememberChanged,
                      onForgotPassword: onForgotPassword,
                    ),
                    if (errorMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 13),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .12),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: .35),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: isSubmitting ? null : onSubmit,
                        icon: isSubmitting
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.login),
                        label: Text(
                          isSubmitting
                              ? 'Ingresando…'
                              : 'Iniciar sesión',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onGuest,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Continuar como invitado'),
                    ),
                    const SizedBox(height: 17),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 2,
                      runSpacing: 0,
                      children: [
                        const Text(
                          '¿No tienes cuenta?',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        TextButton(
                          onPressed: isSubmitting ? null : onRegister,
                          child: const Text('Crear cuenta'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginOptions extends StatelessWidget {
  const _LoginOptions({
    required this.compact,
    required this.rememberMe,
    required this.isSubmitting,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  final bool compact;
  final bool rememberMe;
  final bool isSubmitting;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final rememberWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: rememberMe,
          onChanged: isSubmitting ? null : onRememberChanged,
        ),
        const Flexible(
          child: Text(
            'Recordarme',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );

    final forgotWidget = TextButton(
      onPressed: isSubmitting ? null : onForgotPassword,
      child: const Text(
        '¿Olvidaste tu contraseña?',
        textAlign: TextAlign.end,
        style: TextStyle(fontSize: 12),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: rememberWidget,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: forgotWidget,
          ),
        ],
      );
    }

    return Row(
      children: [
        rememberWidget,
        const Spacer(),
        Flexible(child: forgotWidget),
      ],
    );
  }
}
