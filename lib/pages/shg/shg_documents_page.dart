import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

class ShgDocumentsPage extends StatefulWidget {
  const ShgDocumentsPage({super.key});
  @override
  State<ShgDocumentsPage> createState() => _ShgDocumentsPageState();
}

class _ShgDocumentsPageState extends State<ShgDocumentsPage> {
  final _repo = ShgRepository();
  final GlobalKey<AppAsyncBuilderState<List<ShgDocument>>> _key = GlobalKey();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addDocument(String? shgId) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add document record'),
        content: TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Document name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_nameController.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    _nameController.clear();
    if (name == null || name.isEmpty) return;
    await _repo.addDocument(shgId: shgId, name: name, type: 'PDF');
    _key.currentState?.reload();
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
                icon: Icon(Icons.add_circle_rounded, color: SupabaseService.isConfigured ? Brand.c600 : Neutral.c300),
                onPressed: SupabaseService.isConfigured ? () => _addDocument(shgId) : null,
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
                    trailing: Icon(Icons.download_rounded, size: 18, color: Neutral.c400),
                    chevron: false,
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
