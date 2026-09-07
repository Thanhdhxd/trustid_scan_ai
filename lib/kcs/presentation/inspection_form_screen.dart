import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/dashboard/data/tenant_repository.dart';
import 'package:trustid_scan_ai/farm/data/farm_repository.dart';
import 'package:trustid_scan_ai/farm/domain/location.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kPrimaryLight = Color(0xFF10B981);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kCardDark = Color(0xFF1C3D6E);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class _EvidenceItem {
  final String name;
  final Uint8List bytes;
  final bool isPdf;

  _EvidenceItem({required this.name, required this.bytes, required this.isPdf});
}

class InspectionFormScreen extends ConsumerStatefulWidget {
  final String locationId;
  const InspectionFormScreen({super.key, required this.locationId});

  @override
  ConsumerState<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  GrowingLocation? _location;
  Map<String, dynamic>? _existingInspection;
  List<String> _existingReportUrls = [];
  bool _isLoadingLocation = true;
  bool _isSubmitting = false;

  // 1. Cảm quan & Ngoại quan
  String _colorSensory = 'PASSED'; // PASSED, FAILED
  String _sizeUniformity = 'PASSED'; // PASSED, FAILED
  String _pestPurity = 'PASSED'; // PASSED, FAILED

  // 2. Đo lường định lượng
  final _moistureController = TextEditingController();
  final _impurityController = TextEditingController();
  final _weightController = TextEditingController();
  String _chemicalStatus = 'SAFE'; // SAFE, WARNING

  // 3. Kết luận & Ghi chú
  String _status = 'PASSED'; // PASSED, RE_WORK, FAILED
  final _notesController = TextEditingController();
  final List<_EvidenceItem> _selectedEvidence = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndInspectionDetails();
  }

  @override
  void dispose() {
    _moistureController.dispose();
    _impurityController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateInspectionData(Map<String, dynamic> data) {
    _existingInspection = data;
    _status = data['status']?.toString() ?? 'PASSED';

    final rawNotes = data['notes']?.toString() ?? '';

    // 1. Extract clean user remarks
    if (rawNotes.contains('[Chỉ số KCS]:')) {
      final parts = rawNotes.split('[Chỉ số KCS]:');
      _notesController.text = parts[0].trim();
    } else {
      _notesController.text = rawNotes;
    }

    // 2. Direct metrics map
    dynamic metrics = data['metrics'];
    if (metrics is String && metrics.trim().startsWith('{')) {
      try {
        metrics = jsonDecode(metrics);
      } catch (_) {}
    }

    if (metrics is Map) {
      if (metrics['moisture'] != null) _moistureController.text = metrics['moisture'].toString();
      if (metrics['impurityRate'] != null) _impurityController.text = metrics['impurityRate'].toString();
      if (metrics['avgWeight'] != null) _weightController.text = metrics['avgWeight'].toString();
      if (metrics['chemicalStatus'] != null) _chemicalStatus = metrics['chemicalStatus'].toString();
      if (metrics['colorSensory'] != null) _colorSensory = metrics['colorSensory'].toString();
      if (metrics['sizeUniformity'] != null) _sizeUniformity = metrics['sizeUniformity'].toString();
      if (metrics['pestPurity'] != null) _pestPurity = metrics['pestPurity'].toString();
    }

    // 3. Robust Regex Extraction fallback from rawNotes
    if (_moistureController.text.isEmpty) {
      final match = RegExp(r'Độ ẩm:\s*([\d.]+)%?').firstMatch(rawNotes);
      if (match != null) _moistureController.text = match.group(1)!;
    }
    if (_impurityController.text.isEmpty) {
      final match = RegExp(r'Tạp chất(?:/Lép)?:\s*([\d.]+)%?').firstMatch(rawNotes);
      if (match != null) _impurityController.text = match.group(1)!;
    }
    if (_weightController.text.isEmpty) {
      final match = RegExp(r'Trọng lượng(?: TB)?:\s*([\d.]+)g?').firstMatch(rawNotes);
      if (match != null) _weightController.text = match.group(1)!;
    }
    if (rawNotes.contains('Dư lượng BVTV: An toàn') || rawNotes.contains('Âm tính')) {
      _chemicalStatus = 'SAFE';
    } else if (rawNotes.contains('Dư lượng BVTV: Cần kiểm tra') || rawNotes.contains('Dương tính')) {
      _chemicalStatus = 'WARNING';
    }
    if (rawNotes.contains('Màu sắc: Đạt')) {
      _colorSensory = 'PASSED';
    } else if (rawNotes.contains('Màu sắc: Không đạt')) {
      _colorSensory = 'FAILED';
    }
    if (rawNotes.contains('Độ đồng đều: Đồng đều')) {
      _sizeUniformity = 'PASSED';
    } else if (rawNotes.contains('Độ đồng đều: Không đều')) {
      _sizeUniformity = 'FAILED';
    }
    if (rawNotes.contains('Sâu bệnh: Không phát hiện')) {
      _pestPurity = 'PASSED';
    } else if (rawNotes.contains('Sâu bệnh: Có dấu hiệu')) {
      _pestPurity = 'FAILED';
    }

    // 4. Existing file URLs
    final files = data['reportFiles'] ?? data['report_files'];
    if (files is List) {
      _existingReportUrls = files.map((e) => e.toString()).toList();
    }
  }

  Future<void> _fetchLocationAndInspectionDetails() async {
    try {
      final repo = ref.read(farmRepositoryProvider);

      final results = await Future.wait([
        repo.getLocationById(widget.locationId).then<dynamic>((v) => v).catchError((_) => null),
        repo.getLocationInspections(widget.locationId).then<dynamic>((v) => v).catchError((_) => []),
      ]);

      final loc = results[0] as GrowingLocation?;
      final List<dynamic> inspections = results[1] as List<dynamic>? ?? [];

      Map<String, dynamic>? inspectionData;

      // 1. Try local cache first for full metric details
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('kcs_cache_${widget.locationId}') ??
            (loc?.code != null ? prefs.getString('kcs_cache_${loc!.code}') : null) ??
            (loc?.name != null ? prefs.getString('kcs_cache_${loc!.name}') : null);
        if (cached != null) {
          final decoded = jsonDecode(cached);
          if (decoded is Map<String, dynamic>) {
            inspectionData = decoded;
          }
        }
      } catch (_) {}

      // 2. Server inspection records
      if (inspectionData == null && inspections.isNotEmpty) {
        inspectionData = inspections.last as Map<String, dynamic>;
      } else if (inspectionData == null) {
        // Fallback: check tenant inspections for the current user
        try {
          final user = ref.read(authControllerProvider).value;
          if (user != null) {
            final identifier = user.id ?? user.username;
            if (identifier != null) {
              final tenantRepo = ref.read(tenantRepositoryProvider);
              final allInspections = await tenantRepo.getKcsInspections(identifier);
              for (var ins in allInspections) {
                final lId = ins['locationId'] ?? ins['location_id'] ?? ins['location']?['id'];
                if (lId == widget.locationId || lId == loc?.code || lId == loc?.name) {
                  inspectionData = ins as Map<String, dynamic>;
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _location = loc;
          _isLoadingLocation = false;

          if (inspectionData != null) {
            _populateInspectionData(inspectionData!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _processAndAddImage(XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _selectedEvidence.add(_EvidenceItem(
            name: file.name.isNotEmpty ? file.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
            bytes: bytes,
            isPdf: false,
          ));
        });
      }
    } catch (e) {
      debugPrint('Lỗi đọc ảnh: $e');
    }
  }

  Future<void> _pickFiles() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: kPrimaryLight),
              title: const Text('Chụp ảnh thực tế', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 60,
                );
                if (image != null) {
                  await _processAndAddImage(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
              title: const Text('Chọn từ thư viện ảnh', style: TextStyle(color: kTextLight)),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final List<XFile> images = await picker.pickMultiImage(
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 60,
                );
                for (var img in images) {
                  await _processAndAddImage(img);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeFile(int index) {
    setState(() => _selectedEvidence.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dio = companyApi;

      // 1. Upload newly selected files
      List<String> uploadedUrls = List<String>.from(_existingReportUrls);
      for (var item in _selectedEvidence) {
        FormData formData = FormData.fromMap({
          "file": MultipartFile.fromBytes(item.bytes, filename: item.name),
        });

        try {
          final uploadRes = await dio.post('/files/upload', data: formData);
          final url = uploadRes.data['url'] ?? uploadRes.data['data']?['url'];
          if (url != null) uploadedUrls.add(url.toString());
        } catch (_) {}
      }

      // 2. Format detailed inspection notes and payload
      final quantitativeSummary = <String>[];
      if (_moistureController.text.trim().isNotEmpty) {
        quantitativeSummary.add('Độ ẩm: ${_moistureController.text.trim()}%');
      }
      if (_impurityController.text.trim().isNotEmpty) {
        quantitativeSummary.add('Tạp chất/Lép: ${_impurityController.text.trim()}%');
      }
      if (_weightController.text.trim().isNotEmpty) {
        quantitativeSummary.add('Trọng lượng TB: ${_weightController.text.trim()}g');
      }
      quantitativeSummary.add('Dư lượng BVTV: ${_chemicalStatus == 'SAFE' ? 'An toàn' : 'Cần kiểm tra lại'}');
      quantitativeSummary.add('Màu sắc: ${_colorSensory == 'PASSED' ? 'Đạt' : 'Không đạt'}');
      quantitativeSummary.add('Độ đồng đều: ${_sizeUniformity == 'PASSED' ? 'Đồng đều' : 'Không đều'}');
      quantitativeSummary.add('Sâu bệnh: ${_pestPurity == 'PASSED' ? 'Không phát hiện' : 'Có dấu hiệu'}');

      final userNote = _notesController.text.trim();
      final fullNotes = userNote.isNotEmpty 
          ? '$userNote\n\n[Chỉ số KCS]: ${quantitativeSummary.join(' | ')}'
          : '[Chỉ số KCS]: ${quantitativeSummary.join(' | ')}';

      final data = {
        'locationId': widget.locationId,
        'location_id': widget.locationId,
        'status': _status,
        'notes': fullNotes,
        'reportFiles': uploadedUrls,
        'metrics': {
          'moisture': double.tryParse(_moistureController.text.trim()),
          'impurityRate': double.tryParse(_impurityController.text.trim()),
          'avgWeight': double.tryParse(_weightController.text.trim()),
          'chemicalStatus': _chemicalStatus,
          'colorSensory': _colorSensory,
          'sizeUniformity': _sizeUniformity,
          'pestPurity': _pestPurity,
        }
      };

      await dio.post('/farm/inspections', data: data);

      // Persist inspected location and inspection detail cache
      try {
        final prefs = await SharedPreferences.getInstance();

        final cacheData = {
          'locationId': widget.locationId,
          'status': _status,
          'notes': fullNotes,
          'reportFiles': uploadedUrls,
          'metrics': {
            'moisture': _moistureController.text.trim(),
            'impurityRate': _impurityController.text.trim(),
            'avgWeight': _weightController.text.trim(),
            'chemicalStatus': _chemicalStatus,
            'colorSensory': _colorSensory,
            'sizeUniformity': _sizeUniformity,
            'pestPurity': _pestPurity,
          },
          'inspectionDate': DateTime.now().toIso8601String(),
        };

        final jsonString = jsonEncode(cacheData);
        await prefs.setString('kcs_cache_${widget.locationId}', jsonString);
        if (_location != null) {
          if (_location!.code != null && _location!.code!.isNotEmpty) {
            await prefs.setString('kcs_cache_${_location!.code!}', jsonString);
          }
          await prefs.setString('kcs_cache_${_location!.name}', jsonString);
        }

        final List<String> list = prefs.getStringList('kcs_inspected_location_ids') ?? [];
        if (!list.contains(widget.locationId)) list.add(widget.locationId);
        if (_location != null) {
          if (_location!.code != null && !list.contains(_location!.code!)) {
            list.add(_location!.code!);
          }
          if (!list.contains(_location!.name)) {
            list.add(_location!.name);
          }
        }
        await prefs.setStringList('kcs_inspected_location_ids', list);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ký duyệt và lưu kết quả kiểm định KCS thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(widget.locationId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: ${cleanErrorMessage(e)}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String cleanErrorMessage(dynamic e) {
    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11);
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final loc = _location;
    final isAlreadyInspected = _existingInspection != null;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAlreadyInspected ? 'Chi Tiết Biên Bản KCS' : 'Biên Bản Kiểm Định KCS',
              style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Text(
              'ĐÁNH GIÁ CHẤT LƯỢNG NÔNG SẢN',
              style: TextStyle(fontSize: 10, color: kTextGray, letterSpacing: 0.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextLight),
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 0. Banner Trạng Thái Đã Kiểm Định ──
                  if (isAlreadyInspected) _buildExistingInspectionBanner(),

                  // ── 1. Thông Tin Thửa & Lô Đất ──
                  _buildLocationInfoCard(loc),
                  const SizedBox(height: 20),

                  // ── 2. Đánh Giá Cảm Quan & Ngoại Quan ──
                  _buildSectionHeader('1. Đánh giá Cảm quan & Ngoại quan', Icons.visibility_outlined),
                  const SizedBox(height: 10),
                  _buildSensoryCard(),
                  const SizedBox(height: 20),

                  // ── 3. Đo Lường Định Lượng ──
                  _buildSectionHeader('2. Đo lường Chỉ số Định lượng', Icons.science_outlined),
                  const SizedBox(height: 10),
                  _buildQuantitativeCard(),
                  const SizedBox(height: 20),

                  // ── 4. Ảnh Mẫu & Biên Bản ──
                  _buildSectionHeader('3. Ảnh mẫu kiểm tra & Biên bản', Icons.camera_alt_outlined),
                  const SizedBox(height: 10),
                  _buildEvidenceSection(),
                  const SizedBox(height: 20),

                  // ── 5. Kết Luận & Ký Duyệt ──
                  _buildSectionHeader('4. Kết luận & Phê duyệt chất lượng', Icons.fact_check_outlined),
                  const SizedBox(height: 10),
                  _buildConclusionCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _status == 'FAILED'
                  ? Colors.redAccent
                  : (_status == 'RE_WORK' ? const Color(0xFFD97706) : kPrimaryColor),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isAlreadyInspected
                            ? 'CẬP NHẬT KẾT QUẢ KIỂM ĐỊNH'
                            : (_status == 'PASSED'
                                ? 'XÁC NHẬN & KÝ DUYỆT ĐẠT CHUẨN'
                                : (_status == 'RE_WORK' ? 'YÊU CẦU XỬ LÝ LẠI (RE-WORK)' : 'XÁC NHẬN KHÔNG ĐẠT (REJECTED)')),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Existing Inspection Banner ──
  Widget _buildExistingInspectionBanner() {
    final isPassed = _status == 'PASSED';
    final isRework = _status == 'RE_WORK';
    final color = isPassed ? kPrimaryLight : (isRework ? Colors.amberAccent : Colors.redAccent);
    final rawDate = _existingInspection?['inspectionDate'] ?? _existingInspection?['createdAt'] ?? _existingInspection?['updatedAt'];
    String dateFormatted = '';
    if (rawDate != null) {
      try {
        final dt = DateTime.tryParse(rawDate.toString());
        if (dt != null) {
          final local = dt.toLocal();
          dateFormatted = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isPassed ? Icons.verified : (isRework ? Icons.warning_amber_rounded : Icons.cancel_outlined),
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KẾT QUẢ ĐÃ LƯU: ${isPassed ? 'ĐẠT TIÊU CHUẨN (PASSED)' : (isRework ? 'YÊU CẦU XỬ LÝ LẠI (RE-WORK)' : 'KHÔNG ĐẠT (REJECTED)')}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormatted.isNotEmpty ? 'Thời gian kiểm định: $dateFormatted' : 'Đã được kiểm tra và ký duyệt trên hệ thống TrustID.',
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Card ──
  Widget _buildLocationInfoCard(GrowingLocation? loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco, color: kPrimaryLight, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc?.name ?? 'Đang tải thông tin thửa...',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mã thửa: ${loc?.code ?? widget.locationId}',
                      style: const TextStyle(fontSize: 12, color: kTextGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (loc != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                if (loc.plantType != null && loc.plantType!.isNotEmpty)
                  _buildMiniTag(Icons.grass, loc.plantType!, kPrimaryLight),
                if (loc.areaM2 > 0) ...[
                  const SizedBox(width: 8),
                  _buildMiniTag(Icons.aspect_ratio, '${loc.areaM2.toStringAsFixed(0)} m²', Colors.lightBlueAccent),
                ],
                if (loc.province != null && loc.province!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildMiniTag(Icons.location_on_outlined, loc.province!, Colors.amberAccent),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kPrimaryLight, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextLight),
        ),
      ],
    );
  }

  // ── 1. Cảm Quan ──
  Widget _buildSensoryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildSensoryRow('Màu sắc & Độ tươi:', _colorSensory, (val) => setState(() => _colorSensory = val)),
          const Divider(color: Colors.white10, height: 16),
          _buildSensoryRow('Độ đồng đều kích thước:', _sizeUniformity, (val) => setState(() => _sizeUniformity = val)),
          const Divider(color: Colors.white10, height: 16),
          _buildSensoryRow('Dấu hiệu sâu bệnh / dập nát:', _pestPurity, (val) => setState(() => _pestPurity = val)),
        ],
      ),
    );
  }

  Widget _buildSensoryRow(String label, String currentVal, ValueChanged<String> onChanged) {
    final isPassed = currentVal == 'PASSED';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: kTextLight)),
        ),
        Row(
          children: [
            InkWell(
              onTap: () => onChanged('PASSED'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPassed ? kPrimaryColor : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isPassed ? kPrimaryLight : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 13, color: isPassed ? Colors.white : kTextGray),
                    const SizedBox(width: 4),
                    Text('Đạt', style: TextStyle(fontSize: 12, fontWeight: isPassed ? FontWeight.bold : FontWeight.normal, color: isPassed ? Colors.white : kTextGray)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => onChanged('FAILED'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: !isPassed ? Colors.redAccent : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: !isPassed ? Colors.redAccent : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(Icons.close, size: 13, color: !isPassed ? Colors.white : kTextGray),
                    const SizedBox(width: 4),
                    Text('Chưa đạt', style: TextStyle(fontSize: 12, fontWeight: !isPassed ? FontWeight.bold : FontWeight.normal, color: !isPassed ? Colors.white : kTextGray)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Đo Lường Định Lượng ──
  Widget _buildQuantitativeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricInput(
                  controller: _moistureController,
                  label: 'Độ ẩm mẫu (%)',
                  hint: 'VD: 14.2',
                  suffix: '%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricInput(
                  controller: _impurityController,
                  label: 'Tạp chất / Lép (%)',
                  hint: 'VD: 1.5',
                  suffix: '%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricInput(
                  controller: _weightController,
                  label: 'Trọng lượng TB (g)',
                  hint: 'VD: 25.0',
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dư lượng BVTV / Nitrat', style: TextStyle(fontSize: 12, color: kTextGray, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: kBackgroundDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _chemicalStatus = 'SAFE'),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _chemicalStatus == 'SAFE' ? kPrimaryColor : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                ),
                                child: Text(
                                  'Âm tính',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _chemicalStatus == 'SAFE' ? FontWeight.bold : FontWeight.normal,
                                    color: _chemicalStatus == 'SAFE' ? Colors.white : kTextGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _chemicalStatus = 'WARNING'),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _chemicalStatus == 'WARNING' ? Colors.redAccent : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                ),
                                child: Text(
                                  'Dương tính',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _chemicalStatus == 'WARNING' ? FontWeight.bold : FontWeight.normal,
                                    color: _chemicalStatus == 'WARNING' ? Colors.white : kTextGray,
                                  ),
                                ),
                              ),
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
          const SizedBox(height: 14),

          // ── Cảnh báo thời gian cách ly (PHI) ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrimaryLight.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: kPrimaryLight, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thời gian cách ly (PHI): Đảm bảo an toàn theo nhật ký canh tác.',
                    style: TextStyle(fontSize: 12, color: kPrimaryLight, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTextGray, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: kTextLight, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: kBackgroundDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: kTextGray, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            hintText: hint,
            hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ── 3. Ảnh Mẫu & Biên Bản ──
  Widget _buildEvidenceSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Ảnh mẫu quả/hạt & Báo cáo:',
                  style: TextStyle(fontSize: 13, color: kTextGray),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo, size: 14, color: kPrimaryLight),
                      SizedBox(width: 4),
                      Text('Thêm tệp', style: TextStyle(fontSize: 12, color: kPrimaryLight, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hiển thị các tệp đã lưu trước đó từ server (nếu có)
          if (_existingReportUrls.isNotEmpty) ...[
            const Text('Tệp đã đính kèm:', style: TextStyle(fontSize: 12, color: kTextGray)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _existingReportUrls.length,
                  (index) => _buildExistingUrlThumbnail(_existingReportUrls[index]),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Hiển thị các tệp vừa mới thêm
          if (_selectedEvidence.isNotEmpty) ...[
            const Text('Tệp mới chọn:', style: TextStyle(fontSize: 12, color: kTextGray)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _selectedEvidence.length,
                  (index) => _buildFileThumbnail(_selectedEvidence[index], index),
                ),
              ),
            ),
          ] else if (_existingReportUrls.isEmpty)
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: kBackgroundDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08), style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: kTextGray, size: 28),
                    SizedBox(height: 4),
                    Text('Chạm để chụp ảnh mẫu hoặc đính kèm biên bản', style: TextStyle(color: kTextGray, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingUrlThumbnail(String url) {
    final isPdf = url.toLowerCase().endsWith('.pdf');
    return Container(
      width: 84,
      height: 84,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: kBackgroundDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimaryLight.withOpacity(0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: isPdf
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
                SizedBox(height: 4),
                Text('PDF Report', style: TextStyle(color: kTextGray, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: 84,
              height: 84,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: kTextGray, size: 28),
              ),
            ),
    );
  }

  Widget _buildFileThumbnail(_EvidenceItem item, int index) {
    return Stack(
      children: [
        Container(
          width: 84,
          height: 84,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: kBackgroundDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: item.isPdf
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
                    SizedBox(height: 4),
                    Text('PDF Report', style: TextStyle(color: kTextGray, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                )
              : Image.memory(
                  item.bytes,
                  fit: BoxFit.cover,
                  width: 84,
                  height: 84,
                ),
        ),
        Positioned(
          top: 2,
          right: 12,
          child: GestureDetector(
            onTap: () => _removeFile(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Kết Luận & Phê Duyệt ──
  Widget _buildConclusionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chọn kết luận đánh giá *', style: TextStyle(fontSize: 12, color: kTextGray, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildConclusionOption('PASSED', 'ĐẠT CHUẨN', Icons.check_circle_outline, kPrimaryLight),
              const SizedBox(width: 8),
              _buildConclusionOption('RE_WORK', 'XỬ LÝ LẠI', Icons.replay_outlined, Colors.amberAccent),
              const SizedBox(width: 8),
              _buildConclusionOption('FAILED', 'KHÔNG ĐẠT', Icons.cancel_outlined, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Ghi chú & Ý kiến chuyên môn:', style: TextStyle(fontSize: 12, color: kTextGray, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(color: kTextLight, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: kBackgroundDark,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              hintText: 'Nhập nhận xét về chất lượng lô, lưu ý bảo quản hoặc lý do cần xử lý...',
              hintStyle: const TextStyle(color: kTextGray, fontSize: 12),
            ),
            validator: (val) {
              if (_status != 'PASSED' && (val == null || val.trim().isEmpty)) {
                return 'Vui lòng ghi rõ lý do chưa đạt hoặc yêu cầu xử lý lại';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConclusionOption(String val, String label, IconData icon, Color color) {
    final isSelected = _status == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _status = val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.18) : kBackgroundDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.2),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? color : kTextGray),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : kTextGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
