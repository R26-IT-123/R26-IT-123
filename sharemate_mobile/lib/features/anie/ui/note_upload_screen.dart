import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/anie_topic.dart';
import '../services/anie_api_service.dart';
import 'score_result_screen.dart';

class NoteUploadScreen extends StatefulWidget {
  const NoteUploadScreen({super.key});

  @override
  State<NoteUploadScreen> createState() => _NoteUploadScreenState();
}

class _NoteUploadScreenState extends State<NoteUploadScreen> {
  final _service    = AnieApiService();
  final _titleCtrl  = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  List<AnieTopic> _topics       = [];
  List<String>    _subjects     = [];
  String?         _selectedSubject;
  String?         _selectedTopic;
  List<PlatformFile> _pickedFiles = [];

  bool   _loadingTopics = true;
  bool   _uploading     = false;
  String _uploadStatus  = '';

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _service.fetchTopics();
      final subjects = topics.map((t) => t.subject).toSet().toList()..sort();
      setState(() {
        _topics   = topics;
        _subjects = subjects;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load topics: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTopics = false);
    }
  }

  List<String> _topicsForSubject(String subject) {
    return _topics
        .where((t) => t.subject == subject)
        .map((t) => t.topic)
        .toList();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type:          FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFiles = result.files);
  }

  void _removeFile(int index) {
    setState(() => _pickedFiles.removeAt(index));
  }

  Future<void> _analyse() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick at least one file.')),
      );
      return;
    }

    setState(() {
      _uploading    = true;
      _uploadStatus = 'Uploading files…';
    });

    try {
      final uid     = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final noteId  = DateTime.now().millisecondsSinceEpoch.toString();
      final urls    = <String>[];

      // Upload each file to Firebase Storage
      for (final file in _pickedFiles) {
        if (file.path == null) continue;
        setState(() => _uploadStatus =
            'Uploading ${file.name}…');

        final ref = FirebaseStorage.instance
            .ref('notes/$uid/$noteId/${file.name}');
        await ref.putFile(File(file.path!));
        final url = await ref.getDownloadURL();
        urls.add(url);
      }

      if (urls.isEmpty) {
        throw Exception('No files were uploaded successfully.');
      }

      setState(() => _uploadStatus = 'Analysing with AI model…');

      final result = await _service.validateNote(
        title:    _titleCtrl.text.trim(),
        subject:  _selectedSubject!,
        topic:    _selectedTopic!,
        fileUrls: urls,
      );

      if (!mounted) return;

      final published = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ScoreResultScreen(result: result),
        ),
      );

      if (published == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        title: const Text(
          'Upload Short Note',
          style: TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.w800,
            color:      Color(0xFF111827),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF374151)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _uploading
          ? _UploadingView(status: _uploadStatus)
          : _loadingTopics
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Note title
                        _SectionLabel(label: 'Note Title'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: _inputDecoration('e.g. AI Lecture Summary Week 3'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter a title'
                                  : null,
                        ),
                        const SizedBox(height: 20),

                        // Subject
                        _SectionLabel(label: 'Subject'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value:       _selectedSubject,
                          decoration:  _inputDecoration('Select subject'),
                          items:       _subjects
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ))
                              .toList(),
                          onChanged:   (v) => setState(() {
                            _selectedSubject = v;
                            _selectedTopic   = null;
                          }),
                          validator:   (v) =>
                              v == null ? 'Select a subject' : null,
                        ),
                        const SizedBox(height: 20),

                        // Topic
                        _SectionLabel(label: 'Topic'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value:      _selectedTopic,
                          isExpanded: true,
                          decoration: _inputDecoration('Select topic'),
                          items: (_selectedSubject == null
                                  ? <String>[]
                                  : _topicsForSubject(_selectedSubject!))
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged:  (v) =>
                              setState(() => _selectedTopic = v),
                          validator:  (v) =>
                              v == null ? 'Select a topic' : null,
                        ),
                        const SizedBox(height: 20),

                        // File picker
                        _SectionLabel(label: 'Upload Files (PDF or Images)'),
                        const SizedBox(height: 8),
                        _FilePicker(
                          files:     _pickedFiles,
                          onPick:    _pickFiles,
                          onRemove:  _removeFile,
                        ),
                        const SizedBox(height: 28),

                        // Analyse button
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
                            onPressed: _analyse,
                            icon:  const Icon(Icons.auto_awesome_rounded),
                            label: const Text(
                              'Analyse with AI',
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
                  ),
                ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText:        hint,
      hintStyle:       const TextStyle(color: Color(0xFF9CA3AF)),
      filled:          true,
      fillColor:       Colors.white,
      border:          OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      enabledBorder:   OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      focusedBorder:   OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder:     OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: Color(0xFFDC2626)),
      ),
      contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize:   13,
        fontWeight: FontWeight.w700,
        color:      Color(0xFF374151),
        letterSpacing: 0.2,
      ),
    );
  }
}

// ── File picker widget ────────────────────────────────────────────────────────

class _FilePicker extends StatelessWidget {
  const _FilePicker({
    required this.files,
    required this.onPick,
    required this.onRemove,
  });

  final List<PlatformFile> files;
  final VoidCallback       onPick;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(
                color: const Color(0xFFBFDBFE),
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.upload_file_rounded,
                    size: 36, color: Color(0xFF2563EB)),
                SizedBox(height: 8),
                Text(
                  'Tap to pick PDF or images',
                  style: TextStyle(
                    fontSize:   14,
                    color:      Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'PDF, JPG, PNG, BMP, TIFF — multiple allowed',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...files.asMap().entries.map((entry) {
            final i    = entry.key;
            final file = entry.value;
            final kb   = ((file.size) / 1024).toStringAsFixed(0);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    file.extension == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    color: const Color(0xFF2563EB),
                    size:  20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      Color(0xFF1E40AF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$kb KB',
                          style: const TextStyle(
                            fontSize: 10,
                            color:    Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:        const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFF9CA3AF)),
                    onPressed:   () => onRemove(i),
                    constraints: const BoxConstraints(),
                    padding:     EdgeInsets.zero,
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Uploading state ───────────────────────────────────────────────────────────

class _UploadingView extends StatelessWidget {
  const _UploadingView({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width:  60,
              height: 60,
              child:  CircularProgressIndicator(
                strokeWidth: 5,
                color:       Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Processing your note',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color:    Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The AI model is scoring your note.\nThis may take up to 2 minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color:    Color(0xFF9CA3AF),
                height:   1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
