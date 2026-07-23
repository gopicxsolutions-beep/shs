import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/list_row.dart';

const _typeIcons = <String, IconData>{
  'PDF': Icons.picture_as_pdf_rounded,
  'IMG': Icons.image_rounded,
};

// Mirrors the shg-documents bucket's own allow-list
// (0028_storage_bucket_size_and_type_limits.sql): PDF, JPEG, PNG, WEBP.
const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
const _maxDocumentBytes = 10 * 1024 * 1024; // mirrors the bucket's 10 MiB cap

String _docTypeFor(String? extension) => extension?.toLowerCase() == 'pdf' ? 'PDF' : 'IMG';

String _contentTypeFor(String? extension) => switch (extension?.toLowerCase()) {
  'pdf' => 'application/pdf',
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'image/jpeg',
};

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class ShgDocumentsPage extends StatefulWidget {
  const ShgDocumentsPage({super.key});
  @override
  State<ShgDocumentsPage> createState() => _ShgDocumentsPageState();
}

class _ShgDocumentsPageState extends State<ShgDocumentsPage> {
  final _repo = ShgRepository();
  final GlobalKey<AppAsyncBuilderState<List<ShgDocument>>> _key = GlobalKey();
  final _nameController = TextEditingController();
  bool _busy = false;
  bool _opening = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addDocument(String? shgId) async {
    PlatformFile? picked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameController, maxLength: 100, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'Document name')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: _allowedExtensions, withData: true);
                  final file = result?.files.isNotEmpty == true ? result!.files.first : null;
                  if (file == null || file.bytes == null) return;
                  if (file.size > _maxDocumentBytes) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is too large — please choose one under 10 MB')));
                    }
                    return;
                  }
                  setDialogState(() => picked = file);
                },
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(picked == null ? 'Choose file (PDF, JPG, PNG, WEBP)' : picked!.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)?.actionAdd ?? 'Add')),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final name = _nameController.text.trim();
    _nameController.clear();
    if (confirmed != true) return;
    if (name.isEmpty) {
      // Without this, tapping "Add" on a blank document name silently
      // closed the dialog and added nothing — indistinguishable from a
      // broken button, same silent-no-op gap already fixed for "Add SHG"/
      // "Add scheme" in admin_shgs_page.dart / admin_schemes_page.dart.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document name is required.')));
      return;
    }
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a file to upload.')));
      return;
    }
    setState(() => _busy = true);
    try {
      String? storagePath;
      if (SupabaseService.isConfigured && shgId != null) {
        storagePath = await _repo.uploadDocument(
          shgId: shgId,
          bytes: picked!.bytes!,
          fileName: picked!.name,
          contentType: _contentTypeFor(picked!.extension),
        );
      }
      final saved = await _repo.addDocument(
        shgId: shgId,
        name: name,
        type: _docTypeFor(picked!.extension),
        size: _humanSize(picked!.size),
        storagePath: storagePath,
      );
      if (mounted) {
        if (!saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You're not linked to an SHG, so there's nothing to attach this document to.")),
          );
        } else {
          _key.currentState?.reload();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(SupabaseService.isConfigured ? 'Document added' : 'Demo mode — not saved (connect Supabase to persist)'),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add this document. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDocument(ShgDocument d) async {
    if (_opening) return;
    if (d.storagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No file is attached to this record.')));
      return;
    }
    setState(() => _opening = true);
    try {
      final url = await _repo.getDownloadUrl(d.storagePath!);
      if (!mounted) return;
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this document.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this document.')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final shgId = appState.profile?.shgId;

    return Scaffold(
      appBar: PageHeader(
        title: 'Documents',
        right: isLeaderOrStaff
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? () => _addDocument(shgId) : null,
                tooltip: 'Add document',
              )
            : null,
      ),
      body: AppAsyncBuilder<List<ShgDocument>>(
        key: _key,
        future: () => _repo.fetchDocuments(shgId),
        builder: (context, docs) {
          if (docs.isEmpty) {
            return const AppEmptyState(icon: Icons.folder_off_rounded, message: 'No documents uploaded yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padded: false,
                  child: AppListRow(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Icon(_typeIcons[d.type] ?? Icons.description_rounded, size: 18, color: Brand.c600),
                    ),
                    title: d.name,
                    subtitle: '${d.size ?? ''} · ${DateFormat('dd MMM yyyy').format(d.createdAt)}',
                    trailing: Icon(Icons.download_rounded, size: 18, color: _opening ? Neutral.c200 : Neutral.c400),
                    chevron: false,
                    onTap: _opening ? null : () => _openDocument(d),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
