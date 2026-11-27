import 'dart:convert';
import 'package:dio/dio.dart';

/// Bộ giải mã và chuẩn hóa thông báo lỗi toàn ứng dụng TrustID.
/// Tự động chuyển đổi các ngoại lệ kỹ thuật (DioException, SocketException, mã HTTP 400/401/403/404/500...)
/// thành thông điệp tiếng Việt thân thiện, rõ ràng, dễ hiểu cho người dùng.
String cleanErrorMessage(dynamic error, {String? prefix}) {
  if (error == null) return '';

  String rawMsg = '';
  String? extractedMessage;
  int? statusCode;

  // 1. Phân tích chi tiết nếu error là DioException
  if (error is DioException) {
    statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    // Trích xuất message từ response trả về của backend
    if (responseData != null) {
      if (responseData is Map) {
        final messageVal = responseData['message'] ??
            responseData['error'] ??
            responseData['msg'] ??
            responseData['detail'] ??
            responseData['errors'];

        if (messageVal is List) {
          extractedMessage = messageVal.map((e) => e.toString()).join('\n');
        } else if (messageVal != null) {
          extractedMessage = messageVal.toString();
        }
      } else if (responseData is String) {
        final trimmed = responseData.trim();
        // Kiểm tra nếu là trang lỗi HTML mặc định (Nginx, IIS...)
        if (!trimmed.startsWith('<') && !trimmed.toLowerCase().contains('<!doctype')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map && decoded['message'] != null) {
              final m = decoded['message'];
              extractedMessage = m is List ? m.join('\n') : m.toString();
            } else {
              extractedMessage = trimmed;
            }
          } catch (_) {
            extractedMessage = trimmed;
          }
        }
      }
    }

    // Nếu không trích xuất được message từ body, kiểm tra theo loại lỗi DioExceptionType
    if (extractedMessage == null || extractedMessage.trim().isEmpty) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          rawMsg = 'Kết nối tới máy chủ quá thời gian (Timeout). Vui lòng thử lại.';
          break;
        case DioExceptionType.sendTimeout:
          rawMsg = 'Thời gian gửi dữ liệu quá lâu. Vui lòng kiểm tra lại đường truyền.';
          break;
        case DioExceptionType.receiveTimeout:
          rawMsg = 'Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút.';
          break;
        case DioExceptionType.badCertificate:
          rawMsg = 'Kết nối bảo mật không an toàn (Chứng chỉ SSL không hợp lệ).';
          break;
        case DioExceptionType.cancel:
          rawMsg = 'Yêu cầu đã bị hủy bỏ.';
          break;
        case DioExceptionType.connectionError:
          rawMsg = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng Internet.';
          break;
        case DioExceptionType.badResponse:
          rawMsg = _getMessageForStatusCode(statusCode, extractedMessage);
          break;
        case DioExceptionType.unknown:
        default:
          final underlying = error.error?.toString() ?? error.message ?? '';
          if (_isNetworkIssue(underlying)) {
            rawMsg = 'Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền Internet.';
          } else {
            rawMsg = _getMessageForStatusCode(statusCode, extractedMessage);
          }
          break;
      }
    } else {
      rawMsg = _sanitizeServerMessage(extractedMessage, statusCode);
    }
  } else {
    // 2. Nếu error là Exception thông thường hoặc String
    rawMsg = error.toString();
  }

  // 3. Xử lý các chuỗi lỗi đã bị bọc hoặc ép kiểu sang String
  rawMsg = _cleanStringifiedErrors(rawMsg);

  // 4. Dịch các thuật ngữ kỹ thuật tiếng Anh phổ biến sang tiếng Việt
  rawMsg = _translateEnglishTerms(rawMsg);

  // 5. Gắn prefix ngữ cảnh nếu có
  if (prefix != null && prefix.trim().isNotEmpty) {
    final cleanPrefix = prefix.trim();
    if (rawMsg.startsWith(cleanPrefix)) {
      return rawMsg;
    }
    return '$cleanPrefix: $rawMsg';
  }

  return rawMsg;
}

/// Ánh xạ mã phản hồi HTTP sang thông điệp tiếng Việt tiêu chuẩn
String _getMessageForStatusCode(int? code, [String? defaultMsg]) {
  if (defaultMsg != null && defaultMsg.trim().isNotEmpty) {
    return _sanitizeServerMessage(defaultMsg, code);
  }
  switch (code) {
    case 400:
      return 'Dữ liệu yêu cầu không hợp lệ hoặc thiếu thông tin cần thiết (Lỗi 400).';
    case 401:
      return 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại (Lỗi 401).';
    case 403:
      return 'Bạn không có quyền thực hiện thao tác này (Lỗi 403).';
    case 404:
      return 'Không tìm thấy dữ liệu yêu cầu trên hệ thống (Lỗi 404).';
    case 409:
      return 'Dữ liệu bị trùng lặp hoặc xung đột trạng thái (Lỗi 409).';
    case 410:
      return 'Chức năng này đã ngừng hỗ trợ theo phiên bản mới (Lỗi 410).';
    case 422:
      return 'Dữ liệu gửi lên không đúng định dạng quy định (Lỗi 422).';
    case 500:
      return 'Máy chủ gặp sự cố khi xử lý dữ liệu (Lỗi 500). Vui lòng thử lại sau.';
    case 502:
    case 503:
    case 504:
      return 'Hệ thống máy chủ đang bảo trì hoặc tạm thời quá tải (Lỗi $code). Vui lòng thử lại sau ít phút.';
    default:
      return code != null ? 'Yêu cầu thất bại với mã lỗi HTTP $code.' : 'Đã xảy ra lỗi không xác định.';
  }
}

/// Làm sạch các chuỗi lỗi thô chứa cú pháp kỹ thuật của DioException
String _cleanStringifiedErrors(String msg) {
  var text = msg.trim();

  // Bỏ tiền tố Exception:
  if (text.startsWith('Exception: ')) {
    text = text.substring(11).trim();
  }

  // Bắt các chuỗi lỗi DioException kỹ thuật dạng text
  if (text.contains('DioException') || text.contains('DioError')) {
    final dioRegex = RegExp(r'^(.*?)(?:DioException|DioError)(?:\s*\[([^\]]+)\])?:\s*(.*)$', dotAll: true);
    final match = dioRegex.firstMatch(text);

    String userPrefix = '';
    String dioType = '';
    String rest = text;

    if (match != null) {
      userPrefix = match.group(1)?.trim() ?? '';
      dioType = match.group(2)?.trim().toLowerCase() ?? '';
      rest = match.group(3)?.trim() ?? '';
    }

    String friendlyBody;
    if (rest.contains('status code of 500') || text.contains('status code of 500') || text.contains('code: 500')) {
      friendlyBody = 'Máy chủ gặp sự cố khi xử lý dữ liệu (Lỗi 500). Vui lòng thử lại sau.';
    } else if (rest.contains('status code of 401') || text.contains('status code of 401')) {
      friendlyBody = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';
    } else if (rest.contains('status code of 403') || text.contains('status code of 403')) {
      friendlyBody = 'Bạn không có quyền thực hiện thao tác này.';
    } else if (rest.contains('status code of 404') || text.contains('status code of 404')) {
      friendlyBody = 'Không tìm thấy dữ liệu yêu cầu trên hệ thống.';
    } else if (rest.contains('status code of 400') || text.contains('status code of 400')) {
      friendlyBody = 'Dữ liệu yêu cầu không hợp lệ hoặc thiếu thông tin.';
    } else if (rest.contains('status code of 409') || text.contains('status code of 409')) {
      friendlyBody = 'Dữ liệu bị trùng lặp hoặc xảy ra xung đột.';
    } else if (rest.contains('status code of 422') || text.contains('status code of 422')) {
      friendlyBody = 'Dữ liệu gửi lên không đúng định dạng.';
    } else if (dioType == 'connection error' || _isNetworkIssue(rest) || _isNetworkIssue(text)) {
      friendlyBody = 'Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền Internet.';
    } else if (dioType.contains('timeout') || rest.contains('timeout')) {
      friendlyBody = 'Kết nối quá thời gian chờ (Timeout). Vui lòng thử lại.';
    } else {
      friendlyBody = 'Máy chủ phản hồi không thành công. Vui lòng thử lại sau.';
    }

    if (userPrefix.isNotEmpty) {
      if (userPrefix.endsWith(':')) {
        return '$userPrefix $friendlyBody';
      }
      return '$userPrefix: $friendlyBody';
    }
    return friendlyBody;
  }

  // Kiểm tra mất kết nối mạng thông thường
  if (_isNetworkIssue(text)) {
    return 'Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền Internet.';
  }

  return text;
}

/// Kiểm tra xem chuỗi có phản ánh lỗi hạ tầng mạng / Internet không
bool _isNetworkIssue(String text) {
  final lower = text.toLowerCase();
  return lower.contains('connection error') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('socketexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('clientexception') ||
      lower.contains('no address associated with hostname');
}

/// Lọc bỏ các thông báo lỗi dạng crash Database (SQL query, foreign key, stack trace)
String _sanitizeServerMessage(String msg, int? statusCode) {
  final trimmed = msg.trim();
  final lower = trimmed.toLowerCase();

  if (lower.contains('syntax error') ||
      lower.contains('queryfailed') ||
      lower.contains('violates foreign key') ||
      lower.contains('violates not-null') ||
      lower.contains('duplicate key value') ||
      lower.contains('internal server error') ||
      lower.contains('unhandled exception') ||
      lower.contains('column does not exist') ||
      lower.contains('table does not exist') ||
      lower.contains('stack trace')) {
    if (statusCode == 500) {
      return 'Máy chủ gặp sự cố khi xử lý dữ liệu (Lỗi 500). Vui lòng thử lại sau.';
    }
    if (lower.contains('duplicate key value') || lower.contains('violates foreign key')) {
      return 'Dữ liệu đã tồn tại hoặc mã liên kết không hợp lệ.';
    }
    return 'Có lỗi xảy ra trong quá trình xử lý cơ sở dữ liệu. Vui lòng thử lại.';
  }

  return _translateEnglishTerms(trimmed);
}

/// Từ điển dịch nhanh các thông điệp lỗi tiếng Anh phổ biến sang tiếng Việt
String _translateEnglishTerms(String text) {
  var result = text;

  const translations = <String, String>{
    'Invalid credentials': 'Tài khoản hoặc mật khẩu không chính xác.',
    'User not found': 'Không tìm thấy thông tin tài khoản người dùng.',
    'Email already exists': 'Email này đã được sử dụng trên hệ thống.',
    'Phone already exists': 'Số điện thoại này đã được sử dụng trên hệ thống.',
    'Unauthorized': 'Phiên làm việc đã hết hạn hoặc không có quyền truy cập.',
    'Forbidden': 'Bạn không có quyền thực hiện thao tác này.',
    'Internal server error': 'Máy chủ gặp sự cố khi xử lý dữ liệu (Lỗi 500).',
    'Batch not found': 'Không tìm thấy thông tin lô hàng yêu cầu.',
    'Product not found': 'Không tìm thấy thông tin sản phẩm yêu cầu.',
    'Order not found': 'Không tìm thấy đơn hàng / lệnh sản xuất yêu cầu.',
    'Insufficient quantity': 'Khối lượng tồn kho không đủ để thực hiện.',
    'Serial already exists': 'Mã serial này đã tồn tại trong hệ thống.',
    'Serial not found': 'Mã serial không tồn tại trong kho mã.',
    'Bad Request': 'Yêu cầu không hợp lệ.',
    'Invalid token': 'Mã xác thực không hợp lệ hoặc đã hết hạn.',
    'Token expired': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
  };

  for (final entry in translations.entries) {
    if (result.trim() == entry.key) {
      return entry.value;
    }
    if (result.contains(entry.key)) {
      result = result.replaceAll(entry.key, entry.value);
    }
  }

  return result;
}

/// Thông tin lỗi HTTP đã chuẩn hóa cho phân hệ Lệnh Sản Xuất (`400`, `403`, `404`, `409`, `410`).
class SupplyHttpError {
  final int? statusCode;
  final String? errorCode;
  final String message;

  const SupplyHttpError({
    this.statusCode,
    this.errorCode,
    required this.message,
  });

  bool get isBadRequest => statusCode == 400;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isGone => statusCode == 410;
  bool get isPlanLocked =>
      errorCode == 'PLAN_FEATURE_LOCKED' ||
      errorCode == 'PLAN_EXPIRED' ||
      errorCode == 'TENANT_SUSPENDED';
}

/// Phân tích `DioException` / exception bất kỳ thành `SupplyHttpError` thống nhất.
SupplyHttpError parseSupplyHttpError(Object error) {
  int? statusCode;
  String? errorCode;
  if (error is DioException) {
    statusCode = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map && data['code'] != null) {
      errorCode = data['code'].toString();
    }
  }

  var msg = cleanErrorMessage(error);
  if (msg.isEmpty) {
    if (errorCode == 'PLAN_FEATURE_LOCKED') {
      msg = 'Tính năng này không nằm trong gói dịch vụ hiện tại.';
    } else if (errorCode == 'PLAN_EXPIRED') {
      msg = 'Gói dịch vụ của doanh nghiệp đã hết hạn.';
    } else if (errorCode == 'TENANT_SUSPENDED') {
      msg = 'Tài khoản doanh nghiệp đang tạm khóa.';
    }
  }

  return SupplyHttpError(
    statusCode: statusCode,
    errorCode: errorCode,
    message: msg,
  );
}

