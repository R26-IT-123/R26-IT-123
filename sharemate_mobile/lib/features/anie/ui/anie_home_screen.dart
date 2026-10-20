import 'package:flutter/material.dart';

import '../models/anie_topic.dart';
import '../services/anie_api_service.dart';
import 'note_upload_screen.dart';
import 'subject_notes_screen.dart';

class AnieHomeScreen extends StatefulWidget {
  const AnieHomeScreen({super.key});

  @override
  State<AnieHomeScreen> createState() => _AnieHomeScreenState();
}

class _AnieHomeScreenState extends State<AnieHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _service = AnieApiService();
  final _searchCtrl = TextEditingController();

  List<AnieTopic> _topics = [];
  bool _loadingTopics = true;

  String _searchQuery = '';

  int? _walletBalance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadTopics();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final balance = await _service.fetchWalletBalance();
      if (mounted) setState(() => _walletBalance = balance);
    } catch (_) {
      // Non-critical — the rest of the screen still works without it.
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    setState(() => _loadingTopics = true);
    try {
      final topics = await _service.fetchTopics();
      if (mounted) setState(() => _topics = topics);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTopics = false);
    }
  }

  /// One card per subject, in the order subjects first appear in the topics
  /// list, with the number of topics under each subject.
  List<({String subject, int topicCount})> get _visibleSubjects {
    final query = _searchQuery.trim().toLowerCase();
    final counts = <String, int>{};
    for (final t in _topics) {
      final matches = query.isEmpty ||
          t.subject.toLowerCase().contains(query) ||
          t.topic.toLowerCase().contains(query);
      if (!matches) continue;
      counts[t.subject] = (counts[t.subject] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => (subject: e.key, topicCount: e.value))
        .toList();
  }

  Future<void> _openUpload() async {
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NoteUploadScreen()),
    );
    if (uploaded == true) _loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor:  Colors.white,
            elevation:        0,
            pinned:           true,
            toolbarHeight:    68,
            leading:          IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Color(0xFF374151)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ANIE',
                        style: TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.w800,
                          color:      Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Academic Notes',
                      style: TextStyle(
                        fontSize:   17,
                        fontWeight: FontWeight.w800,
                        color:      Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Share notes, earn tokens',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
            bottom: TabBar(
              controller:       _tab,
              labelColor:       const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF9CA3AF),
              indicatorColor:   const Color(0xFF2563EB),
              indicatorWeight:  3,
              labelStyle:       const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize:   14,
              ),
              tabs: const [
                Tab(text: 'Browse Notes'),
                Tab(text: 'Upload Note'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _BrowseTab(
              subjects:        _visibleSubjects,
              loading:         _loadingTopics,
              searchCtrl:      _searchCtrl,
              walletBalance:   _walletBalance,
              onSearchChanged: (q) => setState(() => _searchQuery = q),
              onRefresh:       _loadTopics,
              onSubjectTap:    (subject) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubjectNotesScreen(subject: subject),
                  ),
                );
              },
            ),
            _UploadTab(onUpload: _openUpload),
          ],
        ),
      ),
    );
  }
}

// ── Browse tab ────────────────────────────────────────────────────────────────

class _BrowseTab extends StatelessWidget {
  const _BrowseTab({
    required this.subjects,
    required this.loading,
    required this.searchCtrl,
    this.walletBalance,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSubjectTap,
  });

  final List<({String subject, int topicCount})> subjects;
  final bool           loading;
  final TextEditingController searchCtrl;
  final int?           walletBalance;
  final void Function(String) onSearchChanged;
  final Future<void> Function() onRefresh;
  final void Function(String) onSubjectTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color:     const Color(0xFF2563EB),
      child: CustomScrollView(
        slivers: [
          // Search field
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: searchCtrl,
                onChanged:  onSearchChanged,
                decoration: InputDecoration(
                  hintText:   'Search subjects or topics…',
                  hintStyle:  const TextStyle(
                    color:    Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF9CA3AF)),
                  suffixIcon: searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            searchCtrl.clear();
                            onSearchChanged('');
                          },
                        ),
                  filled:     true,
                  fillColor:  Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:   const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            ),
          ),

          // Your token total
          if (walletBalance != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width:  36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:        const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.toll_rounded,
                          size:  20,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your Tokens',
                          style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            color:      Color(0xFF374151),
                          ),
                        ),
                      ),
                      Text(
                        '$walletBalance',
                        style: const TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.w900,
                          color:      Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Subjects',
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w800,
                  color:      Color(0xFF111827),
                ),
              ),
            ),
          ),

          if (loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (subjects.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      searchCtrl.text.isEmpty
                          ? Icons.menu_book_rounded
                          : Icons.search_off_rounded,
                      size:  60,
                      color: const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchCtrl.text.isEmpty
                          ? 'No subjects yet'
                          : 'No subjects match your search',
                      style: const TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:  2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SubjectCard(
                    subject:    subjects[i].subject,
                    topicCount: subjects[i].topicCount,
                    onTap:      () => onSubjectTap(subjects[i].subject),
                  ),
                  childCount: subjects.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.topicCount,
    required this.onTap,
  });

  final String subject;
  final int topicCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color:      Color(0x08000000),
              blurRadius: 12,
              offset:     Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                color:        const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: Color(0xFF2563EB),
              ),
            ),
            const Spacer(),
            Text(
              subject,
              style: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color:      Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$topicCount ${topicCount == 1 ? 'topic' : 'topics'}',
              style: const TextStyle(
                fontSize: 12,
                color:    Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload tab ────────────────────────────────────────────────────────────────

class _UploadTab extends StatelessWidget {
  const _UploadTab({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Info banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ANIE Engine',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Share your notes,\nearn tokens.',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w900,
                    height:     1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload a short note. Our AI model scores it and awards you tokens that unlock community notes.',
                  style: TextStyle(
                    color:  Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height:   1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Token rules
          _TokenRulesCard(),
          const SizedBox(height: 20),

          // Upload button
          SizedBox(
            width:  double.infinity,
            height: 54,
            child:  FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onUpload,
              icon:      const Icon(Icons.upload_file_rounded),
              label:     const Text(
                'Upload a Short Note',
                style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TokenRulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Token Earning Rules',
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w800,
              color:      Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          ...[
            ('75 – 100', 'Advanced coverage', '+10 tokens',
                const Color(0xFF166534), const Color(0xFFDCFCE7)),
            ('50 – 74',  'Good coverage',     '+5 tokens',
                const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
            ('40 – 49',  'Basic coverage',    '+2 tokens',
                const Color(0xFF92400E), const Color(0xFFFEF3C7)),
            ('0 – 39',   'Below threshold',   'Rejected',
                const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
          ].map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:   Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        r.$5,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      r.$1,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w800,
                        color:      r.$4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.$2,
                        style: TextStyle(
                          fontSize: 12,
                          color:    r.$4,
                        ),
                      ),
                    ),
                    Text(
                      r.$3,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w800,
                        color:      r.$4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
