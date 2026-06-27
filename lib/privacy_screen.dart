import 'dart:ui';
import 'package:flutter/material.dart';
import 'searxng_config.dart';

// ================================================================
//  PrivacyScreen — Privacidade & Trackers
//  Mostra contador por domínio + toggles por categoria
//  Design glassmorphism — sem AppBar, sem barra preta
// ================================================================

class PrivacyScreen extends StatefulWidget {
  final int totalBlocked;
  final Map<String, int> blockedByDomain;

  const PrivacyScreen({
    Key? key,
    required this.totalBlocked,
    required this.blockedByDomain,
  }) : super(key: key);

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // Toggles por categoria — lidos do SearxNGConfig
  bool _blockAnalytics = true;
  bool _blockAds       = true;
  bool _blockSocial    = true;

  // Categorias mapeadas
  static const _analytics = [
    'google-analytics.com',
    'googletagmanager.com',
    'hotjar.com',
    'segment.com',
    'mixpanel.com',
    'amplitude.com',
  ];

  static const _ads = [
    'doubleclick.net',
    'ads.twitter.com',
    'analytics.tiktok.com',
  ];

  static const _social = [
    'facebook.com/tr',
    'connect.facebook.net',
    'intercom.io',
    'crisp.chat',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sem AppBar — fundo gradiente igual à home
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fundo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDFE9FF),
                  Color(0xFFEDE7F6),
                  Color(0xFFE0F7FA),
                ],
              ),
            ),
          ),

          // Blobs
          Positioned(top: -60, left: -60,
            child: _blob(260, const Color(0xFFB39DDB))),
          Positioned(top: 200, right: -50,
            child: _blob(200, const Color(0xFF80DEEA))),
          Positioned(bottom: 150, left: -40,
            child: _blob(180, const Color(0xFFF48FB1))),

          // Conteúdo
          SafeArea(
            child: Column(
              children: [
                // Cabeçalho glass — sem AppBar nativa
                _GlassHeader(
                  title: 'Privacidade & Trackers',
                  onBack: () => Navigator.pop(context),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      // ── Resumo total ──────────────────────
                      _GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D4FF).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.shield,
                                  color: Color(0xFF00D4FF), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.totalBlocked}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A3E),
                                  ),
                                ),
                                const Text(
                                  'rastreadores bloqueados',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF5F5F5F)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Toggles por categoria ─────────────
                      const _SectionLabel('Categorias bloqueadas'),
                      const SizedBox(height: 8),

                      _CategoryToggle(
                        icon: Icons.analytics,
                        label: 'Analytics',
                        subtitle: 'Google Analytics, Hotjar, Mixpanel...',
                        value: _blockAnalytics,
                        color: const Color(0xFF7C4DFF),
                        onChanged: (v) =>
                            setState(() => _blockAnalytics = v),
                      ),
                      const SizedBox(height: 8),

                      _CategoryToggle(
                        icon: Icons.campaign,
                        label: 'Publicidade',
                        subtitle: 'DoubleClick, Twitter Ads, TikTok Ads...',
                        value: _blockAds,
                        color: const Color(0xFFE07A2A),
                        onChanged: (v) =>
                            setState(() => _blockAds = v),
                      ),
                      const SizedBox(height: 8),

                      _CategoryToggle(
                        icon: Icons.people,
                        label: 'Redes sociais',
                        subtitle: 'Facebook Pixel, Intercom, Crisp...',
                        value: _blockSocial,
                        color: const Color(0xFF1558D6),
                        onChanged: (v) =>
                            setState(() => _blockSocial = v),
                      ),

                      const SizedBox(height: 20),

                      // ── Lista por domínio ─────────────────
                      if (widget.blockedByDomain.isNotEmpty) ...[
                        const _SectionLabel('Bloqueados por domínio'),
                        const SizedBox(height: 8),
                        _GlassCard(
                          child: Column(
                            children: widget.blockedByDomain.entries
                                .toList()
                              ..sort((a, b) => b.value.compareTo(a.value))
                              ..take(20).forEach((_) {})
                              ..asMap()
                              .entries
                              .where((e) =>
                                  e.key <
                                  widget.blockedByDomain.length)
                              .map((e) => e.value)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                                final domain =
                                    entry.value.key;
                                final count =
                                    entry.value.value;
                                final isLast = entry.key ==
                                    widget.blockedByDomain.length - 1;
                                return _DomainRow(
                                  domain: domain,
                                  count: count,
                                  showDivider: !isLast,
                                );
                              })
                              .toList(),
                          ),
                        ),
                      ] else ...[
                        const _SectionLabel('Bloqueados por domínio'),
                        const SizedBox(height: 8),
                        _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Nenhum rastreador bloqueado ainda.\nNavegue para ver os resultados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF5F5F5F)
                                      .withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Lista completa de domínios monitorados
                      const _SectionLabel('Domínios monitorados'),
                      const SizedBox(height: 8),
                      _GlassCard(
                        child: Column(
                          children: SearxNGConfig.trackerDomains
                              .asMap()
                              .entries
                              .map((e) => _DomainRow(
                                    domain: e.value,
                                    count: widget.blockedByDomain[e.value] ?? 0,
                                    showDivider: e.key <
                                        SearxNGConfig.trackerDomains.length - 1,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: const SizedBox.expand(),
        ),
      );
}

// ── Cabeçalho glass (sem AppBar nativa) ─────────────────────────
class _GlassHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _GlassHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withOpacity(0.6), width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A1A3E), size: 22),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A3E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card glass reutilizável ──────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Label de seção ───────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A8A8A),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Toggle de categoria ──────────────────────────────────────────
class _CategoryToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _CategoryToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value
                  ? color.withOpacity(0.3)
                  : Colors.white.withOpacity(0.9),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: value
                              ? const Color(0xFF1A1A3E)
                              : const Color(0xFF8A8A8A),
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8A8A8A))),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Linha de domínio ─────────────────────────────────────────────
class _DomainRow extends StatelessWidget {
  final String domain;
  final int count;
  final bool showDivider;

  const _DomainRow({
    required this.domain,
    required this.count,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.block, size: 14, color: Color(0xFF8A8A8A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  domain,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF333333)),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0097A7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              color: Colors.black.withOpacity(0.06)),
      ],
    );
  }
}
