import 'package:flutter/material.dart';

import '../services/webdav_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.webdavService, this.onSaved});

  final WebdavService webdavService;
  final VoidCallback? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(text: WebdavService.defaultUrl);
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final config = await widget.webdavService.loadConfig();
      if (!mounted) return;
      setState(() {
        _urlController.text = config.url;
        _usernameController.text = config.username;
        _passwordController.text = config.password;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'Could not read secure storage: $error';
        _statusIsError = true;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      await widget.webdavService.saveCredentials(
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await widget.webdavService.connect();
      if (!mounted) return;

      setState(() {
        _saving = false;
        _statusMessage = 'Saved. The NAS connection was verified.';
        _statusIsError = false;
      });
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved and NAS connection verified.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusMessage = error.toString();
        _statusIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NAS WebDAV',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Connect to the Dufs WebDAV endpoint on your '
                            'private tailnet.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'WebDAV URL',
                              hintText: WebdavService.defaultUrl,
                              prefixIcon: Icon(Icons.link),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              try {
                                WebdavService.normalizeUrl(value ?? '');
                                return null;
                              } on WebdavException catch (error) {
                                return error.message;
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _usernameController,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Username is required.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Password is required.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving ? 'Saving and testing…' : 'Save',
                              ),
                            ),
                          ),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _statusIsError
                                    ? theme.colorScheme.errorContainer
                                    : theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _statusIsError
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    size: 20,
                                    color: _statusIsError
                                        ? theme.colorScheme.onErrorContainer
                                        : theme
                                              .colorScheme
                                              .onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _statusMessage!,
                                      style: TextStyle(
                                        color: _statusIsError
                                            ? theme.colorScheme.onErrorContainer
                                            : theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Credential storage',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The password is stored in the platform secure '
                            'store (Android Keystore / iOS Keychain). It is '
                            'never written to this project or to Git.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Default endpoint: ${WebdavService.defaultUrl}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
