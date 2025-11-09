import 'package:flutter/material.dart';

import '../models/dream_entry.dart';
import '../models/dream_highlights.dart';
import '../services/alarm_service.dart';
import '../services/dream_service.dart';
import '../services/voice_recorder.dart';

class DreamCaptureScreen extends StatefulWidget {
  const DreamCaptureScreen({
    super.key,
    DreamService? service,
    WakeAlarmService? alarmService,
    VoiceRecorder? recorder,
  })  : _service = service,
        _alarmService = alarmService,
        _recorder = recorder;

  final DreamService? _service;
  final WakeAlarmService? _alarmService;
  final VoiceRecorder? _recorder;

  @override
  State<DreamCaptureScreen> createState() => _DreamCaptureScreenState();
}

class _DreamCaptureScreenState extends State<DreamCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _transcriptController = TextEditingController();
  final _tagsController = TextEditingController();
  final _moodController = TextEditingController();
  final _searchController = TextEditingController();

  late final DreamService _service;
  late final WakeAlarmService _alarmService;
  late final VoiceRecorder _recorder;

  DreamHighlights? _highlights;
  String? _highlightError;
  Future<List<DreamEntry>>? _dreamsFuture;
  String? _activeTag;
  String? _activeMoodFilter;
  bool _isSubmitting = false;

  bool _assistantsReady = false;
  String? _assistantError;
  ScheduledAlarm? _scheduledAlarm;
  bool _requireVoiceCheckIn = true;
  bool _isSchedulingAlarm = false;

  bool _isRecording = false;
  String? _recordingBanner;
  String? _recordingError;

  String? _journalStatus;
  bool _hasDreams = false;

  bool _captureFormExpanded = true;
  bool _captureFormToggled = false;

  bool _assistantsExpanded = true;
  int _assistantsExpansionRevision = 0;

  final List<String> _promptSuggestions = const [
    'どこで夢が始まりましたか？',
    '誰が登場しましたか？',
    '印象的だった色や音はありますか？',
    '夢の中でどんな感情でしたか？',
    '繰り返し現れたモチーフは？',
    '目覚めたあと何が残りましたか？',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? DreamService();
    _alarmService = widget._alarmService ?? WakeAlarmService();
    _recorder = widget._recorder ?? VoiceRecorder();
    final initialFuture = _service.fetchDreams();
    _dreamsFuture = _trackDreams(initialFuture);
    _loadHighlights();
    _initialiseAssistants();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    _tagsController.dispose();
    _moodController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialiseAssistants() async {
    try {
      await _alarmService.initialise();
      await _recorder.initialise();
      if (!mounted) {
        return;
      }
      setState(() {
        final existingAlarm = _alarmService.scheduledAlarm;
        _assistantsReady = true;
        _assistantError = null;
        _scheduledAlarm = existingAlarm;
        if (existingAlarm != null) {
          _requireVoiceCheckIn = existingAlarm.requireTranscription;
        }
        final shouldExpand = existingAlarm == null;
        if (_assistantsExpanded != shouldExpand) {
          _assistantsExpansionRevision++;
        }
        _assistantsExpanded = shouldExpand;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _assistantsReady = false;
        _assistantError = 'マイクまたは通知の初期化に失敗しました: $error';
        _assistantsExpanded = true;
        _assistantsExpansionRevision++;
      });
    }
  }

  Future<void> _loadHighlights() async {
    try {
      final highlights = await _service.fetchHighlights();
      if (!mounted) {
        return;
      }
      setState(() {
        _highlights = highlights;
        _highlightError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _highlightError = 'Insight lookup failed: $error';
      });
    }
  }

  Future<List<DreamEntry>> _trackDreams(Future<List<DreamEntry>> source) {
    return source.then((dreams) {
      if (!mounted) {
        return dreams;
      }
      setState(() {
        _hasDreams = dreams.isNotEmpty;
        if (!_captureFormToggled) {
          _captureFormExpanded = dreams.isEmpty;
        }
      });
      return dreams;
    });
  }

  Future<void> _reloadDreams() async {
    final query = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
    final future = _service.fetchDreams(
      tag: _activeTag,
      query: query,
      mood: _activeMoodFilter,
    );
    final tracked = _trackDreams(future);
    setState(() {
      _dreamsFuture = tracked;
    });
    await tracked;
  }

  Future<void> _handleRefresh() async {
    await _reloadDreams();
    await _loadHighlights();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    try {
      await _service.createDream(
        title: _titleController.text,
        transcript: _transcriptController.text,
        tags: tags,
        mood: _moodController.text.isEmpty ? null : _moodController.text,
      );

      if (!mounted) {
        return;
      }

      _titleController.clear();
      _transcriptController.clear();
      _tagsController.clear();
      _moodController.clear();

      await _reloadDreams();
      await _loadHighlights();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('夢を保存しました。')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _scheduleAlarm() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _isSchedulingAlarm = true;
    });

    try {
      final alarm = await _alarmService.scheduleAlarm(
        time: picked,
        requireTranscription: _requireVoiceCheckIn,
        note: _transcriptController.text.isEmpty
            ? '話したいキーワードを思い出しましょう'
            : _transcriptController.text.split('\n').first,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scheduledAlarm = alarm;
        _requireVoiceCheckIn = alarm.requireTranscription;
        if (_assistantsReady) {
          _assistantError = null;
        }
        _assistantsExpanded = false;
        _assistantsExpansionRevision++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アラームを ${_formatTimeOfDay(picked)} に設定しました。')),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _assistantError = 'アラームの設定に失敗しました: $error';
          _assistantsExpanded = true;
          _assistantsExpansionRevision++;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSchedulingAlarm = false;
        });
      }
    }
  }

  Future<void> _cancelAlarm() async {
    await _alarmService.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _scheduledAlarm = null;
      _assistantsExpanded = true;
      _assistantsExpansionRevision++;
    });
  }

  bool get _permissionsReady => _assistantsReady && _assistantError == null;

  bool get _hasScheduledAlarm => _scheduledAlarm != null;

  bool get _voiceLockEnforced => _requireVoiceCheckIn;

  bool get _canStartRecording =>
      _permissionsReady && _hasScheduledAlarm && _voiceLockEnforced;

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _recordingError = null;
      _recordingBanner = '録音中...';
    });
    try {
      await _recorder.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recordingError = '録音を開始できませんでした: $error';
        _recordingBanner = null;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final audio = await _recorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
      });

      if (audio == null || audio.isEmpty) {
        setState(() {
          _recordingBanner = null;
          _recordingError = '音声が保存されませんでした。もう一度試してください。';
        });
        return;
      }

      setState(() {
        _recordingBanner = '文字起こし中...';
      });

      final transcription = await _service.transcribeAudio(audio);
      if (!mounted) {
        return;
      }

      final existing = _transcriptController.text.trim();
      final newTranscript = transcription.transcript.trim();
      if (existing.isEmpty) {
        _transcriptController.text = newTranscript;
      } else {
        _transcriptController.text = '$existing\n$newTranscript';
      }
      setState(() {
        _recordingBanner =
            'Transcribed with ${transcription.engine} · ${(transcription.confidence * 100).round()}% confidence';
        _recordingError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recordingError = '文字起こしに失敗しました: $error';
        _recordingBanner = null;
      });
    }
  }

  void _applyPrompt(String prompt) {
    final text = _transcriptController.text;
    final updated = text.isEmpty ? prompt : '$text\n$prompt';
    setState(() {
      _transcriptController.text = updated;
    });
  }

  Future<void> _performSearch() async {
    await _reloadDreams();
  }

  void _onTagSelected(String? tag) {
    if (_activeTag == tag) {
      return;
    }
    setState(() {
      _activeTag = tag;
    });
    _reloadDreams();
  }

  Future<DreamEntry?> _editDream(DreamEntry dream) async {
    final result = await showModalBottomSheet<_DreamEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DreamEditSheet(dream: dream),
    );
    if (result == null) {
      return null;
    }
    final updated = await _service.updateDream(
      id: dream.id,
      title: result.title,
      transcript: result.transcript,
      tags: result.tags,
      mood: result.mood,
    );
    await _reloadDreams();
    await _loadHighlights();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('夢を更新しました。')),
      );
    }
    return updated;
  }

  Future<void> _deleteDream(DreamEntry dream) async {
    await _service.deleteDream(dream.id);
    await _reloadDreams();
    await _loadHighlights();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${dream.title}」を削除しました。')),
      );
    }
  }

  Future<DreamEntry> _generateJournal(
    DreamEntry dream, {
    List<String> focusPoints = const <String>[],
    String? tone,
  }) async {
    setState(() {
      _journalStatus = '「${dream.title}」の夢日記を生成中...';
    });
    final result = await _service.generateJournal(
      id: dream.id,
      focusPoints: focusPoints,
      tone: tone,
    );
    await _reloadDreams();
    await _loadHighlights();
    if (mounted) {
      setState(() {
        _journalStatus = '夢日記を${result.engine}で生成しました。';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('夢日記を生成しました。')),
      );
    }
    return result.entry;
  }

  void _openDreamDetails(DreamEntry dream) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DreamDetailsSheet(
        dream: dream,
        onEdit: () => _editDream(dream),
        onDelete: () => _deleteDream(dream),
        onGenerateJournal: (focusPoints, tone) => _generateJournal(
          dream,
          focusPoints: focusPoints,
          tone: tone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dream Capture Journal'),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '起床直後の断片を逃さず記録しましょう。音声入力・AI要約・夢日記生成までワンストップで体験できます。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildAssistantsCard(),
                  const SizedBox(height: 16),
                  _buildVoiceCaptureCard(),
                  const SizedBox(height: 24),
                  _buildCaptureFormSection(),
                  const SizedBox(height: 24),
                  if (_highlights != null && _highlights!.topTags.isNotEmpty) ...[
                    _buildTagFilters(context),
                    const SizedBox(height: 12),
                  ],
                  _buildSearchControls(),
                  const SizedBox(height: 24),
                  _buildHighlightsSection(),
                  const SizedBox(height: 24),
                  _buildPromptSuggestions(),
                  const SizedBox(height: 16),
                  Text(
                    _activeTag == null
                        ? 'Recently recorded dreams'
                        : 'Dreams tagged "$_activeTag"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_journalStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _journalStatus!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  FutureBuilder<List<DreamEntry>>(
                    future: _dreamsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('Failed to load dreams: ${snapshot.error}'),
                        );
                      }
                      final dreams = snapshot.data ?? <DreamEntry>[];
                      if (dreams.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No dreams recorded yet. Save your first dream to unlock insights and narrative summaries.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      }
                      return Column(
                        children: dreams
                            .map(
                              (dream) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _DreamCard(
                                  dream: dream,
                                  onTap: () => _openDreamDetails(dream),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantsCard() {
    return Card(
      child: ExpansionTile(
        key: ValueKey<int>(_assistantsExpansionRevision),
        maintainState: true,
        initiallyExpanded: _assistantsExpanded || _assistantError != null,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: const Icon(Icons.alarm, size: 20),
        title: _buildStepTitle('STEP 0', 'Wake ritual readiness'),
        subtitle: Text(
          '就寝前に起床アラームと録音の条件を整えて、朝のチェックインをシームレスに。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _assistantsExpanded = expanded;
          });
        },
        children: [
          const SizedBox(height: 12),
          _buildWakePrepChecklist(),
          const SizedBox(height: 12),
          Text(
            '睡眠前にここを済ませておくと、目覚めた瞬間に夢の断片へ集中できます。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('録音が完了するまでアラームを止めない'),
            subtitle: Text(
              _scheduledAlarm != null
                  ? '設定を変更するには一度アラームをクリアしてから再設定してください。'
                  : (_requireVoiceCheckIn
                      ? '音声チェックを終えるまでアラームを停止できないようにして、記録の集中力を守ります。'
                      : 'OFFにすると音声チェック前にアラームを止められますが、STEP 1 は開始できません。'),
            ),
            value: _requireVoiceCheckIn,
            onChanged: _scheduledAlarm != null || _isSchedulingAlarm
                ? null
                : (value) {
                    setState(() {
                      _requireVoiceCheckIn = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isSchedulingAlarm || !_requireVoiceCheckIn
                      ? null
                      : _scheduleAlarm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.alarm_add),
                      const SizedBox(width: 8),
                      Text(_isSchedulingAlarm ? 'Scheduling…' : 'Set wake alarm'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _scheduledAlarm == null ? null : _cancelAlarm,
                icon: const Icon(Icons.close),
                tooltip: 'Clear alarm',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWakePrepChecklist() {
    final theme = Theme.of(context);
    final alarm = _scheduledAlarm;
    final hasAssistantError = _assistantError != null;
    final readinessColor = hasAssistantError
        ? theme.colorScheme.error
        : _assistantsReady
            ? theme.colorScheme.primary
            : theme.colorScheme.secondary;
    final String assistantTitle;
    if (hasAssistantError) {
      assistantTitle = 'アシスタントの準備に失敗しました';
    } else if (_assistantsReady) {
      assistantTitle = '通知とマイクの準備が整いました';
    } else {
      assistantTitle = '通知とマイクの権限を確認しています';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChecklistTile(
          icon: hasAssistantError
              ? Icons.error_outline
              : _assistantsReady
                  ? Icons.notifications_active
                  : Icons.hourglass_bottom,
          iconColor: readinessColor,
          title: assistantTitle,
          subtitle: _assistantError ??
              (_assistantsReady
                  ? 'アラーム停止の制御と録音が目覚めの瞬間から利用できます。'
                  : 'デバイス設定で許可を確認し、アプリを開いたままでお待ちください。'),
        ),
        const SizedBox(height: 8),
        _buildChecklistTile(
          icon: alarm != null ? Icons.alarm_on : Icons.alarm_add,
          iconColor:
              alarm != null ? theme.colorScheme.primary : theme.colorScheme.secondary,
          title: alarm != null
              ? '次のアラームは ${_formatDateTime(alarm.scheduledAt)}'
              : '起床アラームをセットしておきましょう',
          subtitle: alarm != null
              ? '録音必須: ${alarm.requireTranscription ? 'ON' : 'OFF'} · メモ: ${alarm.note ?? 'なし'}'
              : '起床時刻とメモをセットして、未来の自分に合図を送りましょう。',
        ),
        const SizedBox(height: 8),
        _buildChecklistTile(
          icon: _requireVoiceCheckIn ? Icons.mic : Icons.mic_none,
          iconColor: _requireVoiceCheckIn
              ? theme.colorScheme.primary
              : theme.colorScheme.tertiary,
          title: _requireVoiceCheckIn ? '録音必須モードはONです' : '録音必須モードはOFFです',
          subtitle: _requireVoiceCheckIn
              ? '録音を完了するまでアラームを止められないようにし、朝の集中力を確保します。'
              : 'STEP 1 で録音を始めるには、このモードをONにしてからアラームを再設定してください。',
        ),
      ],
    );
  }

  Widget _buildVoiceCaptureCard() {
    final theme = Theme.of(context);
    final alarm = _scheduledAlarm;
    final bool hasAlarm = alarm != null;
    final bool permissionsReady = _permissionsReady;
    final bool lockReady = _voiceLockEnforced;
    String readinessMessage;
    if (_assistantError != null) {
      readinessMessage = _assistantError!;
    } else if (!permissionsReady) {
      readinessMessage = '通知とマイクの初期化が完了するとボイスキャプチャが開放されます。';
    } else if (!hasAlarm) {
      readinessMessage = 'STEP 0 で起床アラームをセットしてください。';
    } else if (!lockReady) {
      readinessMessage = '録音必須モードをONにするとワンタップ録音を開始できます。';
    } else {
      readinessMessage = '録音を開始するとステータスが表示され、停止後は自動で文字起こしされます。';
    }
    return Card(
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: !_hasDreams,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: const Icon(Icons.mic, size: 20),
        title: _buildStepTitle('STEP 1', 'Immediate voice capture'),
        subtitle: Text(
          '起床直後の言葉を逃さず残すための最短導線。ワンタップで録音してテキスト化できます。',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          const SizedBox(height: 12),
          _buildChecklistTile(
            icon: _canStartRecording ? Icons.check_circle : Icons.lock_clock,
            iconColor: _canStartRecording
                ? theme.colorScheme.primary
                : (_assistantError != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.secondary),
            title: _canStartRecording
                ? '録音を開始する準備ができています'
                : 'STEP 0 の準備を完了してください',
            subtitle: _assistantError != null
                ? 'Wake ritual を再確認してください。問題の詳細は STEP 0 に表示されています。'
                : readinessMessage,
          ),
          const SizedBox(height: 12),
          Text(
            '録音を止めると自動でDream transcriptの入力欄に追記され、後で手入力した内容と混ざりません。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _canStartRecording ? _toggleRecording : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                const SizedBox(width: 8),
                Text(_isRecording ? 'Stop recording' : 'Start recording'),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _recordingBanner != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _recordingBanner!,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_recordingError != null) ...[
            const SizedBox(height: 8),
            Text(
              _recordingError!,
              style: theme.textTheme
                  .bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String stepLabel, String title) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badgeStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onPrimaryContainer,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(stepLabel, style: badgeStyle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildPromptSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Need a nudge?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _promptSuggestions
              .map(
                (prompt) => ActionChip(
                  label: Text(prompt),
                  onPressed: () => _applyPrompt(prompt),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildCaptureFormSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      maintainState: true,
      initiallyExpanded: _captureFormExpanded,
      onExpansionChanged: (expanded) {
        setState(() {
          _captureFormExpanded = expanded;
          _captureFormToggled = true;
        });
      },
      title: Text(
        'Capture a new dream',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '音声入力とタグで印象を残しましょう。',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Dream title',
                  hintText: 'e.g. Sunrise flight over mountains',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a short title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _transcriptController,
                decoration: const InputDecoration(
                  labelText: 'Dream transcript',
                  hintText: 'Describe what happened in your dream...',
                ),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A dream transcript is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Comma separated keywords (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _moodController,
                decoration: const InputDecoration(
                  labelText: 'Mood',
                  hintText: 'How did you feel on waking?',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.save_alt),
                label: Text(_isSubmitting ? 'Saving…' : 'Save dream'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSearchControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search your dream world',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by keyword',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch();
                    },
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _activeMoodFilter,
              hint: const Text('Mood'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(value: null, child: Text('Any mood')),
                ...?_highlights?.moods.map(
                  (mood) => DropdownMenuItem<String?>(
                    value: mood.mood,
                    child: Text(mood.mood),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _activeMoodFilter = value;
                });
                _reloadDreams();
              },
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _performSearch,
              child: const Text('Search'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHighlightsSection() {
    if (_highlightError != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _highlightError!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
        ),
      );
    }

    final highlights = _highlights;
    if (highlights == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week in your dream world',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Total dreams recorded: ${highlights.totalCount}'),
            if (highlights.topTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Popular motifs',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: highlights.topTags
                    .map((tag) => Chip(label: Text('#${tag.tag} • ${tag.count}x')))
                    .toList(growable: false),
              ),
            ],
            if (highlights.moods.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Emotional tones',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: highlights.moods
                    .map(
                      (mood) => Chip(
                        avatar: const Icon(Icons.favorite, size: 16),
                        label: Text('${mood.mood} • ${mood.count}'),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilters(BuildContext context) {
    final highlights = _highlights;
    if (highlights == null || highlights.topTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Focus on a theme',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All dreams'),
              selected: _activeTag == null,
              onSelected: (_) => _onTagSelected(null),
            ),
            ...highlights.topTags.map(
              (tag) => ChoiceChip(
                label: Text('#${tag.tag}'),
                selected: _activeTag == tag.tag,
                onSelected: (_) => _onTagSelected(tag.tag),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime timestamp) {
    final date = '${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')}';
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }
}

class _DreamCard extends StatelessWidget {
  const _DreamCard({required this.dream, required this.onTap});

  final DreamEntry dream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dream.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (dream.journal != null)
                    const Tooltip(
                      message: 'AI generated journal available',
                      child: Icon(Icons.auto_stories, size: 20),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dream.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(_formatTimestamp(dream.createdAt)),
                  ),
                  if (dream.mood != null)
                    Chip(
                      avatar: const Icon(Icons.favorite, size: 16),
                      label: Text(dream.mood!),
                    ),
                  ...dream.tags.map((tag) => Chip(label: Text('#$tag'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final date = '${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')}';
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }
}

class DreamDetailsSheet extends StatefulWidget {
  const DreamDetailsSheet({
    super.key,
    required this.dream,
    required this.onEdit,
    required this.onDelete,
    required this.onGenerateJournal,
  });

  final DreamEntry dream;
  final Future<DreamEntry?> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<DreamEntry> Function(List<String> focusPoints, String? tone)
      onGenerateJournal;

  @override
  State<DreamDetailsSheet> createState() => _DreamDetailsSheetState();
}

class _DreamDetailsSheetState extends State<DreamDetailsSheet> {
  late DreamEntry _dream;
  bool _isProcessing = false;
  String? _error;

  final TextEditingController _focusController = TextEditingController();
  final TextEditingController _toneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dream = widget.dream;
  }

  @override
  void dispose() {
    _focusController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final focusPoints = _focusController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      final updated = await widget.onGenerateJournal(
        focusPoints,
        _toneController.text.isEmpty ? null : _toneController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dream = updated;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '夢日記の生成に失敗しました: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleEdit() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final updated = await widget.onEdit();
      if (updated != null && mounted) {
        setState(() {
          _dream = updated;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '更新に失敗しました: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '削除に失敗しました: $error';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dream.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Recorded on ${_dream.createdAt.year}/${_dream.createdAt.month.toString().padLeft(2, '0')}/${_dream.createdAt.day.toString().padLeft(2, '0')} at ${_dream.createdAt.hour.toString().padLeft(2, '0')}:${_dream.createdAt.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_dream.mood != null) ...[
                const SizedBox(height: 12),
                Chip(
                  avatar: const Icon(Icons.favorite),
                  label: Text('Mood: ${_dream.mood}'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _dream.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(_dream.transcript),
              if (_dream.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dream.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 16),
              if (_dream.journal != null) ...[
                Text(
                  'Dream journal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _dream.journal!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_dream.journalGeneratedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Generated on ${_dream.journalGeneratedAt}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _focusController,
                decoration: const InputDecoration(
                  labelText: 'Focus symbols (comma separated)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toneController,
                decoration: const InputDecoration(
                  labelText: 'Desired tone (optional)',
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _handleGenerate,
                      icon: const Icon(Icons.auto_stories),
                      label: Text(_isProcessing ? 'Working…' : 'Generate / refresh journal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _handleEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit entry'),
                  ),
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _handleDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DreamEditResult {
  _DreamEditResult({
    required this.title,
    required this.transcript,
    required this.tags,
    this.mood,
  });

  final String title;
  final String transcript;
  final List<String> tags;
  final String? mood;
}

class _DreamEditSheet extends StatefulWidget {
  const _DreamEditSheet({required this.dream});

  final DreamEntry dream;

  @override
  State<_DreamEditSheet> createState() => _DreamEditSheetState();
}

class _DreamEditSheetState extends State<_DreamEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _transcriptController;
  late final TextEditingController _tagsController;
  late final TextEditingController _moodController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.dream.title);
    _transcriptController = TextEditingController(text: widget.dream.transcript);
    _tagsController = TextEditingController(text: widget.dream.tags.join(', '));
    _moodController = TextEditingController(text: widget.dream.mood ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    _tagsController.dispose();
    _moodController.dispose();
    super.dispose();
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      _DreamEditResult(
        title: _titleController.text,
        transcript: _transcriptController.text,
        tags: tags,
        mood: _moodController.text.isEmpty ? null : _moodController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit dream',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _transcriptController,
                decoration: const InputDecoration(labelText: 'Transcript'),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Transcript is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _moodController,
                decoration: const InputDecoration(labelText: 'Mood'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
