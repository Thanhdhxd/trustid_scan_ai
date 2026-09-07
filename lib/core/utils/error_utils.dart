String cleanErrorMessage(dynamic e) {
  final msg = e.toString();
  if (msg.contains('connection error') || 
      msg.contains('XMLHttpRequest') || 
      msg.contains('SocketException') ||
      msg.contains('HandshakeException')) {
    return 'Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền Internet.';
  }
  if (msg.startsWith('Exception: ')) {
    return msg.replaceFirst('Exception: ', '');
  }
  return msg;
}
