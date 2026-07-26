import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/responsive.dart';
import '../providers/skin_provider.dart';
import '../providers/telegram_account_provider.dart';
import '../services/telegram/td_media.dart';
import '../widgets/common.dart';

/// Telegram account login + source settings.
///
/// This is a real Telegram login: phone number, the one-time code Telegram
/// sends you, and your two-step verification password if you have one. No bot,
/// no forwarding, no 20 MB cap -- anything your account can see can be streamed
/// in the app.
class TelegramScreen extends StatefulWidget {
  const TelegramScreen({super.key});

  @override
  State<TelegramScreen> createState() => _TelegramScreenState();
}

class _TelegramScreenState extends State<TelegramScreen> {
  final _apiIdCtrl = TextEditingController();
  final _apiHashCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _filterCtrl = TextEditingController();

  String _filter = '';
  bool _forceApiForm = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<TelegramAccountProvider>();
    _apiIdCtrl.text = account.apiId;
    _apiHashCtrl.text = account.apiHash;
    _phoneCtrl.text = account.phone;
  }

  @override
  void dispose() {
    _apiIdCtrl.dispose();
    _apiHashCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final r = Responsive.of(context);
    final account = context.watch<TelegramAccountProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.bg,
        title: const Text('Telegram',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (account.isLoggedIn)
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: account.busy
                  ? null
                  : () => context.read<TelegramAccountProvider>().logOut(),
            ),
        ],
      ),
      body: ListView(
        padding:
            EdgeInsets.fromLTRB(r.gutter, 12, r.gutter, r.bottomSafePadding),
        children: [
          _StatusBanner(account: account),
          if (account.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: account.error!,
              onDismiss: () =>
                  context.read<TelegramAccountProvider>().clearError(),
            ),
          ],
          const SizedBox(height: 18),
          ..._stageContent(account),
        ],
      ),
    );
  }

  List<Widget> _stageContent(TelegramAccountProvider account) {
    if (!account.available || account.stage == TgStage.unavailable) {
      return const [_UnavailableCard()];
    }
    if (_forceApiForm || account.stage == TgStage.needsApiCredentials) {
      return _apiForm(account);
    }
    switch (account.stage) {
      case TgStage.connecting:
        return [
          const _InfoCard(
            icon: Icons.sync_rounded,
            title: 'Connecting',
            body: 'Talking to Telegram. This only takes a moment.',
          ),
        ];
      case TgStage.waitPhone:
        return _phoneForm(account);
      case TgStage.waitCode:
        return _codeForm(account);
      case TgStage.waitPassword:
        return _passwordForm(account);
      case TgStage.ready:
        return _accountPanel(account);
      default:
        return _phoneForm(account);
    }
  }

  // ------------------------------------------------------------------- step 1

  List<Widget> _apiForm(TelegramAccountProvider account) {
    return [
      const _InfoCard(
        icon: Icons.vpn_key_rounded
        ,
        title: 'One-time setup',
        body:
            'Telegram requires every client to have its own api_id and api_hash. '
            'Create yours in a minute at my.telegram.org, then paste them here. '
            'They stay on this device.',
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse('https://my.telegram.org/auth'),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('Open my.telegram.org'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _apiIdCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'api_id',
          hintText: '1234567',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _apiHashCtrl,
        decoration: const InputDecoration(
          labelText: 'api_hash',
          hintText: '0123456789abcdef0123456789abcdef',
        ),
      ),
      const SizedBox(height: 16),
      GradientButton(
        label: account.busy ? 'Saving...' : 'Save and continue',
        icon: Icons.arrow_forward_rounded,
        expanded: true,
        onPressed: account.busy
            ? null
            : () async {
                final id = _apiIdCtrl.text.trim();
                final hash = _apiHashCtrl.text.trim();
                if (id.isEmpty || hash.isEmpty) return;
                setState(() => _forceApiForm = false);
                await context
                    .read<TelegramAccountProvider>()
                    .setApiCredentials(id, hash);
              },
      ),
    ];
  }

  // ------------------------------------------------------------------- step 2

  List<Widget> _phoneForm(TelegramAccountProvider account) {
    return [
      const _InfoCard(
        icon: Icons.smartphone_rounded,
        title: 'Log in with your phone number',
        body:
            'Telegram will send a login code to your other Telegram sessions or '
            'by SMS. Nothing is posted from your account -- the app only reads '
            'video files so it can stream them.',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '+91 98765 43210',
        ),
      ),
      const SizedBox(height: 16),
      GradientButton(
        label: account.busy ? 'Sending code...' : 'Send code',
        icon: Icons.send_rounded,
        expanded: true,
        onPressed: account.busy
            ? null
            : () => context
                .read<TelegramAccountProvider>()
                .sendPhone(_phoneCtrl.text),
      ),
      const SizedBox(height: 8),
      _ChangeApiLink(onTap: () => setState(() => _forceApiForm = true)),
    ];
  }

  // ------------------------------------------------------------------- step 3

  List<Widget> _codeForm(TelegramAccountProvider account) {
    return [
      _InfoCard(
        icon: Icons.password_rounded,
        title: 'Enter your login code',
        body: account.codeHint == null
            ? 'Type the code Telegram just sent to ${account.phone}.'
            : '${account.codeHint} \u2022 sent to ${account.phone}.',
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: '', hintText: '000000'),
        onSubmitted: (value) =>
            context.read<TelegramAccountProvider>().submitCode(value),
      ),
      const SizedBox(height: 8),
      GradientButton(
        label: account.busy ? 'Checking...' : 'Log in',
        icon: Icons.login_rounded,
        expanded: true,
        onPressed: account.busy
            ? null
            : () => context
                .read<TelegramAccountProvider>()
                .submitCode(_codeCtrl.text),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: account.busy
                ? null
                : () => context.read<TelegramAccountProvider>().resendCode(),
            child: const Text('Resend code'),
          ),
          TextButton(
            onPressed: account.busy
                ? null
                : () => context.read<TelegramAccountProvider>().changeNumber(),
            child: const Text('Change number'),
          ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------------- step 4

  List<Widget> _passwordForm(TelegramAccountProvider account) {
    return [
      _InfoCard(
        icon: Icons.lock_rounded,
        title: 'Two-step verification',
        body: account.passwordHint == null
            ? 'Your account is protected with a password. Enter it to finish.'
            : 'Password hint: ${account.passwordHint}',
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _passwordCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (value) =>
            context.read<TelegramAccountProvider>().submitPassword(value),
      ),
      const SizedBox(height: 16),
      GradientButton(
        label: account.busy ? 'Checking...' : 'Continue',
        icon: Icons.check_rounded,
        expanded: true,
        onPressed: account.busy
            ? null
            : () => context
                .read<TelegramAccountProvider>()
                .submitPassword(_passwordCtrl.text),
      ),
    ];
  }

  // ---------------------------------------------------------------- logged in

  List<Widget> _accountPanel(TelegramAccountProvider account) {
    final skin = context.skin;
    final provider = context.read<TelegramAccountProvider>();

    final chats = account.chats
        .where((chat) =>
            _filter.isEmpty ||
            chat.title.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: account.enabled,
        activeColor: skin.accent,
        title: const Text('Use Telegram as a source'),
        subtitle: const Text(
            'Telegram results are merged with addons and providers in the stream list'),
        onChanged: provider.setEnabled,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: account.searchAllChats,
        activeColor: skin.accent,
        title: const Text('Search all chats, channels and groups'),
        subtitle: const Text('Looks through everything your account can see'),
        onChanged: provider.setSearchAllChats,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: account.onDemandSearch,
        activeColor: skin.accent,
        title: const Text('Search per title, on demand'),
        subtitle: const Text(
            'Queries Telegram the moment you open a movie or episode'),
        onChanged: provider.setOnDemandSearch,
      ),
      const SizedBox(height: 16),
      const _SectionTitle('Pinned chats'),
      Text(
        'Pick the channels and groups you actually watch from. These are '
        'searched first, and they are the ones indexed for browsing.',
        style: TextStyle(fontSize: 12, height: 1.4, color: skin.textSecondary),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _filterCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: 'Filter chats',
          isDense: true,
        ),
        onChanged: (value) => setState(() => _filter = value),
      ),
      const SizedBox(height: 6),
      if (account.chats.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            account.busy ? 'Loading your chats...' : 'No chats loaded yet.',
            style: TextStyle(color: skin.textSecondary, fontSize: 13),
          ),
        )
      else
        ...chats.map(
          (chat) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: skin.accent,
            value: account.selectedChats.contains(chat.id),
            title: Text(
              chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
            subtitle: Text(
              chat.typeLabel,
              style: TextStyle(fontSize: 11, color: skin.textSecondary),
            ),
            onChanged: (value) => provider.toggleChat(chat.id, value ?? false),
          ),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: GhostButton(
              label: 'Reload chats',
              icon: Icons.refresh_rounded,
              onPressed: account.busy ? null : provider.loadChats,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GhostButton(
              label: 'Index videos',
              icon: Icons.playlist_add_check_rounded,
              onPressed: account.busy ? null : provider.refreshIndex,
            ),
          ),
        ],
      ),
      if (account.index.isNotEmpty) ...[
        const SizedBox(height: 20),
        _SectionTitle('Indexed videos (${account.index.length})'),
        const SizedBox(height: 6),
        ...account.index.take(40).map((media) => _MediaRow(media: media)),
      ],
    ];
  }
}

class _StatusBanner extends StatelessWidget {
  final TelegramAccountProvider account;
  const _StatusBanner({required this.account});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ready = account.isLoggedIn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          skin.accent.withOpacity(ready ? 0.28 : 0.16),
          skin.accentAlt.withOpacity(0.10),
        ]),
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Row(
        children: [
          Icon(ready ? Icons.verified_rounded : Icons.send_rounded,
              color: ready ? skin.accent : skin.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.statusLabel,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Streams start instantly and can be seeked, because files are '
                  'fetched in ranges straight from Telegram.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.4, color: skin.textSecondary),
                ),
              ],
            ),
          ),
          if (account.busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: skin.accent),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: skin.danger.withOpacity(0.12),
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.danger.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: skin.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12.5, color: skin.textPrimary)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: skin.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(body,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: skin.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.extension_off_rounded,
      title: 'Telegram login unavailable in this build',
      body:
          'This APK was built without the Telegram native library, so account '
          'login is disabled. Everything else in the app works normally; '
          'rebuild with the Telegram library step enabled to use it.',
    );
  }
}

class _ChangeApiLink extends StatelessWidget {
  final VoidCallback onTap;
  const _ChangeApiLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Change api_id / api_hash'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
          color: skin.textSecondary,
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final TgMedia media;
  const _MediaRow({required this.media});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final meta = [
      if (media.chatTitle.isNotEmpty) media.chatTitle,
      if (media.sizeLabel.isNotEmpty) media.sizeLabel,
      if (media.durationLabel.isNotEmpty) media.durationLabel,
      if (media.qualityLabel != null) media.qualityLabel!,
    ].join('  \u2022  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: skin.cardBorderRadius,
        border: Border.all(color: skin.stroke),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_rounded, size: 18, color: skin.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(media.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: skin.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
