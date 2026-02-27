class IcdMapper {
  static const Map<String, String> _mapping = {
    'upper respiratory tract infection': 'J06.9',
    'acute pharyngitis': 'J02.9',
    'viral fever': 'B34.9',
    'general opd follow-up': 'Z09',
  };

  String resolveCode(String diagnosisName) {
    return _mapping[diagnosisName.toLowerCase()] ?? 'R69';
  }
}
