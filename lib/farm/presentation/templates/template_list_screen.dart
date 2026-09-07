import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/template.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class TemplateListScreen extends ConsumerStatefulWidget {
  const TemplateListScreen({super.key});

  @override
  ConsumerState<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends ConsumerState<TemplateListScreen> {
  bool _isLoading = true;
  List<ProcessTemplate> _templates = [];
  String _searchQuery = '';

  int _currentPage = 1;
  final int _limit = 15;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTemplates(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMoreData && !_isLoading) {
        _loadTemplates();
      }
    }
  }

  Future<void> _loadTemplates({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isFetchingMore = true);
    }
    
    try {
      final repo = ref.read(farmRepositoryProvider);
      final data = await repo.getTemplates({
        'page': _currentPage,
        'limit': _limit,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      });

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _templates = data;
          } else {
            _templates.addAll(data);
          }
          _currentPage++;
          if (data.length < _limit) {
            _hasMoreData = false;
          }
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Quy trình mẫu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextLight)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextLight),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm quy trình...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: kSurfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                _searchQuery = value;
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _loadTemplates(isRefresh: true);
                });
              },
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadTemplates(isRefresh: true),
              color: kPrimaryColor,
              backgroundColor: kSurfaceDark,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                  : _templates.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('Chưa có quy trình mẫu nào', style: TextStyle(color: kTextGray))),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                          itemCount: _templates.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _templates.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _hasMoreData 
                                      ? const CircularProgressIndicator(color: kPrimaryColor)
                                      : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: kTextGray)),
                                ),
                              );
                            }
                            final template = _templates[index];
                            return Card(
                              elevation: 4,
                              color: kSurfaceDark,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextLight)),
                                subtitle: Text('${template.tasksConfig.length} công việc', style: const TextStyle(color: kTextGray, fontSize: 13)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: template.isActive ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        template.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: template.isActive ? Colors.green : Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.edit, color: kTextGray, size: 20),
                                  ],
                                ),
                                onTap: () async {
                                  await context.push('/manager/farm-templates/form', extra: template);
                                  _loadTemplates(isRefresh: true);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/manager/farm-templates/form');
          _loadTemplates(isRefresh: true);
        },
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.post_add, color: Colors.white),
      ),
    );
  }
}
